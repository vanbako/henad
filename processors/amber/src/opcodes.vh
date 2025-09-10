`ifndef OPCODES_VH
`define OPCODES_VH

`include "src/sizes.vh"

// Suffix semantics (mnemonic endings):
//  - ur: unsigned register form (reg–reg ALU, unsigned flags)
//  - ui: unsigned immediate form (immediate operand; width varies by opcode; shifts use imm5 in [4:0];
//        24-bit immediates are formed via uimm banks + imm12)
//  - sr: signed register form (reg–reg ALU, signed flags)
//  - si: signed immediate form (immediate is sign-extended; width varies by opcode)
//  - so: signed offset form (PC-relative or base+offset; offset is sign-extended; width varies)

// OPCLASSES
`define OPCLASS_0 4'b0000
`define OPCLASS_1 4'b0001
`define OPCLASS_2 4'b0010
`define OPCLASS_3 4'b0011
`define OPCLASS_4 4'b0100
`define OPCLASS_5 4'b0101
`define OPCLASS_6 4'b0110
`define OPCLASS_7 4'b0111
`define OPCLASS_8 4'b1000
`define OPCLASS_9 4'b1001
`define OPCLASS_A 4'b1010
`define OPCLASS_B 4'b1011
`define OPCLASS_C 4'b1100
`define OPCLASS_D 4'b1101
`define OPCLASS_E 4'b1110
`define OPCLASS_F 4'b1111

// OPCLASS_0
`define SUBOP_NOP   4'b0000 // µop & isa
`define SUBOP_MOVur 4'b0001 // µop & isa
`define SUBOP_MCCur 4'b0010 // µop & isa
`define SUBOP_ADDur 4'b0011 // µop & isa
`define SUBOP_SUBur 4'b0100 // µop & isa
`define SUBOP_NOTur 4'b0101 // µop & isa
`define SUBOP_ANDur 4'b0110 // µop & isa
`define SUBOP_ORur  4'b0111 // µop & isa
`define SUBOP_XORur 4'b1000 // µop & isa
`define SUBOP_SHLur 4'b1001 // µop & isa
`define SUBOP_ROLur 4'b1010 // µop & isa
`define SUBOP_SHRur 4'b1011 // µop & isa
`define SUBOP_RORur 4'b1100 // µop & isa
`define SUBOP_CMPur 4'b1101 // µop & isa
`define SUBOP_TSTur 4'b1110 // µop & isa

