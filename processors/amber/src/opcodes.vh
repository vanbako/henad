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
//  - v : checked/trap variant (raises SWI on UB: range/overflow/bounds)

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
`define SUBOP_SHLuiv 4'b1110 // isa (trap on range)
`define SUBOP_SHRuiv 4'b1111 // isa (trap on range)

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
`define OPC_SHLuiv {`OPCLASS_1, `SUBOP_SHLuiv}
`define OPC_SHRuiv {`OPCLASS_1, `SUBOP_SHRuiv}

// OPCLASS_2
`define SUBOP_ADDsr  4'b0011 // µop & isa
`define SUBOP_SUBsr  4'b0100 // µop & isa
`define SUBOP_NEGsr  4'b0101 // µop & isa
`define SUBOP_NEGsv  4'b0110 // isa (trap on overflow)
`define SUBOP_ADDsv  4'b0111 // isa (trap on overflow)
`define SUBOP_SUBsv  4'b1000 // isa (trap on overflow)
`define SUBOP_SHRsrv 4'b1010 // isa (trap on range)
`define SUBOP_SHRsr  4'b1011 // µop & isa
`define SUBOP_CMPsr  4'b1101 // µop & isa
`define SUBOP_TSTsr  4'b1110 // µop & isa

`define OPC_ADDsr {`OPCLASS_2, `SUBOP_ADDsr}
`define OPC_SUBsr {`OPCLASS_2, `SUBOP_SUBsr}
`define OPC_NEGsr {`OPCLASS_2, `SUBOP_NEGsr}
`define OPC_NEGsv {`OPCLASS_2, `SUBOP_NEGsv}
`define OPC_SHRsr {`OPCLASS_2, `SUBOP_SHRsr}
`define OPC_SHRsrv {`OPCLASS_2, `SUBOP_SHRsrv}
`define OPC_CMPsr {`OPCLASS_2, `SUBOP_CMPsr}
`define OPC_TSTsr {`OPCLASS_2, `SUBOP_TSTsr}
`define OPC_ADDsv {`OPCLASS_2, `SUBOP_ADDsv}
`define OPC_SUBsv {`OPCLASS_2, `SUBOP_SUBsv}

// OPCLASS_3
`define SUBOP_MOVsi 4'b0001 // µop & isa
`define SUBOP_MCCsi 4'b0010 // µop & isa
`define SUBOP_ADDsi 4'b0011 // µop & isa
`define SUBOP_SUBsi 4'b0100 // µop & isa
`define SUBOP_ADDsiv 4'b0110 // isa (trap on overflow)
`define SUBOP_SUBsiv 4'b0111 // isa (trap on overflow)
`define SUBOP_SHRsi  4'b1011 // µop & isa
`define SUBOP_SHRsiv 4'b1100 // isa (trap on range)
`define SUBOP_CMPsi 4'b1101 // µop & isa

`define OPC_MOVsi {`OPCLASS_3, `SUBOP_MOVsi}
`define OPC_MCCsi {`OPCLASS_3, `SUBOP_MCCsi}
`define OPC_ADDsi {`OPCLASS_3, `SUBOP_ADDsi}
`define OPC_SUBsi {`OPCLASS_3, `SUBOP_SUBsi}
`define OPC_ADDsiv {`OPCLASS_3, `SUBOP_ADDsiv}
`define OPC_SUBsiv {`OPCLASS_3, `SUBOP_SUBsiv}
`define OPC_SHRsi  {`OPCLASS_3, `SUBOP_SHRsi}
`define OPC_SHRsiv {`OPCLASS_3, `SUBOP_SHRsiv}
`define OPC_CMPsi {`OPCLASS_3, `SUBOP_CMPsi}

// OPCLASS_4 — CHERI Loads/Stores (via CR)
`define SUBOP_LDcso  4'b0000 // isa
`define SUBOP_STcso  4'b0001 // isa
`define SUBOP_STui   4'b0010 // isa
`define SUBOP_STsi   4'b0011 // isa
`define SUBOP_CLDcso 4'b0100 // isa
`define SUBOP_CSTcso 4'b0101 // isa

`define OPC_LDcso  {`OPCLASS_4, `SUBOP_LDcso}
`define OPC_STcso  {`OPCLASS_4, `SUBOP_STcso}
`define OPC_STui   {`OPCLASS_4, `SUBOP_STui}
`define OPC_STsi   {`OPCLASS_4, `SUBOP_STsi}
`define OPC_CLDcso {`OPCLASS_4, `SUBOP_CLDcso}
`define OPC_CSTcso {`OPCLASS_4, `SUBOP_CSTcso}

