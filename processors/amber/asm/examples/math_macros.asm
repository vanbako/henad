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

