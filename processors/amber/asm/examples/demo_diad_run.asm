; Demo: 12-bit diad lane-wise async math wired to testbench outputs
; The default Amber testbench prints DR1, DR2, DR3 at the end.
; This program computes DR3 = DR1 + DR2 (lane-wise) where
;   DR1 = {hi=0x001, lo=0x002}
;   DR2 = {hi=0x003, lo=0x004}
; Expected final print:
;   DR1 (hi) = 0x000004
;   DR2 (lo) = 0x000006
;   DR3 (diad)= 0x004006

    .org 0

start:
    ; Build two diads
    DIAD_MOVUI DR1, #0x001, #0x002
    DIAD_MOVUI DR2, #0x003, #0x004

    ; Lane-wise add: {0x004, 0x006}
    ADD12 DR1, DR2, DR3, DR0

    ; Unpack result into hi/lo to display in DR1/DR2
    UNPACK_DIAD DR3, DR4, DR5      ; DR4=hi, DR5=lo
    MOVUR DR4, DR1                 ; Final print DR1 = 0x000004
    MOVUR DR5, DR2                 ; Final print DR2 = 0x000006

    SRHLT

