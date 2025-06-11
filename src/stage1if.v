// stage1if.v
module stage1if(
    input wire clk,
    input wire rst,
    input wire [11:0] pc_in,
    output wire [11:0] instr_out,
    output wire [11:0] mem_addr
);
    // For now, just pass PC to memory address
    assign mem_addr = pc_in;
    // instr_out will be connected externally from memory
endmodule
