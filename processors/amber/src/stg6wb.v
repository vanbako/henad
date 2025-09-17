`include "src/sizes.vh"
`include "src/cr.vh"

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
    output wire [`HBIT_ADDR:0]   ow_sr_write_data,
    output wire                  ow_sr_write_enable,
    output wire [`HBIT_TGT_AR:0] ow_ar_write_addr,
    output wire [`HBIT_ADDR:0]   ow_ar_write_data,
    output wire                  ow_ar_write_enable,
    input wire  [`HBIT_OPC:0]    iw_opc,
    input wire  [`HBIT_OPC:0]    iw_root_opc,
    output wire [`HBIT_OPC:0]    ow_opc,
    output wire [`HBIT_OPC:0]    ow_root_opc,
    input wire  [`HBIT_TGT_GP:0] iw_tgt_gp,
    input wire                   iw_tgt_gp_we,
    output wire [`HBIT_TGT_GP:0] ow_tgt_gp,
    input wire  [`HBIT_TGT_SR:0] iw_tgt_sr,
    input wire                   iw_tgt_sr_we,
    output wire [`HBIT_TGT_SR:0] ow_tgt_sr,
    input wire  [`HBIT_TGT_AR:0] iw_tgt_ar,
    input wire                   iw_tgt_ar_we,
    input wire  [`HBIT_DATA:0]   iw_result,
    input wire  [`HBIT_ADDR:0]   iw_sr_result,
    input wire  [`HBIT_ADDR:0]   iw_ar_result,
    input wire                   iw_sr_aux_we,
    input wire  [`HBIT_TGT_SR:0] iw_sr_aux_addr,
    input wire  [`HBIT_ADDR:0]   iw_sr_aux_result,
    input wire                   iw_trap_pending,
    output wire [`HBIT_DATA:0]   ow_result,
    output wire                  ow_sr_aux_we,
    output wire [`HBIT_TGT_SR:0] ow_sr_aux_addr,
    output wire [`HBIT_ADDR:0]   ow_sr_aux_result,
    output wire                  ow_trap_pending,
    // CR writeback controls toward regcr
    input wire  [`HBIT_TGT_CR:0] iw_cr_write_addr,
    input wire                   iw_cr_we_base,
    input wire  [`HBIT_ADDR:0]   iw_cr_base,
    input wire                   iw_cr_we_len,
    input wire  [`HBIT_ADDR:0]   iw_cr_len,
    input wire                   iw_cr_we_cur,
    input wire  [`HBIT_ADDR:0]   iw_cr_cur,
    input wire                   iw_cr_we_perms,
    input wire  [`HBIT_DATA:0]   iw_cr_perms,
    input wire                   iw_cr_we_attr,
    input wire  [`HBIT_DATA:0]   iw_cr_attr,
    input wire                   iw_cr_we_tag,
    input wire                   iw_cr_tag,
    output wire [`HBIT_TGT_CR:0] ow_cr_write_addr,
    output wire                  ow_cr_we_base,
    output wire [`HBIT_ADDR:0]   ow_cr_base,
    output wire                  ow_cr_we_len,
    output wire [`HBIT_ADDR:0]   ow_cr_len,
    output wire                  ow_cr_we_cur,
    output wire [`HBIT_ADDR:0]   ow_cr_cur,
    output wire                  ow_cr_we_perms,
    output wire [`HBIT_DATA:0]   ow_cr_perms,
    output wire                  ow_cr_we_attr,
    output wire [`HBIT_DATA:0]   ow_cr_attr,
    output wire                  ow_cr_we_tag,
    output wire                  ow_cr_tag
);
    assign ow_gp_write_enable = iw_tgt_gp_we ? 1'b1 : 1'b0;
    assign ow_gp_write_addr   = iw_tgt_gp;
    assign ow_gp_write_data   = iw_result;
    assign ow_sr_write_enable = iw_tgt_sr_we ? 1'b1 : 1'b0;
    assign ow_sr_write_addr   = iw_tgt_sr;
    assign ow_sr_write_data   = iw_sr_result;
    assign ow_ar_write_enable = iw_tgt_ar_we ? 1'b1 : 1'b0;
