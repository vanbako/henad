// stage5ro.v
`include "src/opcodes.vh"
`include "src/flags.vh"
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
    output wire [3:0]  flag_wdata,
    output wire        flag_we
);
    // Decode opcode for write-back decisions
    wire [3:0] opcode = instr_in[11:8];

    wire reg_write = (opcode == `OPC_R_MOV  || opcode == `OPC_R_ADD ||
                      opcode == `OPC_R_SUB || opcode == `OPC_R_NOT ||
                      opcode == `OPC_R_AND || opcode == `OPC_R_OR  ||
                      opcode == `OPC_R_XOR || opcode == `OPC_R_SL  ||
                      opcode == `OPC_R_SR  || opcode == `OPC_I_MOVi ||
                      opcode == `OPC_I_ADDi|| opcode == `OPC_I_SUBi||
                      opcode == `OPC_I_ANDi|| opcode == `OPC_I_ORi ||
                      opcode == `OPC_I_XORi|| opcode == `OPC_I_SLi ||
                      opcode == `OPC_I_SRi || opcode == `OPC_I_Li  ||
                      opcode == `OPC_RS_ADDs || opcode == `OPC_RS_SUBs ||
                      opcode == `OPC_RS_SRs  || opcode == `OPC_IS_MOVis ||
                      opcode == `OPC_IS_ADDis|| opcode == `OPC_IS_SUBis||
                      opcode == `OPC_IS_SRis || opcode == `OPC_IS_Lis);

    // Pass through the address computed in the RA stage
    assign reg_waddr  = reg_waddr_in;
    assign reg_wdata  = result_in;
    assign reg_we     = enable_in && reg_write;

    assign flag_wdata = flags_in;
    assign flag_we    = enable_in;

    // Propagate program counter and instruction info
    assign pc_out        = pc_in;
    assign instr_out     = instr_in;
    assign instr_set_out = instr_set_in;
endmodule
