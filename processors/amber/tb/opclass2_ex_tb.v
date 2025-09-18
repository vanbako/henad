`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/flags.vh"
`include "src/pstate.vh"
`include "src/sr.vh"

module opclass2_ex_tb;
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
    reg  [`HBIT_ADDR:0]    src_sr_val;
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

    task automatic expect_no_trap;
        input [127:0] label;
        if (ex_branch_taken !== 1'b0 || ex_trap_pending !== 1'b0) begin
            $display("FAIL (%s): branch=%b trap=%b", label, ex_branch_taken, ex_trap_pending);
            $fatal;
        end
    endtask

    task automatic expect_trap;
        input [7:0]    cause;
        input [47:0]   exp_lr;
        input [127:0]  label;
        if (ex_branch_taken !== 1'b1 || ex_trap_pending !== 1'b1) begin
            $display("FAIL (%s): trap not taken branch=%b trap=%b", label, ex_branch_taken, ex_trap_pending);
            $fatal;
        end
        if (ex_tgt_gp_we !== 1'b0) begin
            $display("FAIL (%s): trap should suppress GP write", label);
            $fatal;
        end
        if (sr_aux_we !== 1'b1 || sr_aux_addr !== `SR_IDX_PSTATE) begin
            $display("FAIL (%s): trap PSTATE update missing", label);
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
        if (ex_sr_result !== exp_lr) begin
            $display("FAIL (%s): LR value %h expected %h", label, ex_sr_result, exp_lr);
            $fatal;
        end
    endtask

    always #5 clk = ~clk;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pstate <= {(`HBIT_ADDR+1){1'b0}};
        end else if (sr_aux_we) begin
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
        src_sr = `SR_IDX_PSTATE;
        tgt_ar = 2'd0;
        src_gp_val = 24'd0;
        tgt_gp_val = 24'd0;
        src_ar_val = 48'd0;
        tgt_ar_val = 48'd0;
        src_sr_val = 48'd0;
        tgt_sr_val = 48'd0;
        flush = 1'b0;
        stall = 1'b0;
        mode_kernel = 1'b1;
        cr_s_base = 48'd0; cr_s_len = 48'd0; cr_s_cur = 48'd0;
        cr_s_perms = 24'd0; cr_s_attr = 24'd0; cr_s_tag = 1'b0;
        cr_t_base = 48'd0; cr_t_len = 48'd0; cr_t_cur = 48'd0;
        cr_t_perms = 24'd0; cr_t_attr = 24'd0; cr_t_tag = 1'b0;
        pstate = 48'd0;

        #40 rst = 1'b0;

        // ADDsr basic positive case
        pc = 48'h0010; instr = {`OPC_ADDsr, 16'h0000};
        opc = `OPC_ADDsr; root_opc = `OPC_ADDsr;
        tgt_gp_val = 24'h000003; src_gp_val = 24'h000002;
        step();
        expect_result(24'h000005, "ADDsr+" );
        expect_gp_we(1'b1, "ADDsr+" );
        expect_no_trap("ADDsr+");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "ADDsr+");

        // ADDsr cancel to zero => Z=1
        pc = 48'h0011; tgt_gp_val = 24'h000001; src_gp_val = 24'hFFFFFF;
        step();
        expect_result(24'h000000, "ADDsr zero");
        expect_no_trap("ADDsr zero");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "ADDsr zero");

        // ADDsr overflow: two positives -> negative result, V=1
        pc = 48'h0012; tgt_gp_val = 24'h400000; src_gp_val = 24'h400000;
        step();
        expect_result(24'h800000, "ADDsr ovf");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, "ADDsr ovf");

        // ADDsv no trap
        pc = 48'h0020; instr = {`OPC_ADDsv, 16'h0000};
        opc = `OPC_ADDsv; root_opc = `OPC_ADDsv;
        tgt_gp_val = 24'h7FFFFE; src_gp_val = 24'h000001;
        step();
        expect_result(24'h7FFFFF, "ADDsv ok");
        expect_gp_we(1'b1, "ADDsv ok");
        expect_no_trap("ADDsv ok");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "ADDsv ok");

        // ADDsv overflow trap suppresses write
        pc = 48'h00A0; tgt_gp_val = 24'h7FFFFF; src_gp_val = 24'h000001;
        step();
        expect_trap(`PSTATE_CAUSE_ARITH_OVF, 48'h00A1, "ADDsv trap");

        // SUBsr subtract positive -> positive
        pc = 48'h0030; instr = {`OPC_SUBsr, 16'h0000};
        opc = `OPC_SUBsr; root_opc = `OPC_SUBsr;
        tgt_gp_val = 24'h000007; src_gp_val = 24'h000002;
        step();
        expect_result(24'h000005, "SUBsr+");
        expect_no_trap("SUBsr+");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "SUBsr+");

        // SUBsr subtraction to zero
        pc = 48'h0031; tgt_gp_val = 24'h000001; src_gp_val = 24'h000001;
        step();
        expect_result(24'h000000, "SUBsr zero");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "SUBsr zero");

        // SUBsr overflow: (-2^23) - 1 => positive result with V=1
        pc = 48'h0032; tgt_gp_val = 24'h800000; src_gp_val = 24'h000001;
        step();
        expect_result(24'h7FFFFF, "SUBsr ovf");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b1, "SUBsr ovf");

        // SUBsv no trap
        pc = 48'h0040; instr = {`OPC_SUBsv, 16'h0000};
        opc = `OPC_SUBsv; root_opc = `OPC_SUBsv;
        tgt_gp_val = 24'h000005; src_gp_val = 24'h000003;
        step();
        expect_result(24'h000002, "SUBsv ok");
        expect_no_trap("SUBsv ok");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "SUBsv ok");

        // SUBsv overflow trap
        pc = 48'h00B0; tgt_gp_val = 24'h800000; src_gp_val = 24'h000001;
        step();
        expect_trap(`PSTATE_CAUSE_ARITH_OVF, 48'h00B1, "SUBsv trap");

        // NEGsr basic negative
        pc = 48'h0050; instr = {`OPC_NEGsr, 16'h0000};
        opc = `OPC_NEGsr; root_opc = `OPC_NEGsr;
        tgt_gp_val = 24'h000005;
        step();
        expect_result(24'hFFFFFB, "NEGsr 5");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, "NEGsr 5");

        // NEGsr zero operand
        pc = 48'h0051; tgt_gp_val = 24'h000000;
        step();
        expect_result(24'h000000, "NEGsr zero");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "NEGsr zero");

        // NEGsr overflow when negating INT24_MIN
        pc = 48'h0052; tgt_gp_val = 24'h800000;
        step();
        expect_result(24'h800000, "NEGsr ovf");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b1, "NEGsr ovf");

        // NEGsv normal case
        pc = 48'h0060; instr = {`OPC_NEGsv, 16'h0000};
        opc = `OPC_NEGsv; root_opc = `OPC_NEGsv;
        tgt_gp_val = 24'h000002;
        step();
        expect_result(24'hFFFFFE, "NEGsv ok");
        expect_no_trap("NEGsv ok");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, "NEGsv ok");

        // NEGsv overflow trap
        pc = 48'h00C0; tgt_gp_val = 24'h800000;
        step();
        expect_trap(`PSTATE_CAUSE_ARITH_OVF, 48'h00C1, "NEGsv trap");

        // SHRsr shift by zero leaves flags untouched
        pc = 48'h0070; instr = {`OPC_SHRsr, 16'h0000};
        opc = `OPC_SHRsr; root_opc = `OPC_SHRsr;
        tgt_gp_val = 24'h123456; src_gp_val = 24'h000000;
        step();
        expect_result(24'h123456, "SHRsr n0");
        expect_gp_we(1'b1, "SHRsr n0");
        expect_no_trap("SHRsr n0");
        expect_flags(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "SHRsr n0");

        // SHRsr shift by one: positive operand gives C=1 from LSB
        pc = 48'h0071; tgt_gp_val = 24'h000005; src_gp_val = 24'h000001;
        step();
        expect_result(24'h000002, "SHRsr pos");
        expect_flags(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, "SHRsr pos");

        // SHRsr shift by one on negative keeps sign and sets C from LSB
        pc = 48'h0072; tgt_gp_val = 24'h800003; src_gp_val = 24'h000001;
        step();
        expect_result(24'hC00001, "SHRsr neg");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b1, 1'b0, "SHRsr neg");

        // SHRsr shift amount >= 24 saturates to sign, C cleared
        pc = 48'h0073; tgt_gp_val = 24'h7FFFFF; src_gp_val = 24'h000018;
        step();
        expect_result(24'h000000, "SHRsr wide");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "SHRsr wide");

        // SHRsrv in range behaves like SHRsr
        pc = 48'h0080; instr = {`OPC_SHRsrv, 16'h0000};
        opc = `OPC_SHRsrv; root_opc = `OPC_SHRsrv;
        tgt_gp_val = 24'h800003; src_gp_val = 24'h000001;
        step();
        expect_result(24'hC00001, "SHRsrv ok");
        expect_no_trap("SHRsrv ok");
        expect_flags(1'b1, 1'b0, 1'b1, 1'b1, 1'b0, "SHRsrv ok");

        // SHRsrv trap when shift count >= 24
        pc = 48'h00D0; tgt_gp_val = 24'h0000FF; src_gp_val = 24'h000018;
        step();
        expect_trap(`PSTATE_CAUSE_ARITH_RANGE, 48'h00D1, "SHRsrv trap");

        // CMPsr equality => Z=1
        pc = 48'h0090; instr = {`OPC_CMPsr, 16'h0000};
        opc = `OPC_CMPsr; root_opc = `OPC_CMPsr;
        tgt_gp_val = 24'h123456; src_gp_val = 24'h123456; tgt_gp_we = 1'b0;
        step();
        expect_gp_we(1'b0, "CMPsr eq");
        expect_no_trap("CMPsr eq");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "CMPsr eq");

        // CMPsr negative difference => N=1
        pc = 48'h0091; tgt_gp_val = 24'h000001; src_gp_val = 24'h000003;
        step();
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, "CMPsr neg");

        // CMPsr overflow scenario => V=1
        pc = 48'h0092; tgt_gp_val = 24'h000001; src_gp_val = 24'hFFFFFF;
        step();
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b1, "CMPsr ovf");

        // Restore GP write enable for remaining operations
        tgt_gp_we = 1'b1;

        // TSTsr zero => Z=1
        pc = 48'h0093; instr = {`OPC_TSTsr, 16'h0000};
        opc = `OPC_TSTsr; root_opc = `OPC_TSTsr;
        tgt_gp_val = 24'h000000;
        step();
        expect_no_trap("TSTsr zero");
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "TSTsr zero");

        // TSTsr negative value => N=1
        pc = 48'h0094; tgt_gp_val = 24'h800001;
        step();
        expect_flags(1'b1, 1'b0, 1'b1, 1'b0, 1'b0, "TSTsr neg");

        $display("opclass2_ex_tb PASS");
        $finish;
    end
endmodule
