// control2id.v
module control2id(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out
);
    // Output of the stage before being latched
    wire [11:0] stage_pc;

    // Stage 2 Instruction Decode
    stage2id u_stage2id(
        .clk(clk),
        .rst(rst),
        .pc_in(pc_in),
        .pc_out(stage_pc)
    );

    // Latch between ID and EX stages
    latch2idex u_latch2idex(
        .clk(clk),
        .rst(rst),
        .instr_in(instr_in),
        .pc_in(stage_pc),
        .instr_out(instr_out),
        .pc_out(pc_out)
    );
endmodule
