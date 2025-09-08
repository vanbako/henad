# opclass 0111 Control flow (absolute via AR / long immediates) & linkage

BTP                            ; branch target pad
    isa                branch_target_pad
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0000
    [15- 0] RESERVED
    {}
JCCur    CC, ARt               ; if (CC) goto ARt;
    µop
    isa                jump.[cc] at
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0001
    [15-14] ARt
    [13-10] CC
    [ 9- 0] RESERVED
    {}
JCCui    CC, #imm12            ; if (CC) goto {uimm[35-0], imm12};
    µop
    isa                jump.[cc] imm48 (macro: LUIui #2, #imm48[47-36]; LUIui #1, #imm48[35-24]; LUIui #0, #imm48[23-12]; JCCui CC, #imm48[11-0])
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0010
    [15-12] CC
    [11- 0] imm12
    {}
BCCsr    CC, PC+DRt            ; if (CC) goto PC+signed(DRt);
    µop
    isa               branch.[cc] dt
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0011
    [15-12] DRt
    [11- 8] CC
    [ 7- 0] RESERVED
    {}
BCCso    CC, PC+#imm12         ; if (CC) goto PC+sext(imm12);
    µop
    isa                branch.[cc] imm12
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0100
    [15-12] CC
    [11- 0] imm12
    {}
BALso    PC+#imm16             ; goto PC+sext(imm16);
    µop
    isa                branch.always imm16
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0101
    [15- 0] imm16
    {}
JSRur       ARt                ; call ARt;
    isa                jump_sub at
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0110
    [15-14] ARt
    [13- 0] RESERVED
    {}
    µops
        SRSUBsi     #2, SSP
        SRSTso      LR, #0(SSP)
        SRMOVur     PC, LR
        JCCur       AL, ARt
JSRui       #imm12             ; call {uimm[35-0], imm12};
    isa                jump_sub imm48 (macro: LUIui #2, #imm48[47-36]; LUIui #1, #imm48[35-24]; LUIui #0, #imm48[23-12]; JSRui #imm48[11-0])
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0111
    [15-12] RESERVED
    [11- 0] imm12
    {}
    µops
        SRSUBsi     #2, SSP
        SRSTso      LR, #0(SSP)
        SRMOVur     PC, LR
        JCCui       AL, #imm12
BSRsr       PC+DRt             ; call PC + sext(DRt);
    isa                branch_sub dt
    [23-20] opclass            ; 0111
    [19-16] subop              ; 1000
    [15-12] DRt
    [11- 0] RESERVED
    {}
    µops
        SRSUBsi     #2, SSP
        SRSTso      LR, #0(SSP)
        SRMOVur     PC, LR
        BCCsr       AL, PC+DRt
BSRso       PC+#imm16          ; call PC + sext(imm16); (signed + operation)
    isa                branch_sub imm16
    [23-20] opclass            ; 0111
    [19-16] subop              ; 1001
    [15- 0] imm16
    {}
    µops
        SRSUBsi     #2, SSP
        SRSTso      LR, #0(SSP)
        SRMOVur     PC, LR
        BALso       PC+#imm16
RET                            ; return
    isa                return
    [23-20] opclass            ; 0111
    [19-16] subop              ; 1010
    [15- 0] RESERVED
    {}
    µops
        SRADDsi     #2, SSP
        SRLDso      #-2(SSP), LR
        SRJCCso     AL, LR+#1
