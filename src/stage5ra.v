// stage5ra.v
// Register Address stage placeholder.  Simply forwards the program
// counter so that the final stage sees the same PC value.
module stage5ra(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out
);
    // No register address logic yet.  Propagate the PC.
    assign pc_out = pc_in;
endmodule
