from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional
import re

from .spec import InstructionSpec, get_spec


class AsmError(Exception):
    pass


@dataclass
class IRInstruction:
    addr: int  # word address
    mnemonic: str
    operands: List[str]
    src_line: str
    lineno: int


@dataclass
class IRDirective:
    addr: int  # word address
    name: str
    args: List[str]
    src_line: str
    lineno: int


@dataclass
class IRMacro:
    addr: int
    kind: str  # e.g., 'JCCUI', 'JSRUI'
    operands: List[str]
    src_line: str
    lineno: int


class Assembler:
    def __init__(self, origin: int = 0) -> None:
        # PC counts 24-bit words
        self.origin = origin
        self.symbols: Dict[str, int] = {}
        self._ir: List[IRInstruction | IRDirective | IRMacro] = []
        self._pending_equ: List[tuple[str, str, int]] = []  # (name, expr, lineno)

    # Public API
    def assemble_path(self, path: Path) -> List[int]:
        text = path.read_text(encoding="utf-8")
        return self.assemble(text)

    def assemble(self, source: str) -> List[int]:
        self.symbols.clear()
        self._ir.clear()
        self._pending_equ.clear()
        self._pass1(source)
        self._resolve_pending_equ()
        return self._pass2()

    # Output helpers
    @staticmethod
    def pack_words_bin(words: List[int]) -> bytes:
        # Little-endian per word: [low, mid, high]
        out = bytearray()
        for w in words:
            w &= 0xFFFFFF
            out.append(w & 0xFF)
            out.append((w >> 8) & 0xFF)
            out.append((w >> 16) & 0xFF)
        return bytes(out)

    @staticmethod
    def pack_words_hex(words: List[int]) -> str:
        # One 6-hex-digit word per line, uppercase
        return "\n".join(f"{(w & 0xFFFFFF):06X}" for w in words) + "\n"

    # Internals
    def _pass1(self, source: str) -> None:
        pc = int(self.origin)
        for lineno, raw in enumerate(source.splitlines(), start=1):
            line = self._strip_comment(raw)
            if not line:
                continue

            label, rest = self._split_label(line)
            if label is not None:
                if label in self.symbols:
                    raise AsmError(f"Duplicate label '{label}' at line {lineno}")
                self.symbols[label] = pc
                line = rest
                if not line:
                    # Label-only line
                    continue

            if line.startswith('.'):
                dname, dargs = self._parse_directive(line)
                # Only support .org and .dw24 in skeleton
                if dname == 'org':
                    # Require numeric literal for skeleton
                    if not dargs:
                        raise AsmError(f".org requires an address at line {lineno}")
                    try:
                        pc = self._parse_num(dargs[0])
                    except Exception as e:
                        raise AsmError(f".org parse error at line {lineno}: {e}")
                    # Keep directive in IR for optional listing/debug
                    self._ir.append(IRDirective(pc, dname, dargs, raw, lineno))
                elif dname == 'equ':
                    # .equ NAME, EXPR
                    if len(dargs) != 2:
                        raise AsmError(f".equ requires NAME, EXPR at line {lineno}")
                    name, expr = dargs[0], dargs[1]
                    if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", name):
                        raise AsmError(f"Invalid symbol name in .equ at line {lineno}: '{name}'")
                    if name in self.symbols:
                        raise AsmError(f"Redefinition of symbol '{name}' in .equ at line {lineno}")
                    # Try to evaluate now; if fails (forward ref), queue for later
                    try:
                        val = self._resolve_expr(expr, width=48, is_signed=False, pc=pc)
                        self.symbols[name] = val
                    except AsmError:
                        self._pending_equ.append((name, expr, lineno))
                elif dname in ('dw24', 'diad'):
                    self._ir.append(IRDirective(pc, dname, dargs, raw, lineno))
                    pc += len(dargs)
                elif dname == 'align':
                    if len(dargs) != 1:
                        raise AsmError(f".align requires a single power-of-two value at line {lineno}")
                    try:
                        n = self._parse_num(dargs[0])
                    except Exception as e:
                        raise AsmError(f".align parse error at line {lineno}: {e}")
                    if n <= 0:
                        raise AsmError(f".align value must be > 0 at line {lineno}")
                    aligned = ((pc + n - 1) // n) * n
                    # Record as an ORG directive so pass2 pads as needed
                    self._ir.append(IRDirective(aligned, 'org', [str(aligned)], raw, lineno))
                    pc = aligned
                else:
                    raise AsmError(f"Unknown directive '.{dname}' at line {lineno}")
                continue

            # Instruction
            mnem, ops = self._parse_instruction(line)
            if mnem in ("JCCUI", "JSRUI", "SWIUI"):
                # Macro placeholder; expands to 4 instructions in pass2
                self._ir.append(IRMacro(pc, mnem, ops, raw, lineno))
                pc += 4
            else:
                self._ir.append(IRInstruction(pc, mnem, ops, raw, lineno))
                pc += 1

    def _pass2(self) -> List[int]:
        words: List[int] = []
        for item in self._ir:
            if isinstance(item, IRDirective):
                if item.name == 'org':
                    # Emit padding if there is a gap
                    gap = item.addr - len(words) - self.origin
                    if gap > 0:
                        words.extend([0] * gap)
                elif item.name == 'dw24':
                    for a in item.args:
                        val = self._resolve_expr(a, width=24, is_signed=False, pc=len(words) + self.origin)
                        if val < 0 or val > 0xFFFFFF:
                            raise AsmError(
                                f".dw24 value out of range at line {item.lineno}: {val}"
                            )
                        words.append(val & 0xFFFFFF)
                continue

            if isinstance(item, IRMacro):
                # Expand macros into concrete instructions
                if item.kind == "JCCUI":
                    if len(item.operands) != 2:
                        raise AsmError(f"JCCui requires 2 operands at line {item.lineno}")
                    cc_tok, expr_tok = item.operands
                    imm48 = self._resolve_expr(expr_tok, width=48, is_signed=False, pc=item.addr, pc_relative=False)
                    parts = [
                        (2, (imm48 >> 36) & 0xFFF),
                        (1, (imm48 >> 24) & 0xFFF),
                        (0, (imm48 >> 12) & 0xFFF),
                    ]
                    lui = get_spec("LUIUI"); jccui = get_spec("JCCUI")
                    if not lui or not jccui:
                        raise AsmError("Missing spec for LUIui/JCCui")
                    for x, imm12 in parts:
                        w = lui.encode([str(x), f"#{imm12}"], resolve_expr=self._resolve_expr, pc=item.addr)
                        words.append(w & 0xFFFFFF)
                    w = jccui.encode([cc_tok, f"#{imm48 & 0xFFF}"], resolve_expr=self._resolve_expr, pc=item.addr)
                    words.append(w & 0xFFFFFF)
                elif item.kind == "JSRUI":
                    if len(item.operands) != 1:
                        raise AsmError(f"JSRui requires 1 operand at line {item.lineno}")
                    (expr_tok,) = item.operands
                    imm48 = self._resolve_expr(expr_tok, width=48, is_signed=False, pc=item.addr, pc_relative=False)
                    parts = [
                        (2, (imm48 >> 36) & 0xFFF),
                        (1, (imm48 >> 24) & 0xFFF),
                        (0, (imm48 >> 12) & 0xFFF),
                    ]
                    lui = get_spec("LUIUI"); jsrui = get_spec("JSRUI")
                    if not lui or not jsrui:
                        raise AsmError("Missing spec for LUIui/JSRui")
                    for x, imm12 in parts:
                        w = lui.encode([str(x), f"#{imm12}"], resolve_expr=self._resolve_expr, pc=item.addr)
                        words.append(w & 0xFFFFFF)
                    w = jsrui.encode([f"#{imm48 & 0xFFF}"], resolve_expr=self._resolve_expr, pc=item.addr)
                    words.append(w & 0xFFFFFF)
                elif item.kind == "SWIUI":
                    if len(item.operands) != 1:
                        raise AsmError(f"SWIui requires 1 operand at line {item.lineno}")
                    (expr_tok,) = item.operands
                    imm48 = self._resolve_expr(expr_tok, width=48, is_signed=False, pc=item.addr, pc_relative=False)
                    parts = [
                        (2, (imm48 >> 36) & 0xFFF),
                        (1, (imm48 >> 24) & 0xFFF),
                        (0, (imm48 >> 12) & 0xFFF),
                    ]
                    lui = get_spec("LUIUI"); swi = get_spec("SWI")
                    if not lui or not swi:
                        raise AsmError("Missing spec for LUIui/SWI")
                    for x, imm12 in parts:
                        w = lui.encode([str(x), f"#{imm12}"], resolve_expr=self._resolve_expr, pc=item.addr)
                        words.append(w & 0xFFFFFF)
                    w = swi.encode([f"#{imm48 & 0xFFF}"], resolve_expr=self._resolve_expr, pc=item.addr)
                    words.append(w & 0xFFFFFF)
                else:
                    raise AsmError(f"Unknown macro '{item.kind}' at line {item.lineno}")
                continue

            spec = get_spec(item.mnemonic)
            if spec is None:
                raise AsmError(
                    f"Unknown or unsupported mnemonic '{item.mnemonic}' at line {item.lineno}"
                )
            try:
                w = spec.encode(
                    item.operands,
                    resolve_expr=self._resolve_expr,
                    pc=item.addr,
                )
            except Exception as e:
                raise AsmError(
                    f"Encoding error at line {item.lineno} ({item.src_line.strip()}): {e}"
                )
            words.append(w & 0xFFFFFF)
        return words

    @staticmethod
    def _strip_comment(s: str) -> str:
        # Comments start with ';'
        if ';' in s:
            s = s.split(';', 1)[0]
        return s.strip()

    @staticmethod
    def _split_label(s: str) -> tuple[Optional[str], str]:
        # Leading label:  label: <rest>
        # Allow whitespace before label
        if ':' in s:
            before, after = s.split(':', 1)
            if before.strip() and (after == '' or after.lstrip() == after):
                # Treat as label only if ':' is not part of operand tokens
                return before.strip(), after.strip()
        return None, s

    @staticmethod
    def _parse_directive(s: str) -> tuple[str, List[str]]:
        # .name arg1, arg2, ...
        tok = s[1:].strip()
        parts = tok.split(None, 1)
        name = parts[0].lower()
        rest = parts[1] if len(parts) > 1 else ''
        args = [a.strip() for a in rest.split(',')] if rest else []
        return name, [a for a in args if a]

    @staticmethod
    def _parse_instruction(s: str) -> tuple[str, List[str]]:
        # MNEMONIC op1, op2, ...  (operands are raw strings parsed by spec)
        parts = s.split(None, 1)
        if not parts:
            raise AsmError("Empty instruction line")
        mnem = parts[0].strip().upper()
        ops: List[str] = []
        if len(parts) > 1:
            raw_ops = [o.strip() for o in parts[1].split(',')]
            raw_ops = [o for o in raw_ops if o]
            ops = []
            # Patterns
            pat_expr_paren_ar = re.compile(r"^\s*(.*?)\s*\(\s*(AR\d)\s*\)\s*$", re.IGNORECASE)
            pat_expr_paren_sr = re.compile(r"^\s*(.*?)\s*\(\s*(SR\d|PC|LR|SSP|FL)\s*\)\s*$", re.IGNORECASE)
            pat_ar_plus_expr = re.compile(r"^(AR\d)\s*\+\s*(.+)$", re.IGNORECASE)
            pat_sr_plus_expr = re.compile(r"^(SR\d|PC|LR|SSP|FL)\s*\+\s*(.+)$", re.IGNORECASE)
            pat_pc_plus_dr = re.compile(r"^PC\s*\+\s*(DR\d)$", re.IGNORECASE)
            for tok in raw_ops:
                # Normalize 'PC + DRx' => DRx (for BCCsr encoding) FIRST to avoid SR+expr rule catching it
                m = pat_pc_plus_dr.match(tok)
                if m:
                    ops.append(m.group(1).upper())
                    continue
                # Normalize 'expr(ARx)' => expr, ARx
                m = pat_expr_paren_ar.match(tok)
                if m and m.group(1).strip() != "":
                    expr = m.group(1).strip()
                    ar = m.group(2).upper()
                    ops.append(expr)
                    ops.append(ar)
                    continue
                # Normalize 'expr(SRx)' => expr, SRx
                m = pat_expr_paren_sr.match(tok)
                if m and m.group(1).strip() != "":
                    expr = m.group(1).strip()
                    sr = m.group(2).upper()
                    ops.append(expr)
                    ops.append(sr)
                    continue
                # Normalize 'ARx + expr' => ARx, expr
                m = pat_ar_plus_expr.match(tok)
                if m:
                    ar = m.group(1).upper()
                    expr = m.group(2).strip()
                    ops.append(ar)
                    ops.append(expr)
                    continue
                # Normalize 'SRx + expr' => SRx, expr
                m = pat_sr_plus_expr.match(tok)
                if m:
                    sr = m.group(1).upper()
                    expr = m.group(2).strip()
                    ops.append(sr)
                    ops.append(expr)
                    continue
                ops.append(tok)
        return mnem, ops

    @staticmethod
    def _parse_num(token: str) -> int:
        t = token.strip()
        if t.startswith('#'):
            t = t[1:]
        base = 10
        if t.startswith(('0x', '0X')):
            base = 16
        elif t.startswith(('0b', '0B')):
            base = 2
        elif t.startswith(('0o', '0O')):
            base = 8
        return int(t, base)

    # Expression resolver for immediates (labels, '.', + and -)
    def _resolve_expr(self, token: str, width: int, is_signed: bool, pc: int, pc_relative: bool=False) -> int:
        t = token.strip()
        if t.startswith('#'):
            t = t[1:]
        # Replace '.' with current PC (word address)
        t = t.replace('.', str(pc))

        # Simple left-to-right evaluation of +/- terms
        total = 0
        buf = ''
        sign = 1
        i = 0
        def flush(term: str, sgn: int) -> None:
            nonlocal total
            term = term.strip()
            if not term:
                return
            val: Optional[int]
            val = None
            # symbol?
            if term in self.symbols:
                val = self.symbols[term]
            else:
                # numeric?
                try:
                    val = self._parse_num(term)
                except Exception:
                    raise AsmError(f"Unknown symbol or invalid number in expression: '{term}'")
            total += sgn * int(val)

        while i < len(t):
            ch = t[i]
            if ch in '+-':
                flush(buf, sign)
                buf = ''
                sign = 1 if ch == '+' else -1
                i += 1
                continue
            buf += ch
            i += 1
        flush(buf, sign)

        # Convert absolute to PC-relative if requested and token looked like a bare symbol
        # Heuristic: if expression had no + or - and resolved to a symbol value, above logic already produced the symbol value.
        # Apply pc-relative conversion here.
        if pc_relative:
            total = total - pc

        # Range check and two's complement if signed
        if is_signed:
            minv = -(1 << (width - 1))
            maxv = (1 << (width - 1)) - 1
            if total < minv or total > maxv:
                raise AsmError(f"Signed immediate out of range {minv}..{maxv}: {total} in '{token}'")
            total &= (1 << width) - 1
        else:
            maxv = (1 << width) - 1
            if total < 0 or total > maxv:
                raise AsmError(f"Immediate out of range 0..{maxv}: {total} in '{token}'")
        return total

    def _resolve_pending_equ(self) -> None:
        if not self._pending_equ:
            return
        pend = list(self._pending_equ)
        resolved_any = True
        # Try up to len(pend) passes
        for _ in range(len(pend)):
            if not pend:
                break
            next_pend: List[tuple[str, str, int]] = []
            for name, expr, lineno in pend:
                try:
                    val = self._resolve_expr(expr, width=48, is_signed=False, pc=self.origin)
                    self.symbols[name] = val
                except AsmError:
                    next_pend.append((name, expr, lineno))
            if len(next_pend) == len(pend):
                break
            pend = next_pend
        if pend:
            msgs = ", ".join(f"{n} (line {ln})" for n, _, ln in pend)
            raise AsmError(f"Unresolved .equ forward references: {msgs}")


def assemble_file(path: Path, origin: int = 0) -> bytes:
    asm = Assembler(origin=origin)
    words = asm.assemble_path(path)
    return asm.pack_words_bin(words)
