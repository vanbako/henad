// control5ro.v
module control5ro(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out
);
    // Final Register Operation stage
    stage5ro u_stage5ro(
        .clk(clk),
        .rst(rst),
        .pc_in(pc_in),
        .pc_out(pc_out)
    );

    // No further stage, so pass instruction through
    assign instr_out = instr_in;
endmodule
