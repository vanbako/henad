// control1ia.v
module control1ia(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    output wire [11:0] pc_out
);
    // Output from the stage before being latched
    wire [11:0] stage_pc;

    // Instruction Address stage.  No complex logic yet; just
    // forwards the program counter value.
    stage1ia u_stage1ia(
        .clk(clk),
        .rst(rst),
        .pc_in(pc_in),
        .pc_out(stage_pc)
    );

    // Latch between IA and IF stages
    latch1iaif u_latch1iaif(
        .clk(clk),
        .rst(rst),
        .pc_in(stage_pc),
        .pc_out(pc_out)
    );
endmodule
