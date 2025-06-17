// control5ro.v
module control5ro(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable_in,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    input  wire [3:0]  instr_set_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out,
    output wire [3:0]  instr_set_out
);
    // Final Register Operation stage
    stage5ro u_stage5ro(
        .clk(clk),
        .rst(rst),
        .enable(enable_in),
        .pc_in(pc_in),
        .pc_out(pc_out),
        .enable_out()
    );

    // No further stage, so pass instruction through
    assign instr_out = instr_in;
    assign instr_set_out = instr_set_in;
endmodule
