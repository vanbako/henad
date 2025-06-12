// stage1ia.v
module stage1ia(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out
);
    // No instruction address logic yet.  Simply propagate the PC so
    // that later stages each retain their own copy of the program
    // counter value.
    assign pc_out = pc_in;
endmodule