`ifndef SYNTHESIS
    always @(*) begin
        if (iw_tgt_ar_we) begin
            $display("[WB] AR write CR%0d := %0d", iw_tgt_ar, iw_ar_result);
        end
        if (iw_cr_we_cur) begin
            $display("[WB] CR write CUR CR%0d := %0d", iw_cr_write_addr, iw_cr_cur);
        end
    end
`endif
    assign ow_ar_write_addr   = iw_tgt_ar;
    assign ow_ar_write_data   = iw_ar_result;
    // Pass-through CR writeback controls
    assign ow_cr_write_addr = iw_cr_write_addr;
    assign ow_cr_we_base    = iw_cr_we_base;
    assign ow_cr_base       = iw_cr_base;
    assign ow_cr_we_len     = iw_cr_we_len;
    assign ow_cr_len        = iw_cr_len;
    assign ow_cr_we_cur     = iw_cr_we_cur;
    assign ow_cr_cur        = iw_cr_cur;
    assign ow_cr_we_perms   = iw_cr_we_perms;
    assign ow_cr_perms      = iw_cr_perms;
    assign ow_cr_we_attr    = iw_cr_we_attr;
    assign ow_cr_attr       = iw_cr_attr;
    assign ow_cr_we_tag     = iw_cr_we_tag;
    assign ow_cr_tag        = iw_cr_tag;

    reg [`HBIT_ADDR:0]   r_pc_latch;
    reg [`HBIT_DATA:0]   r_instr_latch;
    reg [`HBIT_OPC:0]    r_opc_latch;
    reg [`HBIT_OPC:0]    r_root_opc_latch;
    reg [`HBIT_TGT_GP:0] r_tgt_gp_latch;
    reg [`HBIT_TGT_SR:0] r_tgt_sr_latch;
    reg [`HBIT_DATA:0]   r_result_latch;
    reg                  r_sr_aux_we_latch;
    reg [`HBIT_TGT_SR:0] r_sr_aux_addr_latch;
    reg [`HBIT_ADDR:0]   r_sr_aux_result_latch;
    reg                  r_trap_pending_latch;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_pc_latch     <= `SIZE_ADDR'b0;
            r_instr_latch  <= `SIZE_DATA'b0;
            r_opc_latch    <= `SIZE_OPC'b0;
            r_root_opc_latch <= `SIZE_OPC'b0;
            r_tgt_gp_latch <= `SIZE_TGT_GP'b0;
            r_tgt_sr_latch <= `SIZE_TGT_SR'b0;
            r_result_latch <= `SIZE_DATA'b0;
            r_sr_aux_we_latch <= 1'b0;
            r_sr_aux_addr_latch <= {(`HBIT_TGT_SR+1){1'b0}};
            r_sr_aux_result_latch <= {`SIZE_ADDR{1'b0}};
            r_trap_pending_latch <= 1'b0;
        end
        else begin
            r_pc_latch     <= iw_pc;
            r_instr_latch  <= iw_instr;
            r_opc_latch    <= iw_opc;
            r_root_opc_latch <= iw_root_opc;
            r_tgt_gp_latch <= iw_tgt_gp;
            r_tgt_sr_latch <= iw_tgt_sr;
            r_result_latch <= iw_result;
            r_sr_aux_we_latch <= iw_sr_aux_we;
            r_sr_aux_addr_latch <= iw_sr_aux_addr;
            r_sr_aux_result_latch <= iw_sr_aux_result;
            r_trap_pending_latch <= iw_trap_pending;
        end
    end
    assign ow_pc     = r_pc_latch;
    assign ow_instr  = r_instr_latch;
    assign ow_opc    = r_opc_latch;
    assign ow_root_opc = r_root_opc_latch;
    assign ow_tgt_gp = r_tgt_gp_latch;
    assign ow_tgt_sr = r_tgt_sr_latch;
    assign ow_result = r_result_latch;
    assign ow_sr_aux_we = r_sr_aux_we_latch;
    assign ow_sr_aux_addr = r_sr_aux_addr_latch;
    assign ow_sr_aux_result = r_sr_aux_result_latch;
    assign ow_trap_pending = r_trap_pending_latch;
endmodule
