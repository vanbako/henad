"""Amber ISA encoding spec (assembler view).

Defines the mapping from ISA mnemonics to 24-bit encodings used by the
assembler. Covers the full architectural ISA (excluding internal micro-ops in
OPCLASS_F)."""
from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Dict, List, Tuple, Optional


# Bit utility
def setbits(word: int, value: int, hi: int, lo: int) -> int:
    mask = ((1 << (hi - lo + 1)) - 1) << lo
    return (word & ~mask) | ((value << lo) & mask)


# Register parsing
def parse_dr(token: str) -> int:
    token = token.strip().upper()
    if not token.startswith("DR"):
        raise ValueError(f"Expected DRx register, got '{token}'")
    idx = int(token[2:])
    if idx < 0 or idx > 15:
        raise ValueError(f"DR index out of range 0..15: {idx}")
    return idx


def parse_ar(token: str) -> int:
    token = token.strip().upper()
    # Accept optional parentheses: (ARx)
    if token.startswith("(") and token.endswith(")"):
        token = token[1:-1].strip()
    if not token.startswith("AR"):
        raise ValueError(f"Expected ARx register, got '{token}'")
    idx = int(token[2:])
    if idx < 0 or idx > 3:
        raise ValueError(f"AR index out of range 0..3: {idx}")
    return idx


def parse_sr(token: str) -> int:
    t = token.strip().upper()
    # Accept optional parentheses: (SRx)
    if t.startswith("(") and t.endswith(")"):
        t = t[1:-1].strip()
    # Named aliases from sr.vh
    aliases = {"LR": 0, "SSP": 1, "FL": 2, "PC": 3}
    if t in aliases:
        return aliases[t]
    if not t.startswith("SR"):
        raise ValueError(f"Expected SRx register or alias, got '{token}'")
    idx = int(t[2:])
    if idx < 0 or idx > 3:
        raise ValueError(f"SR index out of range 0..3: {idx}")
    return idx


# Condition codes (from processors/amber/src/cc.vh)
CC_MAP: Dict[str, int] = {
    "RA": 0x0,
    "AL": 0x0,  # alias
    "EQ": 0x1,
    "NE": 0x2,
    "LT": 0x3,
    "GT": 0x4,
    "LE": 0x5,
    "GE": 0x6,
    "BT": 0x7,
    "AT": 0x8,
    "BE": 0x9,
    "AE": 0xA,
}


def parse_cc(token: str) -> int:
    t = token.strip().upper()
    if t not in CC_MAP:
        raise ValueError(f"Unknown condition code '{token}'")
    return CC_MAP[t]


def parse_hl(token: str) -> int:
    t = token.strip().upper()
    if t in ("H", "HI", "HIGH"):
        return 1
    if t in ("L", "LO", "LOW"):
        return 0
    raise ValueError(f"Expected H or L, got '{token}'")


def parse_imm(token: str) -> int:
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
    try:
        return int(t, base)
    except Exception as e:
        raise ValueError(f"Invalid immediate '{token}': {e}")


