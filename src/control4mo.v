// control4mo.v
module control4mo(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out
);
    wire [11:0] stage_pc;

    // Memory Operation stage
    stage4mo u_stage4mo(
        .clk(clk),
        .rst(rst),
        .pc_in(pc_in),
        .pc_out(stage_pc)
    );

    // Latch between MO and RA
    latch4mora u_latch4mora(
        .clk(clk),
        .rst(rst),
        .instr_in(instr_in),
        .pc_in(stage_pc),
        .instr_out(instr_out),
        .pc_out(pc_out)
    );
endmodule
