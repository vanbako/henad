// opcodes.vh
// Henad 12-bit RISC: Opcode definitions
`ifndef OPCODES_VH
`define OPCODES_VH

// BASE SET
`define OPC_NOP   4'h0
`define OPC_SW    4'h1 // Switch to next set
`define OPC_LUI   4'h2
`define OPC_MOV   4'h3
`define OPC_MOVI  4'h4
`define OPC_ADD   4'h5
`define OPC_ADDI  4'h6
`define OPC_SUB   4'h7
`define OPC_SUBI  4'h8
`define OPC_AND   4'h9
`define OPC_OR    4'hA
`define OPC_XOR   4'hB
`define OPC_NOT   4'hC
// ... add more as needed

// BRANCH SET
`define OPC_B_NOP 4'h0
`define OPC_B_SW  4'h1
`define OPC_B_BCC 4'h2
`define OPC_B_BCCi 4'h3
// ... add more as needed

// MEMORY SET
`define OPC_M_NOP 4'h0
`define OPC_M_SW  4'h1
`define OPC_M_LD  4'h2
`define OPC_M_LDi 4'h3
`define OPC_M_ST  4'h4
`define OPC_M_STi 4'h5
// ... add more as needed

// SPECIAL SET
`define OPC_S_NOP 4'h0
`define OPC_S_SW  4'h1
`define OPC_S_SRMOV 4'h2
`define OPC_S_SRBCC 4'h3
// ... add more as needed

// ...existing code...

`endif // OPCODES_VH