@dataclass
class InstructionSpec:
    mnemonic: str
    opclass: int
    subop: int
    # Ordered operand kinds as they appear in assembly text
    operands: List[str]
    # Map of field name -> (hi, lo) bit positions in the 24-bit word
    fields: Dict[str, Tuple[int, int]]

    def encode(
        self,
        ops: List[str],
        *,
        resolve_expr: Optional[Callable[[str, int, bool, int, bool], int]] = None,
        pc: int = 0,
    ) -> int:
        if len(ops) != len(self.operands):
            raise ValueError(
                f"{self.mnemonic}: expected {len(self.operands)} operands, got {len(ops)}"
            )
        w = 0
        w = setbits(w, self.opclass, 23, 20)
        w = setbits(w, self.subop, 19, 16)

        def enc_val(kind: str, tok: str, hi: int, lo: int) -> int:
            k = kind.upper()
            if k in ("DRS", "DRT"):
                return parse_dr(tok)
            if k in ("ARS", "ART"):
                return parse_ar(tok)
            if k in ("SRS", "SRT"):
                return parse_sr(tok)
            if k == "CC":
                return parse_cc(tok)
            if k == "HL":
                return parse_hl(tok)
            if k.startswith("SIMM") or k.startswith("IMM") or k.startswith("UIMM"):
                width = hi - lo + 1
                is_signed = k.startswith("SIMM")
                if resolve_expr is not None:
                    pc_rel = self.mnemonic in {"BCCSO", "BALSO", "BSRSR", "BSRSO", "ADRASO"}
                    return resolve_expr(tok, width, is_signed, pc, pc_rel)
                # Fallback: numeric only
                v = parse_imm(tok)
                if is_signed:
                    minv = -(1 << (width - 1))
                    maxv = (1 << (width - 1)) - 1
                    if v < minv or v > maxv:
                        raise ValueError(
                            f"signed immediate out of range {minv}..{maxv}: {v}"
                        )
                    v &= (1 << width) - 1
                    return v
                else:
                    maxv = (1 << width) - 1
                    if v < 0 or v > maxv:
                        raise ValueError(f"immediate out of range 0..{maxv}: {v}")
                    return v
            raise ValueError(f"Unknown operand kind '{kind}'")

        for kind, tok in zip(self.operands, ops):
            fld = kind  # field name matches kind in this simple scheme
            if fld not in self.fields:
                raise ValueError(f"Spec for {self.mnemonic} missing field '{fld}'")
            hi, lo = self.fields[fld]
            val = enc_val(kind, tok, hi, lo)
            w = setbits(w, val, hi, lo)

        # Mask down to 24 bits, reserved bits implicitly zero
        return w & 0xFFFFFF


