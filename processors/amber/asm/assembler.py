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
        # Macro system (user-defined)
        self._macros: Dict[str, tuple[List[str], List[str]]] = {}  # NAME -> (params, body_lines)
        self._macro_expansion_id: int = 0

    # Public API
    def assemble_path(self, path: Path) -> List[int]:
        """Assemble a single file with support for .include.

        Relative includes are resolved against the including file's directory.
        """
        text = path.read_text(encoding="utf-8")
        pre = self._expand_includes(text, base_stack=[path.parent])
        return self._assemble_after_preprocess(pre)

    # assemble_paths removed: prefer .include within a single entry file

    def assemble(self, source: str) -> List[int]:
        self.symbols.clear()
        # Preload built-in symbols (CSR indices, math constants)
        try:
            from .builtins import BUILTIN_SYMBOLS  # local import to avoid import cycles during tooling
            self.symbols.update(BUILTIN_SYMBOLS)
        except Exception:
            # Builtins are optional; continue if unavailable
            pass
        self._ir.clear()
        self._pending_equ.clear()
        # When assembling from a raw string, resolve includes relative to CWD.
        pre = self._expand_includes(source, base_stack=[Path.cwd()])
        return self._assemble_after_preprocess(pre)

    # Common path after include expansion
    def _assemble_after_preprocess(self, preprocessed: str) -> List[int]:
        expanded = self._expand_macros(preprocessed)
        self._pass1(expanded)
        self._resolve_pending_equ()
        return self._pass2()

    # ---- Include preprocessor ----------------------------------------------
    def _expand_includes(self, source: str, base_stack: List[Path], depth: int = 0) -> str:
        if depth > 100:
            raise AsmError("Include depth too deep (possible recursion loop)")
        # Be tolerant of UTF-8 BOM at start of files (common on Windows)
        source = source.lstrip('\ufeff')
        out: List[str] = []
        for raw in source.splitlines():
            s = self._strip_comment(raw)
            if not s:
                out.append(raw)
                continue
            label, rest = self._split_label(s)
            probe = rest if rest is not None else s
            if probe.lower().startswith('.include'):
                # Parse path argument
                arg = probe[len('.include'):].strip()
                if not arg:
                    raise AsmError(".include requires a path argument")
                inc_spec = self._parse_include_arg(arg)
                inc_path = self._resolve_include_path(inc_spec, base_stack)
                try:
                    inc_text = inc_path.read_text(encoding='utf-8')
                except Exception as e:
                    raise AsmError(f"Failed to read include '{inc_path}': {e}")
                # Emit optional call-site label before included content
                if label:
                    out.append(f"{label}:")
                # Delimit include region with comments for clarity
                out.append(f"; ---- begin include: {inc_path} ----")
                out.append(
                    self._expand_includes(inc_text, base_stack=base_stack + [inc_path.parent], depth=depth + 1)
                )
                out.append(f"; ---- end include: {inc_path} ----")
                continue
            # Not an include: keep original raw line to preserve formatting
            out.append(raw)
        return "\n".join(out) + ("\n" if not source.endswith("\n") else "")

    @staticmethod
    def _parse_include_arg(arg: str) -> str:
        a = arg.strip()
        if not a:
            raise AsmError(".include missing path argument")
        if a[0] in ('"', "'"):
            q = a[0]
            j = a.find(q, 1)
            if j == -1:
                raise AsmError(".include unterminated quoted path")
            return a[1:j]
        if a[0] == '<':
            j = a.find('>')
            if j == -1:
                raise AsmError(".include unterminated angle-bracket path")
            return a[1:j]
        # Bare token up to whitespace
        return a.split()[0]

    @staticmethod
    def _resolve_include_path(spec: str, base_stack: List[Path]) -> Path:
        p = Path(spec)
        if p.is_absolute() and p.exists():
            return p
        # Resolve relative to the current including file's directory (top of stack)
        if base_stack:
            cand = (base_stack[-1] / spec).resolve()
            if cand.exists():
                return cand
        # Fallback: relative to CWD
        cand = (Path.cwd() / spec).resolve()
        if cand.exists():
            return cand
        # As last resort, return the spec path (it will likely fail on read)
        return p

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
                # Directives handled here: .org, .equ, .dw24/.diad
                if dname == 'org':
                    # Require numeric literal for origin (expressions allowed in .equ)
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
                else:
                    raise AsmError(f"Unknown directive '.{dname}' at line {lineno}")
                continue

            # Instruction
            mnem, ops = self._parse_instruction(line)
            if mnem in ("JCCUI", "JSRUI", "SWIUI"):
                # Macro placeholder; expands to 4 instructions in pass2
                self._ir.append(IRMacro(pc, mnem, ops, raw, lineno))
                pc += 4
            elif mnem in (
                # Async int24 math convenience macros
                "MULU24", "MULS24",
                "DIVU24", "DIVS24",
                "MODU24", "MODS24",
                "SQRTU24",
                "ABS_S24",
                "MIN_U24", "MAX_U24", "MIN_S24", "MAX_S24",
                "CLAMP_U24", "CLAMP_S24",
                # 24/12-bit add/sub/neg via async unit
                "ADD24", "SUB24", "NEG24",
                "ADD12", "SUB12", "NEG12",
                # Packed 12-bit diad math
                "MUL12", "DIV12", "MOD12", "SQRT12", "ABS12",
                "MIN12_U", "MAX12_U", "MIN12_S", "MAX12_S",
                "CLAMP12_U", "CLAMP12_S",
            ):
                # Estimate expansion size to advance PC correctly
                k = mnem
                def need_b() -> bool:
                    return k not in ("SQRTU24", "ABS_S24", "NEG24", "NEG12", "SQRT12", "ABS12")
                def need_c() -> bool:
                    return k.startswith("CLAMP_") or k.startswith("CLAMP12_")
                def res1_needed() -> bool:
                    return k in ("MULU24", "MULS24", "DIVU24", "DIVS24", "DIV12")
                base = 0
                base += 1  # OPA write
                if need_b():
                    base += 1  # OPB write
                if need_c():
                    base += 1  # OPC write
                base += 1  # MOVui ctrl
                base += 1  # CSRWR ctrl
                base += 3  # poll: CSRRD/ANDui/BCCso
                base += 1  # RES0 read
                if res1_needed():
                    base += 1  # RES1 read
                self._ir.append(IRMacro(pc, mnem, ops, raw, lineno))
                pc += base
            elif mnem in ("PACK_DIAD", "UNPACK_DIAD"):
                # Fixed-size helper macros for 12-bit diads
                k = mnem
                base = 6 if k == "PACK_DIAD" else 5
                self._ir.append(IRMacro(pc, mnem, ops, raw, lineno))
                pc += base
            elif mnem in ("DIAD_MOVUI",):
                # Build diad from two immediates into DRdst
                base = 3
                self._ir.append(IRMacro(pc, mnem, ops, raw, lineno))
                pc += base
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
                elif item.name in ('dw24','diad'):
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
                    lui = get_spec("LUIUI"); sysc = get_spec("SYSCALL")
                    if not lui or not sysc:
                        raise AsmError("Missing spec for LUIui/SYSCALL")
                    for x, imm12 in parts:
                        w = lui.encode([str(x), f"#{imm12}"], resolve_expr=self._resolve_expr, pc=item.addr)
                        words.append(w & 0xFFFFFF)
                    w = sysc.encode([f"#{imm48 & 0xFFF}"], resolve_expr=self._resolve_expr, pc=item.addr)
                    words.append(w & 0xFFFFFF)
                elif item.kind in (
                    "MULU24", "MULS24",
                    "DIVU24", "DIVS24",
                    "MODU24", "MODS24",
                    "SQRTU24",
                    "ABS_S24",
                    "MIN_U24", "MAX_U24", "MIN_S24", "MAX_S24",
                    "CLAMP_U24", "CLAMP_S24",
                    # new math ops
                    "ADD24", "SUB24", "NEG24",
                    "ADD12", "SUB12", "NEG12",
                    # packed 12-bit diad ops
                    "MUL12", "DIV12", "MOD12", "SQRT12", "ABS12",
                    "MIN12_U", "MAX12_U", "MIN12_S", "MAX12_S",
                    "CLAMP12_U", "CLAMP12_S",
                    # diad helpers
                    "PACK_DIAD", "UNPACK_DIAD", "DIAD_MOVUI",
                ):
                    # Expand async int24 math macro into CSR writes + poll + reads
                    k = item.kind
                    ops = item.operands
                    pc_here = item.addr

                    # Helper to encode with advancing PC
                    def emit(mn: str, operands: List[str]) -> None:
                        nonlocal pc_here
                        spec = get_spec(mn)
                        if not spec:
                            raise AsmError(f"Missing spec for '{mn}' (expanding {k})")
                        w = spec.encode(operands, resolve_expr=self._resolve_expr, pc=pc_here)
                        words.append(w & 0xFFFFFF)
                        pc_here += 1

                    # Validate operands per macro
                    def expect(n: int) -> None:
                        if len(ops) != n:
                            raise AsmError(f"{k} expects {n} operands at line {item.lineno}")

                    # Map macro -> op constant symbol
                    OP_SYM = {
                        "MULU24": "MATH_OP_MULU",
                        "MULS24": "MATH_OP_MULS",
                        "DIVU24": "MATH_OP_DIVU",
                        "DIVS24": "MATH_OP_DIVS",
                        "MODU24": "MATH_OP_MODU",
                        "MODS24": "MATH_OP_MODS",
                        "SQRTU24": "MATH_OP_SQRTU",
                        "ABS_S24": "MATH_OP_ABS_S",
                        "MIN_U24": "MATH_OP_MIN_U",
                        "MAX_U24": "MATH_OP_MAX_U",
                        "MIN_S24": "MATH_OP_MIN_S",
                        "MAX_S24": "MATH_OP_MAX_S",
                        "CLAMP_U24": "MATH_OP_CLAMP_U",
                        "CLAMP_S24": "MATH_OP_CLAMP_S",
                        # new
                        "ADD24": "MATH_OP_ADD24",
                        "SUB24": "MATH_OP_SUB24",
                        "NEG24": "MATH_OP_NEG24",
                        "ADD12": "MATH_OP_ADD12",
                        "SUB12": "MATH_OP_SUB12",
                        "NEG12": "MATH_OP_NEG12",
                        # packed 12-bit diad
                        "MUL12": "MATH_OP_MUL12",
                        "DIV12": "MATH_OP_DIV12",
                        "MOD12": "MATH_OP_MOD12",
                        "SQRT12": "MATH_OP_SQRT12",
                        "ABS12": "MATH_OP_ABS12",
                        "MIN12_U": "MATH_OP_MIN12_U",
                        "MAX12_U": "MATH_OP_MAX12_U",
                        "MIN12_S": "MATH_OP_MIN12_S",
                        "MAX12_S": "MATH_OP_MAX12_S",
                        "CLAMP12_U": "MATH_OP_CLAMP12_U",
                        "CLAMP12_S": "MATH_OP_CLAMP12_S",
                    }
                    op_sym = OP_SYM.get(k)

                    # Expand per macro
                    if k in ("MULU24", "MULS24"):
                        expect(5)
                        a, b, d_lo, d_hi, tmp = ops
                        # Write operands
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("CSRWR", [b, "#MATH_OPB"])   # OPB := b
                        # Start
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        # Poll ready
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # loop until READY!=0
                        # Read results
                        emit("CSRRD", ["#MATH_RES0", d_lo])
                        emit("CSRRD", ["#MATH_RES1", d_hi])
                    elif k in ("DIVU24", "DIVS24"):
                        expect(5)
                        a, b, d_q, d_r, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("CSRWR", [b, "#MATH_OPB"])   # OPB := b
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_q])
                        emit("CSRRD", ["#MATH_RES1", d_r])
                    elif k in ("MODU24", "MODS24"):
                        expect(4)
                        a, b, d_r, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("CSRWR", [b, "#MATH_OPB"])   # OPB := b
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_r])
                    elif k == "SQRTU24":
                        expect(3)
                        a, d_res, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k == "ABS_S24":
                        expect(3)
                        a, d_res, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k in ("MIN_U24", "MAX_U24", "MIN_S24", "MAX_S24"):
                        expect(4)
                        a, b, d_res, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("CSRWR", [b, "#MATH_OPB"])   # OPB := b
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k in ("CLAMP_U24", "CLAMP_S24"):
                        expect(5)
                        a, d_min, d_max, d_res, tmp = ops
                        emit("CSRWR", [a,     "#MATH_OPA"])  # OPA := a
                        emit("CSRWR", [d_max, "#MATH_OPB"])  # OPB := max
                        emit("CSRWR", [d_min, "#MATH_OPC"])  # OPC := min
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])   # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])       # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k in ("MUL12",):
                        expect(4)
                        a, b, d_res, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("CSRWR", [b, "#MATH_OPB"])   # OPB := b
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k in ("DIV12",):
                        expect(5)
                        a, b, d_q, d_r, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("CSRWR", [b, "#MATH_OPB"])   # OPB := b
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_q])
                        emit("CSRRD", ["#MATH_RES1", d_r])
                    elif k in ("MOD12",):
                        expect(4)
                        a, b, d_r, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("CSRWR", [b, "#MATH_OPB"])   # OPB := b
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_r])
                    elif k in ("SQRT12", "ABS12"):
                        expect(3)
                        a, d_res, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k in ("MIN12_U", "MAX12_U", "MIN12_S", "MAX12_S"):
                        expect(4)
                        a, b, d_res, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("CSRWR", [b, "#MATH_OPB"])   # OPB := b
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k in ("CLAMP12_U", "CLAMP12_S"):
                        expect(5)
                        a, d_min, d_max, d_res, tmp = ops
                        emit("CSRWR", [a,     "#MATH_OPA"])  # OPA := a
                        emit("CSRWR", [d_max, "#MATH_OPB"])  # OPB := max
                        emit("CSRWR", [d_min, "#MATH_OPC"])  # OPC := min
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])   # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])       # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k in ("ADD24", "SUB24"):
                        expect(4)
                        a, b, d_res, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("CSRWR", [b, "#MATH_OPB"])   # OPB := b
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k == "NEG24":
                        expect(3)
                        a, d_res, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k in ("ADD12", "SUB12"):
                        expect(4)
                        a, b, d_res, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("CSRWR", [b, "#MATH_OPB"])   # OPB := b
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k == "NEG12":
                        expect(3)
                        a, d_res, tmp = ops
                        emit("CSRWR", [a, "#MATH_OPA"])   # OPA := a
                        emit("MOVUI", [f"#MATH_CTRL_START + {op_sym}", tmp])
                        emit("CSRWR", [tmp, "#MATH_CTRL"])  # kick
                        emit("CSRRD", ["#MATH_STATUS", tmp])
                        emit("ANDUI", ["#MATH_STATUS_READY", tmp])
                        emit("BCCSO", ["EQ", ".-2"])  # wait
                        emit("CSRRD", ["#MATH_RES0", d_res])
                    elif k == "PACK_DIAD":
                        # PACK_DIAD DRhi, DRlo, DRdst, DRtmp
                        expect(4)
                        dr_hi, dr_lo, dr_dst, dr_tmp = ops
                        emit("MOVUR", [dr_hi, dr_dst])
                        emit("ANDUI", ["#0xFFF", dr_dst])
                        emit("SHLUI", ["#12", dr_dst])
                        emit("MOVUR", [dr_lo, dr_tmp])
                        emit("ANDUI", ["#0xFFF", dr_tmp])
                        emit("ORUR",  [dr_tmp, dr_dst])
                    elif k == "UNPACK_DIAD":
                        # UNPACK_DIAD DRsrc, DRhi, DRlo
                        expect(3)
                        dr_src, dr_hi, dr_lo = ops
                        emit("MOVUR", [dr_src, dr_lo])
                        emit("ANDUI", ["#0xFFF", dr_lo])
                        emit("MOVUR", [dr_src, dr_hi])
                        emit("SHRUI", ["#12", dr_hi])
                        emit("ANDUI", ["#0xFFF", dr_hi])
                    elif k == "DIAD_MOVUI":
                        # DIAD_MOVUI DRdst, #hi12, #lo12
                        expect(3)
                        dr_dst, imm_hi, imm_lo = ops
                        emit("MOVUI", [imm_hi, dr_dst])
                        emit("SHLUI", ["#12", dr_dst])
                        emit("ORUI",  [imm_lo, dr_dst])
                    else:
                        raise AsmError(f"Unknown math macro '{k}' at line {item.lineno}")
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
        # CSR operand order normalization for friendlier syntax
        # Allow: CSRWR CSR_NAME, DRs  -> canonical: CSRWR DRs, CSR_NAME
        # Allow: CSRRD DRt, CSR_NAME  -> canonical: CSRRD CSR_NAME, DRt
        if mnem.upper() == "CSRWR" and len(ops) == 2:
            lhs, rhs = ops[0], ops[1]
            if re.match(r"^DR\d+$", rhs.strip(), re.IGNORECASE) and not re.match(r"^DR\d+$", lhs.strip(), re.IGNORECASE):
                ops = [rhs.upper(), lhs]
        if mnem.upper() == "CSRRD" and len(ops) == 2:
            lhs, rhs = ops[0], ops[1]
            if re.match(r"^DR\d+$", lhs.strip(), re.IGNORECASE) and not re.match(r"^DR\d+$", rhs.strip(), re.IGNORECASE):
                ops = [rhs, lhs.upper()]
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

    # ---- Macro preprocessor -------------------------------------------------
    def _expand_macros(self, source: str) -> str:
        """Implements a lightweight macro preprocessor with:
        - .macro NAME [arg1[,arg2..]] ... .endm: define a macro
        - parameter references inside body using {arg} placeholders
        - .local name[,name..]: mark labels or symbols as local-per-expansion
        Macros may be used anywhere after definition. Expansion is recursive.
        """
        self._macros.clear()

        lines = source.splitlines()

        # First pass: collect all macro definitions and strip them out
        i = 0
        kept_lines: List[str] = []
        while i < len(lines):
            raw = lines[i]
            line = self._strip_comment(raw)
            if line.lower().startswith('.macro'):
                # Parse: .macro NAME [args...]
                head = line[len('.macro'):].strip()
                if not head:
                    raise AsmError(f".macro missing name at line {i+1}")
                parts = head.split(None, 1)
                name = parts[0].strip()
                rest = parts[1] if len(parts) > 1 else ''
                # Args may be comma or whitespace separated; normalize by comma first
                params: List[str] = []
                if rest:
                    # If whitespace separated, allow both. Split by comma then by whitespace.
                    tmp = []
                    for seg in rest.split(','):
                        seg = seg.strip()
                        if not seg:
                            continue
                        tmp.extend([t for t in seg.split() if t])
                    params = [p.strip() for p in tmp if p.strip()]
                body: List[str] = []
                i += 1
                found_end = False
                while i < len(lines):
                    raw_body = lines[i]
                    s = self._strip_comment(raw_body)
                    if s.lower().startswith('.endm') or s.lower().startswith('.endmacro'):
                        found_end = True
                        break
                    body.append(raw_body)
                    i += 1
                if not found_end:
                    raise AsmError(f".macro '{name}' missing .endm at EOF")
                # Register macro (uppercase name for case-insensitive match)
                key = name.strip().upper()
                if not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", key):
                    raise AsmError(f"Invalid macro name '{name}' at line {i+1}")
                if key in self._macros:
                    raise AsmError(f"Redefinition of macro '{name}'")
                self._macros[key] = (params, body)
                # Skip the .endm line
                i += 1
                continue
            else:
                kept_lines.append(raw)
                i += 1

        # Second pass: expand macro invocations recursively
        expanded_lines = self._expand_lines_recursive(kept_lines)
        return "\n".join(expanded_lines)

    def _expand_lines_recursive(self, lines: List[str], depth: int = 0) -> List[str]:
        if depth > 100:
            raise AsmError("Macro expansion too deep (possible recursion)")
        out: List[str] = []
        i = 0
        while i < len(lines):
            raw = lines[i]
            s = self._strip_comment(raw)
            if not s:
                out.append(raw)
                i += 1
                continue
            label, rest = self._split_label(s)
            probe = rest if rest is not None else s
            if probe.startswith('.'):
                # Directives pass through unchanged
                out.append(raw)
                i += 1
                continue
            # Determine mnemonic token
            parts = probe.split(None, 1)
            if not parts:
                out.append(raw)
                i += 1
                continue
            mnem = parts[0].strip().upper()
            if mnem in self._macros:
                arg_str = parts[1] if len(parts) > 1 else ''
                args = [a.strip() for a in arg_str.split(',')] if arg_str else []
                # Expand and replace this line with expansion
                exp_lines = self._expand_one_macro(mnem, args, call_label=label)
                # Process recursively to allow nested macros
                exp_lines = self._expand_lines_recursive(exp_lines, depth + 1)
                out.extend(exp_lines)
                i += 1
                continue
            # Not a macro: keep original raw (preserve comments/spacing)
            out.append(raw)
            i += 1
        return out

    def _expand_one_macro(self, name: str, args: List[str], call_label: Optional[str]) -> List[str]:
        params, body = self._macros[name]
        if len(args) != len(params):
            raise AsmError(
                f"Macro {name} expects {len(params)} arg(s), got {len(args)}"
            )
        # Build param map (case-insensitive keys)
        pmap: Dict[str, str] = {p.strip().upper(): a for p, a in zip(params, args)}
        # Prepare local label mapping for this expansion
        self._macro_expansion_id += 1
        uid = f"__{name}_{self._macro_expansion_id}"
        local_map: Dict[str, str] = {}

        # First pass body scan to collect .local and filter them out
        filtered_body: List[str] = []
        for raw in body:
            line = self._strip_comment(raw)
            if line.lower().startswith('.local'):
                rest = line[len('.local'):].strip()
                # Accept comma or space separated
                items: List[str] = []
                for seg in rest.split(','):
                    seg = seg.strip()
                    if not seg:
                        continue
                    items.extend([t for t in seg.split() if t])
                for nm in items:
                    nm_u = nm.strip()
                    if not nm_u:
                        continue
                    local_map[nm_u] = f"{nm_u}{uid}"
                continue  # do not keep .local in output
            filtered_body.append(raw)

        # Now perform substitution on filtered body
        out: List[str] = []
        for raw in filtered_body:
            line = raw
            # Param substitution: {param}
            def sub_param(m: re.Match[str]) -> str:
                key = m.group(1).strip().upper()
                if key not in pmap:
                    raise AsmError(f"Unknown macro parameter '{{{m.group(1)}}}' in {name}")
                return pmap[key]

            line = re.sub(r"\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}", sub_param, line)

            # Local symbol substitution as whole words
            for k, v in local_map.items():
                line = re.sub(rf"\b{re.escape(k)}\b", v, line)

            out.append(line)

        # Attach call-site label by prefixing a separate label line
        if call_label:
            out.insert(0, f"{call_label}:")
        return out


def assemble_file(path: Path, origin: int = 0) -> bytes:
    asm = Assembler(origin=origin)
    words = asm.assemble_path(path)
    return asm.pack_words_bin(words)

# assemble_files helper removed: prefer .include within a single entry file
