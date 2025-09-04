# Instructions

## Preface

Bit-field annotations indicate bit positions in the 24-bit instruction word.
For example, [23-20] marks the high 4 bits, with the left number the most
significant bit and the right number the least significant.
Registers use the following naming:
  DRx - data registers, ARx - address registers, SRx - special registers.
Suffixes such as t and s denote target and source respectively.
Braces list flags affected by the instruction, e.g. {Z, C} updates the Zero
and Carry flags.

opclass 0000 Core ALU (reg–reg, unsigned flags)

NOP                            ; no operation
    µop
    isa                no_oper
    [23-20] opclass            ; 0000
    [19-16] subop              ; 0000
    [15- 0] RESERVED
    {}
MOVur    DRs, DRt              ; DRt = DRs;
    µop
    isa                copy ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 0001
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z}
MCCur    CC, DRs, DRt          ; if (CC) DRt = DRs;
    µop
    isa                cond_copy.[cc] ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 0010
    [15-12] DRt
    [11- 8] DRs
    [ 7- 4] CC
    [ 3- 0] RESERVED
    {Z}                        ; only if move happens
ADDur    DRs, DRt              ; unsigned DRt += DRs;
    µop
    isa                add.u ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 0011
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, C}
SUBur    DRs, DRt              ; unsigned DRt -= DRs;
    µop
    isa                sub.u ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 0100
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, C}
NOTur    DRt                   ; DRt ~= DRt;
    µop
    isa                not dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 0101
    [15-12] DRt
    [11- 0] RESERVED
    {Z}
ANDur    DRs, DRt              ; DRt &= DRs;
    µop
    isa                and ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 0110
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z}
ORur     DRs, DRt              ; DRt |= DRs;
    µop
    isa                or ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 0111
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z}
XORur    DRs, DRt              ; DRt ^= DRs;
    µop
    isa                xor ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 1000
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z}
SHLur    DRs, DRt              ; DRt <<= DRs[4:0];
    µop
    isa                shift_left ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 1001
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, C}                     ; only if DRs is non-zero, otherwise unchanged
ROLur    DRs, DRt              ; DRt <<<= DRs[4:0];
    µop
    isa                rot_left ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 1010
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, C}                     ; only if DRs is non-zero, otherwise unchanged
SHRur    DRs, DRt              ; unsigned DRt >>= DRs[4:0];
    µop
    isa                shift_right ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 1011
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, C}                     ; only if DRs is non-zero, otherwise unchanged
RORur    DRs, DRt              ; DRt >>>= DRs[4:0];
    µop
    isa                rot_right ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 1100
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, C}                     ; only if DRs is non-zero, otherwise unchanged
CMPur    DRs, DRt              ; unsigned compare DRs, DRt;
    µop
    isa                comp.u ds, dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 1101
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, C}
TSTur    DRt                   ; unsigned DRt == 0;
    µop
    isa                test.u dt
    [23-20] opclass            ; 0000
    [19-16] subop              ; 1110
    [15-12] DRt
    [11- 0] RESERVED
    {Z}

; opclass 0001 Core ALU (imm/uimm, unsigned flags)

; LUIui ; [OPC]ui sequences must be made atomic
; A [OPC]ui without previous LUIui is undefined behaviour for now (I should implement an exception for this)

LUIui    #x, #imm12            ; case (x); 0: uimm[11-0] = imm12; 1: uimm[23-12] = imm12; 2: uimm[35-24] = imm12; endcase;
    µop
    isa                load_upper_imm x, imm12
    [23-20] opclass            ; 0001
    [19-16] subop              ; 0000
    [15-14] x
    [13-12] RESERVED
    [11- 0] imm12
    {}
