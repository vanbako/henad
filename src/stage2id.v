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
    // No real decode logic yet.  The instruction set would normally
    // change when a special "SW" instruction is decoded.  For now the
    // stage simply passes the current set through, incrementing it when
    // the opcode matches OPC_SW.  This remains purely combinational.

    wire [3:0] opcode = instr_in[11:8];

    assign pc_out = pc_in;
    assign instr_set_out = (opcode == `OPC_SW) ? instr_set_in + 4'd1
                                               : instr_set_in;
    // Propagate enable
    assign enable_out = enable;
endmodule