`define OPC_NOP   {`OPCLASS_0, `SUBOP_NOP}
`define OPC_MOVur {`OPCLASS_0, `SUBOP_MOVur}
`define OPC_MCCur {`OPCLASS_0, `SUBOP_MCCur}
`define OPC_ADDur {`OPCLASS_0, `SUBOP_ADDur}
`define OPC_SUBur {`OPCLASS_0, `SUBOP_SUBur}
`define OPC_NOTur {`OPCLASS_0, `SUBOP_NOTur}
`define OPC_ANDur {`OPCLASS_0, `SUBOP_ANDur}
`define OPC_ORur  {`OPCLASS_0, `SUBOP_ORur}
`define OPC_XORur {`OPCLASS_0, `SUBOP_XORur}
`define OPC_SHLur {`OPCLASS_0, `SUBOP_SHLur}
`define OPC_ROLur {`OPCLASS_0, `SUBOP_ROLur}
`define OPC_SHRur {`OPCLASS_0, `SUBOP_SHRur}
`define OPC_RORur {`OPCLASS_0, `SUBOP_RORur}
`define OPC_CMPur {`OPCLASS_0, `SUBOP_CMPur}
`define OPC_TSTur {`OPCLASS_0, `SUBOP_TSTur}

// OPCLASS_1
`define SUBOP_LUIui 4'b0000 // µop & isa
`define SUBOP_MOVui 4'b0001 // µop & isa
`define SUBOP_ADDui 4'b0011 // µop & isa
`define SUBOP_SUBui 4'b0100 // µop & isa
`define SUBOP_ANDui 4'b0110 // µop & isa
`define SUBOP_ORui  4'b0111 // µop & isa
`define SUBOP_XORui 4'b1000 // µop & isa
`define SUBOP_SHLui 4'b1001 // µop & isa
`define SUBOP_ROLui 4'b1010 // µop & isa
`define SUBOP_SHRui 4'b1011 // µop & isa
`define SUBOP_RORui 4'b1100 // µop & isa
`define SUBOP_CMPui 4'b1101 // µop & isa

`define OPC_LUIui {`OPCLASS_1, `SUBOP_LUIui}
`define OPC_MOVui {`OPCLASS_1, `SUBOP_MOVui}
`define OPC_ADDui {`OPCLASS_1, `SUBOP_ADDui}
`define OPC_SUBui {`OPCLASS_1, `SUBOP_SUBui}
`define OPC_ANDui {`OPCLASS_1, `SUBOP_ANDui}
`define OPC_ORui  {`OPCLASS_1, `SUBOP_ORui}
`define OPC_XORui {`OPCLASS_1, `SUBOP_XORui}
`define OPC_SHLui {`OPCLASS_1, `SUBOP_SHLui}
`define OPC_ROLui {`OPCLASS_1, `SUBOP_ROLui}
`define OPC_SHRui {`OPCLASS_1, `SUBOP_SHRui}
`define OPC_RORui {`OPCLASS_1, `SUBOP_RORui}
`define OPC_CMPui {`OPCLASS_1, `SUBOP_CMPui}

// OPCLASS_2
`define SUBOP_ADDsr 4'b0011 // µop & isa
`define SUBOP_SUBsr 4'b0100 // µop & isa
`define SUBOP_NEGsr 4'b0101 // µop & isa
`define SUBOP_SHRsr 4'b1011 // µop & isa
`define SUBOP_CMPsr 4'b1101 // µop & isa
`define SUBOP_TSTsr 4'b1110 // µop & isa

`define OPC_ADDsr {`OPCLASS_2, `SUBOP_ADDsr}
`define OPC_SUBsr {`OPCLASS_2, `SUBOP_SUBsr}
`define OPC_NEGsr {`OPCLASS_2, `SUBOP_NEGsr}
`define OPC_SHRsr {`OPCLASS_2, `SUBOP_SHRsr}
`define OPC_CMPsr {`OPCLASS_2, `SUBOP_CMPsr}
`define OPC_TSTsr {`OPCLASS_2, `SUBOP_TSTsr}

// OPCLASS_3
`define SUBOP_MOVsi 4'b0001 // µop & isa
`define SUBOP_MCCsi 4'b0010 // µop & isa
`define SUBOP_ADDsi 4'b0011 // µop & isa
`define SUBOP_SUBsi 4'b0100 // µop & isa
`define SUBOP_SHRsi 4'b1011 // µop & isa
`define SUBOP_CMPsi 4'b1101 // µop & isa

`define OPC_MOVsi {`OPCLASS_3, `SUBOP_MOVsi}
`define OPC_MCCsi {`OPCLASS_3, `SUBOP_MCCsi}
`define OPC_ADDsi {`OPCLASS_3, `SUBOP_ADDsi}
`define OPC_SUBsi {`OPCLASS_3, `SUBOP_SUBsi}
`define OPC_SHRsi {`OPCLASS_3, `SUBOP_SHRsi}
`define OPC_CMPsi {`OPCLASS_3, `SUBOP_CMPsi}

// OPCLASS_4
`define SUBOP_LDso  4'b0000 // µop & isa
`define SUBOP_STso  4'b0001 // µop & isa
`define SUBOP_STui  4'b0010 // µop & isa
`define SUBOP_STsi  4'b0011 // µop & isa
`define SUBOP_LDAso 4'b0100 // µop & isa
`define SUBOP_STAso 4'b0101 // µop & isa

`define OPC_LDso  {`OPCLASS_4, `SUBOP_LDso}
`define OPC_STso  {`OPCLASS_4, `SUBOP_STso}
`define OPC_STui  {`OPCLASS_4, `SUBOP_STui}
`define OPC_STsi  {`OPCLASS_4, `SUBOP_STsi}
`define OPC_LDAso {`OPCLASS_4, `SUBOP_LDAso}
`define OPC_STAso {`OPCLASS_4, `SUBOP_STAso}

// OPCLASS_5
`define SUBOP_MOVAur 4'b0001 // µop & isa
`define SUBOP_MOVDur 4'b0010 // µop & isa
`define SUBOP_ADDAur 4'b0011 // µop & isa
`define SUBOP_SUBAur 4'b0100 // µop & isa
`define SUBOP_ADDAsr 4'b0101 // µop & isa
`define SUBOP_SUBAsr 4'b0110 // µop & isa
`define SUBOP_ADDAsi 4'b0111 // µop & isa
`define SUBOP_SUBAsi 4'b1000 // µop & isa
`define SUBOP_LEAso  4'b1001 // µop & isa
`define SUBOP_ADRAso 4'b1010 // µop & isa
`define SUBOP_MOVAui 4'b1011 // µop & isa
`define SUBOP_CMPAur 4'b1101 // µop & isa
`define SUBOP_TSTAur 4'b1110 // µop & isa

