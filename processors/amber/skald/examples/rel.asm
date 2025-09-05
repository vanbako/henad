    .org 0
main:
    ; prologue (callee-saved)
    ADRAso #__skald_stack_top, AR0
    PUSHur DR1, AR0
    PUSHur DR2, AR0
    PUSHur DR3, AR0
    PUSHur DR4, AR0
    PUSHur DR5, AR0
    PUSHur DR6, AR0
    PUSHur DR7, AR0
    PUSHur DR8, AR0
    PUSHur DR9, AR0
    PUSHur DR10, AR0
    ; let a:u24 -> DR1
    MOVui #5, DR2
    MOVur DR2, DR1
    ; let b:u24 -> DR3
    MOVui #7, DR4
    MOVur DR4, DR3
    ; let x:u24 -> DR5
    CMPUR DR3, DR1
    MOVui #0, DR6
    MCCsi BT, #1, DR6
    MOVur DR6, DR7
    CMPUR DR3, DR1
    MOVui #0, DR8
    MCCsi EQ, #1, DR8
    ADDUR DR8, DR7
    MOVur DR7, DR9
    CMPUR DR3, DR1
    MOVui #0, DR10
    MCCsi AE, #1, DR10
    ADDUR DR10, DR9
    MOVur DR9, DR5
    MOVur DR5, DR0
    POPur AR0, DR10
    POPur AR0, DR9
    POPur AR0, DR8
    POPur AR0, DR7
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
