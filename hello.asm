    .org 0
GLOBAL_U:
    .dw24 #1
GLOBAL_P:
    .dw24 #0
    .dw24 #0
main:
    ; prologue (callee-saved)
    ADRAso #__skald_stack_top, AR0
    PUSHur DR1, AR0
    PUSHur DR2, AR0
    PUSHur DR3, AR0
    PUSHur DR4, AR0
    PUSHur DR5, AR0
    PUSHur DR6, AR0
    ; let a:u24 -> DR1
    MOVui #1, DR2
    MOVur DR2, DR1
    ; let b:u24 -> DR3
    MOVui #2, DR4
    MOVur DR4, DR3
    ; let c:u24 -> DR5
    MOVur DR1, DR6
    ADDUR DR3, DR6
    MOVur DR6, DR5
    MOVur DR5, DR0
    POPur AR0, DR6
    POPur AR0, DR5
    POPur AR0, DR4
    POPur AR0, DR3
    POPur AR0, DR2
    POPur AR0, DR1
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