`define OPC_MOVAur {`OPCLASS_5, `SUBOP_MOVAur}
`define OPC_MOVDur {`OPCLASS_5, `SUBOP_MOVDur}
`define OPC_ADDAur {`OPCLASS_5, `SUBOP_ADDAur}
`define OPC_SUBAur {`OPCLASS_5, `SUBOP_SUBAur}
`define OPC_ADDAsr {`OPCLASS_5, `SUBOP_ADDAsr}
`define OPC_SUBAsr {`OPCLASS_5, `SUBOP_SUBAsr}
`define OPC_ADDAsi {`OPCLASS_5, `SUBOP_ADDAsi}
`define OPC_SUBAsi {`OPCLASS_5, `SUBOP_SUBAsi}
`define OPC_LEAso  {`OPCLASS_5, `SUBOP_LEAso}
`define OPC_ADRAso {`OPCLASS_5, `SUBOP_ADRAso}
`define OPC_MOVAui {`OPCLASS_5, `SUBOP_MOVAui}
`define OPC_CMPAur {`OPCLASS_5, `SUBOP_CMPAur}
`define OPC_TSTAur {`OPCLASS_5, `SUBOP_TSTAur}

// OPCLASS_6
`define SUBOP_BTP   4'b0000 // isa
`define SUBOP_JCCur 4'b0001 // µop & isa
`define SUBOP_JCCui 4'b0010 // µop & isa
`define SUBOP_BCCsr 4'b0011 // µop & isa
`define SUBOP_BCCso 4'b0100 // µop & isa
`define SUBOP_BALso 4'b0101 // µop & isa
`define SUBOP_JSRur 4'b0110 // isa
`define SUBOP_JSRui 4'b0111 // isa
`define SUBOP_BSRsr 4'b1000 // isa
`define SUBOP_BSRso 4'b1001 // isa
`define SUBOP_RET   4'b1010 // isa

