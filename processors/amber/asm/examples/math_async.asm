; Example: Using async 24-bit math CSRs from assembler

    .org 0

start:
    ; A := 100, B := 7
    MOVui #100, DR1
    MOVui #7,   DR2

    ; Write operands
    CSRWR MATH_OPA, DR1      ; normalized to CSRWR DR1, #MATH_OPA
    CSRWR MATH_OPB, DR2

    ; Start unsigned DIVU: CTRL = START + OP(DIVU)
    MOVui #MATH_CTRL_START + MATH_OP_DIVU, DR3
    CSRWR MATH_CTRL, DR3

wait_ready:
    CSRRD MATH_STATUS, DR0
    ANDui #MATH_STATUS_READY, DR0
    BCCso EQ, wait_ready      ; loop while READY == 0

    ; Read quotient and remainder
    CSRRD MATH_RES0, DR4      ; quotient
    CSRRD MATH_RES1, DR5      ; remainder

    ; Done: fallthrough
