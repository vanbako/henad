; Demo: 24-bit async math wired to testbench outputs
; The default Amber testbench prints DR1, DR2, DR3 at the end.
; This program computes quotient and remainder of 100/7 and places:
;   DR1 = quotient (14 -> 0x00000E)
;   DR2 = remainder (2  -> 0x000002)
; Then computes sqrt(20736)=144 and places:
;   DR3 = 144 (0x000090)

    .org 0

start:
    ; q,r = 100 / 7
    MOVui #100, DR1
    MOVui #7,   DR2
    DIVU24 DR1, DR2, DR3, DR4, DR0   ; q->DR3, r->DR4
    MOVUR DR3, DR1                   ; DR1 = q = 14 (0x00000E)
    MOVUR DR4, DR2                   ; DR2 = r = 2  (0x000002)

    ; sqrt(576) = 24
    MOVui #576, DR5
    SQRTU24 DR5, DR6, DR0
    MOVUR DR6, DR3                   ; DR3 = 24 (0x000018)

    SRHLT