`define OPC_BTP   {`OPCLASS_6, `SUBOP_BTP}
`define OPC_JCCur {`OPCLASS_6, `SUBOP_JCCur}
`define OPC_JCCui {`OPCLASS_6, `SUBOP_JCCui}
`define OPC_BCCsr {`OPCLASS_6, `SUBOP_BCCsr}
`define OPC_BCCso {`OPCLASS_6, `SUBOP_BCCso}
`define OPC_BALso {`OPCLASS_6, `SUBOP_BALso}
`define OPC_JSRur {`OPCLASS_6, `SUBOP_JSRur}
`define OPC_JSRui {`OPCLASS_6, `SUBOP_JSRui}
`define OPC_BSRsr {`OPCLASS_6, `SUBOP_BSRsr}
`define OPC_BSRso {`OPCLASS_6, `SUBOP_BSRso}
`define OPC_RET   {`OPCLASS_6, `SUBOP_RET}

// OPCLASS_7
`define SUBOP_PUSHur  4'b0000 // isa
`define SUBOP_PUSHAur 4'b0001 // isa
`define SUBOP_POPur   4'b0010 // isa
`define SUBOP_POPAur  4'b0011 // isa

`define OPC_PUSHur  {`OPCLASS_7, `SUBOP_PUSHur}
`define OPC_PUSHAur {`OPCLASS_7, `SUBOP_PUSHAur}
`define OPC_POPur   {`OPCLASS_7, `SUBOP_POPur}
`define OPC_POPAur  {`OPCLASS_7, `SUBOP_POPAur}

// OPCLASS_8
`define SUBOP_CSRRD 4'b0000 // isa
`define SUBOP_CSRWR 4'b0001 // isa

`define OPC_CSRRD {`OPCLASS_8, `SUBOP_CSRRD}
`define OPC_CSRWR {`OPCLASS_8, `SUBOP_CSRWR}

// OPCLASS_9

`define SUBOP_SRHLT  4'b0000 // µop & isa
`define SUBOP_SETSSP 4'b0001 // isa
`define SUBOP_SWI    4'b0010 // isa
`define SUBOP_SRET   4'b0011 // isa

`define OPC_SRHLT  {`OPCLASS_9, `SUBOP_SRHLT}
`define OPC_SETSSP {`OPCLASS_9, `SUBOP_SETSSP}
`define OPC_SWI    {`OPCLASS_9, `SUBOP_SWI}
`define OPC_SRET   {`OPCLASS_9, `SUBOP_SRET}

// OPCLASS_A

// OPCLASS_B

// OPCLASS_C

// OPCLASS_D

// OPCLASS_E

// OPCLASS_F

`define SUBOP_SRJCCso  4'b0000 // µop
`define SUBOP_SRMOVur  4'b0001 // µop
`define SUBOP_SRMOVAur 4'b0010 // µop
`define SUBOP_SRADDsi  4'b0011 // µop
`define SUBOP_SRSUBsi  4'b0100 // µop
`define SUBOP_SRLDso   4'b0101 // µop
`define SUBOP_SRSTso   4'b0110 // µop

`define OPC_SRJCCso  {`OPCLASS_F, `SUBOP_SRJCCso}
`define OPC_SRMOVur  {`OPCLASS_F, `SUBOP_SRMOVur}
`define OPC_SRMOVAur {`OPCLASS_F, `SUBOP_SRMOVAur}
`define OPC_SRADDsi  {`OPCLASS_F, `SUBOP_SRADDsi}
`define OPC_SRSUBsi  {`OPCLASS_F, `SUBOP_SRSUBsi}
`define OPC_SRLDso   {`OPCLASS_F, `SUBOP_SRLDso}
`define OPC_SRSTso   {`OPCLASS_F, `SUBOP_SRSTso}

function automatic [79:0] opc2str;
    input [`HBIT_OPC:0] opc;
    begin
        case (opc)
