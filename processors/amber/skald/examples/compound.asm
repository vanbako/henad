    .org 0
main:
    ; prologue (skeleton, no saves)
    ; let a:u24 -> DR1
    MOVui #1, DR2
    MOVur DR2, DR1
    ; let b:u24 -> DR3
    MOVui #2, DR4
    MOVur DR4, DR3
    ; let c:s24 -> DR5
    MOVui #3, DR6
    MOVur DR6, DR5
    ADDUR DR3, DR1
    MOVui #1, DR7
    ORUR DR7, DR1
    XORUR DR3, DR1
    MOVui #2, DR8
    SHLUR DR8, DR1
    MOVui #1, DR9
    SHRUR DR9, DR1
    MOVui #1, DR10
    ADDSR DR10, DR5
    MOVui #2, DR11
    SUBSR DR11, DR5
    MOVui #1, DR12
    SHRSR DR12, DR5
    MOVur DR1, DR0
    RET
