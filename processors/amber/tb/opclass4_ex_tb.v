`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/cr.vh"

module opclass4_ex_tb;
    reg                    clk;
    reg                    rst;
    reg  [`HBIT_ADDR:0]    pc;
    wire [`HBIT_ADDR:0]    ex_pc;
    reg  [`HBIT_DATA:0]    instr;
    wire [`HBIT_DATA:0]    ex_instr;
    reg  [`HBIT_OPC:0]     opc;
    wire [`HBIT_OPC:0]     ex_opc;
    reg                    sgn_en;
    reg                    imm_en;
    reg  [`HBIT_IMM14:0]   imm14_val;
    reg  [`HBIT_IMM12:0]   imm12_val;
    reg  [`HBIT_IMM10:0]   imm10_val;
    reg  [`HBIT_IMM16:0]   imm16_val;
    reg  [`HBIT_CC:0]      cc;
    reg  [`HBIT_TGT_GP:0]  tgt_gp;
    reg                    tgt_gp_we;
    wire [`HBIT_TGT_GP:0]  ex_tgt_gp;
    wire                   ex_tgt_gp_we;
    reg  [`HBIT_TGT_SR:0]  tgt_sr;
    reg                    tgt_sr_we;
    wire [`HBIT_TGT_SR:0]  ex_tgt_sr;
    wire                   ex_tgt_sr_we;
    reg  [`HBIT_SRC_GP:0]  src_gp;
    reg  [`HBIT_TGT_AR:0]  src_ar;
    reg  [`HBIT_SRC_SR:0]  src_sr;
    reg  [`HBIT_TGT_AR:0]  tgt_ar;
    wire [`HBIT_TGT_AR:0]  ex_tgt_ar;
    wire                   ex_tgt_ar_we;
    wire [`HBIT_ADDR:0]    ex_addr;
    wire [`HBIT_DATA:0]    ex_result;
    wire [`HBIT_ADDR:0]    ex_ar_result;
    wire [`HBIT_ADDR:0]    ex_sr_result;
    wire                   branch_taken;
    wire [`HBIT_ADDR:0]    branch_pc;
    reg  [`HBIT_DATA:0]    src_gp_val;
    reg  [`HBIT_DATA:0]    tgt_gp_val;
    reg  [`HBIT_ADDR:0]    src_ar_val;
    reg  [`HBIT_ADDR:0]    tgt_ar_val;
    reg  [`HBIT_ADDR:0]    src_sr_val;
    reg  [`HBIT_ADDR:0]    tgt_sr_val;
    reg                    flush;
    reg                    stall;

    // CR views for EX
    reg  [`HBIT_ADDR:0]    cr_s_base, cr_s_len, cr_s_cur;
    reg  [`HBIT_DATA:0]    cr_s_perms, cr_s_attr;
    reg                    cr_s_tag;
    reg  [`HBIT_ADDR:0]    cr_t_base, cr_t_len, cr_t_cur;
    reg  [`HBIT_DATA:0]    cr_t_perms, cr_t_attr;
    reg                    cr_t_tag;

    stg_ex dut(
        .iw_clk(clk), .iw_rst(rst), .iw_pc(pc), .ow_pc(ex_pc),
        .iw_instr(instr), .ow_instr(ex_instr), .iw_opc(opc), .ow_opc(ex_opc),
        .iw_sgn_en(sgn_en), .iw_imm_en(imm_en),
        .iw_imm14_val(imm14_val), .iw_imm12_val(imm12_val), .iw_imm10_val(imm10_val), .iw_imm16_val(imm16_val),
        .iw_cc(cc),
        .iw_tgt_gp(tgt_gp), .iw_tgt_gp_we(tgt_gp_we), .ow_tgt_gp(ex_tgt_gp), .ow_tgt_gp_we(ex_tgt_gp_we),
        .iw_tgt_sr(tgt_sr), .iw_tgt_sr_we(tgt_sr_we), .ow_tgt_sr(ex_tgt_sr), .ow_tgt_sr_we(ex_tgt_sr_we),
        .iw_tgt_ar(tgt_ar), .ow_tgt_ar(ex_tgt_ar), .ow_tgt_ar_we(ex_tgt_ar_we),
        .iw_src_gp(src_gp), .iw_src_ar(src_ar), .iw_src_sr(src_sr),
        .ow_addr(ex_addr), .ow_result(ex_result), .ow_ar_result(ex_ar_result), .ow_sr_result(ex_sr_result),
        .ow_branch_taken(branch_taken), .ow_branch_pc(branch_pc),
        .iw_src_gp_val(src_gp_val), .iw_tgt_gp_val(tgt_gp_val),
        .iw_src_ar_val(src_ar_val), .iw_tgt_ar_val(tgt_ar_val),
        .iw_src_sr_val(src_sr_val), .iw_tgt_sr_val(tgt_sr_val),
        .iw_flush(flush), .iw_stall(stall),
        // CR read/write unused here
        .ow_cr_write_addr(), .ow_cr_we_base(), .ow_cr_base(), .ow_cr_we_len(), .ow_cr_len(),
        .ow_cr_we_cur(), .ow_cr_cur(), .ow_cr_we_perms(), .ow_cr_perms(), .ow_cr_we_attr(), .ow_cr_attr(),
        .ow_cr_we_tag(), .ow_cr_tag(),
        .iw_cr_s_base(cr_s_base), .iw_cr_s_len(cr_s_len), .iw_cr_s_cur(cr_s_cur), .iw_cr_s_perms(cr_s_perms), .iw_cr_s_attr(cr_s_attr), .iw_cr_s_tag(cr_s_tag),
        .iw_cr_t_base(cr_t_base), .iw_cr_t_len(cr_t_len), .iw_cr_t_cur(cr_t_cur), .iw_cr_t_perms(cr_t_perms), .iw_cr_t_attr(cr_t_attr), .iw_cr_t_tag(cr_t_tag)
    );

    task step; begin @(posedge clk); @(posedge clk); end endtask
    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        rst = 1; stall = 0; flush = 0;
        pc = 48'h0000_0600; instr = 0; opc = 0; sgn_en = 1; imm_en = 1;
        imm14_val = 0; imm12_val = 0; imm10_val = 0; imm16_val = 0;
        cc = `CC_RA; tgt_gp = 0; tgt_gp_we = 1; tgt_sr = 0; tgt_sr_we = 0; tgt_ar = 0;
        src_gp = 0; src_ar = 0; src_sr = 2'b10;
        src_gp_val = 0; tgt_gp_val = 24'h000000; src_ar_val = 0; tgt_ar_val = 0; src_sr_val = 0; tgt_sr_val = 0;
        cr_s_base=0; cr_s_len=0; cr_s_cur=0; cr_s_perms=0; cr_s_attr=0; cr_s_tag=0;
        cr_t_base=0; cr_t_len=0; cr_t_cur=0; cr_t_perms=0; cr_t_attr=0; cr_t_tag=0;
        #12 rst = 0;

        // A) LDcso: addr = CRs.cur + off; no trap
        cr_s_base = 48'd100; cr_s_len = 48'd32; cr_s_cur = 48'd105; cr_s_perms = (24'd1<<`CR_PERM_R_BIT); cr_s_attr=0; cr_s_tag=1;
        opc = `OPC_LDcso; imm10_val = 10'd1; step();
        if (branch_taken) begin $display("LDcso unexpectedly trapped"); $fatal; end
        if (ex_addr !== 48'd106) begin $display("LDcso addr %0d", ex_addr); $fatal; end

        // B) STcso: addr = CRt.cur + off; result = DRs
        cr_t_base = 48'd200; cr_t_len = 48'd16; cr_t_cur = 48'd205; cr_t_perms = (24'd1<<`CR_PERM_W_BIT); cr_t_attr=0; cr_t_tag=1;
        opc = `OPC_STcso; src_gp_val = 24'h112233; imm10_val = 10'd1; step();
        if (branch_taken) $fatal;
        if (ex_addr !== 48'd206) $fatal;
        if (ex_result !== 24'h112233) $fatal;

        // C) STui: immediate 0xABC123 to (CR1.cur)
        // First, load upper bank0 via LUIui
        opc = `OPC_LUIui; instr[15:14] = 2'b00; imm12_val = 12'hABC; step();
        // Set CRt as earlier; now STui with low imm12
        opc = `OPC_STui; instr[15:14] = 2'b01; imm12_val = 12'h123; step();
        if (branch_taken) $fatal;
        if (ex_addr !== cr_t_cur) $fatal;
        if (ex_result !== 24'hABC123) $fatal;

        // D) STsi: negative immediate
        opc = `OPC_STsi; instr[15:14] = 2'b01; imm14_val = 14'h3FF8; step(); // -8
        if (branch_taken) $fatal;
        if (ex_result !== 24'hFFFFF8) $fatal;

        // E) CLDcso: check-only op (valid)
        cr_s_base = 48'd300; cr_s_len = 48'd64; cr_s_cur = 48'd300; cr_s_perms = (24'd1<<`CR_PERM_LC_BIT); cr_s_attr=0; cr_s_tag=1;
        opc = `OPC_CLDcso; imm10_val = 10'd0; step(); if (branch_taken) $fatal;
        // E2) CLDcso: invalid (missing LC) -> trap
        cr_s_perms = (24'd1<<`CR_PERM_R_BIT); opc = `OPC_CLDcso; imm10_val = 10'd0; step(); if (!branch_taken) $fatal;

        // F) CSTcso: check-only (valid)
        cr_t_base = 48'd400; cr_t_len = 48'd32; cr_t_cur = 48'd404; cr_t_perms = (24'd1<<`CR_PERM_SC_BIT); cr_t_attr=0; cr_t_tag=1;
        opc = `OPC_CSTcso; imm10_val = 10'd2; step(); if (branch_taken) $fatal;
        // F2) CSTcso: invalid (missing SC) -> trap
        cr_t_perms = (24'd1<<`CR_PERM_W_BIT); opc = `OPC_CSTcso; imm10_val = 10'd2; step(); if (!branch_taken) $fatal;

        $display("opclass4_ex_tb PASS");
        $finish;
    end
endmodule

