`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/opcodes.vh"
`include "src/csr.vh"
`include "src/pstate.vh"

module amber(
    input wire iw_clk,
    input wire iw_rst
);
    // ----------------------------
    // Instruction-side cache and backing BRAM
    // ----------------------------
    wire [`HBIT_ADDR:0] w_imem_addr  [0:1];
    wire [`HBIT_ADDR:0] w_imem_rdata [0:1];
    // Backing BRAM (mem.v) for I-cache (instance kept as u_imem for TB access)
    wire                ic_b_we     [0:1];
    wire [`HBIT_ADDR:0] ic_b_addr_a [0:1];
    wire [`HBIT_ADDR:0] ic_b_wdata  [0:1];
    wire                ic_b_is48   [0:1];
    wire [`HBIT_ADDR:0] ic_b_rdata  [0:1];

    mem #(.READ_MEM(1)) u_imem(
        .iw_clk  (iw_clk),
        .iw_we   (ic_b_we),
        .iw_addr (ic_b_addr_a),
        .iw_wdata(ic_b_wdata),
        .iw_is48 (ic_b_is48),
        .or_rdata(ic_b_rdata)
    );
    // I-back BRAM is read-only in normal operation
    assign ic_b_we[0]    = 1'b0;
    assign ic_b_we[1]    = 1'b0;
    assign ic_b_wdata[0] = {(`HBIT_ADDR+1){1'b0}};
    assign ic_b_wdata[1] = {(`HBIT_ADDR+1){1'b0}};
    assign ic_b_is48[0]  = 1'b0;
    assign ic_b_is48[1]  = 1'b0;

    // I-cache instance
    wire                w_ic_stall;
    wire [`HBIT_ADDR:0] ic_f_rdata;
    wire [`HBIT_ADDR:0] ic_refill_addr;
    wire                ic_refill_req;
`ifndef AMBER_USE_GWDDR
    reg  [`HBIT_ADDR:0] ic_refill_addr_q;
    reg                 ic_refill_req_q;
`endif
    icache_16x16_24 u_icache(
        .clk     (iw_clk),
        .rst     (iw_rst),
        .f_addr  (w_imem_addr[0]),
        .f_is48  (1'b0),
        .f_rdata (ic_f_rdata),
        .ow_stall(w_ic_stall),
        .b_addr  (ic_refill_addr),
        .b_req   (ic_refill_req),
        .b_valid (
`ifndef AMBER_USE_GWDDR
            ic_refill_req_q
`else
            ic_refill_ic_valid
`endif
        ),
        .b_rdata (ic_b_rdata[0])
    );
