// stage1if.v
module stage1if(
    input wire clk,
    input wire rst,
    input wire [11:0] instr_mem_data,
    input wire [11:0] pc_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out
);
    assign pc_out = pc_in;
    assign instr_out = instr_mem_data;
endmodule
