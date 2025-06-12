// control3ex.v
module control3ex(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out
);
    wire [11:0] stage_pc;

    // Execute stage
    stage3ex u_stage3ex(
        .clk(clk),
        .rst(rst),
        .pc_in(pc_in),
        .pc_out(stage_pc)
    );

    // Latch between EX and MA
    latch3exma u_latch3exma(
        .clk(clk),
        .rst(rst),
        .instr_in(instr_in),
        .pc_in(stage_pc),
        .instr_out(instr_out),
        .pc_out(pc_out)
    );
endmodule
