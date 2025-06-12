// control5ra.v
module control5ra(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out
);
    wire [11:0] stage_pc;

    // Register Address stage
    stage5ra u_stage5ra(
        .clk(clk),
        .rst(rst),
        .pc_in(pc_in),
        .pc_out(stage_pc)
    );

    // Latch between RA and RO
    latch5raro u_latch5raro(
        .clk(clk),
        .rst(rst),
        .instr_in(instr_in),
        .pc_in(stage_pc),
        .instr_out(instr_out),
        .pc_out(pc_out)
    );
endmodule
