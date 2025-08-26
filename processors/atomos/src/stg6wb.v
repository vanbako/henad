`include "src/sizes.vh"

module stg_wb(
    input wire                   iw_clk,
    input wire                   iw_rst,
    input wire  [`HBIT_ADDR:0]   iw_pc,
    output wire [`HBIT_ADDR:0]   ow_pc,
    input wire  [`HBIT_DATA:0]   iw_instr,
    output wire [`HBIT_DATA:0]   ow_instr,
    output wire [`HBIT_TGT_GP:0] ow_gp_write_addr,
    output wire [`HBIT_DATA:0]   ow_gp_write_data,
    output wire                  ow_gp_write_enable,
    output wire [`HBIT_TGT_SR:0] ow_sr_write_addr,
    output wire [`HBIT_DATA:0]   ow_sr_write_data,
    output wire                  ow_sr_write_enable,
    input wire  [`HBIT_OPC:0]    iw_opc,
    output wire [`HBIT_OPC:0]    ow_opc,
    input wire  [`HBIT_TGT_GP:0] iw_tgt_gp,
    input wire                   iw_tgt_gp_we,
    output wire [`HBIT_TGT_GP:0] ow_tgt_gp,
    input wire  [`HBIT_TGT_SR:0] iw_tgt_sr,
    input wire                   iw_tgt_sr_we,
    output wire [`HBIT_TGT_SR:0] ow_tgt_sr,
    input wire  [`HBIT_DATA:0]   iw_result,
    output wire [`HBIT_DATA:0]   ow_result
);
    assign ow_gp_write_enable = iw_tgt_gp_we ? 1'b1 : 1'b0;
    assign ow_gp_write_addr   = iw_tgt_gp;
    assign ow_gp_write_data   = iw_result;
    assign ow_sr_write_enable = iw_tgt_sr_we ? 1'b1 : 1'b0;
    assign ow_sr_write_addr   = iw_tgt_sr;
    assign ow_sr_write_data   = iw_result;

    reg [`HBIT_ADDR:0]   r_pc_latch;
    reg [`HBIT_DATA:0]   r_instr_latch;
    reg [`HBIT_OPC:0]    r_opc_latch;
    reg [`HBIT_TGT_GP:0] r_tgt_gp_latch;
    reg [`HBIT_TGT_SR:0] r_tgt_sr_latch;
    reg [`HBIT_DATA:0]   r_result_latch;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_pc_latch     <= `SIZE_ADDR'b0;
            r_instr_latch  <= `SIZE_DATA'b0;
            r_opc_latch    <= `SIZE_OPC'b0;
            r_tgt_gp_latch <= `SIZE_TGT_GP'b0;
            r_tgt_sr_latch <= `SIZE_TGT_SR'b0;
            r_result_latch <= `SIZE_DATA'b0;
        end
        else begin
            r_pc_latch     <= iw_pc;
            r_instr_latch  <= iw_instr;
            r_opc_latch    <= iw_opc;
            r_tgt_gp_latch <= iw_tgt_gp;
            r_tgt_sr_latch <= iw_tgt_sr;
            r_result_latch <= iw_result;
        end
    end
    assign ow_pc     = r_pc_latch;
    assign ow_instr  = r_instr_latch;
    assign ow_opc    = r_opc_latch;
    assign ow_tgt_gp = r_tgt_gp_latch;
    assign ow_tgt_sr = r_tgt_sr_latch;
    assign ow_result = r_result_latch;
endmodule
