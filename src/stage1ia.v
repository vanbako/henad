// stage1ia.v
module stage1ia(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out,
    // Address sent to instruction memory.  Splitting the fetch
    // stage allows the address to be registered one cycle earlier
    // than the data fetch.
    output wire [11:0] mem_addr
);
    // No instruction address logic yet.  Simply propagate the PC so
    // that later stages each retain their own copy of the program
    // counter value.
    assign pc_out  = pc_in;
    // The instruction memory address is simply the current PC value.
    assign mem_addr = pc_in;
endmodule