# Minimal subset of instruction specs to demonstrate the path.
SPECS: Dict[str, InstructionSpec] = {
    # OPCLASS 0: Core ALU (reg-reg, unsigned flags)
    "NOP": InstructionSpec("NOP", 0x0, 0x0, [], {}),
    "MOVUR": InstructionSpec(
        "MOVUR", 0x0, 0x1, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "MCCUR": InstructionSpec(
        "MCCUR",
        0x0,
        0x2,
        ["CC", "DRs", "DRt"],
        {"DRt": (15, 12), "DRs": (11, 8), "CC": (7, 4)},
    ),
    "ADDUR": InstructionSpec(
        "ADDUR", 0x0, 0x3, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "SUBUR": InstructionSpec(
        "SUBUR", 0x0, 0x4, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "NOTUR": InstructionSpec("NOTUR", 0x0, 0x5, ["DRt"], {"DRt": (15, 12)}),
    "ANDUR": InstructionSpec(
        "ANDUR", 0x0, 0x6, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "ORUR": InstructionSpec(
        "ORUR", 0x0, 0x7, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "XORUR": InstructionSpec(
        "XORUR", 0x0, 0x8, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "SHLUR": InstructionSpec(
        "SHLUR", 0x0, 0x9, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "ROLUR": InstructionSpec(
        "ROLUR", 0x0, 0xA, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "SHRUR": InstructionSpec(
        "SHRUR", 0x0, 0xB, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "RORUR": InstructionSpec(
        "RORUR", 0x0, 0xC, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "CMPUR": InstructionSpec(
        "CMPUR", 0x0, 0xD, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "TSTUR": InstructionSpec("TSTUR", 0x0, 0xE, ["DRt"], {"DRt": (15, 12)}),

    # OPCLASS 1: Core ALU (imm/uimm)
    "LUIUI": InstructionSpec(
        "LUIUI", 0x1, 0x0, ["UIMM2", "IMM12"], {"UIMM2": (15, 14), "IMM12": (11, 0)}
    ),
    "MOVUI": InstructionSpec(
        "MOVUI", 0x1, 0x1, ["IMM12", "DRt"], {"DRt": (15, 12), "IMM12": (11, 0)}
    ),
    "ADDUI": InstructionSpec(
        "ADDUI", 0x1, 0x3, ["IMM12", "DRt"], {"DRt": (15, 12), "IMM12": (11, 0)}
    ),
    "SUBUI": InstructionSpec(
        "SUBUI", 0x1, 0x4, ["IMM12", "DRt"], {"DRt": (15, 12), "IMM12": (11, 0)}
    ),
    "ANDUI": InstructionSpec(
        "ANDUI", 0x1, 0x6, ["IMM12", "DRt"], {"DRt": (15, 12), "IMM12": (11, 0)}
    ),
    "ORUI": InstructionSpec(
        "ORUI", 0x1, 0x7, ["IMM12", "DRt"], {"DRt": (15, 12), "IMM12": (11, 0)}
    ),
    "XORUI": InstructionSpec(
        "XORUI", 0x1, 0x8, ["IMM12", "DRt"], {"DRt": (15, 12), "IMM12": (11, 0)}
    ),
    # Shift-by-immediate uses imm5 in [4:0] (unsigned op with immediate)
    "SHLUI": InstructionSpec(
        "SHLUI", 0x1, 0x9, ["IMM5", "DRt"], {"DRt": (15, 12), "IMM5": (4, 0)}
    ),
    "ROLUI": InstructionSpec(
        "ROLUI", 0x1, 0xA, ["IMM5", "DRt"], {"DRt": (15, 12), "IMM5": (4, 0)}
    ),
    "SHRUI": InstructionSpec(
        "SHRUI", 0x1, 0xB, ["IMM5", "DRt"], {"DRt": (15, 12), "IMM5": (4, 0)}
    ),
    "RORUI": InstructionSpec(
        "RORUI", 0x1, 0xC, ["IMM5", "DRt"], {"DRt": (15, 12), "IMM5": (4, 0)}
    ),
    "CMPUI": InstructionSpec(
        "CMPUI", 0x1, 0xD, ["IMM12", "DRt"], {"DRt": (15, 12), "IMM12": (11, 0)}
    ),

    # OPCLASS 2: Core ALU (reg-reg, signed flags)
    "ADDSR": InstructionSpec(
        "ADDSR", 0x2, 0x3, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "SUBSR": InstructionSpec(
        "SUBSR", 0x2, 0x4, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "NEGSR": InstructionSpec("NEGSR", 0x2, 0x5, ["DRt"], {"DRt": (15, 12)}),
    # Trap-on-overflow variants
    "NEGSV": InstructionSpec("NEGSV", 0x2, 0x6, ["DRt"], {"DRt": (15, 12)}),
    "ADDSV": InstructionSpec(
        "ADDSV", 0x2, 0x7, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "SUBSV": InstructionSpec(
        "SUBSV", 0x2, 0x8, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    # Trap-on-range variant of arithmetic right shift (reg)
    "SHRSRV": InstructionSpec(
        "SHRSRV", 0x2, 0xA, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "SHRSR": InstructionSpec(
        "SHRSR", 0x2, 0xB, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "CMPSR": InstructionSpec(
        "CMPSR", 0x2, 0xD, ["DRs", "DRt"], {"DRt": (15, 12), "DRs": (11, 8)}
    ),
    "TSTSR": InstructionSpec("TSTSR", 0x2, 0xE, ["DRt"], {"DRt": (15, 12)}),

    # OPCLASS 3: Core ALU (imm, signed flags)
    "MOVSI": InstructionSpec(
        "MOVSI", 0x3, 0x1, ["SIMM12", "DRt"], {"DRt": (15, 12), "SIMM12": (11, 0)}
    ),
    "MCCSI": InstructionSpec(
        "MCCSI", 0x3, 0x2, ["CC", "SIMM8", "DRt"], {"DRt": (15, 12), "CC": (11, 8), "SIMM8": (7, 0)}
    ),
    "ADDSI": InstructionSpec(
        "ADDSI", 0x3, 0x3, ["SIMM12", "DRt"], {"DRt": (15, 12), "SIMM12": (11, 0)}
    ),
    "SUBSI": InstructionSpec(
        "SUBSI", 0x3, 0x4, ["SIMM12", "DRt"], {"DRt": (15, 12), "SIMM12": (11, 0)}
    ),
    "SHRSI": InstructionSpec(
        "SHRSI", 0x3, 0xB, ["IMM5", "DRt"], {"DRt": (15, 12), "IMM5": (4, 0)}
    ),
    # Trap-on-overflow/range immediate variants
    "ADDSIV": InstructionSpec(
        "ADDSIV", 0x3, 0x6, ["SIMM12", "DRt"], {"DRt": (15, 12), "SIMM12": (11, 0)}
    ),
    "SUBSIV": InstructionSpec(
        "SUBSIV", 0x3, 0x7, ["SIMM12", "DRt"], {"DRt": (15, 12), "SIMM12": (11, 0)}
    ),
    "SHRSIV": InstructionSpec(
        "SHRSIV", 0x3, 0xC, ["IMM5", "DRt"], {"DRt": (15, 12), "IMM5": (4, 0)}
    ),
    "CMPSI": InstructionSpec(
        "CMPSI", 0x3, 0xD, ["SIMM12", "DRt"], {"DRt": (15, 12), "SIMM12": (11, 0)}
    ),

    # OPCLASS 4: Loads/Stores (base only)
    "LDUR": InstructionSpec(
        "LDUR", 0x4, 0x0, ["ARs", "DRt"], {"DRt": (15, 12), "ARs": (11, 10)}
    ),
    "STUR": InstructionSpec(
        "STUR", 0x4, 0x1, ["DRs", "ARt"], {"ARt": (15, 14), "DRs": (13, 10)}
    ),
    # Store immediate (unsigned/signed) to (ARt)
    # STUI: 24-bit immediate formed from LUIui bank0 (bits[23:12]) + IMM12
    "STUI": InstructionSpec(
        "STUI", 0x4, 0x2, ["IMM12", "ARt"], {"ARt": (15, 14), "IMM12": (11, 0)}
    ),
    # STSI: sign-extended 14-bit immediate to (ARt)
    "STSI": InstructionSpec(
        "STSI", 0x4, 0x3, ["SIMM14", "ARt"], {"ARt": (15, 14), "SIMM14": (13, 0)}
    ),

    # OPCLASS 5: Loads/Stores (base + signed offset)
    # Syntax normalized by assembler: "#imm(ARs), DRt" => [imm, ARs, DRt]
    "LDSO": InstructionSpec(
        "LDSO", 0x5, 0x0, ["SIMM10", "ARs", "DRt"], {"DRt": (15, 12), "ARs": (11, 10), "SIMM10": (9, 0)}
    ),
    # Syntax: "DRs, #imm(ARt)" => [DRs, imm, ARt]
    "STSO": InstructionSpec(
        "STSO", 0x5, 0x1, ["DRs", "SIMM10", "ARt"], {"ARt": (15, 14), "DRs": (13, 10), "SIMM10": (9, 0)}
    ),
    # Syntax: "#imm(ARs), ARt" => [imm, ARs, ARt]
    "LDASO": InstructionSpec(
        "LDASO", 0x5, 0x2, ["SIMM12", "ARs", "ARt"], {"ARt": (15, 14), "ARs": (13, 12), "SIMM12": (11, 0)}
    ),
    # Syntax: "ARs, #imm(ARt)" => [ARs, imm, ARt]
    "STASO": InstructionSpec(
        "STASO", 0x5, 0x3, ["ARs", "SIMM12", "ARt"], {"ARt": (15, 14), "ARs": (13, 12), "SIMM12": (11, 0)}
    ),

    # OPCLASS 7: Control flow (subset)
    "JCCUR": InstructionSpec(
        "JCCUR", 0x7, 0x1, ["CC", "ARt"], {"ARt": (15, 14), "CC": (13, 10)}
    ),
    # PC-relative via register: CC, PC+DRt
    "BCCSR": InstructionSpec(
        "BCCSR", 0x7, 0x3, ["CC", "DRt"], {"DRt": (15, 12), "CC": (11, 8)}
    ),
    # Macro-backed absolute jump via uimm: expanded to LUIui#2,#..; LUIui#1,#..; LUIui#0,#..; JCCui CC,#imm12
    "JCCUI": InstructionSpec(
        "JCCUI", 0x7, 0x2, ["CC", "IMM12"], {"CC": (15, 12), "IMM12": (11, 0)}
    ),
    "BCCSO": InstructionSpec(
        "BCCSO", 0x7, 0x4, ["CC", "SIMM12"], {"CC": (15, 12), "SIMM12": (11, 0)}
    ),
    "BALSO": InstructionSpec(
        "BALSO", 0x7, 0x5, ["SIMM16"], {"SIMM16": (15, 0)}
    ),
    # Macro-backed call via uimm
    "JSRUI": InstructionSpec(
        "JSRUI", 0x7, 0x7, ["IMM12"], {"IMM12": (11, 0)}
    ),
    "RET": InstructionSpec("RET", 0x7, 0xA, [], {}),
}

# OPCLASS 6: Address-register ALU & moves (selected subset)
SPECS.update({
    # unsigned add/sub with DRs
    "ADDAUR": InstructionSpec(
        "ADDAUR", 0x6, 0x3, ["DRs", "ARt"], {"ARt": (15, 14), "DRs": (13, 10)}
    ),
    "SUBAUR": InstructionSpec(
        "SUBAUR", 0x6, 0x4, ["DRs", "ARt"], {"ARt": (15, 14), "DRs": (13, 10)}
    ),
    # signed add/sub with DRs
    "ADDASR": InstructionSpec(
        "ADDASR", 0x6, 0x5, ["DRs", "ARt"], {"ARt": (15, 14), "DRs": (13, 10)}
    ),
    "SUBASR": InstructionSpec(
        "SUBASR", 0x6, 0x6, ["DRs", "ARt"], {"ARt": (15, 14), "DRs": (13, 10)}
    ),
    # signed add/sub immediate
    "ADDASI": InstructionSpec(
        "ADDASI", 0x6, 0x7, ["SIMM12", "ARt"], {"ARt": (15, 14), "SIMM12": (11, 0)}
    ),
    "SUBASI": InstructionSpec(
        "SUBASI", 0x6, 0x8, ["SIMM12", "ARt"], {"ARt": (15, 14), "SIMM12": (11, 0)}
    ),
    # address calc: ARt = ARs + simm12
    "LEASO": InstructionSpec(
        "LEASO", 0x6, 0x9, ["ARs", "SIMM12", "ARt"], {"ARt": (15, 14), "ARs": (13, 12), "SIMM12": (11, 0)}
    ),
    # address calc from PC: ARt = PC + simm14 (PC-relative)
    "ADRASO": InstructionSpec(
        "ADRASO", 0x6, 0xA, ["SIMM14", "ARt"], {"ARt": (15, 14), "SIMM14": (13, 0)}
    ),
    # compare/test address registers
    "CMPAUR": InstructionSpec(
        "CMPAUR", 0x6, 0xD, ["ARs", "ARt"], {"ARt": (15, 14), "ARs": (13, 12)}
    ),
    "TSTAUR": InstructionSpec("TSTAUR", 0x6, 0xE, ["ARt"], {"ARt": (15, 14)}),
    # Moves with H|L select bit at [9]
    "MOVAUR": InstructionSpec(
        "MOVAUR", 0x6, 0x1, ["DRs", "ARt", "HL"], {"ARt": (15, 14), "DRs": (13, 10), "HL": (9, 9)}
    ),
    "MOVDUR": InstructionSpec(
        "MOVDUR", 0x6, 0x2, ["ARs", "DRt", "HL"], {"DRt": (15, 12), "ARs": (11, 10), "HL": (9, 9)}
    ),
})

# OPCLASS 8: CSR access (match HDL opcodes.vh)
SPECS.update({
    # Read CSR[index] -> DRt
    "CSRRD": InstructionSpec(
        "CSRRD", 0x8, 0x0, ["IMM12", "DRt"], {"DRt": (15, 12), "IMM12": (11, 0)}
    ),
    # Write DRs -> CSR[index]
    "CSRWR": InstructionSpec(
        "CSRWR", 0x8, 0x1, ["DRs", "IMM12"], {"DRs": (15, 12), "IMM12": (11, 0)}
    ),
})

# OPCLASS 9: privileged (match HDL names and encodings)
SPECS.update({
    "HLT":     InstructionSpec("HLT",     0x9, 0x0, [], {}),
    "SETSSP":  InstructionSpec("SETSSP",  0x9, 0x1, ["ARs"], {"ARs": (15, 14)}),
    # System call: jumps to absolute handler address formed via LUIui banks + IMM12
    "SYSCALL": InstructionSpec("SYSCALL", 0x9, 0x2, ["IMM12"], {"IMM12": (11, 0)}),
    # Kernel return
    "KRET":    InstructionSpec("KRET",    0x9, 0x3, [], {}),
})

# OPCLASS F: SR ops
# Note: OPCLASS_F contains micro-ops only (no standalone ISA mnemonics).
# The assembler intentionally does not expose those.

# Additional ISA control-flow and stack ops (OPCLASS_7 and OPCLASS_8)
SPECS.update({
    # Control flow (OPCLASS_7)
    "BTP": InstructionSpec("BTP", 0x7, 0x0, [], {}),
    "JCCUR": InstructionSpec("JCCUR", 0x7, 0x1, ["CC", "ARt"], {"ARt": (15, 14), "CC": (13, 10)}),
    "JCCUI": InstructionSpec("JCCUI", 0x7, 0x2, ["CC", "IMM12"], {"CC": (15, 12), "IMM12": (11, 0)}),
    "BCCSR": InstructionSpec("BCCSR", 0x7, 0x3, ["CC", "DRt"], {"DRt": (15, 12), "CC": (11, 8)}),
    "BCCSO": InstructionSpec("BCCSO", 0x7, 0x4, ["CC", "SIMM12"], {"CC": (15, 12), "SIMM12": (11, 0)}),
    "BALSO": InstructionSpec("BALSO", 0x7, 0x5, ["SIMM16"], {"SIMM16": (15, 0)}),
    # Calls/returns (JSR/BSR/RET)
    "JSRUR": InstructionSpec("JSRUR", 0x7, 0x6, ["ARt"], {"ARt": (15, 14)}),
    "JSRUI": InstructionSpec("JSRUI", 0x7, 0x7, ["IMM12"], {"IMM12": (11, 0)}),
    "BSRSR": InstructionSpec("BSRSR", 0x7, 0x8, ["DRt"], {"DRt": (15, 12)}),
    "BSRSO": InstructionSpec("BSRSO", 0x7, 0x9, ["SIMM16"], {"SIMM16": (15, 0)}),
    "RET":   InstructionSpec("RET",   0x7, 0xA, [], {}),
})

SPECS.update({
    # Stack operations (OPCLASS_8)
    # PUSHUR: DRs -> -(ARt)
    "PUSHUR":  InstructionSpec("PUSHUR",  0x8, 0x0, ["DRs", "ARt"], {"ARt": (15, 14), "DRs": (13, 10)}),
    # PUSHAUR: ARs(48b) -> -(ARt)
    "PUSHAUR": InstructionSpec("PUSHAUR", 0x8, 0x1, ["ARs", "ARt"], {"ARt": (15, 14), "ARs": (13, 12)}),
    # POPUR:  +(ARs) -> DRt
    "POPUR":   InstructionSpec("POPUR",   0x8, 0x2, ["ARs", "DRt"], {"DRt": (15, 12), "ARs": (11, 10)}),
    # POPAUR: +(ARs) -> ARt(48b)
    "POPAUR":  InstructionSpec("POPAUR",  0x8, 0x3, ["ARs", "ARt"], {"ARt": (15, 14), "ARs": (13, 12)}),
})


def get_spec(mnemonic: str) -> InstructionSpec | None:
    return SPECS.get(mnemonic.upper())
