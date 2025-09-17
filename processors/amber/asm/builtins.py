"""Built-in assembler symbols for Amber CSR indices and async int24 math.

These are injected into the assembler symbol table before pass1, so they can
be used anywhere (including in .equ expressions) without requiring a header.

Notes on math control:
- MATH_CTRL uses bit0 START and bits[5:1] OP. Since the assembler expression
  language does not include shifts or bitwise OR, we provide pre-shifted OP
  constants and a START bit constant so users can write:
    CSRWR DRx, #MATH_CTRL_START + MATH_OP_DIVU
"""

# Core CSR indices (12-bit)
BUILTIN_SYMBOLS = {
    # General CSRs
    "STATUS":      0x00,
    "CAUSE":       0x01,
    "EPC_LO":      0x02,
    "EPC_HI":      0x03,
    "CYCLE_L":     0x04,
    "CYCLE_H":     0x05,
    "INSTRET_L":   0x06,
    "INSTRET_H":   0x07,

    # Async 24-bit math CSRs
    "MATH_CTRL":     0x10,
    "MATH_STATUS":   0x11,
    "MATH_OPA":      0x12,
    "MATH_OPB":      0x13,
    "MATH_RES0":     0x14,
    "MATH_RES1":     0x15,
    "MATH_OPC":      0x16,

    # MATH_STATUS bits
    "MATH_STATUS_READY": 1 << 0,
    "MATH_STATUS_BUSY":  1 << 1,
    "MATH_STATUS_DIV0":  1 << 2,

    # MATH_CTRL bits
    "MATH_CTRL_START":   1 << 0,

    # Pre-shifted OP field values (OP at [5:1])
    "MATH_OP_MULU":    (0x0 << 1),
    "MATH_OP_DIVU":    (0x1 << 1),
    "MATH_OP_MODU":    (0x2 << 1),
    "MATH_OP_SQRTU":   (0x3 << 1),
    "MATH_OP_MULS":    (0x4 << 1),
    "MATH_OP_DIVS":    (0x5 << 1),
    "MATH_OP_MODS":    (0x6 << 1),
    "MATH_OP_ABS_S":   (0x7 << 1),
    "MATH_OP_MIN_U":   (0x8 << 1),
    "MATH_OP_MAX_U":   (0x9 << 1),
    "MATH_OP_MIN_S":   (0xA << 1),
    "MATH_OP_MAX_S":   (0xB << 1),
    "MATH_OP_CLAMP_U": (0xC << 1),
    "MATH_OP_CLAMP_S": (0xD << 1),
    # New ops: 24-bit and 12-bit diad add/sub/neg
    "MATH_OP_ADD24":   (0xE << 1),
    "MATH_OP_SUB24":   (0xF << 1),
    "MATH_OP_NEG24":   (0x10 << 1),
    "MATH_OP_ADD12":   (0x11 << 1),
    "MATH_OP_SUB12":   (0x12 << 1),
    "MATH_OP_NEG12":   (0x13 << 1),
    # Packed 12-bit lane-wise ops
    "MATH_OP_MUL12":   (0x14 << 1),
    "MATH_OP_DIV12":   (0x15 << 1),
    "MATH_OP_MOD12":   (0x16 << 1),
    "MATH_OP_SQRT12":  (0x17 << 1),
    "MATH_OP_ABS12":   (0x18 << 1),
    "MATH_OP_MIN12_U": (0x19 << 1),
    "MATH_OP_MAX12_U": (0x1A << 1),
    "MATH_OP_MIN12_S": (0x1B << 1),
    "MATH_OP_MAX12_S": (0x1C << 1),
    "MATH_OP_CLAMP12_U": (0x1D << 1),
    "MATH_OP_CLAMP12_S": (0x1E << 1),
}
