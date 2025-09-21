
`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/pstate.vh"
`include "src/sr.vh"

module opclass1_ex_tb;
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
    reg  [`HBIT_ADDR:0]    pstate;

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

    task automatic step;
        begin @(posedge clk); @(posedge clk); end
    endtask

    task automatic expect_flags;
        input        expect_we;
        input        exp_z;
        input        exp_n;
        input        exp_c;
        input        exp_v;
        input [127:0] label;
        if (expect_we) begin
            if (sr_aux_we !== 1'b1) begin
                $display("FAIL (%s): expected flag update", label);
                $fatal;
            end
            if (sr_aux_addr !== `SR_IDX_PSTATE) begin
                $display("FAIL (%s): PSTATE addr mismatch %0d", label, sr_aux_addr);
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
                $display("FAIL (%s): unexpected flag update", label);
                $fatal;
            end
        end
    endtask

    task automatic expect_result;
        input [23:0] expected;
        input [127:0] label;
        if (ex_result !== expected) begin
            $display("FAIL (%s): result %h expected %h", label, ex_result, expected);
            $fatal;
        end
    endtask

    task automatic expect_gp_we;
        input        expected;
        input [127:0] label;
        if (ex_tgt_gp_we !== expected) begin
            $display("FAIL (%s): GP write enable %b expected %b", label, ex_tgt_gp_we, expected);
            $fatal;
        end
    endtask

    task automatic expect_no_branch;
        input [127:0] label;
        if (ex_branch_taken !== 1'b0 || ex_trap_pending !== 1'b0) begin
            $display("FAIL (%s): branch=%b trap=%b", label, ex_branch_taken, ex_trap_pending);
            $fatal;
        end
    endtask

    task automatic expect_trap;
        input [7:0]  exp_cause;
        input [47:0] exp_pc;
        input [47:0] exp_lr;
        input [127:0] label;
        if (ex_branch_taken !== 1'b1 || ex_trap_pending !== 1'b1) begin
            $display("FAIL (%s): trap not taken branch=%b trap=%b", label, ex_branch_taken, ex_trap_pending);
            $fatal;
        end
        if (ex_branch_pc !== exp_pc) begin
            $display("FAIL (%s): trap PC %h expected %h", label, ex_branch_pc, exp_pc);
            $fatal;
        end
        if (ex_tgt_sr_we !== 1'b1 || ex_tgt_sr !== `SR_IDX_LR) begin
            $display("FAIL (%s): LR write missing", label);
            $fatal;
        end
        if (ex_sr_result !== exp_lr) begin
            $display("FAIL (%s): LR value %h expected %h", label, ex_sr_result, exp_lr);
            $fatal;
        end
        if (sr_aux_we !== 1'b1 || sr_aux_addr !== `SR_IDX_PSTATE) begin
            $display("FAIL (%s): trap PSTATE update missing", label);
            $fatal;
        end
        if (sr_aux_result[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO] !== exp_cause) begin
            $display("FAIL (%s): trap cause %02h expected %02h", label,
                     sr_aux_result[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO], exp_cause);
            $fatal;
        end
    endtask

    task automatic expect_branch;
        input [47:0] exp_pc;
        input [127:0] label;
        if (ex_branch_taken !== 1'b1 || ex_trap_pending !== 1'b0) begin
            $display("FAIL (%s): branch=%b trap=%b", label, ex_branch_taken, ex_trap_pending);
            $fatal;
        end
        if (ex_branch_pc !== exp_pc) begin
            $display("FAIL (%s): branch PC %h expected %h", label, ex_branch_pc, exp_pc);
            $fatal;
        end
    endtask

    task automatic set_uimm_bank;
        input [1:0]  bank_sel;
        input [11:0] val;
        reg saved_we;
        begin
            saved_we = tgt_gp_we;
            opc = `OPC_LUIui;
            root_opc = `OPC_LUIui;
            instr = {`OPC_LUIui, bank_sel[1:0], 2'b00, val};
            imm12_val = val;
            tgt_gp_we = 1'b0;
            step();
            tgt_gp_we = saved_we;
        end
    endtask

    task automatic program_trap_base;
        input [47:0] base;
        begin
            set_uimm_bank(2'b10, base[47:36]);
            set_uimm_bank(2'b01, base[35:24]);
            set_uimm_bank(2'b00, base[23:12]);
        end
    endtask

    task automatic drain_trap;
        begin
            opc = `OPC_NOP;
            root_opc = `OPC_NOP;
            instr = {`OPC_NOP, 16'd0};
            tgt_gp_we = 1'b0;
            step();
            tgt_gp_we = 1'b1;
        end
    endtask

    always #5 clk = ~clk;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pstate <= {(`HBIT_ADDR+1){1'b0}};
        end else begin
            if (sr_aux_we)
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
        sgn_en = 1'b0;
        imm_en = 1'b0;
        imm14_val = '0;
        imm12_val = '0;
        imm10_val = '0;
        imm16_val = '0;
        cc = `CC_RA;
        tgt_gp = 4'd0;
        tgt_gp_we = 1'b1;
        tgt_sr = `SR_IDX_FL;
        tgt_sr_we = 1'b0;
        src_gp = 4'd0;
        src_ar = 2'd0;
        src_sr = `SR_IDX_FL;
        tgt_ar = 2'd0;
        src_gp_val = 24'd0;
        tgt_gp_val = 24'd0;
        src_ar_val = 48'd0;
        tgt_ar_val = 48'd0;
        tgt_sr_val = 48'd0;
        flush = 1'b0;
        stall = 1'b0;
        mode_kernel = 1'b0;
        cr_s_base = 48'd0; cr_s_len = 48'd0; cr_s_cur = 48'd0;
        cr_s_perms = 24'd0; cr_s_attr = 24'd0; cr_s_tag = 1'b0;
        cr_t_base = 48'd0; cr_t_len = 48'd0; cr_t_cur = 48'd0;
        cr_t_perms = 24'd0; cr_t_attr = 24'd0; cr_t_tag = 1'b0;

        #40 rst = 1'b0;

        // MOVui without valid uimm bank -> UIMM_STATE trap
        pc = 48'h0040;
        opc = `OPC_MOVui; root_opc = `OPC_MOVui;
        imm12_val = 12'h123;
        tgt_gp_val = 24'hDEADBE;
        step();
        expect_trap(`PSTATE_CAUSE_UIMM_STATE, 48'h0, 48'h0041, "MOVui missing uimm");
        expect_gp_we(1'b0, "MOVui missing uimm");
        drain_trap();

        // Program bank0=0xABC for subsequent immediates
        set_uimm_bank(2'b00, 12'hABC);

        // MOVui successful path
        opc = `OPC_MOVui; root_opc = `OPC_MOVui;
        imm12_val = 12'h123; tgt_gp_val = 24'h0;
        step();
        expect_result(24'hABC123, "MOVui value");
        expect_gp_we(1'b1, "MOVui value");
        expect_no_branch("MOVui value");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "MOVui value");

        // MOVui producing zero updates Z
        set_uimm_bank(2'b00, 12'h000);
        opc = `OPC_MOVui; root_opc = `OPC_MOVui;
        imm12_val = 12'h000; tgt_gp_val = 24'hFFFF00;
        step();
        expect_result(24'h000000, "MOVui zero");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "MOVui zero");

        // ADDui with carry wrap
        set_uimm_bank(2'b00, 12'h000);
        opc = `OPC_ADDui; root_opc = `OPC_ADDui;
        imm12_val = 12'h001; tgt_gp_val = 24'hFFFFFF;
        step();
        expect_result(24'h000000, "ADDui wrap");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b1, 1'b0, "ADDui wrap");

        // SUBui borrow
        opc = `OPC_SUBui; root_opc = `OPC_SUBui;
        imm12_val = 12'h001; tgt_gp_val = 24'h000000;
        step();
        expect_result(24'hFFFFFF, "SUBui borrow");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, "SUBui borrow");

        // ANDui mask
        set_uimm_bank(2'b00, 12'h00F);
        opc = `OPC_ANDui; root_opc = `OPC_ANDui;
        imm12_val = 12'h0F0; tgt_gp_val = 24'hFF00FF;
        step();
        expect_result(24'h0000F0, "ANDui mask");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "ANDui mask");

        // ORui combine
        set_uimm_bank(2'b00, 12'h000);
        opc = `OPC_ORui; root_opc = `OPC_ORui;
        imm12_val = 12'h00F; tgt_gp_val = 24'h000F00;
        step();
        expect_result(24'h000F0F, "ORui combine");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "ORui combine");

        // XORui toggle bits
        set_uimm_bank(2'b00, 12'h000);
        opc = `OPC_XORui; root_opc = `OPC_XORui;
        imm12_val = 12'h0F0; tgt_gp_val = 24'h00F0F0;
        step();
        expect_result(24'h00F000, "XORui toggle");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "XORui toggle");

        // SHLui amount 0 keeps value
        set_uimm_bank(2'b00, 12'h000);
        opc = `OPC_SHLui; root_opc = `OPC_SHLui;
        imm12_val = 12'h000; tgt_gp_val = 24'h123456;
        step();
        expect_result(24'h123456, "SHLui amt0");
        expect_flags(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "SHLui amt0");

        // SHLui amount 1 updates carry
        imm12_val = 12'h001; tgt_gp_val = 24'h800001;
        step();
        expect_result(24'h000002, "SHLui amt1");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, "SHLui amt1");

        // SHLui amount 24 clamps to zero with Z=1, C=0
        imm12_val = 12'd24; tgt_gp_val = 24'h123456;
        step();
        expect_result(24'h000000, "SHLui amt24");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "SHLui amt24");

        // SHLuiv in-range amount 3
        imm12_val = 12'd3; opc = `OPC_SHLuiv; root_opc = `OPC_SHLuiv;
        tgt_gp_val = 24'h000101;
        step();
        expect_result(24'h000808, "SHLuiv amt3");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "SHLuiv amt3");

        // SHLuiv range trap with programmed base 0x001234560000
        program_trap_base(48'h001234_560000);
        opc = `OPC_SHLuiv; root_opc = `OPC_SHLuiv;
        imm12_val = 12'd24; tgt_gp_val = 24'hABCDEF; pc = 48'h100;
        step();
        expect_trap(`PSTATE_CAUSE_ARITH_RANGE, 48'h001234_560000, 48'h101, "SHLuiv trap");
        expect_gp_we(1'b0, "SHLuiv trap");
        drain_trap();

        // SHRui amount 0 no flags
        set_uimm_bank(2'b00, 12'h000);
        opc = `OPC_SHRui; root_opc = `OPC_SHRui;
        imm12_val = 12'd0; tgt_gp_val = 24'h00F000;
        step();
        expect_result(24'h00F000, "SHRui amt0");
        expect_flags(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "SHRui amt0");

        // SHRui amount 1 updates carry
        imm12_val = 12'd1; tgt_gp_val = 24'h000303;
        step();
        expect_result(24'h000181, "SHRui amt1");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, "SHRui amt1");

        // SHRui amount 24 clamps to zero
        imm12_val = 12'd24; tgt_gp_val = 24'h123456;
        step();
        expect_result(24'h000000, "SHRui amt24");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "SHRui amt24");

        // SHRuiv in-range amount 4
        set_uimm_bank(2'b00, 12'h000);
        opc = `OPC_SHRuiv; root_opc = `OPC_SHRuiv;
        imm12_val = 12'd4; tgt_gp_val = 24'hFF0000;
        step();
        expect_result(24'h0FF000, "SHRuiv amt4");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "SHRuiv amt4");

        // SHRuiv trap with base 0x002345670000
        program_trap_base(48'h002345_670000);
        opc = `OPC_SHRuiv; root_opc = `OPC_SHRuiv;
        imm12_val = 12'd24; tgt_gp_val = 24'h010101; pc = 48'h200;
        step();
        expect_trap(`PSTATE_CAUSE_ARITH_RANGE, 48'h002345_670000, 48'h201, "SHRuiv trap");
        expect_gp_we(1'b0, "SHRuiv trap");
        drain_trap();

        // ROLui amount 0 keeps value
        set_uimm_bank(2'b00, 12'h000);
        opc = `OPC_ROLui; root_opc = `OPC_ROLui;
        imm12_val = 12'd0; tgt_gp_val = 24'h010203;
        step();
        expect_result(24'h010203, "ROLui amt0");
        expect_flags(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "ROLui amt0");

        // ROLui amount 1 rotates MSB into LSB
        imm12_val = 12'd1; tgt_gp_val = 24'h800001;
        step();
        expect_result(24'h000003, "ROLui amt1");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, "ROLui amt1");

        // ROLui amount 25 (effective 1) keeps C=0 for value without high bit
        imm12_val = 12'd25; tgt_gp_val = 24'h012345;
        step();
        expect_result(24'h02468A, "ROLui amt25");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "ROLui amt25");

        // RORui amount 0 keeps value
        opc = `OPC_RORui; root_opc = `OPC_RORui;
        imm12_val = 12'd0; tgt_gp_val = 24'h00C000;
        step();
        expect_result(24'h00C000, "RORui amt0");
        expect_flags(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "RORui amt0");

        // RORui amount 1 rotates LSB into MSB
        imm12_val = 12'd1; tgt_gp_val = 24'h000001;
        step();
        expect_result(24'h800000, "RORui amt1");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, "RORui amt1");

        // RORui amount 5 pattern rotate
        imm12_val = 12'd5; tgt_gp_val = 24'hABCDE0;
        step();
        expect_result(24'h055E6F, "RORui amt5");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "RORui amt5");

        // CMPui equal -> Z=1, C=0 and no GP write
        set_uimm_bank(2'b00, 12'h123);
        tgt_gp_we = 1'b0;
        opc = `OPC_CMPui; root_opc = `OPC_CMPui;
        imm12_val = 12'h456; tgt_gp_val = 24'h123456;
        step();
        expect_gp_we(1'b0, "CMPui eq");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "CMPui eq");

        // CMPui target < imm -> C=1
        set_uimm_bank(2'b00, 12'h000);
        opc = `OPC_CMPui; root_opc = `OPC_CMPui;
        imm12_val = 12'h002; tgt_gp_val = 24'h000001;
        step();
        expect_flags(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, "CMPui lt");
        tgt_gp_we = 1'b1;

        // JCCui absolute branch with valid banks
        program_trap_base(48'h012345_678000);
        set_uimm_bank(2'b00, 12'h678);
        tgt_gp_we = 1'b0;
        opc = `OPC_JCCui; root_opc = `OPC_JCCui;
        cc = `CC_RA; imm12_val = 12'h9AB; pc = 48'h300;
        step();
        expect_branch(48'h012345_6789AB, "JCCui branch");
        tgt_gp_we = 1'b1;

        // JCCui with invalid uimm banks branches to vector base (no trap flag)
        flush = 1'b1; step(); flush = 1'b0;
        opc = `OPC_JCCui; root_opc = `OPC_JCCui;
        cc = `CC_RA; imm12_val = 12'h111; pc = 48'h400;
        step();
        expect_branch(48'h0, "JCCui missing banks");
        expect_gp_we(1'b0, "JCCui missing banks");
        drain_trap();

        $display("opclass1_ex_tb PASS");
        $finish;
    end
endmodule
