`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"

module stg_mo(
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
    // iw_mem_mp selects which memory port MO uses in this cycle.
    // MA set the address on the opposite port in the previous cycle, so the
    // two ports exist to let MA and MO alternate each cycle.
    //
    // 48-bit ops do NOT use both ports simultaneously. MO still accesses a
    // single port selected by iw_mem_mp, using the full 48-bit per-port
    // buses: `ow_mem_wdata[*]` for stores and `iw_mem_rdata[*]` for loads.
    // The memory (`mem.v`) packs/unpacks adjacent 24-bit words internally
    // when `ow_mem_is48[*]` is asserted for that selected port.
    input wire                   iw_mem_mp,
    output reg                   ow_mem_we [0:1],
    output reg  [`HBIT_ADDR:0]   ow_mem_wdata [0:1],  // 48-bit write bus per port
    output reg                   ow_mem_is48 [0:1],   // per-port access width: 1=48b
    input wire  [`HBIT_ADDR:0]   iw_mem_rdata [0:1],  // 48-bit read bus per port
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
    // Forward CR writeback controls to WB
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
    reg [`HBIT_DATA:0] r_result;
    reg [`HBIT_ADDR:0] r_sr_result_next;
    reg [`HBIT_ADDR:0] r_ar_result_next;
    always @(*) begin
        ow_mem_we[0] = 1'b0;
        ow_mem_we[1] = 1'b0;
        ow_mem_wdata[0] = {`SIZE_ADDR{1'b0}};
        ow_mem_wdata[1] = {`SIZE_ADDR{1'b0}};
        ow_mem_is48[0] = 1'b0;
        ow_mem_is48[1] = 1'b0;
        r_result = iw_result;
        r_sr_result_next = iw_sr_result;
        r_ar_result_next = iw_ar_result;
        case (iw_opc)
            `OPC_SRLDso: begin
                // 48-bit little-endian load from the selected port
                // Enable 48-bit read packing on both ports to tolerate the
                // MA/MO port alternation.
                ow_mem_is48[0] = 1'b1;
                ow_mem_is48[1] = 1'b1;
                r_sr_result_next = iw_mem_rdata[iw_mem_mp];
                r_result = r_sr_result_next[23:0];
            end
            `OPC_LDcso: begin
                // 24-bit load from selected port
                // is48 left at 0 (default); read low 24 bits
                r_result = iw_mem_rdata[iw_mem_mp][23:0];
            end
            `OPC_STui, `OPC_STsi: begin
                // 24-bit store to the selected port for this cycle
                ow_mem_we[iw_mem_mp] = 1'b1;
                ow_mem_wdata[iw_mem_mp] = {24'b0, iw_result};
                ow_mem_is48[iw_mem_mp] = 1'b0;
            end
            `OPC_STcso: begin
                // 24-bit store with address supplied by MA
                ow_mem_we[iw_mem_mp] = 1'b1;
                ow_mem_wdata[iw_mem_mp] = {24'b0, iw_result};
                ow_mem_is48[iw_mem_mp] = 1'b0;
            end
            `OPC_SRSTso: begin
                // 48-bit little-endian store on the selected port
                // Use latched SR value (from previous cycle) to align with MA
                ow_mem_we[iw_mem_mp] = 1'b1;
                ow_mem_wdata[iw_mem_mp] = r_sr_result_latch;
                ow_mem_is48[iw_mem_mp] = 1'b1;
            end
        endcase
    end
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
            r_result_latch    <= r_result;
            r_sr_result_latch <= r_sr_result_next;
            r_ar_result_latch <= r_ar_result_next;
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
    assign ow_result    = r_result_latch;
    assign ow_sr_result = r_sr_result_latch;
    assign ow_ar_result = r_ar_result_latch;
    assign ow_sr_aux_we = r_sr_aux_we_latch;
    assign ow_sr_aux_addr = r_sr_aux_addr_latch;
    assign ow_sr_aux_result = r_sr_aux_result_latch;
    assign ow_trap_pending = r_trap_pending_latch;
    // Forward CR writeback controls to WB
    assign ow_cr_write_addr = r_cr_write_addr_latch;
    assign ow_cr_we_base    = r_cr_we_base_latch;
    assign ow_cr_base       = r_cr_base_latch;
    assign ow_cr_we_len     = r_cr_we_len_latch;
    assign ow_cr_len        = r_cr_len_latch;
    assign ow_cr_we_cur     = r_cr_we_cur_latch;
    assign ow_cr_cur        = r_cr_cur_latch;
    assign ow_cr_we_perms   = r_cr_we_perms_latch;
    assign ow_cr_perms      = r_cr_perms_latch;
    assign ow_cr_we_attr    = r_cr_we_attr_latch;
    assign ow_cr_attr       = r_cr_attr_latch;
    assign ow_cr_we_tag     = r_cr_we_tag_latch;
    assign ow_cr_tag        = r_cr_tag_latch;
endmodule
