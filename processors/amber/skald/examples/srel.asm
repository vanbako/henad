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
    PUSHur DR11, AR0
    PUSHur DR12, AR0
    PUSHur DR13, AR0
    PUSHur DR14, AR0
    PUSHur DR15, AR0
    PUSHur DR16, AR0
    ; let a:s24 -> DR1
    MOVui #0, DR2
    MOVur DR2, DR3
    MOVui #1, DR4
    SUBSR DR4, DR3
    MOVur DR3, DR5
    MOVui #2, DR6
    ADDSR DR6, DR5
    MOVur DR5, DR1
    ; let b:s24 -> DR7
    MOVui #0, DR8
    MOVur DR8, DR7
    ; let x:u24 -> DR9
    CMPSR DR7, DR1
    MOVui #0, DR10
    MCCsi LT, #1, DR10
    MOVur DR10, DR11
    CMPSR DR7, DR1
    MOVui #0, DR12
    MCCsi GT, #1, DR12
    ADDUR DR12, DR11
    MOVur DR11, DR13
    CMPSR DR7, DR1
    MOVui #0, DR14
    MCCsi LE, #1, DR14
    ADDUR DR14, DR13
    MOVur DR13, DR15
    CMPSR DR7, DR1
    MOVui #0, DR16
    MCCsi GE, #1, DR16
    ADDUR DR16, DR15
    MOVur DR15, DR9
    MOVur DR9, DR0
    POPur AR0, DR16
    POPur AR0, DR15
    POPur AR0, DR14
    POPur AR0, DR13
    POPur AR0, DR12
    POPur AR0, DR11
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
