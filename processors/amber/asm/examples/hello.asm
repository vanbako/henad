; Minimal Amber assembly example (skeleton)
; Assembles NOP and MOVur using the partial spec

    .org 0

start:
    NOP
    MOVur DR1, DR2    ; DR2 := DR1

    ; Signed immediate move and add
    MOVsi #-1, DR3
    ADDui #0x123, DR4

next:
    ; Simple forward branch using label expression
    BCCso AL, next     ; branch always to self (imm=0)

    ; Base+offset load/store (OP5)
    LDso #-1(AR0), DR5
    STso DR6, #2(AR1)

    ; Conditional set imm8 when Z=1
    MCCsi EQ, #1, DR7

    ; Absolute jump/call using macro expansion (LUIui*3 + JCCui/JSRui)
    JCCui AL, start
    JSRui start

    ; Address register ops (OP6)
    ADDAsi #4, AR0       ; AR0 += 4
    LEAso AR1+#8, AR2    ; AR2 = AR1 + 8
    ADRAso .+2, AR3      ; AR3 = PC + 2 (relative)
    BCCsr AL, PC+DR0     ; Branch via PC + DR0 (encodes CC+DRt)

    ; Alignment and equ example
    .equ CONST, 0x12
    .align 4             ; align PC to next multiple of 4 words
    MOVui #CONST, DR0

    ; Move with H/L halves
    MOVAur DR1, AR0, L
    MOVDur AR2, DR3, H
