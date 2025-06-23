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

    wire reg_write = ({instr_set_in, opcode} == {`ISET_R,  `OPC_R_MOV})  ||
                     ({instr_set_in, opcode} == {`ISET_I,  `OPC_I_MOVi}) ||
                     ({instr_set_in, opcode} == {`ISET_IS, `OPC_IS_MOVis}) ||
                     ({instr_set_in, opcode} == {`ISET_R,  `OPC_R_ADD})  ||
                     ({instr_set_in, opcode} == {`ISET_I,  `OPC_I_ADDi}) ||
                     ({instr_set_in, opcode} == {`ISET_RS, `OPC_RS_ADDs}) ||
                     ({instr_set_in, opcode} == {`ISET_IS, `OPC_IS_ADDis})||
                     ({instr_set_in, opcode} == {`ISET_R,  `OPC_R_SUB})  ||
                     ({instr_set_in, opcode} == {`ISET_I,  `OPC_I_SUBi}) ||
                     ({instr_set_in, opcode} == {`ISET_RS, `OPC_RS_SUBs}) ||
                     ({instr_set_in, opcode} == {`ISET_IS, `OPC_IS_SUBis})||
                     ({instr_set_in, opcode} == {`ISET_R,  `OPC_R_NOT})  ||
                     ({instr_set_in, opcode} == {`ISET_R,  `OPC_R_AND})  ||
                     ({instr_set_in, opcode} == {`ISET_I,  `OPC_I_ANDi}) ||
                     ({instr_set_in, opcode} == {`ISET_R,  `OPC_R_OR})   ||
                     ({instr_set_in, opcode} == {`ISET_I,  `OPC_I_ORi})  ||
                     ({instr_set_in, opcode} == {`ISET_R,  `OPC_R_XOR})  ||
                     ({instr_set_in, opcode} == {`ISET_I,  `OPC_I_XORi}) ||
                     ({instr_set_in, opcode} == {`ISET_R,  `OPC_R_SL})   ||
                     ({instr_set_in, opcode} == {`ISET_I,  `OPC_I_SLi})  ||
                     ({instr_set_in, opcode} == {`ISET_R,  `OPC_R_SR})   ||
                     ({instr_set_in, opcode} == {`ISET_I,  `OPC_I_SRi})  ||
                     ({instr_set_in, opcode} == {`ISET_RS, `OPC_RS_SRs}) ||
                     ({instr_set_in, opcode} == {`ISET_IS, `OPC_IS_SRis})||
                     ({instr_set_in, opcode} == {`ISET_R,  `OPC_R_LD})   ||
                     ({instr_set_in, opcode} == {`ISET_I,  `OPC_I_LDi})  ||
                     ({instr_set_in, opcode} == {`ISET_I,  `OPC_I_Li})   ||
                     ({instr_set_in, opcode} == {`ISET_IS, `OPC_IS_Lis});

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
