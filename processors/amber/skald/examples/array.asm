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
    PUSHur DR1, AR0
    PUSHur DR2, AR0
    PUSHur DR3, AR0
    PUSHur DR4, AR0
    PUSHur DR5, AR0
    PUSHur DR6, AR0
    PUSHur DR7, AR0
    PUSHur DR8, AR0
    PUSHur DR9, AR0
    SUBASI #8, AR0
    LEASO AR0, #0, AR1
    LEASO AR0, #4, AR2
    ; alloc frame for data:u24[4] size 4w -> AR1 at +0
    ; alloc frame for pairs:Pair[2] size 4w -> AR2 at +4
    ; let data:u24[4] -> AR1 (frame)
    ; let i:u24 -> DR1
    MOVui #1, DR2
    MOVur DR2, DR1
    MOVui #0, DR3
    LEASO AR1, #0, AR3
    ADDAUR DR3, AR3
    MOVui #5, DR4
    STSO DR4, #0, AR3
    LEASO AR1, #0, AR4
    ADDAUR DR1, AR4
    MOVui #7, DR5
    STSO DR5, #0, AR4
    ; let x:u24 -> DR6
    LEASO AR1, #0, AR5
    ADDAUR DR1, AR5
    LDSO #0, AR5, DR7
    MOVur DR7, DR6
    ; let pairs:Pair[2] -> AR2 (frame)
    MOVui #1, DR8
    MOVui #0, DR9
    ADDUR DR8, DR9
    ADDUR DR8, DR9
    LEASO AR2, #0, AR6
    ADDAUR DR9, AR6
    STSO DR6, #0, AR6
    ADDASI #8, AR0
    POPur AR0, DR9
    POPur AR0, DR8
    POPur AR0, DR7
    POPur AR0, DR6
    POPur AR0, DR5
    POPur AR0, DR4
    POPur AR0, DR3
    POPur AR0, DR2
    POPur AR0, DR1
    POPAur AR0, AR6
    POPAur AR0, AR5
    POPAur AR0, AR4
    POPAur AR0, AR3
    POPAur AR0, AR2
    POPAur AR0, AR1
    RET
    ADDASI #8, AR0
    POPur AR0, DR9
    POPur AR0, DR8
    POPur AR0, DR7
    POPur AR0, DR6
    POPur AR0, DR5
    POPur AR0, DR4
    POPur AR0, DR3
    POPur AR0, DR2
    POPur AR0, DR1
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
