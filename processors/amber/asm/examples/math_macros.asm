; Example: Macro-based async int24 math

    .org 0

start:
    ; Compute q,r = 100 / 7 using DIVU24
    MOVui #100, DR1
    MOVui #7,   DR2
    DIVU24 DR1, DR2, DR3, DR4, DR0   ; q->DR3, r->DR4, tmp DR0

    ; Product = 0x34 * 0x20 (small immediates for demo)
    MOVui #0x34, DR5
    MOVui #0x20, DR6
    MULU24 DR5, DR6, DR7, DR8, DR0   ; lo->DR7, hi->DR8

    ; Clamp signed: res = clamp(A=DR9, [min=DR10, max=DR11])
    CLAMP_S24 DR9, DR10, DR11, DR12, DR0

    ; --- Packed 12-bit diad math examples ---
    ; Build two diads: DR1 = {hi=0x001, lo=0x002}, DR2 = {hi=0x003, lo=0x004}
    DIAD_MOVUI DR1, #0x001, #0x002
    DIAD_MOVUI DR2, #0x003, #0x004

    ; Lane-wise add/sub/neg
    ADD12 DR1, DR2, DR3, DR0   ; DR3 = {0x004,0x006}
    SUB12 DR1, DR2, DR4, DR0   ; DR4 = {0xFFE,0xFFE}
    NEG12 DR4, DR5, DR0        ; DR5 = {0x002,0x002}

    ; Lane-wise mul/div/mod
    MUL12 DR1, DR2, DR6, DR0   ; DR6 = {0x003*0x001, 0x004*0x002} masked to 12b
    DIV12 DR6, DR1, DR7, DR8, DR0 ; DR7=q diad, DR8=r diad
    MOD12 DR6, DR1, DR9, DR0      ; DR9=r diad

    ; Lane-wise sqrt/abs
    SQRT12 DR6, DR10, DR0
    ABS12  DR4, DR11, DR0

    ; Lane-wise min/max (unsigned/signed)
    MIN12_U DR1, DR2, DR12, DR0
    MAX12_S DR4, DR5, DR13, DR0

    ; Lane-wise clamp unsigned and signed
    ; Clamp DR1 to [min=DR2, max=DR6] (per lane)
    CLAMP12_U DR1, DR2, DR6, DR14, DR0
    ; Clamp DR4 (signed) to [min=DR5, max=DR3]
    CLAMP12_S DR4, DR5, DR3, DR15, DR0
