// stage5ro.v
`include "src/opcodes.vh"
`include "src/flags.vh"
`include "src/iset.vh"
module stage5ro(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable_in,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    input  wire [3:0]  instr_set_in,
    input  wire [11:0] result_in,
    input  wire [3:0]  flags_in,
    // Register address prepared by the RA stage
    input  wire [3:0]  reg_waddr_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out,
    output wire [3:0]  instr_set_out,
    output wire [3:0]  reg_waddr,
    output wire [11:0] reg_wdata,
    output wire        reg_we,
    // Write interface for the link register
    output wire [11:0] lr_wdata,
    output wire        lr_we,
    output wire [3:0]  flag_wdata,
    output wire        flag_we
);
    // Bring in the shared reg_write_fn helper
    `define DEFINE_REG_WRITE_FN
    `include "src/iset.vh"
    `undef DEFINE_REG_WRITE_FN
    // Decode opcode for write-back decisions
    wire [3:0] opcode = instr_in[11:8];

    wire reg_write = reg_write_fn(instr_set_in, opcode);

    // Pass through the address computed in the RA stage
    assign reg_waddr  = reg_waddr_in;
    assign reg_wdata  = result_in;
    assign reg_we     = enable_in && reg_write;

    // Write to the link register for the SRMOV instruction
    wire lr_write = ({instr_set_in, opcode} == {`ISET_S, `OPC_S_SRMOV});
    assign lr_wdata = result_in;
    assign lr_we    = enable_in && lr_write;

    assign flag_wdata = flags_in;
    assign flag_we    = enable_in;

    // Propagate program counter and instruction info
    assign pc_out        = pc_in;
    assign instr_out     = instr_in;
    assign instr_set_out = instr_set_in;
endmodule
