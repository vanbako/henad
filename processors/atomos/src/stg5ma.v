`include "src/sizes.vh"
`include "src/opcodes.vh"

module stg_ma(
    input wire                   iw_clk,
    input wire                   iw_rst,
    input wire  [`HBIT_ADDR:0]   iw_pc,
    output wire [`HBIT_ADDR:0]   ow_pc,
    input wire  [`HBIT_DATA:0]   iw_instr,
    output wire [`HBIT_DATA:0]   ow_instr,
    input wire  [`HBIT_OPC:0]    iw_opc,
    output wire [`HBIT_OPC:0]    ow_opc,
    input wire  [`HBIT_TGT_GP:0] iw_tgt_gp,
    input wire                   iw_tgt_gp_we,
    output wire [`HBIT_TGT_GP:0] ow_tgt_gp,
    output wire                  ow_tgt_gp_we,
    input wire  [`HBIT_TGT_SR:0] iw_tgt_sr,
    input wire                   iw_tgt_sr_we,
    output wire [`HBIT_TGT_SR:0] ow_tgt_sr,
    output wire                  ow_tgt_sr_we,
    output wire                  ow_mem_mp,
    output reg  [`HBIT_ADDR:0]   ow_mem_addr [0:1],
    input wire  [`HBIT_ADDR:0]   iw_addr,
    input wire  [`HBIT_DATA:0]   iw_result,
    output wire [`HBIT_DATA:0]   ow_result
);
    reg [`HBIT_ADDR:0]   r_pc_latch;
    reg [`HBIT_DATA:0]   r_instr_latch;
    reg [`HBIT_OPC:0]    r_opc_latch;
    reg [`HBIT_TGT_GP:0] r_tgt_gp_latch;
    reg                  r_tgt_gp_we_latch;
    reg [`HBIT_TGT_SR:0] r_tgt_sr_latch;
    reg                  r_tgt_sr_we_latch;
    reg                  r_mem_mp_latch;
    reg [`HBIT_DATA:0]   r_result_latch;
    always @(*) begin
        if ((iw_opc == `OPC_RU_LDu)   || (iw_opc == `OPC_RU_STu)  ||
            (iw_opc == `OPC_IU_STiu)  || (iw_opc == `OPC_IS_STis) ||
            (iw_opc == `OPC_SR_SRLDu) || (iw_opc == `OPC_SR_SRSTu)) begin
            if (r_mem_mp_latch)
                ow_mem_addr[0] = iw_addr;
            else
                ow_mem_addr[1] = iw_addr;
        end
    end
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_pc_latch        <= `SIZE_ADDR'b0;
            r_instr_latch     <= `SIZE_DATA'b0;
            r_opc_latch       <= `SIZE_OPC'b0;
            r_tgt_gp_latch    <= `SIZE_TGT_GP'b0;
            r_tgt_gp_we_latch <= 1'b0;
            r_tgt_sr_latch    <= `SIZE_TGT_SR'b0;
            r_tgt_sr_we_latch <= 1'b0;
            r_mem_mp_latch    <= 1'b0;
            r_result_latch    <= `SIZE_DATA'b0;
        end
        else begin
            r_pc_latch        <= iw_pc;
            r_instr_latch     <= iw_instr;
            r_opc_latch       <= iw_opc;
            r_tgt_gp_latch    <= iw_tgt_gp;
            r_tgt_gp_we_latch <= iw_tgt_gp_we;
            r_tgt_sr_latch    <= iw_tgt_sr;
            r_tgt_sr_we_latch <= iw_tgt_sr_we;
            r_mem_mp_latch    <= ~r_mem_mp_latch;
            r_result_latch    <= iw_result;
        end
    end
    assign ow_pc        = r_pc_latch;
    assign ow_instr     = r_instr_latch;
    assign ow_opc       = r_opc_latch;
    assign ow_tgt_gp    = r_tgt_gp_latch;
    assign ow_tgt_gp_we = r_tgt_gp_we_latch;
    assign ow_tgt_sr    = r_tgt_sr_latch;
    assign ow_tgt_sr_we = r_tgt_sr_we_latch;
    assign ow_mem_mp    = r_mem_mp_latch;
    assign ow_result    = r_result_latch;
endmodule
