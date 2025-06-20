// control2id.v
`include "src/opcodes.vh"
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
    // NOP or SW instructions are fully handled in the decode stage.  When
    // SW is seen the instruction set is updated, so the original instruction
    // should not proceed further down the pipeline.  In these cases a NOP is
    // forwarded instead of the actual instruction.
    wire [11:0] forwarded_instr;

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

    // Replace the instruction with a NOP once handled.  Both OPC_NOP and
    // OPC_SW have no further effects down the pipeline.
    wire [3:0] opcode = instr_in[11:8];
    assign forwarded_instr = (opcode == `OPC_NOP || opcode == `OPC_SW)
                             ? 12'b0 : instr_in;

    // Latch between ID and EX stages
    latch2idex u_latch2idex(
        .clk(clk),
        .rst(rst),
        .enable(enable_in),
        .instr_in(forwarded_instr),
        .instr_set_in(stage_set),
        .pc_in(stage_pc),
        .instr_out(instr_out),
        .instr_set_out(instr_set_out),
        .pc_out(pc_out)
    );
endmodule
