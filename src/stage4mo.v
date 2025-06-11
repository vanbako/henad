// stage4mo.v
// Memory Operation stage placeholder.  The PC is simply passed to the
// next stage.
module stage4mo(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out
);
    // No memory operation logic yet.  Propagate the PC.
    assign pc_out = pc_in;
endmodule
