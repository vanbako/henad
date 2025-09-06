    .org 0
main:
    ; prologue (callee-saved)
    ADRAso #__skald_stack_top, AR0
    PUSHAur AR1, AR0
    PUSHAur AR2, AR0
    PUSHAur AR3, AR0
    PUSHAur AR4, AR0
    PUSHAur AR5, AR0
    PUSHAur AR6, AR0
    PUSHAur AR7, AR0
    PUSHur DR1, AR0
    PUSHur DR2, AR0
    PUSHur DR3, AR0
    SUBASI #3, AR0
    LEASO AR0, #0, AR1
    ; alloc frame for s:S size 3w -> AR1 at +0
    ; let s:S -> AR1 (frame)
    ; let a:addr<u24> -> AR2
    ; let b:u24 -> DR1
    MOVui #3, DR2
    STSO DR2, #2, AR1
    LEASO AR1, #2, AR3
    STASO AR3, #0, AR1
    LDASO #0, AR1, AR4
    LEASO AR4, #0, AR2
    LEASO AR1, #0, AR5
    LDASO #0, AR5, AR6
    LEASO AR6, #0, AR2
    LEASO AR1, #2, AR7
    LDSO #0, AR7, DR3
    MOVur DR3, DR1
    ADDASI #3, AR0
    POPur AR0, DR3
    POPur AR0, DR2
    POPur AR0, DR1
    POPAur AR0, AR7
    POPAur AR0, AR6
    POPAur AR0, AR5
    POPAur AR0, AR4
    POPAur AR0, AR3
    POPAur AR0, AR2
    POPAur AR0, AR1
    RET
    ; --- Skald demo stack region ---
__skald_stack_area:
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
    .dw24 #0
__skald_stack_top:
