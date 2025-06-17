// stage5ro.v
// Register Operation stage placeholder.  The program counter is simply
// passed through.
module stage5ro(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out,
    output wire        enable_out
);
    // No register operation logic yet.  Propagate the PC.
    assign pc_out = pc_in;
    assign enable_out = enable;
endmodule