// OPCLASS_0
            `OPC_NOP:     opc2str = "NOP";
            `OPC_MOVur:   opc2str = "MOVur";
            `OPC_MCCur:   opc2str = "MCCur";
            `OPC_ADDur:   opc2str = "ADDur";
            `OPC_SUBur:   opc2str = "SUBur";
            `OPC_NOTur:   opc2str = "NOTur";
            `OPC_ANDur:   opc2str = "ANDur";
            `OPC_ORur:    opc2str = "ORur";
            `OPC_XORur:   opc2str = "XORur";
            `OPC_SHLur:   opc2str = "SHLur";
            `OPC_ROLur:   opc2str = "ROLur";
            `OPC_SHRur:   opc2str = "SHRur";
            `OPC_RORur:   opc2str = "RORur";
            `OPC_CMPur:   opc2str = "CMPur";
            `OPC_TSTur:   opc2str = "TSTur";
// OPCLASS_1
            `OPC_LUIui:   opc2str = "LUIui";
            `OPC_MOVui:   opc2str = "MOVui";
            `OPC_ADDui:   opc2str = "ADDui";
            `OPC_SUBui:   opc2str = "SUBui";
            `OPC_ANDui:   opc2str = "ANDui";
            `OPC_ORui:    opc2str = "ORui";
            `OPC_XORui:   opc2str = "XORui";
            `OPC_SHLui:   opc2str = "SHLui";
            `OPC_ROLui:   opc2str = "ROLui";
            `OPC_SHRui:   opc2str = "SHRui";
            `OPC_RORui:   opc2str = "RORui";
            `OPC_CMPui:   opc2str = "CMPui";
// OPCLASS_2
            `OPC_NEGsr:   opc2str = "NEGsr";
            `OPC_ADDsr:   opc2str = "ADDsr";
            `OPC_SUBsr:   opc2str = "SUBsr";
            `OPC_SHRsr:   opc2str = "SHRsr";
            `OPC_CMPsr:   opc2str = "CMPsr";
            `OPC_TSTsr:   opc2str = "TSTsr";
// OPCLASS_3
            `OPC_MOVsi:   opc2str = "MOVsi";
            `OPC_MCCsi:   opc2str = "MCCsi";
            `OPC_ADDsi:   opc2str = "ADDsi";
            `OPC_SUBsi:   opc2str = "SUBsi";
            `OPC_SHRsi:   opc2str = "SHRsi";
            `OPC_CMPsi:   opc2str = "CMPsi";
// OPCLASS_4
            `OPC_LDur:    opc2str = "LDur";
            `OPC_STur:    opc2str = "STur";
            `OPC_STui:    opc2str = "STui";
            `OPC_STsi:    opc2str = "STsi";
// OPCLASS_5
            `OPC_LDso:    opc2str = "LDso";
            `OPC_STso:    opc2str = "STso";
            `OPC_LDAso:   opc2str = "LDAso";
            `OPC_STAso:   opc2str = "STAso";
// OPCLASS_6
            `OPC_MOVAur:  opc2str = "MOVAur";
            `OPC_MOVDur:  opc2str = "MOVDur";
            `OPC_ADDAur:  opc2str = "ADDAur";
            `OPC_SUBAur:  opc2str = "SUBAur";
            `OPC_ADDAsr:  opc2str = "ADDAsr";
            `OPC_SUBAsr:  opc2str = "SUBAsr";
            `OPC_ADDAsi:  opc2str = "ADDAsi";
            `OPC_SUBAsi:  opc2str = "SUBAsi";
            `OPC_LEAso:   opc2str = "LEAso";
            `OPC_ADRAso:  opc2str = "ADRAso";
            `OPC_CMPAur:  opc2str = "CMPAur";
            `OPC_TSTAur:  opc2str = "TSTAur";
// OPCLASS_7
            `OPC_BTP:     opc2str = "BTP";
            `OPC_JCCur:   opc2str = "JCCur";
            `OPC_JCCui:   opc2str = "JCCui";
            `OPC_BCCsr:   opc2str = "BCCsr";
            `OPC_BCCso:   opc2str = "BCCso";
            `OPC_BALso:   opc2str = "BALso";
            `OPC_JSRur:   opc2str = "JSRur";
            `OPC_JSRui:   opc2str = "JSRui";
            `OPC_BSRsr:   opc2str = "BSRsr";
            `OPC_BSRso:   opc2str = "BSRso";
            `OPC_RET:     opc2str = "RET";
// OPCLASS_8
            `OPC_PUSHur:  opc2str = "PUSHur";
            `OPC_PUSHAur: opc2str = "PUSHAur";
            `OPC_POPur:   opc2str = "POPur";
            `OPC_POPAur:  opc2str = "POPAur";
// OPCLASS_9
            `OPC_CSRRD:   opc2str = "CSRRD";
            `OPC_CSRWR:   opc2str = "CSRWR";
// OPCLASS_A
            `OPC_SRHLT:   opc2str = "SRHLT";
            `OPC_SETSSP:  opc2str = "SETSSP";
            `OPC_SWI:     opc2str = "SWI";
            `OPC_SRET:    opc2str = "SRET";
// OPCLASS_B
// OPCLASS_C
// OPCLASS_D
// OPCLASS_E
// OPCLASS_F
            `OPC_SRMOVur: opc2str = "SRMOVur";
            `OPC_SRMOVAur:opc2str = "SRMOVAur";
            `OPC_SRJCCso: opc2str = "SRJCCso";
            `OPC_SRADDsi: opc2str = "SRADDsi";
            `OPC_SRSUBsi: opc2str = "SRSUBsi";
            `OPC_SRSTso:  opc2str = "SRSTso";
            `OPC_SRLDso:  opc2str = "SRLDso";
// DEFAULT
            default:      opc2str = "UNKNOWN";
        endcase
    end
endfunction

`endif // OPCODES_VH
