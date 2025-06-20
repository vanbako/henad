// opcodes.vh
// Henad 12-bit RISC: Opcode definitions
`ifndef OPCODES_VH
`define OPCODES_VH

// OPCODES independent of instruction set
`define OPC_NOP      4'h0
`define OPC_SW       4'h1

// REGISTER SET
`define OPC_R_MOV    4'h2
`define OPC_R_ADD    4'h3
`define OPC_R_SUB    4'h4
`define OPC_R_NOT    4'h5
`define OPC_R_AND    4'h6
`define OPC_R_OR     4'h7
`define OPC_R_XOR    4'h8
`define OPC_R_SL     4'h9
`define OPC_R_SR     4'hA
`define OPC_R_CMP    4'hB
`define OPC_R_BCC    4'hC
`define OPC_R_LD     4'hD
`define OPC_R_ST     4'hE

// REGISTER SIGNED SET
`define OPC_RS_ADDs  4'h3
`define OPC_RS_SUBs  4'h4
`define OPC_RS_SRs   4'hA
`define OPC_RS_CMPs  4'hB

// IMMEDIATE SET
`define OPC_I_MOVi   4'h2
`define OPC_I_ADDi   4'h3
`define OPC_I_SUBi   4'h4
`define OPC_I_ANDi   4'h6
`define OPC_I_ORi    4'h7
`define OPC_I_XORi   4'h8
`define OPC_I_SLi    4'h9
`define OPC_I_SRi    4'hA
`define OPC_I_CMPi   4'hB
`define OPC_I_BCCi   4'hC
`define OPC_I_LDi    4'hD
`define OPC_I_STi    4'hE
`define OPC_I_Li     4'hF

// IMMEDIATE SIGNED SET
`define OPC_IS_MOVis 4'h2
`define OPC_IS_ADDis 4'h3
`define OPC_IS_SUBis 4'h4
`define OPC_IS_SRis  4'hA
`define OPC_IS_CMPis 4'hB
`define OPC_IS_BCCis 4'hC
`define OPC_IS_Lis   4'hF

// SPECIAL SET
`define OPC_S_SRMOV  4'h2
`define OPC_S_SRBCC  4'hC
`define OPC_S_HLT    4'hF

`endif // OPCODES_VH