`ifndef AMBER_USE_GWDDR
    // 1-cycle handshake to BRAM: capture request and drive address; data valid next cycle
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            ic_refill_req_q  <= 1'b0;
            ic_refill_addr_q <= {(`HBIT_ADDR+1){1'b0}};
        end else begin
            ic_refill_req_q  <= ic_refill_req;
            if (ic_refill_req)
                ic_refill_addr_q <= ic_refill_addr;
        end
    end
    // Drive backing BRAM port 0 with refill address; leave port 1 idle
    assign ic_b_addr_a[0] = ic_refill_addr_q;
    assign ic_b_addr_a[1] = {(`HBIT_ADDR+1){1'b0}};
`else
    // DDR native refill shim: define ic_valid wire; instance later with D-cache
    wire                ic_refill_ic_valid;
`endif
    // Present cache data to IF on port [0]; zero port [1]
    assign w_imem_rdata[0] = ic_f_rdata;
    assign w_imem_rdata[1] = {(`HBIT_ADDR+1){1'b0}};

    // ----------------------------
    // Data-side cache and backing BRAM
    // ----------------------------
    wire                w_dmem_we    [0:1];
    wire [`HBIT_ADDR:0] w_dmem_addr  [0:1];
    wire [`HBIT_ADDR:0] w_dmem_wdata [0:1];
    wire                w_dmem_is48  [0:1];
    wire [`HBIT_ADDR:0] w_dmem_rdata [0:1];

`ifndef AMBER_USE_GWDDR
    // Backing BRAM (mem.v) for D-cache (instance kept as u_dmem for TB access)
    wire [`HBIT_ADDR:0] dc_b_addr;
    wire                dc_b_req;
    reg                 dc_b_req_q;
    reg  [`HBIT_ADDR:0] dc_b_addr_q;
    wire                dc_b_we;
    wire [`HBIT_ADDR:0] dc_b_wdata;
    wire                dc_b_is48;
    wire [`HBIT_ADDR:0] dc_b_rdata;
    // Local array wires to connect to mem.v cleanly
    wire                dmem_we_arr    [0:1];
    wire [`HBIT_ADDR:0] dmem_addr_arr  [0:1];
    wire [`HBIT_ADDR:0] dmem_wdata_arr [0:1];
    wire                dmem_is48_arr  [0:1];
    wire [`HBIT_ADDR:0] dmem_rdata_arr [0:1];

    assign dmem_we_arr[0]    = 1'b0;
    assign dmem_we_arr[1]    = dc_b_we;
    assign dmem_addr_arr[0]  = {(`HBIT_ADDR+1){1'b0}};
    // Use combinational address for write-throughs; latched address for refills
    assign dmem_addr_arr[1]  = (dc_b_we ? dc_b_addr : dc_b_addr_q);
    assign dmem_wdata_arr[0] = {(`HBIT_ADDR+1){1'b0}};
    assign dmem_wdata_arr[1] = dc_b_wdata;
    assign dmem_is48_arr[0]  = 1'b0;
    assign dmem_is48_arr[1]  = dc_b_is48;
    assign dc_b_rdata        = dmem_rdata_arr[1];

    mem #(.READ_MEM(0)) u_dmem(
        .iw_clk  (iw_clk),
        .iw_we   (dmem_we_arr),
        .iw_addr (dmem_addr_arr),
        .iw_wdata(dmem_wdata_arr),
        .iw_is48 (dmem_is48_arr),
        .or_rdata(dmem_rdata_arr)
    );
`endif

    wire w_dc_stall;
    dcache_16x16_24 u_dcache(
        .clk      (iw_clk),
        .rst      (iw_rst),
        .f_we     (w_dmem_we),
        .f_addr   (w_dmem_addr),
        .f_wdata  (w_dmem_wdata),
        .f_is48   (w_dmem_is48),
        .f_rdata  (w_dmem_rdata),
        .ow_stall (w_dc_stall),
        .b_addr   (dc_b_addr),
        .b_req    (dc_b_req),
        .b_we     (dc_b_we),
        .b_wdata  (dc_b_wdata),
        .b_is48   (dc_b_is48),
        .b_valid  (
`ifndef AMBER_USE_GWDDR
            dc_b_req_q
`else
            dc_refill_valid
`endif
        ),
        .b_rdata  (dc_b_rdata)
    );
`ifndef AMBER_USE_GWDDR
    // 1-cycle handshake to BRAM for D-cache refills
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            dc_b_req_q  <= 1'b0;
            dc_b_addr_q <= {(`HBIT_ADDR+1){1'b0}};
        end else begin
            dc_b_req_q <= dc_b_req;
            if (dc_b_req)
                dc_b_addr_q <= dc_b_addr;
        end
    end
`else
    wire dc_refill_valid;
    // Instantiate the combined DDR3-native refill/write-through shim here
    amber_refill_gwddr u_refill (
        .clk      (iw_clk),
        .rst      (iw_rst),
        // I-cache side
        .ic_req   (ic_refill_req),
        .ic_addr  (ic_refill_addr),
        .ic_valid (ic_refill_ic_valid),
        .ic_rdata (ic_b_rdata[0]),
        // D-cache side
        .dc_req   (dc_b_req),
        .dc_addr  (dc_b_addr),
        .dc_valid (dc_refill_valid),
        .dc_rdata (dc_b_rdata),
        .dc_we    (dc_b_we),
        .dc_wdata (dc_b_wdata),
        .dc_is48  (dc_b_is48)
        // Native DDR3 UI ports to be wired at board top
    );
`endif

    wire                w_ia_valid;
    reg  [`HBIT_ADDR:0] r_ia_pc;
    wire [`HBIT_ADDR:0] w_iaif_pc;
    wire [`HBIT_ADDR:0] w_ifxt_pc;
    wire [`HBIT_ADDR:0] w_xtid_pc;
    wire [`HBIT_ADDR:0] w_idex_pc;
    wire [`HBIT_ADDR:0] w_exma_pc;
    wire [`HBIT_ADDR:0] w_mamo_pc;
    wire [`HBIT_ADDR:0] w_mowb_pc;
    wire [`HBIT_ADDR:0] w_wb_pc;

    wire [`HBIT_DATA:0] w_ifxt_instr;
    wire [`HBIT_DATA:0] w_xtid_instr;
    wire [`HBIT_DATA:0] w_idex_instr;
    wire [`HBIT_DATA:0] w_exma_instr;
    wire [`HBIT_DATA:0] w_mamo_instr;
    wire [`HBIT_DATA:0] w_mowb_instr;
    wire [`HBIT_DATA:0] w_wb_instr;

    wire [`HBIT_TGT_GP:0] w_gp_read_addr1;
    wire [`HBIT_TGT_GP:0] w_gp_read_addr2;
    wire [`HBIT_TGT_GP:0] w_gp_write_addr;
    wire [`HBIT_DATA:0]   w_gp_write_data;
    wire                  w_gp_write_enable;
    wire [`HBIT_DATA:0]   w_gp_read_data1;
    wire [`HBIT_DATA:0]   w_gp_read_data2;

    reggp u_reggp(
        .iw_clk         (iw_clk),
        .iw_rst         (iw_rst),
        .iw_read_addr1  (w_gp_read_addr1),
        .iw_read_addr2  (w_gp_read_addr2),
        .iw_write_addr  (w_gp_write_addr),
        .iw_write_data  (w_gp_write_data),
        .iw_write_enable(w_gp_write_enable),
        .ow_read_data1  (w_gp_read_data1),
        .ow_read_data2  (w_gp_read_data2)
    );

    wire [`HBIT_TGT_SR:0] w_sr_read_addr1;
    wire [`HBIT_TGT_SR:0] w_sr_read_addr2;
    wire [`HBIT_TGT_SR:0] w_sr_write_addr;
    wire [`HBIT_ADDR:0]   w_sr_write_data;
    wire                  w_sr_write_enable;
    wire [`HBIT_ADDR:0]   w_sr_write_pc;
    wire                  w_sr_write_pc_enable;
    wire [`HBIT_ADDR:0]   w_sr_read_data1;
    wire [`HBIT_ADDR:0]   w_sr_read_data2;
    wire [`HBIT_ADDR:0]   w_sr_pstate;

    wire csrwr_pstate_lo = (w_wb_opc == `OPC_CSRWR) && (w_wb_instr[11:0] == `CSR_IDX_PSTATE_LO);
    wire csrwr_pstate_hi = (w_wb_opc == `OPC_CSRWR) && (w_wb_instr[11:0] == `CSR_IDX_PSTATE_HI);
    wire csrwr_pstate    = csrwr_pstate_lo | csrwr_pstate_hi;
    wire [`HBIT_ADDR:0] csr_pstate_new = csrwr_pstate_lo
        ? { w_sr_pstate[47:24], w_wb_result }
        : { w_wb_result, w_sr_pstate[23:0] };
    wire                  w_sr_aux_we_final   = w_wb_sr_aux_we | csrwr_pstate;
    wire [`HBIT_TGT_SR:0] w_sr_aux_addr_final = csrwr_pstate ? `SR_IDX_PSTATE : w_wb_sr_aux_addr;
    wire [`HBIT_ADDR:0]   w_sr_aux_result_final = csrwr_pstate ? csr_pstate_new : w_wb_sr_aux_result;

    regsr u_regsr(
        .iw_clk            (iw_clk),
        .iw_rst            (iw_rst),
        .iw_read_addr1     (w_sr_read_addr1),
        .iw_read_addr2     (w_sr_read_addr2),
        .iw_write_addr     (w_sr_write_addr),
        .iw_write_data     (w_sr_write_data),
        .iw_write_enable   (w_sr_write_enable),
        .iw_w2_enable      (w_wb_sr_aux_we),
        .iw_w2_addr        (w_wb_sr_aux_addr),
        .iw_w2_data        (w_wb_sr_aux_result),
        .ow_read_data1     (w_sr_read_data1),
        .ow_read_data2     (w_sr_read_data2),
        .ow_pstate         (w_sr_pstate)
    );

    // Address registers (legacy AR view)
    // Internally backed by capability registers (CR). We expose the AR read
    // and write paths but implement them as reads/writes to CR.cursor.
    wire [`HBIT_TGT_AR:0] w_ar_read_addr1;
    wire [`HBIT_TGT_AR:0] w_ar_read_addr2;
    wire [`HBIT_TGT_AR:0] w_ar_write_addr;
    wire [`HBIT_ADDR:0]   w_ar_write_data;
    wire                  w_ar_write_enable;
    wire [`HBIT_ADDR:0]   w_ar_read_data1;
    wire [`HBIT_ADDR:0]   w_ar_read_data2;

    // Capability registers (CR0..CR3)
    // Map AR indices to CR indices; expose CR.cursor as AR read data and
    // drive CR.cursor writes from AR write port.
    wire [`HBIT_TGT_CR:0] w_cr_read_addr1;
    wire [`HBIT_TGT_CR:0] w_cr_read_addr2;
    wire [`HBIT_ADDR:0]   w_cr_read_base1;
    wire [`HBIT_ADDR:0]   w_cr_read_len1;
    wire [`HBIT_ADDR:0]   w_cr_read_cur1;
    wire [`HBIT_DATA:0]   w_cr_read_perms1;
    wire [`HBIT_DATA:0]   w_cr_read_attr1;
    wire                  w_cr_read_tag1;
    wire [`HBIT_ADDR:0]   w_cr_read_base2;
    wire [`HBIT_ADDR:0]   w_cr_read_len2;
    wire [`HBIT_ADDR:0]   w_cr_read_cur2;
    wire [`HBIT_DATA:0]   w_cr_read_perms2;
    wire [`HBIT_DATA:0]   w_cr_read_attr2;
    wire                  w_cr_read_tag2;

    regcr u_regcr(
        .iw_clk             (iw_clk),
        .iw_rst             (iw_rst),
        .iw_read_addr1      (w_cr_read_addr1),
        .iw_read_addr2      (w_cr_read_addr2),
        .ow_read_base1      (w_cr_read_base1),
        .ow_read_len1       (w_cr_read_len1),
        .ow_read_cur1       (w_cr_read_cur1),
        .ow_read_perms1     (w_cr_read_perms1),
        .ow_read_attr1      (w_cr_read_attr1),
        .ow_read_tag1       (w_cr_read_tag1),
        .ow_read_base2      (w_cr_read_base2),
        .ow_read_len2       (w_cr_read_len2),
        .ow_read_cur2       (w_cr_read_cur2),
        .ow_read_perms2     (w_cr_read_perms2),
        .ow_read_attr2      (w_cr_read_attr2),
        .ow_read_tag2       (w_cr_read_tag2),
        // Write CR fields: prefer CR writeback controls from WB; fall back to AR->CUR writes
        .iw_write_addr      (w_cr_wb_any ? w_wb_cr_write_addr : w_ar_write_addr),
        .iw_write_en_base   (w_cr_wb_any ? w_wb_cr_we_base   : 1'b0),
        .iw_write_base      (w_cr_wb_any ? w_wb_cr_base      : {(`HBIT_ADDR+1){1'b0}}),
        .iw_write_en_len    (w_cr_wb_any ? w_wb_cr_we_len    : 1'b0),
        .iw_write_len       (w_cr_wb_any ? w_wb_cr_len       : {(`HBIT_ADDR+1){1'b0}}),
        .iw_write_en_cur    (w_cr_wb_any ? w_wb_cr_we_cur    : w_ar_write_enable),
        .iw_write_cur       (w_cr_wb_any ? w_wb_cr_cur       : w_ar_write_data),
        .iw_write_en_perms  (w_cr_wb_any ? w_wb_cr_we_perms  : 1'b0),
        .iw_write_perms     (w_cr_wb_any ? w_wb_cr_perms     : {(`HBIT_DATA+1){1'b0}}),
        .iw_write_en_attr   (w_cr_wb_any ? w_wb_cr_we_attr   : 1'b0),
        .iw_write_attr      (w_cr_wb_any ? w_wb_cr_attr      : {(`HBIT_DATA+1){1'b0}}),
        .iw_write_en_tag    (w_cr_wb_any ? w_wb_cr_we_tag    : 1'b0),
        .iw_write_tag       (w_cr_wb_any ? w_wb_cr_tag       : 1'b0)
    );

    // Present CR.cursor as legacy AR read data
    assign w_ar_read_data1 = w_cr_read_cur1;
    assign w_ar_read_data2 = w_cr_read_cur2;

    wire                w_stall;
    wire                w_hazard_stall;
    wire                w_bubble;
    wire                w_branch_taken;
    wire [`HBIT_ADDR:0] w_branch_pc;

    // PCC mirror (from CSR window) for fetch gating
    reg [`HBIT_ADDR:0] r_pcc_base;
    reg [`HBIT_ADDR:0] r_pcc_len;
    reg [`HBIT_ADDR:0] r_pcc_cur;
    reg [`HBIT_DATA:0] r_pcc_perms;
    reg [`HBIT_DATA:0] r_pcc_attr;
    reg                r_pcc_tag;

    // Simple PCC-based fetch gating
    wire w_pcc_x          = r_pcc_perms[2];
    wire w_pcc_in_bounds  = (r_ia_pc >= r_pcc_base) && (r_ia_pc < (r_pcc_base + r_pcc_len));
    wire w_pcc_ok_raw     = r_pcc_tag && w_pcc_x && w_pcc_in_bounds;
    // Relax PCC gating during macro expansion to avoid starving uops
    wire w_pcc_ok         = (w_xt_busy || w_xt_seq_start) ? 1'b1 : w_pcc_ok_raw;

    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_ia_pc <= `SIZE_ADDR'b0;
        end else if (w_branch_taken_eff) begin
            r_ia_pc <= w_branch_pc;
        end else if (r_core_halt) begin
            r_ia_pc <= r_ia_pc;
        end else if (w_stall) begin
            r_ia_pc <= r_ia_pc;
        end else begin
            if (w_pcc_ok)
                r_ia_pc <= r_ia_pc + `SIZE_ADDR'd1;
            else
                r_ia_pc <= r_ia_pc; // Hold on PCC violation (trap path TBD)
        end
    end

    stg_ia u_stg_ia(
        .iw_clk     (iw_clk),
        .iw_rst     (iw_rst),
        .ow_mem_addr(w_imem_addr),
        .iw_pc      (r_ia_pc),
        .ow_pc      (w_iaif_pc),
        .ow_ia_valid(w_ia_valid),
        .iw_flush   (w_branch_taken_eff),
        .iw_stall   (w_stall)
    );

    // Lookahead: next instruction entering XT is a capability macro (CLD/CST)\n    wire w_next_is_cap_macro = ((w_ifxt_instr[23:16] == OPC_CLDcso) || (w_ifxt_instr[23:16] == OPC_CSTcso));\n    // Mask spurious branch during capability macro micro-ops (start/active)
    wire w_mask_xt_br = ((w_xt_busy) || (w_xt_seq_start)) && (
        (w_exma_opc == `OPC_CR2SR)   || (w_exma_opc == `OPC_SR2CR) ||
        (w_exma_opc == `OPC_SRLDso)  || (w_exma_opc == `OPC_SRSTso) ||
        (w_exma_opc == `OPC_SRADDsi) || (w_exma_opc == `OPC_SRSUBsi) ||
        (w_exma_opc == `OPC_SRMOVAur) ||
        // Also suppress UIMM_STATE traps from stray MOVui during macro sequences
        (w_exma_opc == `OPC_MOVui)
    );
    wire w_branch_taken_eff = w_branch_taken & ~w_mask_xt_br;

    stg_if u_stg_if(
        .iw_clk     (iw_clk),
        .iw_rst     (iw_rst),
        .iw_mem_data(w_imem_rdata),
        .iw_ia_valid(w_ia_valid),
        .iw_pc      (w_iaif_pc),
        .ow_pc      (w_ifxt_pc),
        .ow_instr   (w_ifxt_instr),
        .iw_flush   (w_branch_taken_eff),
        .iw_stall   (w_stall)
    );

    wire w_xt_busy;
    wire w_xt_seq_start;
    stg_xt u_stg_xt(
        .iw_clk     (iw_clk),
        .iw_rst     (iw_rst),
        .iw_pc      (w_ifxt_pc),
        .ow_pc      (w_xtid_pc),
        .iw_instr   (w_ifxt_instr),
        .ow_instr   (w_xtid_instr),
        .ow_root_opc(w_root_opc_xtid),
        .iw_flush   (w_branch_taken_eff),
        .iw_stall   (w_stall),
        .ow_busy    (w_xt_busy),
        .ow_seq_start(w_xt_seq_start)
    );

    wire [`HBIT_OPC:0]    w_opc;
    wire [`HBIT_OPC:0]    w_root_opc_xtid;
    wire [`HBIT_OPC:0]    w_root_opc;
    wire                  w_sgn_en;
    wire                  w_imm_en;
    wire [`HBIT_IMM14:0]  w_imm14_val;
    wire [`HBIT_IMM12:0]  w_imm12_val;
    wire [`HBIT_IMM10:0]  w_imm10_val;
    wire [`HBIT_IMM16:0]  w_imm16_val;
    wire [`HBIT_CC:0]     w_cc;
    wire                  w_has_src_gp;
    wire [`HBIT_TGT_GP:0] w_tgt_gp;
    wire                  w_tgt_gp_we;
    wire                  w_has_src_ar;
    wire [`HBIT_TGT_AR:0] w_src_ar;
    wire                  w_has_tgt_ar;
    wire [`HBIT_TGT_AR:0] w_tgt_ar;
    wire                  w_has_src_sr;
    wire [`HBIT_TGT_SR:0] w_tgt_sr;
    wire                  w_tgt_sr_we;
    wire [`HBIT_SRC_GP:0] w_src_gp;
    wire [`HBIT_SRC_SR:0] w_src_sr;

    stg_id u_stg_id(
        .iw_clk       (iw_clk),
        .iw_rst       (iw_rst),
        .iw_pc        (w_xtid_pc),
        .ow_pc        (w_idex_pc),
        .iw_instr     (w_xtid_instr),
        .iw_root_opc  (w_root_opc_xtid),
        .ow_instr     (w_idex_instr),
        .ow_opc       (w_opc),
        .ow_root_opc  (w_root_opc),
        .ow_sgn_en    (w_sgn_en),
        .ow_imm_en    (w_imm_en),
        .ow_imm14_val (w_imm14_val),
        .ow_imm12_val (w_imm12_val),
        .ow_imm10_val (w_imm10_val),
        .ow_imm16_val (w_imm16_val),
        .ow_cc        (w_cc),
        .ow_has_src_gp(w_has_src_gp),
        .ow_tgt_gp    (w_tgt_gp),
        .ow_tgt_gp_we (w_tgt_gp_we),
        .ow_has_src_ar(w_has_src_ar),
        .ow_src_ar    (w_src_ar),
        .ow_has_tgt_ar(w_has_tgt_ar),
        .ow_tgt_ar    (w_tgt_ar),
        .ow_has_src_sr(w_has_src_sr),
        .ow_tgt_sr    (w_tgt_sr),
        .ow_tgt_sr_we (w_tgt_sr_we),
        .ow_src_gp    (w_src_gp),
        .ow_src_sr    (w_src_sr),
        .iw_flush     (w_branch_taken),
        .iw_stall     (w_stall)
    );

    wire [`HBIT_OPC:0]    w_exma_opc;
    wire                  w_exma_halt;
    wire [`HBIT_OPC:0]    w_exma_root_opc;
    wire [`HBIT_TGT_GP:0] w_exma_tgt_gp;
    wire                  w_exma_tgt_gp_we;
    wire [`HBIT_TGT_SR:0] w_exma_tgt_sr;
    wire                  w_exma_tgt_sr_we;
    wire [`HBIT_TGT_AR:0] w_exma_tgt_ar;
    wire                  w_exma_tgt_ar_we;
    wire [`HBIT_ADDR:0]   w_exma_addr;
    wire [`HBIT_DATA:0]   w_exma_result;
    wire [`HBIT_ADDR:0]   w_exma_sr_result;
    wire [`HBIT_ADDR:0]   w_exma_ar_result;
    wire                  w_exma_sr_aux_we;
    wire [`HBIT_TGT_SR:0] w_exma_sr_aux_addr;
    wire [`HBIT_ADDR:0]   w_exma_sr_aux_result;
    wire                  w_exma_trap_pending;
    // CR writeback buses EX->MA
    wire [`HBIT_TGT_CR:0] w_exma_cr_write_addr;
    wire                  w_exma_cr_we_base;
    wire [`HBIT_ADDR:0]   w_exma_cr_base;
    wire                  w_exma_cr_we_len;
    wire [`HBIT_ADDR:0]   w_exma_cr_len;
    wire                  w_exma_cr_we_cur;
    wire [`HBIT_ADDR:0]   w_exma_cr_cur;
    wire                  w_exma_cr_we_perms;
    wire [`HBIT_DATA:0]   w_exma_cr_perms;
    wire                  w_exma_cr_we_attr;
    wire [`HBIT_DATA:0]   w_exma_cr_attr;
    wire                  w_exma_cr_we_tag;
    wire                  w_exma_cr_tag;

    wire [`HBIT_OPC:0]    w_mamo_opc;
    wire [`HBIT_OPC:0]    w_mamo_root_opc;
    wire [`HBIT_TGT_GP:0] w_mamo_tgt_gp;
    wire                  w_mamo_tgt_gp_we;
    wire [`HBIT_TGT_SR:0] w_mamo_tgt_sr;
    wire                  w_mamo_tgt_sr_we;
    wire [`HBIT_DATA:0]   w_mamo_result;
    wire [`HBIT_TGT_AR:0] w_mamo_tgt_ar;
    wire                  w_mamo_tgt_ar_we;
    wire [`HBIT_ADDR:0]   w_mamo_sr_result;
    wire [`HBIT_ADDR:0]   w_mamo_ar_result;
    wire                  w_mamo_sr_aux_we;
    wire [`HBIT_TGT_SR:0] w_mamo_sr_aux_addr;
    wire [`HBIT_ADDR:0]   w_mamo_sr_aux_result;
    wire                  w_mamo_trap_pending;
    // CR writeback buses MA->MO
    wire [`HBIT_TGT_CR:0] w_mamo_cr_write_addr;
    wire                  w_mamo_cr_we_base;
    wire [`HBIT_ADDR:0]   w_mamo_cr_base;
    wire                  w_mamo_cr_we_len;
    wire [`HBIT_ADDR:0]   w_mamo_cr_len;
    wire                  w_mamo_cr_we_cur;
    wire [`HBIT_ADDR:0]   w_mamo_cr_cur;
    wire                  w_mamo_cr_we_perms;
    wire [`HBIT_DATA:0]   w_mamo_cr_perms;
    wire                  w_mamo_cr_we_attr;
    wire [`HBIT_DATA:0]   w_mamo_cr_attr;
    wire                  w_mamo_cr_we_tag;
    wire                  w_mamo_cr_tag;

    wire [`HBIT_OPC:0]    w_mowb_opc;
    wire [`HBIT_OPC:0]    w_mowb_root_opc;
    wire [`HBIT_TGT_GP:0] w_mowb_tgt_gp;
    wire                  w_mowb_tgt_gp_we;
    wire [`HBIT_TGT_SR:0] w_mowb_tgt_sr;
    wire                  w_mowb_tgt_sr_we;
    wire [`HBIT_DATA:0]   w_mowb_result;
    wire [`HBIT_TGT_AR:0] w_mowb_tgt_ar;
    wire                  w_mowb_tgt_ar_we;
    wire [`HBIT_ADDR:0]   w_mowb_sr_result;
    wire [`HBIT_ADDR:0]   w_mowb_ar_result;
    wire                  w_mowb_sr_aux_we;
    wire [`HBIT_TGT_SR:0] w_mowb_sr_aux_addr;
    wire [`HBIT_ADDR:0]   w_mowb_sr_aux_result;
    wire                  w_mowb_trap_pending;
    // CR writeback buses MO->WB
    wire [`HBIT_TGT_CR:0] w_wb_cr_write_addr;
    wire                  w_wb_cr_we_base;
    wire [`HBIT_ADDR:0]   w_wb_cr_base;
    wire                  w_wb_cr_we_len;
    wire [`HBIT_ADDR:0]   w_wb_cr_len;
    wire                  w_wb_cr_we_cur;
    wire [`HBIT_ADDR:0]   w_wb_cr_cur;
    wire                  w_wb_cr_we_perms;
    wire [`HBIT_DATA:0]   w_wb_cr_perms;
    wire                  w_wb_cr_we_attr;
    wire [`HBIT_DATA:0]   w_wb_cr_attr;
    wire                  w_wb_cr_we_tag;
    wire                  w_wb_cr_tag;
    wire                  w_cr_wb_any = w_wb_cr_we_base | w_wb_cr_we_len | w_wb_cr_we_cur | w_wb_cr_we_perms | w_wb_cr_we_attr | w_wb_cr_we_tag;

    wire [`HBIT_DATA:0]   w_src_gp_val;
    wire [`HBIT_DATA:0]   w_tgt_gp_val;
    wire [`HBIT_ADDR:0]   w_src_ar_val;
    wire [`HBIT_ADDR:0]   w_tgt_ar_val;
    wire [`HBIT_ADDR:0]   w_src_sr_val;
    wire [`HBIT_ADDR:0]   w_tgt_sr_val;

    assign w_gp_read_addr1 = w_src_gp;
    assign w_gp_read_addr2 = w_tgt_gp;
    assign w_ar_read_addr1 = w_has_src_ar ? w_src_ar : {(`HBIT_TGT_AR+1){1'b0}};
    assign w_ar_read_addr2 = w_has_tgt_ar ? w_tgt_ar : {(`HBIT_TGT_AR+1){1'b0}};
    // Map AR read indices into CR read ports
    assign w_cr_read_addr1 = w_ar_read_addr1;
    assign w_cr_read_addr2 = w_ar_read_addr2;
    assign w_sr_read_addr1 = w_src_sr;
    assign w_sr_read_addr2 = w_tgt_sr;

    // CSR file plumbing
    wire [`HBIT_TGT_CSR:0] w_csr_read_addr1;
    wire [`HBIT_TGT_CSR:0] w_csr_read_addr2;
    wire [`HBIT_TGT_CSR:0] w_csr_write_addr;
    wire [`HBIT_DATA:0]    w_csr_write_data;
    wire                   w_csr_write_enable;
    wire [`HBIT_DATA:0]    w_csr_read_data1;
    wire [`HBIT_DATA:0]    w_csr_read_data2;
    wire                   w_csr_write_enable_reg;
    wire                   w_csr_write_enable_mmu;
    wire [`HBIT_DATA:0]    w_csr_read_data1_mux;
    wire                   w_mmu_csr_read_valid;
    wire [`HBIT_DATA:0]    w_mmu_csr_read_data;

    // MMU translation/control wires
    wire                   w_mmu_d_stall;
    wire                   w_mmu_d_resp_valid;
    wire [`HBIT_ADDR:0]    w_mmu_d_resp_paddr;
    wire [5:0]             w_mmu_d_resp_port;
    wire                   w_mmu_d_resp_linear;
    wire                   w_mmu_d_fault;
    wire [2:0]             w_mmu_d_fault_code;
    wire [`HBIT_ADDR:0]    w_mmu_d_fault_vaddr;
    wire                   w_mmu_i_stall;
    wire                   w_mmu_i_resp_valid;
    wire [`HBIT_ADDR:0]    w_mmu_i_resp_paddr;
    wire                   w_mmu_i_fault;
    wire [2:0]             w_mmu_i_fault_code;
    wire [`HBIT_ADDR:0]    w_mmu_i_fault_vaddr;
    wire [3:0]             w_mmu_status_fault_bits;
    wire [`HBIT_ADDR:0]    w_mmu_status_fault_va;
    wire                   w_mmu_status_busy;

    // Wires for async CSR write port (e.g., math unit)
    wire                   w_csr_w2_en;
    wire [`HBIT_TGT_CSR:0] w_csr_w2_addr;
    wire [`HBIT_DATA:0]    w_csr_w2_data;
    // Taps for math engine CSRs
    wire [`HBIT_DATA:0]    w_csr_math_ctrl;
    wire [`HBIT_DATA:0]    w_csr_math_opa;
    wire [`HBIT_DATA:0]    w_csr_math_opb;
    wire [`HBIT_DATA:0]    w_csr_math_opc;

    regcsr u_regcsr(
        .iw_clk         (iw_clk),
        .iw_rst         (iw_rst),
        .iw_read_addr1  (w_csr_read_addr1),
        .iw_read_addr2  (w_csr_read_addr2),
        .iw_write_addr  (w_csr_write_addr),
        .iw_write_data  (w_csr_write_data),
        .iw_write_enable(w_csr_write_enable_reg),
        // Aux write port from async engines
        .iw_w2_enable   (w_csr_w2_en),
        .iw_w2_addr     (w_csr_w2_addr),
        .iw_w2_data     (w_csr_w2_data),
        .ow_read_data1  (w_csr_read_data1),
        .ow_read_data2  (w_csr_read_data2),
        .ow_math_ctrl   (w_csr_math_ctrl),
        .ow_math_opa    (w_csr_math_opa),
        .ow_math_opb    (w_csr_math_opb),
        .ow_math_opc    (w_csr_math_opc)
    );

    // Privilege mode: 1 = kernel, 0 = user
    reg r_mode_kernel;
    reg r_core_halt;
    // Drive CSR read addr from current EX instruction when CSRRD
    assign w_csr_read_addr1 = (w_opc == `OPC_CSRRD) ? w_idex_instr[11:0] : {(`HBIT_TGT_CSR+1){1'b0}};
    assign w_csr_read_addr2 = {(`HBIT_TGT_CSR+1){1'b0}};
    // Effective CSR read data overrides for dynamic fields:
    // - PSTATE mirrors live architectural state (handled via sr file)
    // - PCC_CUR mirrors live PC (split across LO/HI)
    wire csr_is_read   = (w_opc == `OPC_CSRRD);
    wire [`HBIT_TGT_CSR:0] csr_idx = w_idex_instr[11:0];
    assign w_csr_read_data1_mux = w_mmu_csr_read_valid ? w_mmu_csr_read_data : w_csr_read_data1;
    wire [`HBIT_DATA:0] w_csr_read_data1_eff =
        (csr_is_read && (csr_idx == `CSR_IDX_PSTATE_LO))
            ? w_sr_pstate[23:0]
        : (csr_is_read && (csr_idx == `CSR_IDX_PSTATE_HI))
            ? w_sr_pstate[47:24]
        : (csr_is_read && (csr_idx == `CSR_IDX_PCC_CUR_LO))
            ? r_pcc_cur[23:0]
        : (csr_is_read && (csr_idx == `CSR_IDX_PCC_CUR_HI))
            ? r_pcc_cur[47:24]
        : w_csr_read_data1_mux;
    // Mux SR source value: for CSRRD feed CSR read data zero-extended
    wire [`HBIT_ADDR:0] w_src_sr_val_mux = (w_opc == `OPC_CSRRD) ? { {(`SIZE_ADDR-`SIZE_DATA){1'b0}}, w_csr_read_data1_eff } : w_src_sr_val;

    // CSR write driven in WB when CSRWR retires
    assign w_csr_write_enable = (w_wb_opc == `OPC_CSRWR);
    assign w_csr_write_addr   = w_wb_instr[11:0];
    assign w_csr_write_data   = w_wb_result;
    assign w_csr_write_enable_mmu = w_csr_write_enable &&
        (w_csr_write_addr >= `CSR_IDX_MMU_CFG) && (w_csr_write_addr <= `CSR_IDX_MMU_TLBVPN_HI);
    assign w_csr_write_enable_reg = w_csr_write_enable && ~w_csr_write_enable_mmu;

    // Mirror PCC window into local registers for fetch gating; keep PCC.cursor synced to PC
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_pcc_base  <= {(`HBIT_ADDR+1){1'b0}};
            r_pcc_len   <= `SIZE_ADDR'd4096; // default 4K BAUs
            r_pcc_cur   <= {(`HBIT_ADDR+1){1'b0}};
            r_pcc_perms <= 24'b0000_0000_0000_0000_0000_0100; // X=1
            r_pcc_attr  <= {(`HBIT_DATA+1){1'b0}};
            r_pcc_tag   <= 1'b1;
        end else begin
            // Track PC in PCC.cursor (synchronize)
            r_pcc_cur <= r_ia_pc;
            // Only allow kernel to modify PCC window via CSR
            if (w_csr_write_enable && r_mode_kernel) begin
                case (w_csr_write_addr)
                    `CSR_IDX_PCC_BASE_LO: r_pcc_base[23:0]  <= w_csr_write_data;
                    `CSR_IDX_PCC_BASE_HI: r_pcc_base[47:24] <= w_csr_write_data;
                    `CSR_IDX_PCC_LEN_LO:  r_pcc_len[23:0]   <= w_csr_write_data;
                    `CSR_IDX_PCC_LEN_HI:  r_pcc_len[47:24]  <= w_csr_write_data;
                    `CSR_IDX_PCC_CUR_LO:  r_pcc_cur[23:0]   <= w_csr_write_data;
                    `CSR_IDX_PCC_CUR_HI:  r_pcc_cur[47:24]  <= w_csr_write_data;
                    `CSR_IDX_PCC_PERMS:   r_pcc_perms       <= w_csr_write_data;
                    `CSR_IDX_PCC_ATTR:    r_pcc_attr        <= w_csr_write_data;
                    `CSR_IDX_PCC_TAG:     r_pcc_tag         <= w_csr_write_data[0];
                endcase
            end
        end
    end

    // Async 24-bit math engine connected via CSR window
    math24_async u_math24_async(
        .iw_clk        (iw_clk),
        .iw_rst        (iw_rst),
        .iw_math_ctrl  (w_csr_math_ctrl),
        .iw_math_opa   (w_csr_math_opa),
        .iw_math_opb   (w_csr_math_opb),
        .iw_math_opc   (w_csr_math_opc),
        .ow_csr_wen    (w_csr_w2_en),
        .ow_csr_waddr  (w_csr_w2_addr),
        .ow_csr_wdata  (w_csr_w2_data)
    );

    // Kernel/User mode state machine (handles CSR writes and SYSCALL/KRET)
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            // Reset into kernel mode
            r_mode_kernel <= 1'b1;
        end else begin
            // CSR writes to STATUS allowed only in kernel; update mode bit from bit[0]
            if (w_csr_write_enable && (w_csr_write_addr == `CSR_IDX_PSTATE_LO) && r_mode_kernel)
                r_mode_kernel <= w_csr_write_data[`PSTATE_BIT_MODE];
            // Trap entry/return: update mode on taken branch of SYSCALL/KRET
            if (w_branch_taken) begin
                if (w_exma_trap_pending) begin
                    r_mode_kernel <= 1'b1;
                end else if (w_exma_root_opc == `OPC_SYSCALL) begin
                    r_mode_kernel <= 1'b1;
                end else if (w_exma_root_opc == `OPC_KRET) begin
                    r_mode_kernel <= 1'b0;
                end
            end
        end
    end

    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_core_halt <= 1'b0;
        end else if (w_exma_halt) begin
            r_core_halt <= 1'b1;
        end
    end

    forward u_forward(
        .iw_tgt_gp        (w_tgt_gp),
        .iw_tgt_gp_we     (w_tgt_gp_we),
        .iw_tgt_exma_gp   (w_exma_tgt_gp),
        .iw_tgt_exma_gp_we(w_exma_tgt_gp_we),
        .iw_tgt_mamo_gp   (w_mamo_tgt_gp),
        .iw_tgt_mamo_gp_we(w_mamo_tgt_gp_we),
        .iw_tgt_mowb_gp   (w_mowb_tgt_gp),
        .iw_tgt_mowb_gp_we(w_mowb_tgt_gp_we),
        // SR
        .iw_tgt_sr        (w_tgt_sr),
        .iw_tgt_sr_we     (w_tgt_sr_we),
        .iw_tgt_exma_sr   (w_exma_tgt_sr),
        .iw_tgt_exma_sr_we(w_exma_tgt_sr_we),
        .iw_tgt_mamo_sr   (w_mamo_tgt_sr),
        .iw_tgt_mamo_sr_we(w_mamo_tgt_sr_we),
        .iw_tgt_mowb_sr   (w_mowb_tgt_sr),
        .iw_tgt_mowb_sr_we(w_mowb_tgt_sr_we),
        // AR
        .iw_tgt_ar        (w_tgt_ar),
        .iw_tgt_exma_ar   (w_exma_tgt_ar),
        .iw_tgt_exma_ar_we(w_exma_tgt_ar_we),
        .iw_tgt_mamo_ar   (w_mamo_tgt_ar),
        .iw_tgt_mamo_ar_we(w_mamo_tgt_ar_we),
        .iw_tgt_mowb_ar   (w_mowb_tgt_ar),
        .iw_tgt_mowb_ar_we(w_mowb_tgt_ar_we),
        .iw_src_gp        (w_src_gp),
        .iw_src_sr        (w_src_sr),
        .iw_src_ar        (w_src_ar),
        .iw_gp_read_data1 (w_gp_read_data1),
        .iw_gp_read_data2 (w_gp_read_data2),
        .iw_sr_read_data1 (w_sr_read_data1),
        .iw_sr_read_data2 (w_sr_read_data2),
        .iw_ar_read_data1 (w_ar_read_data1),
        .iw_ar_read_data2 (w_ar_read_data2),
        .iw_exma_result   (w_exma_result),
        .iw_mamo_result   (w_mamo_result),
        .iw_mowb_result   (w_mowb_result),
        .iw_exma_sr_result(w_exma_sr_result),
        .iw_mamo_sr_result(w_mamo_sr_result),
        .iw_mowb_sr_result(w_mowb_sr_result),
        .iw_exma_ar_result(w_exma_ar_result),
        .iw_mamo_ar_result(w_mamo_ar_result),
        .iw_mowb_ar_result(w_mowb_ar_result),
        .or_src_gp_val    (w_src_gp_val),
        .or_tgt_gp_val    (w_tgt_gp_val),
        .or_src_sr_val    (w_src_sr_val),
        .or_tgt_sr_val    (w_tgt_sr_val),
        .or_src_ar_val    (w_src_ar_val),
        .or_tgt_ar_val    (w_tgt_ar_val)
    );

    hazard u_hazard(
        .iw_clk           (iw_clk),
        .iw_rst           (iw_rst),
        .iw_idex_opc      (w_opc),
        .ow_stall         (w_hazard_stall)
    );
    // Global stall is OR of hazard and cache refills
    assign w_stall = w_hazard_stall | w_ic_stall | w_dc_stall |
        w_mmu_d_stall | w_mmu_i_stall | r_core_halt;
`ifndef SYNTHESIS
    always @(posedge iw_clk) begin
        if (w_branch_taken_eff) begin
            $display("[BR] branch taken: opc=%h pc=%0d -> %0d%s", w_exma_opc, w_exma_pc, w_branch_pc, (w_mask_xt_br?" (masked)":""));
        end
    end
`endif

    stg_ex u_stg_ex(
        .iw_clk           (iw_clk),
        .iw_rst           (iw_rst),
        .iw_pc            (w_idex_pc),
        .ow_pc            (w_exma_pc),
        .iw_instr         (w_idex_instr),
        .ow_instr         (w_exma_instr),
        .iw_opc           (w_opc),
        .iw_root_opc      (w_root_opc),
        .ow_opc           (w_exma_opc),
        .ow_root_opc      (w_exma_root_opc),
        .iw_sgn_en        (w_sgn_en),
        .iw_imm_en        (w_imm_en),
        .iw_imm14_val     (w_imm14_val),
        .iw_imm12_val     (w_imm12_val),
        .iw_imm10_val     (w_imm10_val),
        .iw_imm16_val     (w_imm16_val),
        .iw_cc            (w_cc),
        .iw_tgt_gp        (w_tgt_gp),
        .iw_tgt_gp_we     (w_tgt_gp_we),
        .ow_tgt_gp        (w_exma_tgt_gp),
        .ow_tgt_gp_we     (w_exma_tgt_gp_we),
        .iw_tgt_sr        (w_tgt_sr),
        .iw_tgt_sr_we     (w_tgt_sr_we),
        .ow_tgt_sr        (w_exma_tgt_sr),
        .ow_tgt_sr_we     (w_exma_tgt_sr_we),
        .iw_tgt_ar        (w_tgt_ar),
        .ow_tgt_ar        (w_exma_tgt_ar),
        .ow_tgt_ar_we     (w_exma_tgt_ar_we),
        .iw_src_gp        (w_src_gp),
        .iw_src_ar        (w_src_ar),
        .iw_src_sr        (w_src_sr),
        .ow_addr          (w_exma_addr),
        .ow_result        (w_exma_result),
        .ow_ar_result     (w_exma_ar_result),
        .ow_sr_result     (w_exma_sr_result),
        .ow_sr_aux_we     (w_exma_sr_aux_we),
        .ow_sr_aux_addr   (w_exma_sr_aux_addr),
        .ow_sr_aux_result (w_exma_sr_aux_result),
        .ow_branch_taken  (w_branch_taken),
        .ow_branch_pc     (w_branch_pc),
        .ow_trap_pending  (w_exma_trap_pending),
        .ow_halt          (w_exma_halt),
        .iw_src_gp_val    (w_src_gp_val),
        .iw_tgt_gp_val    (w_tgt_gp_val),
        .iw_src_ar_val    (w_src_ar_val),
        .iw_tgt_ar_val    (w_tgt_ar_val),
        .iw_src_sr_val    (w_src_sr_val_mux),
        .iw_tgt_sr_val    (w_tgt_sr_val),
        .iw_pstate_val    (w_sr_pstate),
        // CR writeback controls out of EX
        .ow_cr_write_addr (w_exma_cr_write_addr),
        .ow_cr_we_base    (w_exma_cr_we_base),
        .ow_cr_base       (w_exma_cr_base),
        .ow_cr_we_len     (w_exma_cr_we_len),
        .ow_cr_len        (w_exma_cr_len),
        .ow_cr_we_cur     (w_exma_cr_we_cur),
        .ow_cr_cur        (w_exma_cr_cur),
        .ow_cr_we_perms   (w_exma_cr_we_perms),
        .ow_cr_perms      (w_exma_cr_perms),
        .ow_cr_we_attr    (w_exma_cr_we_attr),
        .ow_cr_attr       (w_exma_cr_attr),
        .ow_cr_we_tag     (w_exma_cr_we_tag),
        .ow_cr_tag        (w_exma_cr_tag),
        .iw_mode_kernel   (r_mode_kernel),
        .iw_mmu_d_fault   (w_mmu_d_fault),
        .iw_mmu_d_fault_code (w_mmu_d_fault_code),
        .iw_mmu_d_fault_va   (w_mmu_d_fault_vaddr),
        // CR read views mapped from CR read ports 1/2 (driven by AR indices)
        .iw_cr_s_base     (w_cr_read_base1),
        .iw_cr_s_len      (w_cr_read_len1),
        .iw_cr_s_cur      (w_cr_read_cur1),
        .iw_cr_s_perms    (w_cr_read_perms1),
        .iw_cr_s_attr     (w_cr_read_attr1),
        .iw_cr_s_tag      (w_cr_read_tag1),
        .iw_cr_t_base     (w_cr_read_base2),
        .iw_cr_t_len      (w_cr_read_len2),
        .iw_cr_t_cur      (w_cr_read_cur2),
        .iw_cr_t_perms    (w_cr_read_perms2),
        .iw_cr_t_attr     (w_cr_read_attr2),
        .iw_cr_t_tag      (w_cr_read_tag2),
        .iw_flush         (w_branch_taken),
        .iw_stall         (w_stall)
    );

    wire w_exma_is_load  = (w_exma_opc == `OPC_SRLDso) || (w_exma_opc == `OPC_LDcso);
    wire w_exma_is_store = (w_exma_opc == `OPC_STui) || (w_exma_opc == `OPC_STsi) ||
                           (w_exma_opc == `OPC_STcso) || (w_exma_opc == `OPC_SRSTso);
    wire w_exma_is_mem_op = w_exma_is_load | w_exma_is_store;

    wire w_tlbinv_all_pulse  = (w_exma_opc == `OPC_TLBINV_ALL)  & ~w_stall;
    wire w_tlbinv_asid_pulse = (w_exma_opc == `OPC_TLBINV_ASID) & ~w_stall;
    wire w_tlbinv_page_pulse = (w_exma_opc == `OPC_TLBINV_PAGE) & ~w_stall;
    wire [15:0] w_tlbinv_asid_value = w_src_gp_val[15:0];
    wire [35:0] w_tlbinv_page_vpn   = w_src_sr_val[47:12];

    amber_mmu u_mmu(
        .iw_clk               (iw_clk),
        .iw_rst               (iw_rst),
        .iw_mode_kernel       (r_mode_kernel),
        .iw_flush             (w_branch_taken_eff),
        .iw_csr_read_en       (csr_is_read),
        .iw_csr_read_addr     (w_csr_read_addr1),
        .ow_csr_read_data     (w_mmu_csr_read_data),
        .ow_csr_read_valid    (w_mmu_csr_read_valid),
        .iw_csr_write_en      (w_csr_write_enable_mmu),
        .iw_csr_write_addr    (w_csr_write_addr),
        .iw_csr_write_data    (w_csr_write_data),
        .iw_tlbinv_all        (w_tlbinv_all_pulse),
        .iw_tlbinv_asid_valid (w_tlbinv_asid_pulse),
        .iw_tlbinv_asid       (w_tlbinv_asid_value),
        .iw_tlbinv_page_valid (w_tlbinv_page_pulse),
        .iw_tlbinv_page_vpn   (w_tlbinv_page_vpn),
        .iw_tlbinv_page_global(1'b1),
        .iw_d_req_valid       (w_exma_is_mem_op),
        .iw_d_req_vaddr       (w_exma_addr),
        .iw_d_req_is_store    (w_exma_is_store),
        .ow_d_stall           (w_mmu_d_stall),
        .ow_d_resp_valid      (w_mmu_d_resp_valid),
        .ow_d_resp_paddr      (w_mmu_d_resp_paddr),
        .ow_d_resp_port       (w_mmu_d_resp_port),
        .ow_d_resp_linear     (w_mmu_d_resp_linear),
        .ow_d_fault           (w_mmu_d_fault),
        .ow_d_fault_code      (w_mmu_d_fault_code),
        .ow_d_fault_vaddr     (w_mmu_d_fault_vaddr),
        .iw_i_req_valid       (1'b0),
        .iw_i_req_vaddr       ({(`HBIT_ADDR+1){1'b0}}),
        .ow_i_stall           (w_mmu_i_stall),
        .ow_i_resp_valid      (w_mmu_i_resp_valid),
        .ow_i_resp_paddr      (w_mmu_i_resp_paddr),
        .ow_i_fault           (w_mmu_i_fault),
        .ow_i_fault_code      (w_mmu_i_fault_code),
        .ow_i_fault_vaddr     (w_mmu_i_fault_vaddr),
        .ow_status_fault_bits (w_mmu_status_fault_bits),
        .ow_status_fault_va   (w_mmu_status_fault_va),
        .ow_status_busy       (w_mmu_status_busy)
    );

    wire [`HBIT_ADDR:0] w_exma_addr_phys = w_mmu_d_resp_valid ? w_mmu_d_resp_paddr : w_exma_addr;

    wire w_mem_mp;

    stg_ma u_stg_ma(
        .iw_clk      (iw_clk),
        .iw_rst      (iw_rst),
        .iw_stall    (w_stall),
        .iw_pc       (w_exma_pc),
        .ow_pc       (w_mamo_pc),
        .iw_instr    (w_exma_instr),
        .ow_instr    (w_mamo_instr),
        .iw_opc      (w_exma_opc),
        .iw_root_opc (w_exma_root_opc),
        .ow_opc      (w_mamo_opc),
        .ow_root_opc (w_mamo_root_opc),
        .iw_tgt_gp   (w_exma_tgt_gp),
        .iw_tgt_gp_we(w_exma_tgt_gp_we),
        .ow_tgt_gp   (w_mamo_tgt_gp),
        .ow_tgt_gp_we(w_mamo_tgt_gp_we),
        .iw_tgt_sr   (w_exma_tgt_sr),
        .iw_tgt_sr_we(w_exma_tgt_sr_we),
        .ow_tgt_sr   (w_mamo_tgt_sr),
        .ow_tgt_sr_we(w_mamo_tgt_sr_we),
        .iw_tgt_ar   (w_exma_tgt_ar),
        .iw_tgt_ar_we(w_exma_tgt_ar_we),
        .ow_tgt_ar   (w_mamo_tgt_ar),
        .ow_tgt_ar_we(w_mamo_tgt_ar_we),
        .ow_mem_mp   (w_mem_mp),
        .ow_mem_addr (w_dmem_addr),
        .iw_addr     (w_exma_addr_phys),
        .iw_result   (w_exma_result),
        .ow_result   (w_mamo_result),
        .iw_sr_result(w_exma_sr_result),
        .ow_sr_result(w_mamo_sr_result),
        .iw_ar_result(w_exma_ar_result),
        .ow_ar_result(w_mamo_ar_result),
        .iw_sr_aux_we  (w_exma_sr_aux_we),
        .iw_sr_aux_addr(w_exma_sr_aux_addr),
        .iw_sr_aux_result(w_exma_sr_aux_result),
        .iw_trap_pending(w_exma_trap_pending),
        .ow_sr_aux_we  (w_mamo_sr_aux_we),
        .ow_sr_aux_addr(w_mamo_sr_aux_addr),
        .ow_sr_aux_result(w_mamo_sr_aux_result),
        .ow_trap_pending(w_mamo_trap_pending),
        // CR writeback forward EX->MA
        .iw_cr_write_addr (w_exma_cr_write_addr),
        .iw_cr_we_base    (w_exma_cr_we_base),
        .iw_cr_base       (w_exma_cr_base),
        .iw_cr_we_len     (w_exma_cr_we_len),
        .iw_cr_len        (w_exma_cr_len),
        .iw_cr_we_cur     (w_exma_cr_we_cur),
        .iw_cr_cur        (w_exma_cr_cur),
        .iw_cr_we_perms   (w_exma_cr_we_perms),
        .iw_cr_perms      (w_exma_cr_perms),
        .iw_cr_we_attr    (w_exma_cr_we_attr),
        .iw_cr_attr       (w_exma_cr_attr),
        .iw_cr_we_tag     (w_exma_cr_we_tag),
        .iw_cr_tag        (w_exma_cr_tag),
        .ow_cr_write_addr (w_mamo_cr_write_addr),
        .ow_cr_we_base    (w_mamo_cr_we_base),
        .ow_cr_base       (w_mamo_cr_base),
        .ow_cr_we_len     (w_mamo_cr_we_len),
        .ow_cr_len        (w_mamo_cr_len),
        .ow_cr_we_cur     (w_mamo_cr_we_cur),
        .ow_cr_cur        (w_mamo_cr_cur),
        .ow_cr_we_perms   (w_mamo_cr_we_perms),
        .ow_cr_perms      (w_mamo_cr_perms),
        .ow_cr_we_attr    (w_mamo_cr_we_attr),
        .ow_cr_attr       (w_mamo_cr_attr),
        .ow_cr_we_tag     (w_mamo_cr_we_tag),
        .ow_cr_tag        (w_mamo_cr_tag)
    );

    stg_mo u_stg_mo(
        .iw_clk      (iw_clk),
        .iw_rst      (iw_rst),
        .iw_pc       (w_mamo_pc),
        .ow_pc       (w_mowb_pc),
        .iw_instr    (w_mamo_instr),
        .ow_instr    (w_mowb_instr),
        .iw_opc      (w_mamo_opc),
        .iw_root_opc (w_mamo_root_opc),
        .ow_opc      (w_mowb_opc),
        .ow_root_opc (w_mowb_root_opc),
        .iw_tgt_gp   (w_mamo_tgt_gp),
        .iw_tgt_gp_we(w_mamo_tgt_gp_we),
        .ow_tgt_gp   (w_mowb_tgt_gp),
        .ow_tgt_gp_we(w_mowb_tgt_gp_we),
        .iw_tgt_sr   (w_mamo_tgt_sr),
        .iw_tgt_sr_we(w_mamo_tgt_sr_we),
        .ow_tgt_sr   (w_mowb_tgt_sr),
        .ow_tgt_sr_we(w_mowb_tgt_sr_we),
        .iw_tgt_ar   (w_mamo_tgt_ar),
        .iw_tgt_ar_we(w_mamo_tgt_ar_we),
        .ow_tgt_ar   (w_mowb_tgt_ar),
        .ow_tgt_ar_we(w_mowb_tgt_ar_we),
        .iw_mem_mp   (w_mem_mp),
        .ow_mem_we   (w_dmem_we),
        .ow_mem_wdata(w_dmem_wdata),
        .ow_mem_is48 (w_dmem_is48),
        .iw_mem_rdata(w_dmem_rdata),
        .iw_result   (w_mamo_result),
        .ow_result   (w_mowb_result),
        .iw_sr_result(w_mamo_sr_result),
        .ow_sr_result(w_mowb_sr_result),
        .iw_ar_result(w_mamo_ar_result),
        .ow_ar_result(w_mowb_ar_result),
        .iw_sr_aux_we  (w_mamo_sr_aux_we),
        .iw_sr_aux_addr(w_mamo_sr_aux_addr),
        .iw_sr_aux_result(w_mamo_sr_aux_result),
        .iw_trap_pending(w_mamo_trap_pending),
        .ow_sr_aux_we  (w_mowb_sr_aux_we),
        .ow_sr_aux_addr(w_mowb_sr_aux_addr),
        .ow_sr_aux_result(w_mowb_sr_aux_result),
        .ow_trap_pending(w_mowb_trap_pending),
        // CR writeback forward MA->MO
        .iw_cr_write_addr (w_mamo_cr_write_addr),
        .iw_cr_we_base    (w_mamo_cr_we_base),
        .iw_cr_base       (w_mamo_cr_base),
        .iw_cr_we_len     (w_mamo_cr_we_len),
        .iw_cr_len        (w_mamo_cr_len),
        .iw_cr_we_cur     (w_mamo_cr_we_cur),
        .iw_cr_cur        (w_mamo_cr_cur),
        .iw_cr_we_perms   (w_mamo_cr_we_perms),
        .iw_cr_perms      (w_mamo_cr_perms),
        .iw_cr_we_attr    (w_mamo_cr_we_attr),
        .iw_cr_attr       (w_mamo_cr_attr),
        .iw_cr_we_tag     (w_mamo_cr_we_tag),
        .iw_cr_tag        (w_mamo_cr_tag),
        .ow_cr_write_addr (w_wb_cr_write_addr),
        .ow_cr_we_base    (w_wb_cr_we_base),
        .ow_cr_base       (w_wb_cr_base),
        .ow_cr_we_len     (w_wb_cr_we_len),
        .ow_cr_len        (w_wb_cr_len),
        .ow_cr_we_cur     (w_wb_cr_we_cur),
        .ow_cr_cur        (w_wb_cr_cur),
        .ow_cr_we_perms   (w_wb_cr_we_perms),
        .ow_cr_perms      (w_wb_cr_perms),
        .ow_cr_we_attr    (w_wb_cr_we_attr),
        .ow_cr_attr       (w_wb_cr_attr),
        .ow_cr_we_tag     (w_wb_cr_we_tag),
        .ow_cr_tag        (w_wb_cr_tag)
    );

    wire [`HBIT_OPC:0]    w_wb_opc;
    wire [`HBIT_OPC:0]    w_wb_root_opc;
    wire [`HBIT_TGT_GP:0] w_wb_tgt_gp;
    wire [`HBIT_TGT_SR:0] w_wb_tgt_sr;
    wire [`HBIT_DATA:0]   w_wb_result;
    wire                  w_wb_sr_aux_we;
    wire [`HBIT_TGT_SR:0] w_wb_sr_aux_addr;
    wire [`HBIT_ADDR:0]   w_wb_sr_aux_result;
    wire                  w_wb_trap_pending;

    stg_wb u_stg_wb(
        .iw_clk            (iw_clk),
        .iw_rst            (iw_rst),
        .iw_pc             (w_mowb_pc),
        .ow_pc             (w_wb_pc),
        .iw_instr          (w_mowb_instr),
        .ow_instr          (w_wb_instr),
        .ow_gp_write_addr  (w_gp_write_addr),
        .ow_gp_write_data  (w_gp_write_data),
        .ow_gp_write_enable(w_gp_write_enable),
        .ow_sr_write_addr  (w_sr_write_addr),
        .ow_sr_write_data  (w_sr_write_data),
        .ow_sr_write_enable(w_sr_write_enable),
        .iw_opc            (w_mowb_opc),
        .iw_root_opc       (w_mowb_root_opc),
        .ow_opc            (w_wb_opc),
        .ow_root_opc       (w_wb_root_opc),
        .iw_tgt_gp         (w_mowb_tgt_gp),
        .iw_tgt_gp_we      (w_mowb_tgt_gp_we),
        .ow_tgt_gp         (w_wb_tgt_gp),
        .iw_tgt_sr         (w_mowb_tgt_sr),
        .iw_tgt_sr_we      (w_mowb_tgt_sr_we),
        .ow_tgt_sr         (w_wb_tgt_sr),
        .iw_tgt_ar         (w_mowb_tgt_ar),
        .iw_tgt_ar_we      (w_mowb_tgt_ar_we),
        .ow_ar_write_addr  (w_ar_write_addr),
        .ow_ar_write_data  (w_ar_write_data),
        .ow_ar_write_enable(w_ar_write_enable),
        .iw_result         (w_mowb_result),
        .iw_sr_result      (w_mowb_sr_result),
        .iw_ar_result      (w_mowb_ar_result),
        .iw_sr_aux_we      (w_mowb_sr_aux_we),
        .iw_sr_aux_addr    (w_mowb_sr_aux_addr),
        .iw_sr_aux_result  (w_mowb_sr_aux_result),
        .iw_trap_pending   (w_mowb_trap_pending),
        .ow_result         (w_wb_result),
        // CR writeback forward MO->WB
        .iw_cr_write_addr  (w_wb_cr_write_addr),
        .iw_cr_we_base     (w_wb_cr_we_base),
        .iw_cr_base        (w_wb_cr_base),
        .iw_cr_we_len      (w_wb_cr_we_len),
        .iw_cr_len         (w_wb_cr_len),
        .iw_cr_we_cur      (w_wb_cr_we_cur),
        .iw_cr_cur         (w_wb_cr_cur),
        .iw_cr_we_perms    (w_wb_cr_we_perms),
        .iw_cr_perms       (w_wb_cr_perms),
        .iw_cr_we_attr     (w_wb_cr_we_attr),
        .iw_cr_attr        (w_wb_cr_attr),
        .iw_cr_we_tag      (w_wb_cr_we_tag),
        .iw_cr_tag         (w_wb_cr_tag),
        .ow_sr_aux_we      (w_wb_sr_aux_we),
        .ow_sr_aux_addr    (w_wb_sr_aux_addr),
        .ow_sr_aux_result  (w_wb_sr_aux_result),
        .ow_trap_pending   (w_wb_trap_pending),
        .ow_cr_write_addr  (),
        .ow_cr_we_base     (),
        .ow_cr_base        (),
        .ow_cr_we_len      (),
        .ow_cr_len         (),
        .ow_cr_we_cur      (),
        .ow_cr_cur         (),
        .ow_cr_we_perms    (),
        .ow_cr_perms       (),
        .ow_cr_we_attr     (),
        .ow_cr_attr        (),
        .ow_cr_we_tag      (),
        .ow_cr_tag         ()
    );
endmodule
