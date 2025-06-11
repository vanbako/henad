// stage2id.v
// Simple placeholder for the Instruction Decode stage.  The stage
// currently just passes the program counter through so that each
// pipeline stage retains its own PC value.
module stage2id(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out
);
    // No decode logic yet.  Simply propagate the PC.
    assign pc_out = pc_in;
endmodule
