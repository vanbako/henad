// stage4mo.v
`include "src/iset.vh"
`include "src/opcodes.vh"
module stage4mo(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable_in,
    output wire        enable_out,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    input  wire [3:0]  instr_set_in,
    input  wire [11:0] result_in,
    input  wire [11:0] store_data_in,
    input  wire [3:0]  flags_in,
    // Data returned from the data memory
    input  wire [11:0] mem_rdata,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out,
    output wire [3:0]  instr_set_out,
    output wire [11:0] result_out,
    output wire [3:0]  flags_out,
    // Write interface for the data memory
    output wire [11:0] mem_wdata,
    output wire        mem_we
);
    // Propagate enable directly to the next stage
    assign enable_out = enable_in;

    // Decode opcode for load/store behaviour
    wire [3:0] opcode = instr_in[11:8];
    wire       load_instr  = ({instr_set_in, opcode} == {`ISET_R, `OPC_R_LD})  ||
                             ({instr_set_in, opcode} == {`ISET_I, `OPC_I_LDi});
    wire       store_instr = ({instr_set_in, opcode} == {`ISET_R, `OPC_R_ST})  ||
                             ({instr_set_in, opcode} == {`ISET_I, `OPC_I_STi});

    // For load instructions use the memory data as the result.  All
    // other instructions simply forward the execute stage result.
    wire [11:0] stage_pc     = pc_in;
    wire [11:0] stage_result = load_instr ? mem_rdata : result_in;
    wire [3:0]  stage_flags  = flags_in;

    assign mem_wdata = store_data_in;
    assign mem_we    = enable_in && store_instr;

    // Latch registers between the MO stage and the Register Address stage
    reg [11:0] pc_latch;
    reg [11:0] instr_latch;
    reg [3:0]  set_latch;
    reg [11:0] result_latch;
    reg [3:0]  flags_latch;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_latch    <= 12'b0;
            instr_latch <= 12'b0;
            set_latch   <= `ISET_R;
            result_latch<= 12'b0;
            flags_latch <= 4'b0;
        end else if (enable_in) begin
            pc_latch    <= stage_pc;
            instr_latch <= instr_in;
            set_latch   <= instr_set_in;
            result_latch<= stage_result;
            flags_latch <= stage_flags;
        end
    end

    assign pc_out        = pc_latch;
    assign instr_out     = instr_latch;
    assign instr_set_out = set_latch;
    assign result_out    = result_latch;
    assign flags_out     = flags_latch;
endmodule
