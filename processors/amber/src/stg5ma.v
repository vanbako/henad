`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"

module stg_ma(
    input wire                   iw_clk,
    input wire                   iw_rst,
    input wire  [`HBIT_ADDR:0]   iw_pc,
    output wire [`HBIT_ADDR:0]   ow_pc,
    input wire  [`HBIT_DATA:0]   iw_instr,
    output wire [`HBIT_DATA:0]   ow_instr,
    input wire  [`HBIT_OPC:0]    iw_opc,
    input wire  [`HBIT_OPC:0]    iw_root_opc,
    output wire [`HBIT_OPC:0]    ow_opc,
    output wire [`HBIT_OPC:0]    ow_root_opc,
    input wire  [`HBIT_TGT_GP:0] iw_tgt_gp,
    input wire                   iw_tgt_gp_we,
    output wire [`HBIT_TGT_GP:0] ow_tgt_gp,
    output wire                  ow_tgt_gp_we,
    input wire  [`HBIT_TGT_SR:0] iw_tgt_sr,
    input wire                   iw_tgt_sr_we,
    output wire [`HBIT_TGT_SR:0] ow_tgt_sr,
    output wire                  ow_tgt_sr_we,
    input wire  [`HBIT_TGT_AR:0] iw_tgt_ar,
    input wire                   iw_tgt_ar_we,
    output wire [`HBIT_TGT_AR:0] ow_tgt_ar,
    output wire                  ow_tgt_ar_we,
    output wire                  ow_mem_mp,
    output reg  [`HBIT_ADDR:0]   ow_mem_addr [0:1],
    input wire  [`HBIT_ADDR:0]   iw_addr,
    input wire  [`HBIT_DATA:0]   iw_result,
    output wire [`HBIT_DATA:0]   ow_result,
    input wire  [`HBIT_ADDR:0]   iw_sr_result,
    output wire [`HBIT_ADDR:0]   ow_sr_result,
    input wire  [`HBIT_ADDR:0]   iw_ar_result,
    output wire [`HBIT_ADDR:0]   ow_ar_result,
    input wire                   iw_sr_aux_we,
    input wire  [`HBIT_TGT_SR:0] iw_sr_aux_addr,
    input wire  [`HBIT_ADDR:0]   iw_sr_aux_result,
    input wire                   iw_trap_pending,
    output wire                  ow_sr_aux_we,
    output wire [`HBIT_TGT_SR:0] ow_sr_aux_addr,
    output wire [`HBIT_ADDR:0]   ow_sr_aux_result,
    output wire                  ow_trap_pending,
    // Forward CR writeback controls to MO
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
    reg [`HBIT_ADDR:0]   r_pc_latch;
    reg [`HBIT_DATA:0]   r_instr_latch;
    reg [`HBIT_OPC:0]    r_opc_latch;
    reg [`HBIT_OPC:0]    r_root_opc_latch;
    reg [`HBIT_TGT_GP:0] r_tgt_gp_latch;
    reg                  r_tgt_gp_we_latch;
    reg [`HBIT_TGT_SR:0] r_tgt_sr_latch;
    reg                  r_tgt_sr_we_latch;
    reg [`HBIT_TGT_AR:0] r_tgt_ar_latch;
    reg                  r_tgt_ar_we_latch;
    // r_mem_mp_latch: Memory port multiplexer bit
    //
    // This bit toggles every cycle (when not in reset). MA uses the opposite
    // port index (~r_mem_mp_latch) to present the address for the next cycle,
    // while MO uses r_mem_mp_latch in the current cycle. This way MO always
    // reads/writes the address set by MA in the previous cycle.
    reg                  r_mem_mp_latch;
    reg [`HBIT_DATA:0]   r_result_latch;
    reg [`HBIT_ADDR:0]   r_sr_result_latch;
    reg [`HBIT_ADDR:0]   r_ar_result_latch;
    reg                  r_sr_aux_we_latch;
    reg [`HBIT_TGT_SR:0] r_sr_aux_addr_latch;
    reg [`HBIT_ADDR:0]   r_sr_aux_result_latch;
    reg                  r_trap_pending_latch;
    // CR writeback latches
    reg [`HBIT_TGT_CR:0] r_cr_write_addr_latch;
    reg                  r_cr_we_base_latch;
    reg [`HBIT_ADDR:0]   r_cr_base_latch;
    reg                  r_cr_we_len_latch;
    reg [`HBIT_ADDR:0]   r_cr_len_latch;
    reg                  r_cr_we_cur_latch;
    reg [`HBIT_ADDR:0]   r_cr_cur_latch;
    reg                  r_cr_we_perms_latch;
    reg [`HBIT_DATA:0]   r_cr_perms_latch;
    reg                  r_cr_we_attr_latch;
    reg [`HBIT_DATA:0]   r_cr_attr_latch;
    reg                  r_cr_we_tag_latch;
    reg                  r_cr_tag_latch;
    always @(*) begin
        // Address driving policy for the dual-port memory
        // MA always drives only the port opposite to MO so the address is
        // held for MO in the next cycle, regardless of 24/48-bit width.
        if (r_mem_mp_latch)
            ow_mem_addr[0] = iw_addr;
        else
            ow_mem_addr[1] = iw_addr;
    end
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_pc_latch        <= `SIZE_ADDR'b0;
            r_instr_latch     <= `SIZE_DATA'b0;
            r_opc_latch       <= `SIZE_OPC'b0;
            r_root_opc_latch  <= `SIZE_OPC'b0;
            r_tgt_gp_latch    <= `SIZE_TGT_GP'b0;
            r_tgt_gp_we_latch <= 1'b0;
            r_tgt_sr_latch    <= `SIZE_TGT_SR'b0;
            r_tgt_sr_we_latch <= 1'b0;
            r_tgt_ar_latch    <= `SIZE_TGT_AR'b0;
            r_tgt_ar_we_latch <= 1'b0;
            r_mem_mp_latch    <= 1'b0; // start with MA driving [1], MO uses [0]
            r_result_latch    <= `SIZE_DATA'b0;
            r_sr_result_latch <= `SIZE_ADDR'b0;
            r_ar_result_latch <= `SIZE_ADDR'b0;
            r_sr_aux_we_latch    <= 1'b0;
            r_sr_aux_addr_latch  <= {(`HBIT_TGT_SR+1){1'b0}};
            r_sr_aux_result_latch<= {`SIZE_ADDR{1'b0}};
            r_trap_pending_latch <= 1'b0;
        end
        else begin
            r_pc_latch        <= iw_pc;
            r_instr_latch     <= iw_instr;
            r_opc_latch       <= iw_opc;
            r_root_opc_latch  <= iw_root_opc;
            r_tgt_gp_latch    <= iw_tgt_gp;
            r_tgt_gp_we_latch <= iw_tgt_gp_we;
            r_tgt_sr_latch    <= iw_tgt_sr;
            r_tgt_sr_we_latch <= iw_tgt_sr_we;
            r_tgt_ar_latch    <= iw_tgt_ar;
            r_tgt_ar_we_latch <= iw_tgt_ar_we;
            // Toggle each cycle so MA/MO alternate [0]/[1]
            r_mem_mp_latch    <= ~r_mem_mp_latch;
            r_result_latch    <= iw_result;
            r_sr_result_latch <= iw_sr_result;
            r_ar_result_latch <= iw_ar_result;
            r_sr_aux_we_latch    <= iw_sr_aux_we;
            r_sr_aux_addr_latch  <= iw_sr_aux_addr;
            r_sr_aux_result_latch<= iw_sr_aux_result;
            r_trap_pending_latch <= iw_trap_pending;
            // Latch CR writeback controls
            r_cr_write_addr_latch <= iw_cr_write_addr;
            r_cr_we_base_latch    <= iw_cr_we_base;
            r_cr_base_latch       <= iw_cr_base;
            r_cr_we_len_latch     <= iw_cr_we_len;
            r_cr_len_latch        <= iw_cr_len;
            r_cr_we_cur_latch     <= iw_cr_we_cur;
            r_cr_cur_latch        <= iw_cr_cur;
            r_cr_we_perms_latch   <= iw_cr_we_perms;
            r_cr_perms_latch      <= iw_cr_perms;
            r_cr_we_attr_latch    <= iw_cr_we_attr;
            r_cr_attr_latch       <= iw_cr_attr;
            r_cr_we_tag_latch     <= iw_cr_we_tag;
            r_cr_tag_latch        <= iw_cr_tag;
        end
    end
    assign ow_pc        = r_pc_latch;
    assign ow_instr     = r_instr_latch;
    assign ow_opc       = r_opc_latch;
    assign ow_root_opc  = r_root_opc_latch;
    assign ow_tgt_gp    = r_tgt_gp_latch;
    assign ow_tgt_gp_we = r_tgt_gp_we_latch;
    assign ow_tgt_sr    = r_tgt_sr_latch;
    assign ow_tgt_sr_we = r_tgt_sr_we_latch;
    assign ow_tgt_ar    = r_tgt_ar_latch;
    assign ow_tgt_ar_we = r_tgt_ar_we_latch;
    // MO uses r_mem_mp_latch to select its port; MA uses ~r_mem_mp_latch.
    assign ow_mem_mp    = r_mem_mp_latch;
    assign ow_result    = r_result_latch;
    assign ow_sr_result = r_sr_result_latch;
    assign ow_ar_result = r_ar_result_latch;
    assign ow_sr_aux_we = r_sr_aux_we_latch;
    assign ow_sr_aux_addr = r_sr_aux_addr_latch;
    assign ow_sr_aux_result = r_sr_aux_result_latch;
    assign ow_trap_pending = r_trap_pending_latch;
    // Forward CR writebacks
    assign ow_cr_write_addr = r_cr_write_addr_latch;
    assign ow_cr_we_base    = r_cr_we_base_latch;
    assign ow_cr_base       = r_cr_base_latch;
    assign ow_cr_we_len     = r_cr_we_len_latch;
    assign ow_cr_len        = r_cr_len_latch;
    assign ow_cr_we_cur     = r_cr_we_cur_latch;
    assign ow_cr_cur        = r_cr_cur_latch;
    assign ow_cr_we_perms   = r_cr_we_perms_latch;
    assign ow_cr_perms      = r_cr_perms_latch;
`ifndef SYNTHESIS
    always @(posedge iw_clk) begin
        if (!iw_rst && (iw_opc == `OPC_SRLDso)) begin
            $display("[MA] SRLDso addr=%0d mem_mp=%0d", iw_addr, r_mem_mp_latch);
        end
    end
`endif

    assign ow_cr_we_attr    = r_cr_we_attr_latch;
    assign ow_cr_attr       = r_cr_attr_latch;
    assign ow_cr_we_tag     = r_cr_we_tag_latch;
    assign ow_cr_tag        = r_cr_tag_latch;
endmodule
