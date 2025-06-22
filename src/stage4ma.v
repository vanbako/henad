// stage4ma.v
`include "src/iset.vh"
module stage4ma(
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
    // The Memory Address stage currently performs no modifications to the
    // program counter.  The value is simply forwarded to the next stage while
    // preserving the enable signal.
    assign enable_out = enable_in;

    // Stage output prior to latching.  Kept as a separate wire so that future
    // memory address logic can easily be inserted here.
    wire [11:0] stage_pc = pc_in;

    // Latch registers between MA and MO stages
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