// OPCLASS_5 — CHERI Capability ops (moves, offset/bounds)
`define SUBOP_CMOV    4'b0001 // isa
`define SUBOP_CINC    4'b0010 // isa
`define SUBOP_CINCi   4'b0011 // isa
`define SUBOP_CSETB   4'b0100 // isa
`define SUBOP_CSETBi  4'b0101 // isa
`define SUBOP_CGETP   4'b0110 // isa
`define SUBOP_CANDP   4'b0111 // isa
`define SUBOP_CGETT   4'b1000 // isa
`define SUBOP_CCLRT   4'b1001 // isa
// checked variants (trap on bounds/invalid): allocate distinct subops
`define SUBOP_CINCv   4'b1010 // isa (trap on bounds)
`define SUBOP_CINCiv  4'b1011 // isa (trap on bounds)
`define SUBOP_CSETBv  4'b1100 // isa (trap on invalid bounds)
`define SUBOP_CSETBiv 4'b1101 // isa (trap on invalid bounds)

`define OPC_CMOV    {`OPCLASS_5, `SUBOP_CMOV}
`define OPC_CINC    {`OPCLASS_5, `SUBOP_CINC}
`define OPC_CINCi   {`OPCLASS_5, `SUBOP_CINCi}
`define OPC_CSETB   {`OPCLASS_5, `SUBOP_CSETB}
`define OPC_CSETBi  {`OPCLASS_5, `SUBOP_CSETBi}
`define OPC_CGETP   {`OPCLASS_5, `SUBOP_CGETP}
`define OPC_CANDP   {`OPCLASS_5, `SUBOP_CANDP}
`define OPC_CGETT   {`OPCLASS_5, `SUBOP_CGETT}
`define OPC_CCLRT   {`OPCLASS_5, `SUBOP_CCLRT}
`define OPC_CINCv   {`OPCLASS_5, `SUBOP_CINCv}
`define OPC_CINCiv  {`OPCLASS_5, `SUBOP_CINCiv}
`define OPC_CSETBv  {`OPCLASS_5, `SUBOP_CSETBv}
`define OPC_CSETBiv {`OPCLASS_5, `SUBOP_CSETBiv}

// OPCLASS_6 — Control Flow (per updated docs)
`define SUBOP_BTP   4'b0000 // isa
`define SUBOP_JCCui 4'b0010 // µop & isa
`define SUBOP_BCCsr 4'b0011 // µop & isa
`define SUBOP_BCCso 4'b0100 // µop & isa
`define SUBOP_BALso 4'b0101 // µop & isa
`define SUBOP_JSRui 4'b0111 // isa
`define SUBOP_BSRsr 4'b1000 // isa
`define SUBOP_BSRso 4'b1001 // isa
`define SUBOP_RET   4'b1010 // isa

`define OPC_BTP   {`OPCLASS_6, `SUBOP_BTP}
`define OPC_JCCui {`OPCLASS_6, `SUBOP_JCCui}
`define OPC_BCCsr {`OPCLASS_6, `SUBOP_BCCsr}
`define OPC_BCCso {`OPCLASS_6, `SUBOP_BCCso}
`define OPC_BALso {`OPCLASS_6, `SUBOP_BALso}
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

// OPCLASS_9 — privileged / kernel-only
`define SUBOP_HLT     4'b0000 // isa
`define SUBOP_SETSSP  4'b0001 // isa
`define SUBOP_SYSCALL 4'b0010 // isa (aka SWI)
`define SUBOP_KRET    4'b0011 // isa (aka SRET)

`define OPC_HLT     {`OPCLASS_9, `SUBOP_HLT}
`define OPC_SETSSP  {`OPCLASS_9, `SUBOP_SETSSP}
`define OPC_SYSCALL {`OPCLASS_9, `SUBOP_SYSCALL}
`define OPC_KRET    {`OPCLASS_9, `SUBOP_KRET}

// Backward-compatible aliases removed to avoid ambiguity

// OPCLASS_A

// OPCLASS_B

// OPCLASS_C

// OPCLASS_D

// OPCLASS_E

// OPCLASS_F

// OPCLASS_F — Micro-ops (match opclassf.md)
`define SUBOP_SRMOVur  4'b0000 // µop
`define SUBOP_SRMOVAur 4'b0001 // µop
`define SUBOP_SRJCCso  4'b0010 // µop
`define SUBOP_SRADDsi  4'b0011 // µop
`define SUBOP_SRSUBsi  4'b0100 // µop
`define SUBOP_SRSTso   4'b0101 // µop
`define SUBOP_SRLDso   4'b0110 // µop
`define SUBOP_CR2SR    4'b0111 // µop
`define SUBOP_SR2CR    4'b1000 // µop

`define OPC_SRMOVur  {`OPCLASS_F, `SUBOP_SRMOVur}
`define OPC_SRMOVAur {`OPCLASS_F, `SUBOP_SRMOVAur}
`define OPC_SRJCCso  {`OPCLASS_F, `SUBOP_SRJCCso}
`define OPC_SRADDsi  {`OPCLASS_F, `SUBOP_SRADDsi}
`define OPC_SRSUBsi  {`OPCLASS_F, `SUBOP_SRSUBsi}
`define OPC_SRSTso   {`OPCLASS_F, `SUBOP_SRSTso}
`define OPC_SRLDso   {`OPCLASS_F, `SUBOP_SRLDso}
`define OPC_CR2SR    {`OPCLASS_F, `SUBOP_CR2SR}
`define OPC_SR2CR    {`OPCLASS_F, `SUBOP_SR2CR}

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
            `OPC_SHLuiv:  opc2str = "SHLuiv";
            `OPC_SHRuiv:  opc2str = "SHRuiv";
