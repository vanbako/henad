    .org 0
GLOBAL_U:
    .dw24 #1
GLOBAL_P:
    .dw24 #0
    .dw24 #0
main:
    ; prologue (skeleton, no saves)
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
    RET