MOVui    #imm12, DRt           ; DRt = {uimm[11-0], imm12};
    µop
    isa                copy imm24, dt (macro: LUIui #0, #imm24[23-12]; MOVui #imm24[11-0], DRt)
    [23-20] opclass            ; 0001
    [19-16] subop              ; 0001
    [15-12] DRt
    [11- 0] imm12
    {Z}
ADDui    #imm12, DRt           ; unsigned DRt += {uimm[11-0], imm12};
    µop
    isa                add.u imm24, dt (macro: LUIui #0, #imm24[23-12]; ADDui #imm24[11-0], DRt)
    [23-20] opclass            ; 0001
    [19-16] subop              ; 0011
    [15-12] DRt
    [11- 0] imm12
    {Z, C}
SUBui    #imm12, DRt           ; unsigned DRt -= {uimm[11-0], imm12};
    µop
    isa                sub.u imm24, dt (macro: LUIui #0, #imm24[23-12]; SUBui #imm24[11-0], DRt)
    [23-20] opclass            ; 0001
    [19-16] subop              ; 0100
    [15-12] DRt
    [11- 0] imm12
    {Z, C}
ANDui    #imm12, DRt           ; DRt &= {uimm[11-0], imm12};
    µop
    isa                and imm24, dt (macro: LUIui #0, #imm24[23-12]; ANDui #imm24[11-0], DRt)
    [23-20] opclass            ; 0001
    [19-16] subop              ; 0110
    [15-12] DRt
    [11- 0] imm12
    {Z}
ORui     #imm12, DRt           ; DRt |= {uimm[11-0], imm12};
    µop
    isa                or imm24, dt (macro: LUIui #0, #imm24[23-12]; ORui #imm24[11-0], DRt)
    [23-20] opclass            ; 0001
    [19-16] subop              ; 0111
    [15-12] DRt
    [11- 0] imm12
    {Z}
XORui    #imm12, DRt           ; DRt ^= {uimm[11-0], imm12};
    µop
    isa                xor imm24, dt (macro: LUIui #0, #imm24[23-12]; XORui #imm24[11-0], DRt)
    [23-20] opclass            ; 0001
    [19-16] subop              ; 1000
    [15-12] DRt
    [11- 0] imm12
    {Z}
SHLui    #imm5, DRt            ; DRt <<= imm5;
    µop
    isa                shift_left imm5, dt
    [23-20] opclass            ; 0001
    [19-16] subop              ; 1001
    [15-12] DRt
    [11- 5] RESERVED
    [ 4- 0] imm5
    {Z, C}                     ; only if imm5 is non-zero, otherwise unchanged
ROLui    #imm5, DRt            ; DRt <<<= imm5;
    µop
    isa                rot_left imm5, dt
    [23-20] opclass            ; 0001
    [19-16] subop              ; 1010
    [15-12] DRt
    [11- 5] RESERVED
    [ 4- 0] imm5
    {Z, C}                     ; only if imm5 is non-zero, otherwise unchanged
SHRui    #imm5, DRt            ; unsigned DRt >>= imm5;
    µop
    isa                shift_right imm5, dt
    [23-20] opclass            ; 0001
    [19-16] subop              ; 1011
    [15-12] DRt
    [11- 5] RESERVED
    [ 4- 0] imm5
    {Z, C}                     ; only if imm5 is non-zero, otherwise unchanged
RORui    #imm5, DRt            ; DRt >>>= imm5;
    µop
    isa                rot_right imm5, dt
    [23-20] opclass            ; 0001
    [19-16] subop              ; 1100
    [15-12] DRt
    [11- 5] RESERVED
    [ 4- 0] imm5
    {Z, C}                     ; only if imm5 is non-zero, otherwise unchanged
CMPui    #imm12, DRt           ; unsigned compare {uimm[11-0], imm12}, DRt;
    µop
    isa                comp.u imm24, dt (macro: LUIui #0, #imm24[23-12]; CMPui #imm24[11-0], DRt)
    [23-20] opclass            ; 0001
    [19-16] subop              ; 1101
    [15-12] DRt
    [11- 0] imm12
    {Z, C}

; opclass 0010 Core ALU (reg–reg, signed flags)

ADDsr    DRs, DRt              ; signed DRt += DRs;
    µop
    isa                add.s ds, dt
    [23-20] opclass            ; 0010
    [19-16] subop              ; 0011
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, N, V}
SUBsr    DRs, DRt              ; signed DRt -= DRs;
    µop
    isa                sub.s ds, dt
    [23-20] opclass            ; 0010
    [19-16] subop              ; 0100
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, N, V}
NEGsr    DRt                   ; signed DRt = -DRt;
    µop
    isa                neg dt
    [23-20] opclass            ; 0010
    [19-16] subop              ; 0101
    [15-12] DRt
    [11- 0] RESERVED
    {Z, N, V}
SHRsr    DRs, DRt              ; signed DRt >>= DRs[4:0];
    µop
    isa                shift_right.s ds, dt
    [23-20] opclass            ; 0010
    [19-16] subop              ; 1011
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, N, C}                  ; only if DRs is non-zero, otherwise unchanged
CMPsr    DRs, DRt              ; signed compare DRs, DRt;
    µop
    isa                comp.s ds, dt
    [23-20] opclass            ; 0010
    [19-16] subop              ; 1101
    [15-12] DRt
    [11- 8] DRs
    [ 7- 0] RESERVED
    {Z, N, V}
TSTsr    DRt                   ; signed DRt test;
    µop
    isa                test.s dt
    [23-20] opclass            ; 0010
    [19-16] subop              ; 1110
    [15-12] DRt
    [11- 0] RESERVED
    {Z, N}

; opclass 0011 Core ALU (imm, signed flags / PC-rel)

MOVsi    #imm12, DRt           ; signed DRt = sext(imm12);
    µop
    isa                copy.s imm12, dt
    [23-20] opclass            ; 0011
    [19-16] subop              ; 0000
    [15-12] DRt
    [11- 0] imm12
    {Z, N}
MCCsi    CC, #imm8, DRt        ; if (CC) DRt = sext(imm8);
    µop
    isa               cond_copy.s.[cc] imm8, dt
    [23-20] opclass            ; 0011
    [19-16] subop              ; 0001
    [15-12] DRt
    [11- 8] CC
    [ 7- 0] imm8
    {Z}                        ; only if move happens
ADDsi    #imm12, DRt           ; signed DRt += sext(imm12);
    µop
    isa                add.s imm12, dt
    [23-20] opclass            ; 0011
    [19-16] subop              ; 0011
    [15-12] DRt
    [11- 0] imm12
    {Z, N, V}
SUBsi    #imm12, DRt           ; signed DRt -= sext(imm12);
    µop
    isa                sub.s imm12, dt
    [23-20] opclass            ; 0011
    [19-16] subop              ; 0100
    [15-12] DRt
    [11- 0] imm12
    {Z, N, V}
SHRsi    #imm5, DRt            ; signed DRt >>= imm5;
    µop
    isa                shift_right.s imm5, dt
    [23-20] opclass            ; 0011
    [19-16] subop              ; 1011
    [15-12] DRt
    [11- 5] RESERVED
    [ 4- 0] imm5
    {Z, N, C}                  ; only if imm5 is non-zero, otherwise unchanged
CMPsi    #imm12, DRt           ; signed compare sext(imm12), DRt;
    µop
    isa               comp.s imm12, dt
    [23-20] opclass            ; 0011
    [19-16] subop              ; 1101
    [15-12] DRt
    [11- 0] imm12
    {Z, N, V}

; opclass 0100 Loads/Stores (base only)
LDur     (ARs), DRt            ; DRt = (ARs);
    µop
    isa                load (as), dt
    [23-20] opclass            ; 0100
    [19-16] subop              ; 0000
    [15-12] DRt
    [11-10] ARs
    [ 9- 0] RESERVED
    {}
STur     DRs, (ARt)            ; (ARt) = DRs;
    µop
    isa                store ds, (at)
    [23-20] opclass            ; 0100
    [19-16] subop              ; 0001
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
STui     #imm12, (ARt)         ; (ARt) = {uimm[11-0], imm12};
    µop
    isa                store imm24, (at) (macro: LUIui #0, #imm24[23-12]; STui #imm24[11-0], (ARt))
    [23-20] opclass            ; 0100
    [19-16] subop              ; 0010
    [15-14] ARt
    [13-12] RESERVED
    [11- 0] imm12
    {}
STsi     #imm14, (ARt)         ; (ARt) = sext(imm14);
    µop
    isa                store.s imm14, (at)
    [23-20] opclass            ; 0100
    [19-16] subop              ; 0011
    [15-14] ARt
    [13- 0] imm14
    {}

; opclass 0101 Loads/Stores (base + signed offset)
; don't need the .s suffix as offsets are always signed

LDso     #imm10(ARs), DRt      ; DRt = (ARs + sext(imm10));
    µop
    isa                load imm10(as), dt
    [23-20] opclass            ; 0101
    [19-16] subop              ; 0000
    [15-12] DRt
    [11-10] ARs
    [ 9- 0] imm10
    {}
STso     DRs, #imm10(ARt)      ; (ARt + sext(imm10)) = DRs;
    µop
    isa                store ds, imm10(at)
    [23-20] opclass            ; 0101
    [19-16] subop              ; 0001
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] imm10
    {}
LDAso       #imm12(ARs), ARt   ; ARt = (ARs + sext(imm12)); (signed + operation)
    µop
    isa                load imm12(as), at
    [23-20] opclass            ; 0101
    [19-16] subop              ; 0010
    [15-14] ARt
    [13-12] ARs
    [11- 0] imm12
    {}
STAso       ARs, #imm12(ARt)   ; (ARt + sext(imm12)) = ARs; (signed + operation)
    µop
    isa                store as, imm12(at)
    [23-20] opclass            ; 0101
    [19-16] subop              ; 0011
    [15-14] ARt
    [13-12] ARs
    [11- 0] imm12
    {}

; opclass 0110 Address-register ALU & moves (reg)

MOVAur      DRs, ARt, H|L      ; if (L) ARt[23:0] = DRs; else ARt[47:24] = DRs;
    µop
    isa                copy.[h|l] ds, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0001
    [15-14] ARt
    [13-10] DRs
    [ 9   ] H|L                ; H=1, L=0
    [ 8- 0] RESERVED
    {}
MOVDur     ARs, DRt, H|L       ; if (L) DRt = ARs[23:0]; else DRt = ARs[47:24];
    µop
    isa                copy.[h|l] as, dt
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0010
    [15-12] DRt
    [11-10] ARs
    [ 9   ] H|L                ; H=1, L=0
    [ 8- 0] RESERVED
    {Z}
ADDAur      DRs, ARt           ; unsigned ARt += zext(DRs);
    µop
    isa                add.u ds, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0011
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
SUBAur      DRs, ARt           ; unsigned ARt -= zext(DRs);
    µop
    isa                sub.u ds, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0100
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
ADDAsr      DRs, ARt           ; signed ARt += sext(DRs);
    µop
    isa                add.s ds, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0101
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
SUBAsr      DRs, ARt           ; signed ARt -= sext(DRs);
    µop
    isa                sub.s ds, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0110
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
ADDAsi      #imm12, ARt        ; signed ARt += sext(imm12);
    µop
    isa                add.s imm12, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0111
    [15-14] ARt
    [11- 0] imm12
    {}
SUBAsi      #imm12, ARt        ; signed ARt -= sext(imm12);
    µop
    isa                sub.s imm12, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 1000
    [15-14] ARt
    [11- 0] imm12
    {}
LEAso       ARs+#imm12, ARt    ; ARt = ARs + sext(imm12); (signed + operation)
    µop
    isa                copy_offset imm12, as, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 1001
    [15-14] ARt
    [13-12] ARs
    [11- 0] imm12
    {}
ADRAso      PC+#imm14, ARt     ; ARt = PC + sext(imm14); (signed + operation)
    µop
    isa                copy_from_pc_offset imm14, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 1010
    [15-14] ARt
    [13- 0] imm14
    {}
; TODO: MOVAui (#imm48[47-36]; LUIui #1, #imm48[35-24]; LUIui #0, #imm48[23-12]; MOVAui #imm48[11-0], ARt)
CMPAur      ARs, ARt           ; unsigned compare ARs, ARt;
    µop
    isa                comp.u as, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 1101
    [15-14] ARt
    [13-12] ARs
    [11- 0] RESERVED
    {Z, C}
TSTAur      ARt                ; unsigned ARt == 0;
    µop
    isa                test.u at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 1110
    [15-14] ARt
    [13- 0] RESERVED
    {Z}

; opclass 0111 Control flow (absolute via AR / long immediates) & linkage

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

; opclass 1000 Stack helpers

PUSHur      DRs, (ARt)         ; --1(ARt) = DRs;
    isa                push ds, (at)
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0000
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
    µops
        SUBAsi      #1, ARt
        STur        DRs, (ARt)
PUSHAur     ARs, (ARt)         ; --2(ARt) = ARs;
    isa                push as, (at)
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0001
    [15-14] ARt
    [13-12] ARs
    [11- 0] RESERVED
    {}
    µops
        SUBAsi      #2, ARt
        STAso       ARs, #0(ARt)
POPur       (ARs), DRt         ; DRt = (ARs)1++
    isa                pop (as), dt
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0010
    [15-12] DRt
    [11-10] ARs
    [ 9- 0] RESERVED
    {}
    µops
        ADDAsi      #1, ARs
        LDso        #-1(ARs), DRt
POPAur      (ARs), ARt         ; ARt = (ARs)2++
    isa                pop (as), at
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0011
    [15-14] ARt
    [13-12] ARs
    [11- 0] RESERVED
    {}
    µops
        ADDAsi      #2, ARs
        LDAso       #-2(ARs), ARt

; opclass 1001 CSR access

CSRRD     #csr8, DRt          ; DRt = CSR[csr8] (24-bit)
    isa                csr_read csr8, dt
    [23-20] opclass            ; 1001
    [19-16] subop              ; 0000
    [15-12] DRt
    [11- 8] RESERVED
    [ 7- 0] csr8
    {Z}

CSRWR     DRs, #csr8          ; CSR[csr8] = DRs (24-bit)
    isa                csr_write ds, csr8
    [23-20] opclass            ; 1001
    [19-16] subop              ; 0001
    [15-14] RESERVED
    [13-10] DRs
    [ 9- 8] RESERVED
    [ 7- 0] csr8
    {}

; opclass 1010 privileged / kernel-only

SRHLT                          ; halt;
    µop
    isa                halt
    [23-20] opclass            ; 1010
    [19-16] subop              ; 0000
    [15- 0] RESERVED
    {}
SETSSP      ARs                ; SSP = ARs;
    isa                copy_to_ssp as
    [23-20] opclass            ; 1010
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
    ; Notes:
    ;   - The three upper immediate banks are loaded via prior LUIui #2/#1/#0 instructions.
    ;   - imm12 provides the low 12 bits of the absolute handler address.
    ;   - On a taken SWI, the branch flushes earlier in-flight instructions as usual.
    [23-20] opclass            ; 1010
    [19-16] subop              ; 0010
    [15-12] RESERVED
    [11- 0] imm12
    {}

; opclass 1011 MMU / TLB & Cache management

; opclass 1100 Atomics & SMP

; opclass 1101 24 bit integer math unit

; opclass 1110 24 bit float math unit

; opclass 1111 µop (future ISA can use the same opcodes)

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
