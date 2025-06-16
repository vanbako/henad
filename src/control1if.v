// control1if.v
module control1if(
    input wire clk,
    input wire rst,
    input wire [11:0] pc_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out,
    // Instruction memory interface
    input wire [11:0] instr_mem_data
);
    wire [11:0] stage_pc;
    wire [11:0] stage_instr;
    // Stage1if: generate memory address from PC
    stage1if u_stage1if(
        .clk(clk),
        .rst(rst),
        .instr_mem_data(instr_mem_data),
        .pc_in(pc_in),
        .pc_out(stage_pc),
        .instr_out(stage_instr) // Instruction comes from memory
    );
    // Latch1ifid: latch instruction and PC
    latch1ifid u_latch1ifid(
        .clk(clk),
        .rst(rst),
        .pc_in(stage_pc),
        .instr_in(stage_instr),
        .pc_out(pc_out),
        .instr_out(instr_out)
    );
endmodule
