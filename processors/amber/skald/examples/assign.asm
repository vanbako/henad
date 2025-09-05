    .org 0
main:
    ; prologue (skeleton, no saves)
    ; let x:u24 -> DR1
    MOVui #1, DR2
    MOVui #2, DR3
    MOVui #3, DR4
    MOVui #4, DR5
    MOVur DR4, DR6
    ADDUR DR5, DR6
    MOVur DR3, DR7
    SUBUR DR6, DR7
    MOVur DR2, DR8
    SUBUR DR7, DR8
    MOVur DR8, DR1
    MOVui #1, DR9
    MOVur DR1, DR10
    ADDUR DR9, DR10
    MOVur DR10, DR1
    MOVur DR1, DR0
    RET
