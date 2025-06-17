// stage5ra.v
// Register Address stage placeholder.  Simply forwards the program
// counter so that the final stage sees the same PC value.
module stage5ra(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out,
    output wire        enable_out
);
    // No register address logic yet.  Propagate the PC.
    assign pc_out = pc_in;
    assign enable_out = enable;
endmodule
