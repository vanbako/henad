`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/pstate.vh"
`include "src/sr.vh"
`include "src/flags.vh"

module opclass3_ex_tb;
    reg                    clk;
    reg                    rst;
    reg  [`HBIT_ADDR:0]    pc;
    wire [`HBIT_ADDR:0]    ex_pc;
    reg  [`HBIT_DATA:0]    instr;
    wire [`HBIT_DATA:0]    ex_instr;
    reg  [`HBIT_OPC:0]     opc;
    reg  [`HBIT_OPC:0]     root_opc;
    wire [`HBIT_OPC:0]     ex_opc;
    wire [`HBIT_OPC:0]     ex_root_opc;
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
    wire                   ex_branch_taken;
    wire [`HBIT_ADDR:0]    ex_branch_pc;
    wire                   ex_trap_pending;
    wire                   ex_halt;
    reg  [`HBIT_DATA:0]    src_gp_val;
    reg  [`HBIT_DATA:0]    tgt_gp_val;
    reg  [`HBIT_ADDR:0]    src_ar_val;
    reg  [`HBIT_ADDR:0]    tgt_ar_val;
    reg  [`HBIT_ADDR:0]    tgt_sr_val;
    reg                    flush;
    reg                    stall;
    reg                    mode_kernel;

    wire                   sr_aux_we;
    wire [`HBIT_TGT_SR:0]  sr_aux_addr;
    wire [`HBIT_ADDR:0]    sr_aux_result;

    wire [`HBIT_TGT_CR:0]  cr_write_addr;
    wire                   cr_we_base;
    wire [`HBIT_ADDR:0]    cr_base;
    wire                   cr_we_len;
    wire [`HBIT_ADDR:0]    cr_len;
    wire                   cr_we_cur;
    wire [`HBIT_ADDR:0]    cr_cur;
    wire                   cr_we_perms;
    wire [`HBIT_DATA:0]    cr_perms;
    wire                   cr_we_attr;
    wire [`HBIT_DATA:0]    cr_attr;
    wire                   cr_we_tag;
    wire                   cr_tag;

    reg  [`HBIT_ADDR:0]    cr_s_base;
    reg  [`HBIT_ADDR:0]    cr_s_len;
    reg  [`HBIT_ADDR:0]    cr_s_cur;
    reg  [`HBIT_DATA:0]    cr_s_perms;
    reg  [`HBIT_DATA:0]    cr_s_attr;
    reg                    cr_s_tag;
    reg  [`HBIT_ADDR:0]    cr_t_base;
    reg  [`HBIT_ADDR:0]    cr_t_len;
    reg  [`HBIT_ADDR:0]    cr_t_cur;
    reg  [`HBIT_DATA:0]    cr_t_perms;
    reg  [`HBIT_DATA:0]    cr_t_attr;
    reg                    cr_t_tag;

    reg  [`HBIT_ADDR:0]    pstate;

    stg_ex dut(
        .iw_clk(clk),
        .iw_rst(rst),
        .iw_pc(pc),
        .ow_pc(ex_pc),
        .iw_instr(instr),
        .ow_instr(ex_instr),
        .iw_opc(opc),
        .iw_root_opc(root_opc),
        .ow_opc(ex_opc),
        .ow_root_opc(ex_root_opc),
        .iw_sgn_en(sgn_en),
        .iw_imm_en(imm_en),
        .iw_imm14_val(imm14_val),
        .iw_imm12_val(imm12_val),
        .iw_imm10_val(imm10_val),
        .iw_imm16_val(imm16_val),
        .iw_cc(cc),
        .iw_tgt_gp(tgt_gp),
        .iw_tgt_gp_we(tgt_gp_we),
        .ow_tgt_gp(ex_tgt_gp),
        .ow_tgt_gp_we(ex_tgt_gp_we),
        .iw_tgt_sr(tgt_sr),
        .iw_tgt_sr_we(tgt_sr_we),
        .ow_tgt_sr(ex_tgt_sr),
        .ow_tgt_sr_we(ex_tgt_sr_we),
        .iw_src_gp(src_gp),
        .iw_src_ar(src_ar),
        .iw_src_sr(src_sr),
        .iw_tgt_ar(tgt_ar),
        .ow_tgt_ar(ex_tgt_ar),
        .ow_tgt_ar_we(ex_tgt_ar_we),
        .ow_addr(ex_addr),
        .ow_result(ex_result),
        .ow_ar_result(ex_ar_result),
        .ow_sr_result(ex_sr_result),
        .ow_sr_aux_we(sr_aux_we),
        .ow_sr_aux_addr(sr_aux_addr),
        .ow_sr_aux_result(sr_aux_result),
        .ow_branch_taken(ex_branch_taken),
        .ow_branch_pc(ex_branch_pc),
        .ow_trap_pending(ex_trap_pending),
        .ow_halt(ex_halt),
        .iw_src_gp_val(src_gp_val),
        .iw_tgt_gp_val(tgt_gp_val),
        .iw_src_ar_val(src_ar_val),
        .iw_tgt_ar_val(tgt_ar_val),
        .iw_src_sr_val(pstate),
        .iw_tgt_sr_val(tgt_sr_val),
        .iw_pstate_val(pstate),
        .ow_cr_write_addr(cr_write_addr),
        .ow_cr_we_base(cr_we_base),
        .ow_cr_base(cr_base),
        .ow_cr_we_len(cr_we_len),
        .ow_cr_len(cr_len),
        .ow_cr_we_cur(cr_we_cur),
        .ow_cr_cur(cr_cur),
        .ow_cr_we_perms(cr_we_perms),
        .ow_cr_perms(cr_perms),
        .ow_cr_we_attr(cr_we_attr),
        .ow_cr_attr(cr_attr),
        .ow_cr_we_tag(cr_we_tag),
        .ow_cr_tag(cr_tag),
        .iw_cr_s_base(cr_s_base),
        .iw_cr_s_len(cr_s_len),
        .iw_cr_s_cur(cr_s_cur),
        .iw_cr_s_perms(cr_s_perms),
        .iw_cr_s_attr(cr_s_attr),
        .iw_cr_s_tag(cr_s_tag),
        .iw_cr_t_base(cr_t_base),
        .iw_cr_t_len(cr_t_len),
        .iw_cr_t_cur(cr_t_cur),
        .iw_cr_t_perms(cr_t_perms),
        .iw_cr_t_attr(cr_t_attr),
        .iw_cr_t_tag(cr_t_tag),
        .iw_flush(flush),
        .iw_mode_kernel(mode_kernel),
        .iw_stall(stall)
    );

    localparam [47:0] TRAP_BASE = 48'h001234_560000;

    task automatic step;
        begin
            @(posedge clk);
            @(posedge clk);
        end
    endtask

    task automatic expect_flags;
        input        expect_we;
        input        exp_z;
        input        exp_n;
        input        exp_c;
        input        exp_v;
        input [127:0] label;
        begin
            if (expect_we) begin
                if (sr_aux_we !== 1'b1) begin
                    $display("FAIL (%s): expected flag update", label);
                    $fatal;
                end
                if (sr_aux_addr !== `SR_IDX_PSTATE) begin
                    $display("FAIL (%s): unexpected SR aux addr %0d", label, sr_aux_addr);
                    $fatal;
                end
                if (sr_aux_result[`PSTATE_BIT_Z] !== exp_z ||
                    sr_aux_result[`PSTATE_BIT_N] !== exp_n ||
                    sr_aux_result[`PSTATE_BIT_C] !== exp_c ||
                    sr_aux_result[`PSTATE_BIT_V] !== exp_v) begin
                    $display("FAIL (%s): flags ZNCV=%0d%0d%0d%0d", label,
                             sr_aux_result[`PSTATE_BIT_Z],
                             sr_aux_result[`PSTATE_BIT_N],
                             sr_aux_result[`PSTATE_BIT_C],
                             sr_aux_result[`PSTATE_BIT_V]);
                    $fatal;
                end
            end else begin
                if (sr_aux_we !== 1'b0) begin
                    $display("FAIL (%s): unexpected flag write", label);
                    $fatal;
                end
            end
        end
    endtask

    task automatic expect_result;
        input [23:0] expected;
        input [127:0] label;
        begin
            if (ex_result !== expected) begin
                $display("FAIL (%s): result %h expected %h", label, ex_result, expected);
                $fatal;
            end
        end
    endtask

    task automatic expect_gp_we;
        input        expected;
        input [127:0] label;
        begin
            if (ex_tgt_gp_we !== expected) begin
                $display("FAIL (%s): GP write enable %b expected %b", label, ex_tgt_gp_we, expected);
                $fatal;
            end
        end
    endtask

    task automatic expect_no_branch;
        input [127:0] label;
        begin
            if (ex_branch_taken !== 1'b0 || ex_trap_pending !== 1'b0) begin
                $display("FAIL (%s): branch=%b trap=%b", label, ex_branch_taken, ex_trap_pending);
                $fatal;
            end
        end
    endtask

    task automatic expect_trap;
        input [7:0]    cause;
        input [47:0]   expected_pc;
        input [47:0]   expected_lr;
        input [127:0]  label;
        begin
            if (ex_branch_taken !== 1'b1 || ex_trap_pending !== 1'b1) begin
                $display("FAIL (%s): trap not taken branch=%b trap=%b", label, ex_branch_taken, ex_trap_pending);
                $fatal;
            end
            if (ex_branch_pc !== expected_pc) begin
                $display("FAIL (%s): branch PC %h expected %h", label, ex_branch_pc, expected_pc);
                $fatal;
            end
            if (ex_tgt_gp_we !== 1'b0) begin
                $display("FAIL (%s): trap should suppress GP write", label);
                $fatal;
            end
            if (sr_aux_we !== 1'b1 || sr_aux_addr !== `SR_IDX_PSTATE) begin
                $display("FAIL (%s): trap should update PSTATE", label);
                $fatal;
            end
            if (sr_aux_result[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO] !== cause) begin
                $display("FAIL (%s): trap cause %02h expected %02h", label,
                         sr_aux_result[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO], cause);
                $fatal;
            end
            if (sr_aux_result[`PSTATE_BIT_TPE] !== 1'b1 ||
                sr_aux_result[`PSTATE_BIT_MODE] !== 1'b1) begin
                $display("FAIL (%s): trap PSTATE bits TPE=%b MODE=%b", label,
                         sr_aux_result[`PSTATE_BIT_TPE], sr_aux_result[`PSTATE_BIT_MODE]);
                $fatal;
            end
            if (ex_tgt_sr_we !== 1'b1 || ex_tgt_sr !== `SR_IDX_LR) begin
                $display("FAIL (%s): LR write missing on trap", label);
                $fatal;
            end
            if (ex_sr_result !== expected_lr) begin
                $display("FAIL (%s): LR value %h expected %h", label, ex_sr_result, expected_lr);
                $fatal;
            end
        end
    endtask

    always #5 clk = ~clk;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pstate <= {(`HBIT_ADDR+1){1'b0}};
        end else if (sr_aux_we && sr_aux_addr == `SR_IDX_PSTATE) begin
            pstate <= sr_aux_result;
        end
    end

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        pc = 48'd0;
        instr = 24'd0;
        opc = `OPC_NOP;
        root_opc = `OPC_NOP;
        sgn_en = 1'b1;
        imm_en = 1'b1;
        imm14_val = '0;
        imm12_val = '0;
        imm10_val = '0;
        imm16_val = '0;
        cc = `CC_RA;
        tgt_gp = 4'd3;
        tgt_gp_we = 1'b1;
        tgt_sr = `SR_IDX_FL;
        tgt_sr_we = 1'b0;
        src_gp = 4'd2;
        src_ar = 2'd0;
        src_sr = `SR_IDX_PSTATE;
        tgt_ar = 2'd0;
        src_gp_val = 24'd0;
        tgt_gp_val = 24'd0;
        src_ar_val = 48'd0;
        tgt_ar_val = 48'd0;
        tgt_sr_val = 48'd0;
        flush = 1'b0;
        stall = 1'b0;
        mode_kernel = 1'b1;
        cr_s_base = 48'd0; cr_s_len = 48'd0; cr_s_cur = 48'd0;
        cr_s_perms = 24'd0; cr_s_attr = 24'd0; cr_s_tag = 1'b0;
        cr_t_base = 48'd0; cr_t_len = 48'd0; cr_t_cur = 48'd0;
        cr_t_perms = 24'd0; cr_t_attr = 24'd0; cr_t_tag = 1'b0;
        pstate = 48'd0;
        pstate[`PSTATE_BIT_MODE] = 1'b1;

        #40 rst = 1'b0;

        // Program trap vector banks for SWI targets
        tgt_gp_we = 1'b0;
        opc = `OPC_LUIui; root_opc = `OPC_LUIui;
        instr = {`OPC_LUIui, 2'b10, 12'h001, 2'b00}; imm12_val = 12'h001; step();
        instr = {`OPC_LUIui, 2'b01, 12'h234, 2'b00}; imm12_val = 12'h234; step();
        instr = {`OPC_LUIui, 2'b00, 12'h560, 2'b00}; imm12_val = 12'h560; step();
        tgt_gp_we = 1'b1;
        imm12_val = 12'd0;
        instr = 24'd0;

        // MOVsi #0 -> DRt (flags Z=1, N=0)
        pc = 48'h0100; opc = `OPC_MOVsi; root_opc = `OPC_MOVsi;
        instr = {`OPC_MOVsi, tgt_gp, 12'h000}; imm12_val = 12'h000;
        tgt_gp_val = 24'hAAAAAA;
        step();
        expect_result(24'h000000, "MOVsi zero");
        expect_gp_we(1'b1, "MOVsi zero");
        expect_no_branch("MOVsi zero");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "MOVsi zero");

        // MCCsi EQ should take when Z=1, imm8=0x7F
        pc = 48'h0101; opc = `OPC_MCCsi; root_opc = `OPC_MCCsi;
        cc = `CC_EQ; instr = {`OPC_MCCsi, tgt_gp, cc, 8'h7F};
        tgt_gp_val = 24'h012345;
        step();
        expect_result(24'h00007F, "MCCsi EQ take");
        expect_gp_we(1'b1, "MCCsi EQ take");
        expect_no_branch("MCCsi EQ take");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "MCCsi EQ take");

        // MCCsi EQ should skip when Z=0
        pc = 48'h0102; opc = `OPC_MCCsi; root_opc = `OPC_MCCsi;
        cc = `CC_EQ; instr = {`OPC_MCCsi, tgt_gp, cc, 8'h55};
        tgt_gp_val = 24'h345678;
        step();
        expect_result(24'h345678, "MCCsi EQ skip");
        expect_gp_we(1'b1, "MCCsi EQ skip");
        expect_no_branch("MCCsi EQ skip");
        expect_flags(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "MCCsi EQ skip");

        // MOVsi positive immediate preserves positive flag state
        pc = 48'h0103; opc = `OPC_MOVsi; root_opc = `OPC_MOVsi;
        instr = {`OPC_MOVsi, tgt_gp, 12'h7AB}; imm12_val = 12'h7AB;
        step();
        expect_result(24'h0007AB, "MOVsi pos");
        expect_gp_we(1'b1, "MOVsi pos");
        expect_no_branch("MOVsi pos");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "MOVsi pos");

        // MOVsi negative immediate sign-extends
        pc = 48'h0104; opc = `OPC_MOVsi; root_opc = `OPC_MOVsi;
        instr = {`OPC_MOVsi, tgt_gp, 12'hF80}; imm12_val = 12'hF80;
        step();
        expect_result(24'hFFFF80, "MOVsi neg");
        expect_gp_we(1'b1, "MOVsi neg");
        expect_no_branch("MOVsi neg");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, "MOVsi neg");

        // MCCsi LT should take when N^V=1
        pc = 48'h0105; opc = `OPC_MCCsi; root_opc = `OPC_MCCsi;
        cc = `CC_LT; instr = {`OPC_MCCsi, tgt_gp, cc, 8'h81};
        tgt_gp_val = 24'h111111;
        step();
        expect_result(24'hFFFF81, "MCCsi LT take");
        expect_gp_we(1'b1, "MCCsi LT take");
        expect_no_branch("MCCsi LT take");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "MCCsi LT take");

        // MCCsi RA always takes (imm8=0 -> Z=1)
        pc = 48'h0106; opc = `OPC_MCCsi; root_opc = `OPC_MCCsi;
        cc = `CC_RA; instr = {`OPC_MCCsi, tgt_gp, cc, 8'h00};
        step();
        expect_result(24'h000000, "MCCsi RA");
        expect_gp_we(1'b1, "MCCsi RA");
        expect_no_branch("MCCsi RA");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "MCCsi RA");

        // SHRsi with imm=0 leaves value and flags untouched
        pc = 48'h0110; opc = `OPC_SHRsi; root_opc = `OPC_SHRsi;
        instr = {`OPC_SHRsi, tgt_gp, 12'h000}; imm12_val = 12'h000;
        tgt_gp_val = 24'h123456;
        step();
        expect_result(24'h123456, "SHRsi amt0");
        expect_gp_we(1'b1, "SHRsi amt0");
        expect_no_branch("SHRsi amt0");
        expect_flags(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "SHRsi amt0");

        // SHRsi arithmetic shift right by 1 captures carry
        pc = 48'h0111; opc = `OPC_SHRsi; root_opc = `OPC_SHRsi;
        instr = {`OPC_SHRsi, tgt_gp, 12'h001}; imm12_val = 12'h001;
        tgt_gp_val = 24'h800001;
        step();
        expect_result(24'hC00000, "SHRsi amt1");
        expect_gp_we(1'b1, "SHRsi amt1");
        expect_no_branch("SHRsi amt1");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b1, 1'b0, "SHRsi amt1");

        // MCCsi BT should take when C=1
        pc = 48'h0112; opc = `OPC_MCCsi; root_opc = `OPC_MCCsi;
        cc = `CC_BT; instr = {`OPC_MCCsi, tgt_gp, cc, 8'h02};
        tgt_gp_val = 24'hDEAD00;
        step();
        expect_result(24'h000002, "MCCsi BT take");
        expect_gp_we(1'b1, "MCCsi BT take");
        expect_no_branch("MCCsi BT take");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "MCCsi BT take");

        // SHRsi with imm>=24 saturates to sign bits
        pc = 48'h0113; opc = `OPC_SHRsi; root_opc = `OPC_SHRsi;
        instr = {`OPC_SHRsi, tgt_gp, 12'd24}; imm12_val = 12'd24;
        tgt_gp_val = 24'h000100;
        step();
        expect_result(24'h000000, "SHRsi amt24");
        expect_gp_we(1'b1, "SHRsi amt24");
        expect_no_branch("SHRsi amt24");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "SHRsi amt24");

        // ADDsi basic positive addition
        pc = 48'h0120; opc = `OPC_ADDsi; root_opc = `OPC_ADDsi;
        instr = {`OPC_ADDsi, tgt_gp, 12'h002}; imm12_val = 12'h002;
        tgt_gp_val = 24'h000010;
        step();
        expect_result(24'h000012, "ADDsi basic");
        expect_gp_we(1'b1, "ADDsi basic");
        expect_no_branch("ADDsi basic");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "ADDsi basic");

        // ADDsi producing negative result (no overflow)
        pc = 48'h0121; opc = `OPC_ADDsi; root_opc = `OPC_ADDsi;
        instr = {`OPC_ADDsi, tgt_gp, 12'hF80}; imm12_val = 12'hF80;
        tgt_gp_val = 24'hFFFF00;
        step();
        expect_result(24'hFFFE80, "ADDsi neg");
        expect_gp_we(1'b1, "ADDsi neg");
        expect_no_branch("ADDsi neg");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, "ADDsi neg");

        // ADDsi overflow across signed positive range
        pc = 48'h0122; opc = `OPC_ADDsi; root_opc = `OPC_ADDsi;
        instr = {`OPC_ADDsi, tgt_gp, 12'h010}; imm12_val = 12'h010;
        tgt_gp_val = 24'h7FFFF0;
        step();
        expect_result(24'h800000, "ADDsi ovf");
        expect_gp_we(1'b1, "ADDsi ovf");
        expect_no_branch("ADDsi ovf");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, "ADDsi ovf");

        // ADDsiv without overflow behaves like ADDsi
        pc = 48'h0130; opc = `OPC_ADDsiv; root_opc = `OPC_ADDsiv;
        instr = {`OPC_ADDsiv, tgt_gp, 12'h001}; imm12_val = 12'h001;
        tgt_gp_val = 24'h000100;
        step();
        expect_result(24'h000101, "ADDsiv ok");
        expect_gp_we(1'b1, "ADDsiv ok");
        expect_no_branch("ADDsiv ok");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "ADDsiv ok");

        // ADDsiv overflow triggers trap and suppresses writeback
        pc = 48'h0200; opc = `OPC_ADDsiv; root_opc = `OPC_ADDsiv;
        instr = {`OPC_ADDsiv, tgt_gp, 12'h001}; imm12_val = 12'h001;
        tgt_gp_val = 24'h7FFFFF;
        step();
        expect_trap(`PSTATE_CAUSE_ARITH_OVF, TRAP_BASE, 48'h0201, "ADDsiv trap");
        // Clear pstate to baseline for subsequent tests
        pstate = 48'd0; pstate[`PSTATE_BIT_MODE] = 1'b1;
        // Drain pipeline after trap
        opc = `OPC_NOP; root_opc = `OPC_NOP; tgt_gp_we = 1'b0;
        step();
        tgt_gp_we = 1'b1;

        // SUBsi subtract positive immediate
        pc = 48'h0140; opc = `OPC_SUBsi; root_opc = `OPC_SUBsi;
        instr = {`OPC_SUBsi, tgt_gp, 12'h002}; imm12_val = 12'h002;
        tgt_gp_val = 24'h000010;
        step();
        expect_result(24'h00000E, "SUBsi basic");
        expect_gp_we(1'b1, "SUBsi basic");
        expect_no_branch("SUBsi basic");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "SUBsi basic");

        // SUBsi result negative without overflow
        pc = 48'h0141; opc = `OPC_SUBsi; root_opc = `OPC_SUBsi;
        instr = {`OPC_SUBsi, tgt_gp, 12'h002}; imm12_val = 12'h002;
        tgt_gp_val = 24'h000001;
        step();
        expect_result(24'hFFFFFF, "SUBsi neg");
        expect_gp_we(1'b1, "SUBsi neg");
        expect_no_branch("SUBsi neg");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, "SUBsi neg");

        // SUBsi overflow when subtracting negative immediate
        pc = 48'h0142; opc = `OPC_SUBsi; root_opc = `OPC_SUBsi;
        instr = {`OPC_SUBsi, tgt_gp, 12'hFFF}; imm12_val = 12'hFFF;
        tgt_gp_val = 24'h7FFFFF;
        step();
        expect_result(24'h800000, "SUBsi ovf");
        expect_gp_we(1'b1, "SUBsi ovf");
        expect_no_branch("SUBsi ovf");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, "SUBsi ovf");

        // SUBsiv without overflow behaves like SUBsi
        pc = 48'h0150; opc = `OPC_SUBsiv; root_opc = `OPC_SUBsiv;
        instr = {`OPC_SUBsiv, tgt_gp, 12'h001}; imm12_val = 12'h001;
        tgt_gp_val = 24'h000010;
        step();
        expect_result(24'h00000F, "SUBsiv ok");
        expect_gp_we(1'b1, "SUBsiv ok");
        expect_no_branch("SUBsiv ok");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "SUBsiv ok");

        // SUBsiv overflow triggers ARITH_OVF trap
        pc = 48'h0300; opc = `OPC_SUBsiv; root_opc = `OPC_SUBsiv;
        instr = {`OPC_SUBsiv, tgt_gp, 12'h001}; imm12_val = 12'h001;
        tgt_gp_val = 24'h800000;
        step();
        expect_trap(`PSTATE_CAUSE_ARITH_OVF, TRAP_BASE, 48'h0301, "SUBsiv trap");
        pstate = 48'd0; pstate[`PSTATE_BIT_MODE] = 1'b1;
        opc = `OPC_NOP; root_opc = `OPC_NOP; tgt_gp_we = 1'b0;
        step();
        tgt_gp_we = 1'b1;

        // SHRsiv valid shift mirrors SHRsi behavior
        pc = 48'h0160; opc = `OPC_SHRsiv; root_opc = `OPC_SHRsiv;
        instr = {`OPC_SHRsiv, tgt_gp, 12'h001}; imm12_val = 12'h001;
        tgt_gp_val = 24'hFFFF00;
        step();
        expect_result(24'hFFFF80, "SHRsiv amt1");
        expect_gp_we(1'b1, "SHRsiv amt1");
        expect_no_branch("SHRsiv amt1");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, "SHRsiv amt1");

        // SHRsiv with shift amount 0 leaves state untouched
        pc = 48'h0161; opc = `OPC_SHRsiv; root_opc = `OPC_SHRsiv;
        instr = {`OPC_SHRsiv, tgt_gp, 12'h000}; imm12_val = 12'h000;
        tgt_gp_val = 24'hABCD01;
        step();
        expect_result(24'hABCD01, "SHRsiv amt0");
        expect_gp_we(1'b1, "SHRsiv amt0");
        expect_no_branch("SHRsiv amt0");
        expect_flags(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "SHRsiv amt0");

        // SHRsiv imm>=24 raises ARITH_RANGE trap
        pc = 48'h0400; opc = `OPC_SHRsiv; root_opc = `OPC_SHRsiv;
        instr = {`OPC_SHRsiv, tgt_gp, 12'd24}; imm12_val = 12'd24;
        tgt_gp_val = 24'h123456;
        step();
        expect_trap(`PSTATE_CAUSE_ARITH_RANGE, TRAP_BASE, 48'h0401, "SHRsiv trap");
        pstate = 48'd0; pstate[`PSTATE_BIT_MODE] = 1'b1;
        opc = `OPC_NOP; root_opc = `OPC_NOP; tgt_gp_we = 1'b0;
        step();
        tgt_gp_we = 1'b1;

        // CMPsi equality => Z=1
        pc = 48'h0170; opc = `OPC_CMPsi; root_opc = `OPC_CMPsi;
        instr = {`OPC_CMPsi, tgt_gp, 12'h123}; imm12_val = 12'h123;
        tgt_gp_val = 24'h000123; tgt_gp_we = 1'b0;
        step();
        expect_gp_we(1'b0, "CMPsi eq");
        expect_no_branch("CMPsi eq");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "CMPsi eq");

        // CMPsi negative difference => N=1
        pc = 48'h0171; opc = `OPC_CMPsi; root_opc = `OPC_CMPsi;
        instr = {`OPC_CMPsi, tgt_gp, 12'h010}; imm12_val = 12'h010;
        tgt_gp_val = 24'hFFFF00;
        step();
        expect_gp_we(1'b0, "CMPsi neg");
        expect_no_branch("CMPsi neg");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, "CMPsi neg");

        // CMPsi overflow case => V=1 when positive - (-1)
        pc = 48'h0172; opc = `OPC_CMPsi; root_opc = `OPC_CMPsi;
        instr = {`OPC_CMPsi, tgt_gp, 12'hFFF}; imm12_val = 12'hFFF;
        tgt_gp_val = 24'h7FFFFF;
        step();
        expect_gp_we(1'b0, "CMPsi ovf");
        expect_no_branch("CMPsi ovf");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, "CMPsi ovf");
        tgt_gp_we = 1'b1;

        $display("opclass3_ex_tb PASS");
        $finish;
    end
endmodule
