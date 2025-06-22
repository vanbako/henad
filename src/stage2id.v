// stage2id.v
`include "src/opcodes.vh"
`include "src/iset.vh"
module stage2id(
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
    // Propagate enable to the next stage
    assign enable_out = enable_in;

    // Decode stage: update instruction set when a SW instruction is seen
    wire [3:0] opcode = instr_in[11:8];
    wire [3:0] stage_set = (opcode == `OPC_SW) ? {1'b0, instr_in[2:0]}
                                              : instr_set_in;

    // Replace handled instructions with NOPs
    wire [11:0] forwarded_instr =
        (opcode == `OPC_NOP || opcode == `OPC_SW) ? 12'b0 : instr_in;

    // Latch outputs for the next pipeline stage
    reg [11:0]  pc_latch;
    reg [11:0]  instr_latch;
    reg [3:0]   set_latch;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_latch   <= 12'b0;
            instr_latch <= 12'b0;
            set_latch  <= `ISET_R;
        end else if (enable_in) begin
            pc_latch   <= pc_in;
            instr_latch <= forwarded_instr;
            set_latch  <= stage_set;
        end
    end

    assign pc_out        = pc_latch;
    assign instr_out     = instr_latch;
    assign instr_set_out = set_latch;
endmodule
