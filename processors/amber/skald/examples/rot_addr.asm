    .org 0
main:
    ; prologue (callee-saved)
    ADRAso #__skald_stack_top, AR0
    PUSHAur AR1, AR0
    PUSHur DR1, AR0
    PUSHur DR2, AR0
    PUSHur DR3, AR0
    PUSHur DR4, AR0
    PUSHur DR5, AR0
    PUSHur DR6, AR0
    PUSHur DR7, AR0
    PUSHur DR8, AR0
    PUSHur DR9, AR0
    ; let x:u24 -> DR1
    MOVui #1, DR2
    MOVur DR2, DR1
    ; let y:u24 -> DR3
    MOVui #3, DR4
    MOVur DR4, DR3
    ; let s:s24 -> DR5
    MOVui #2, DR6
    MOVur DR6, DR5
    ; let A:addr -> AR1
    MOVui #0, DR7
    MOVAur DR7, AR1, L
    ROLUR DR3, DR1
    MOVui #1, DR8
    RORUR DR8, DR1
    MOVur DR1, DR9
    NOTUR DR9
    MOVur DR9, DR1
    ADDAUR DR3, AR1
    SUBASR DR5, AR1
    MOVur DR1, DR0
    POPur AR0, DR9
    POPur AR0, DR8
    POPur AR0, DR7
    POPur AR0, DR6
    POPur AR0, DR5
    POPur AR0, DR4
    POPur AR0, DR3
    POPur AR0, DR2
    POPur AR0, DR1
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
