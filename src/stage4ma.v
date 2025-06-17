// stage4ma.v
// Memory Address stage placeholder.  It simply passes the program
// counter to the Memory Operation stage so that each stage keeps its
// own PC value.
module stage4ma(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out,
    output wire        enable_out
);
    // No memory address logic yet.  Propagate the PC.
    assign pc_out = pc_in;
    assign enable_out = enable;
endmodule
