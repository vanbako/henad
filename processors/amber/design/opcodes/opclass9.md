# opclass 1001 privileged / kernel-only

SRHLT                          ; halt;
    µop
    isa                halt
    [23-20] opclass            ; 1001
    [19-16] subop              ; 0000
    [15- 0] RESERVED
    {}
SETSSP      ARs                ; SSP = ARs;
    isa                copy_to_ssp as
    [23-20] opclass            ; 1001
    [19-16] subop              ; 0001
    [15-14] ARs
    [13- 0] RESERVED
    {}
    µops
        SRMOVAur     ARs, SSP

SWI        #imm12             ; software interrupt to absolute handler
    isa                swi #imm12
    ; Semantics:
    ;   LR := PC + 1 (return address)
    ;   PC := {UIMM2[47:36], UIMM1[35:24], UIMM0[23:12], imm12[11:0]}
    ;   Mode: enter kernel mode
    ; Notes:
    ;   - The three upper immediate banks are loaded via prior LUIui #2/#1/#0 instructions.
    ;   - imm12 provides the low 12 bits of the absolute handler address.
    ;   - On a taken SWI, the branch flushes earlier in-flight instructions as usual.
    [23-20] opclass            ; 1001
    [19-16] subop              ; 0010
    [15-12] RESERVED
    [11- 0] imm12
    {}

SRET                          ; supervisor return
    isa                sret
    ; Semantics:
    ;   PC := LR (return to address saved by SWI/JSR sequence)
    ;   Mode: leave kernel mode and resume in user mode
    [23-20] opclass            ; 1001
    [19-16] subop              ; 0011
    [15- 0] RESERVED
    {}
