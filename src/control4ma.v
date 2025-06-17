// control4ma.v
module control4ma(
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
    wire [11:0] stage_pc;

    // Memory Address stage
    stage4ma u_stage4ma(
        .clk(clk),
        .rst(rst),
        .enable(enable_in),
        .pc_in(pc_in),
        .pc_out(stage_pc),
        .enable_out(enable_out)
    );

    // Latch between MA and MO
    latch4mamo u_latch4mamo(
        .clk(clk),
        .rst(rst),
        .enable(enable_in),
        .instr_in(instr_in),
        .instr_set_in(instr_set_in),
        .pc_in(stage_pc),
        .instr_out(instr_out),
        .instr_set_out(instr_set_out),
        .pc_out(pc_out)
    );
endmodule
