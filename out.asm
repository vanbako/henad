    .org 0
main:
    ; prologue (callee-saved)
    ADRAso #__skald_stack_top, AR0
    PUSHAur AR1, AR0
    PUSHAur AR2, AR0
    PUSHAur AR3, AR0
    PUSHAur AR4, AR0
    PUSHur DR1, AR0
    PUSHur DR2, AR0
    PUSHur DR3, AR0
    PUSHur DR4, AR0
    PUSHur DR5, AR0
    PUSHur DR6, AR0
    PUSHur DR7, AR0
    PUSHur DR8, AR0
    SUBASI #2, AR0
    LEASO AR0, #0, AR1
    ; alloc frame for p:Point size 2w -> AR1 at +0
    ; let p:Point -> AR1 (frame)
    ; let x:u24 -> DR1
    MOVui #5, DR2
    STSO DR2, #0, AR1
    MOVui #7, DR3
    STSO DR3, #1, AR1
    LDSO #0, AR1, DR4
    MOVur DR4, DR5
    LDSO #1, AR1, DR6
    ADDUR DR6, DR5
    MOVur DR5, DR1
    ; let ax:addr<u24> -> AR2
    LEASO AR1, #0, AR3
    LEASO AR3, #0, AR2
    ; let bx:u24 -> DR7
    LEASO AR1, #0, AR4
    LDSO #0, AR4, DR8
    MOVur DR8, DR7
    ADDUR DR7, DR1
    ADDASI #2, AR0
    POPur AR0, DR8
    POPur AR0, DR7
    POPur AR0, DR6
    POPur AR0, DR5
    POPur AR0, DR4
    POPur AR0, DR3
    POPur AR0, DR2
    POPur AR0, DR1
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
