// stage3ex.v
// Placeholder for the Execute stage.  Like the other stages, it
// currently just forwards the program counter to the next stage.
module stage3ex(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out,
    output wire        enable_out
);
    // No execute logic yet.  Propagate the PC.
    assign pc_out = pc_in;
    assign enable_out = enable;
endmodule
