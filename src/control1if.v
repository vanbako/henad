// control1if.v
module control1if(
    input wire clk,
    input wire rst,
    input wire [11:0] pc_in,
    output wire [11:0] pc_out,
    // Instruction memory interface
    output wire [11:0] mem_addr,
    input wire [11:0] instr_mem_data,
    output wire [11:0] ifid_instr,
    output wire [11:0] ifid_pc
);
    // Stage1if: generate memory address from PC
    stage1if u_stage1if(
        .clk(clk),
        .rst(rst),
        .pc_in(pc_in),
        .instr_out(), // Not used here, instr comes from memory
        .mem_addr(mem_addr)
    );
    // Latch1ifid: latch instruction and PC
    latch1ifid u_latch1ifid(
        .clk(clk),
        .rst(rst),
        .instr_in(instr_mem_data),
        .pc_in(pc_in),
        .instr_out(ifid_instr),
        .pc_out(ifid_pc)
    );
    // Next PC logic (for now, just increment)
    assign pc_out = pc_in + 12'd1;
endmodule
