// control5ra.v
`include "src/iset.vh"
module control5ra(
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
    // Propagate enable directly to the next stage
    assign enable_out = enable_in;

    // The Register Address stage currently performs no logic and simply
    // forwards the program counter.
    wire [11:0] stage_pc = pc_in;

    // Latch registers between RA and RO stages
    reg [11:0] pc_latch;
    reg [11:0] instr_latch;
    reg [3:0]  set_latch;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_latch    <= 12'b0;
            instr_latch <= 12'b0;
            set_latch   <= `ISET_R;
        end else if (enable_in) begin
            pc_latch    <= stage_pc;
            instr_latch <= instr_in;
            set_latch   <= instr_set_in;
        end
    end

    assign pc_out        = pc_latch;
    assign instr_out     = instr_latch;
    assign instr_set_out = set_latch;
endmodule
