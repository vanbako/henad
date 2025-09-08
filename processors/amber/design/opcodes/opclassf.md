# opclass 1111 µop

SRMOVur     SRs, SRt           ; SRt = SRs;
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0000
    [15-14] SRt
    [13-12] SRs
    [11- 0] RESERVED
    {}
SRMOVAur    ARs, SRt           ; SRt = ARs;
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0001
    [15-14] SRt
    [13-12] ARs
    [11- 0] RESERVED
    {}
SRJCCso     CC, SRt+#imm10     ; if (CC) goto SRt + sext(imm10); (signed + operation)
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0010
    [15-14] SRt
    [13-10] CC
    [ 9- 0] imm10
    {}
SRADDsi     #imm14, SRt        ; signed SRt += sext(imm14);
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0011
    [15-14] SRt
    [13- 0] imm14
    {}
SRSUBsi     #imm14, SRt        ; signed SRt -= sext(imm14);
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0100
    [15-14] SRt
    [13- 0] imm14
    {}
SRSTso      SRs, #imm12(SRt)   ; (SRt + sext(imm12)) = SRs; (signed + operation)
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0101
    [15-14] SRt
    [13-12] SRs
    [11- 0] imm12
    {}
SRLDso      #imm12(SRs), SRt   ; SRt = (SRs + sext(imm12)); (signed + operation)
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0110
    [15-14] SRt
    [13-12] SRs
    [11- 0] imm12
    {}
