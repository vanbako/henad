// stage5ra.v
`include "src/iset.vh"
module stage5ra(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable_in,
    output wire        enable_out,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    input  wire [3:0]  instr_set_in,
    input  wire [11:0] result_in,
    input  wire [3:0]  flags_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out,
    output wire [3:0]  instr_set_out,
    output wire [11:0] result_out,
    output wire [3:0]  flags_out,
    // Decoded register address for the writeback stage
    output wire [3:0]  reg_waddr_out
);
    // Propagate enable directly to the next stage
    assign enable_out = enable_in;

    // The Register Address stage currently performs no logic and simply
    // forwards the program counter.
    wire [11:0] stage_pc     = pc_in;
    wire [11:0] stage_result = result_in;
    wire [3:0]  stage_flags  = flags_in;
    // Target register address extracted from the instruction
    wire [3:0]  stage_waddr  = instr_in[7:4];

    // Latch registers between RA and RO stages
    reg [11:0] pc_latch;
    reg [11:0] instr_latch;
    reg [3:0]  set_latch;
    reg [11:0] result_latch;
    reg [3:0]  flags_latch;
    reg [3:0]  waddr_latch;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_latch    <= 12'b0;
            instr_latch <= 12'b0;
            set_latch   <= `ISET_R;
            result_latch<= 12'b0;
            flags_latch <= 4'b0;
            waddr_latch <= 4'b0;
        end else if (enable_in) begin
            pc_latch     <= stage_pc;
            instr_latch  <= instr_in;
            set_latch    <= instr_set_in;
            result_latch <= stage_result;
            flags_latch  <= stage_flags;
            waddr_latch  <= stage_waddr;
        end
    end

    assign pc_out        = pc_latch;
    assign instr_out     = instr_latch;
    assign instr_set_out = set_latch;
    assign result_out    = result_latch;
    assign flags_out     = flags_latch;
    assign reg_waddr_out = waddr_latch;
endmodule
