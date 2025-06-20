// stage2id.v
// Simple placeholder for the Instruction Decode stage.  The stage
// currently just passes the program counter through so that each
// pipeline stage retains its own PC value.
`include "src/opcodes.vh"
`include "src/iset.vh"

module stage2id(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [11:0] instr_in,
    input  wire [3:0]  instr_set_in,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out,
    output wire [3:0]  instr_set_out,
    output wire        enable_out
);
    // No real decode logic yet.  The instruction set changes when the
    // special "SW" instruction is decoded.  The instruction encodes the
    // new set in its lowest three bits, which map to the constants in
    // `iset.vh`.  The update is purely combinational for now.

    wire [3:0] opcode = instr_in[11:8];

    assign pc_out = pc_in;
    // When OPC_SW is seen, switch to the set encoded in bits [2:0] of the
    // instruction.  Otherwise propagate the current set unchanged.
    assign instr_set_out = (opcode == `OPC_SW) ? {1'b0, instr_in[2:0]}
                                               : instr_set_in;
    // Propagate enable
    assign enable_out = enable;
endmodule
