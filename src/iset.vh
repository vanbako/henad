// iset.vh
// Henad 12-bit RISC: Instruction Set Codes (for opcode set switching)
`ifndef ISET_VH
`define ISET_VH

// Instruction set codes (for opcode set switching)
`define ISET_BASE   4'h0 // Base set
`define ISET_BRANCH 4'h1 // Branch set
`define ISET_MEM    4'h2 // Memory set
`define ISET_SPEC   4'h3 // Special set
// ... add more as needed

`endif // ISET_VH
