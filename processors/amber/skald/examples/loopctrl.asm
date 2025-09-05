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
    ; let i:u24 -> DR1
    MOVui #0, DR2
    MOVur DR2, DR1
    ; let acc:u24 -> DR3
    MOVui #0, DR4
    MOVur DR4, DR3
__sk_while_1:
    MOVui #10, DR5
    CMPUR DR5, DR1
    MOVui #0, DR6
    MCCsi BT, #1, DR6
    TSTUR DR6
    BCCso EQ, __sk_endwhile_2
    MOVui #1, DR7
    ADDUR DR7, DR1
    MOVui #3, DR8
    CMPUR DR8, DR1
    MOVui #0, DR9
    MCCsi EQ, #1, DR9
    TSTUR DR9
    BCCso EQ, __sk_endif_3
    BALso __sk_while_1
__sk_endif_3:
    MOVui #8, DR10
    CMPUR DR10, DR1
    MOVui #0, DR11
    MCCsi EQ, #1, DR11
    TSTUR DR11
    BCCso EQ, __sk_endif_4
    BALso __sk_endwhile_2
__sk_endif_4:
    ADDUR DR1, DR3
    BALso __sk_while_1
__sk_endwhile_2:
    MOVur DR3, DR0
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