// OPCLASS_2
            `OPC_NEGsr:   opc2str = "NEGsr";
            `OPC_NEGsv:   opc2str = "NEGsv";
            `OPC_ADDsr:   opc2str = "ADDsr";
            `OPC_SUBsr:   opc2str = "SUBsr";
            `OPC_ADDsv:   opc2str = "ADDsv";
            `OPC_SUBsv:   opc2str = "SUBsv";
            `OPC_SHRsr:   opc2str = "SHRsr";
            `OPC_SHRsrv:  opc2str = "SHRsrv";
            `OPC_CMPsr:   opc2str = "CMPsr";
            `OPC_TSTsr:   opc2str = "TSTsr";
// OPCLASS_3
            `OPC_MOVsi:   opc2str = "MOVsi";
            `OPC_MCCsi:   opc2str = "MCCsi";
            `OPC_ADDsi:   opc2str = "ADDsi";
            `OPC_SUBsi:   opc2str = "SUBsi";
            `OPC_ADDsiv:  opc2str = "ADDsiv";
            `OPC_SUBsiv:  opc2str = "SUBsiv";
            `OPC_SHRsi:   opc2str = "SHRsi";
            `OPC_SHRsiv:  opc2str = "SHRsiv";
            `OPC_CMPsi:   opc2str = "CMPsi";
// OPCLASS_4 (CHERI LD/ST)
            `OPC_LDcso:   opc2str = "LDcso";
            `OPC_STcso:   opc2str = "STcso";
            `OPC_STui:    opc2str = "STui";
            `OPC_STsi:    opc2str = "STsi";
            `OPC_CLDcso:  opc2str = "CLDcso";
            `OPC_CSTcso:  opc2str = "CSTcso";
// OPCLASS_6 (control flow)
            `OPC_BTP:     opc2str = "BTP";
            `OPC_JCCui:   opc2str = "JCCui";
            `OPC_BCCsr:   opc2str = "BCCsr";
            `OPC_BCCso:   opc2str = "BCCso";
            `OPC_BALso:   opc2str = "BALso";
            `OPC_JSRui:   opc2str = "JSRui";
            `OPC_BSRsr:   opc2str = "BSRsr";
            `OPC_BSRso:   opc2str = "BSRso";
            `OPC_RET:     opc2str = "RET";
// OPCLASS_7
            `OPC_PUSHur:  opc2str = "PUSHur";
            `OPC_PUSHAur: opc2str = "PUSHAur";
            `OPC_POPur:   opc2str = "POPur";
            `OPC_POPAur:  opc2str = "POPAur";
// OPCLASS_8 (CSR)
            `OPC_CSRRD:   opc2str = "CSRRD";
            `OPC_CSRWR:   opc2str = "CSRWR";
// OPCLASS_9 (priv)
            `OPC_HLT:     opc2str = "HLT";
            `OPC_SETSSP:  opc2str = "SETSSP";
            `OPC_SYSCALL: opc2str = "SYSCALL";
            `OPC_KRET:    opc2str = "KRET";
// OPCLASS_B
// OPCLASS_C
// OPCLASS_D
// OPCLASS_E
// OPCLASS_5 (CHERI caps)
            `OPC_CMOV:    opc2str = "CMOV";
            `OPC_CINC:    opc2str = "CINC";
            `OPC_CINCi:   opc2str = "CINCi";
            `OPC_CSETB:   opc2str = "CSETB";
            `OPC_CSETBi:  opc2str = "CSETBi";
            `OPC_CGETP:   opc2str = "CGETP";
            `OPC_CANDP:   opc2str = "CANDP";
            `OPC_CGETT:   opc2str = "CGETT";
            `OPC_CCLRT:   opc2str = "CCLRT";
            `OPC_CINCv:   opc2str = "CINCv";
            `OPC_CINCiv:  opc2str = "CINCiv";
            `OPC_CSETBv:  opc2str = "CSETBv";
            `OPC_CSETBiv: opc2str = "CSETBiv";
// OPCLASS_F
            `OPC_SRMOVur:  opc2str = "SRMOVur";
            `OPC_SRMOVAur: opc2str = "SRMOVAur";
            `OPC_SRJCCso:  opc2str = "SRJCCso";
            `OPC_SRADDsi:  opc2str = "SRADDsi";
            `OPC_SRSUBsi:  opc2str = "SRSUBsi";
            `OPC_SRSTso:   opc2str = "SRSTso";
            `OPC_SRLDso:   opc2str = "SRLDso";
            `OPC_CR2SR:    opc2str = "CR2SR";
            `OPC_SR2CR:    opc2str = "SR2CR";
// DEFAULT
            default:      opc2str = "UNKNOWN";
        endcase
    end
endfunction

`endif // OPCODES_VH
