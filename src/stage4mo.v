// stage4mo.v
// Memory Operation stage placeholder.  The PC is simply passed to the
// next stage.
module stage4mo(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out,
    output wire        enable_out
);
    // No memory operation logic yet.  Propagate the PC.
    assign pc_out = pc_in;
    assign enable_out = enable;
endmodule
