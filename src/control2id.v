// control2id.v
module control2id(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable_in,
    output wire        enable_out,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    input  wire [3:0]  instr_set_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out,
    output wire [3:0]  instr_set_out
);
    // Output of the stage before being latched
    wire [11:0] stage_pc;

    // Stage 2 Instruction Decode
    wire [3:0] stage_set;

    stage2id u_stage2id(
        .clk(clk),
        .rst(rst),
        .enable(enable_in),
        .instr_in(instr_in),
        .instr_set_in(instr_set_in),
        .pc_in(pc_in),
        .pc_out(stage_pc),
        .instr_set_out(stage_set),
        .enable_out(enable_out)
    );

    // Latch between ID and EX stages
    latch2idex u_latch2idex(
        .clk(clk),
        .rst(rst),
        .enable(enable_in),
        .instr_in(instr_in),
        .instr_set_in(stage_set),
        .pc_in(stage_pc),
        .instr_out(instr_out),
        .instr_set_out(instr_set_out),
        .pc_out(pc_out)
    );
endmodule
