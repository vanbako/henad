; Example: 12-bit diad helpers and lane-wise math

    .org 0

start:
    ; Create two diads from immediates: DR1 = {0x001,0x002}, DR2 = {0x003,0x004}
    DIAD_MOVUI DR1, #0x001, #0x002
    DIAD_MOVUI DR2, #0x003, #0x004

    ; Lane-wise add/sub/neg
    ADD12 DR1, DR2, DR3, DR0         ; {0x004,0x006}
    SUB12 DR1, DR2, DR4, DR0         ; {0xFFE,0xFFE}
    NEG12 DR4, DR5, DR0              ; {0x002,0x002}

    ; Lane-wise mul/div/mod
    MUL12 DR1, DR2, DR6, DR0         ; mul per lane (wrap)
    DIV12 DR6, DR1, DR7, DR8, DR0    ; q in DR7, r in DR8
    MOD12 DR6, DR1, DR9, DR0         ; r in DR9

    ; Lane-wise sqrt/abs
    SQRT12 DR6, DR10, DR0
    ABS12  DR4, DR11, DR0

    ; Lane-wise min/max (unsigned/signed)
    MIN12_U DR1, DR2, DR12, DR0
    MAX12_S DR4, DR5, DR13, DR0

    ; Clamp unsigned and signed (per lane)
    CLAMP12_U DR1, DR2, DR6, DR14, DR0  ; clamp to [DR2, DR6]
    CLAMP12_S DR4, DR5, DR3, DR15, DR0  ; clamp to [DR5, DR3]

    ; Unpack and repack to demonstrate helpers
    UNPACK_DIAD DR3, DR4, DR5
    PACK_DIAD   DR4, DR5, DR6, DR0
