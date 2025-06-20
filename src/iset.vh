// iset.vh
// Henad 12-bit RISC: Instruction Set Codes (for opcode set switching)
`ifndef ISET_VH
`define ISET_VH

// Instruction set codes (for opcode set switching)
`define ISET_R  4'h0 // Register set
`define ISET_RS 4'h1 // Register signed set
`define ISET_I  4'h2 // Immediate set
`define ISET_IS 4'h3 // Immediate signed set
`define ISET_S  4'h4 // Special set

`endif // ISET_VH
