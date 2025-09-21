`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/cr.vh"
`include "src/pstate.vh"

module opclass5_ex_tb;
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
    wire                   sr_aux_we;
    wire [`HBIT_TGT_SR:0]  sr_aux_addr;
    wire [`HBIT_ADDR:0]    sr_aux_result;
    wire                   branch_taken;
    wire [`HBIT_ADDR:0]    branch_pc;
    wire                   trap_pending;
    wire                   halt;
    reg  [`HBIT_DATA:0]    src_gp_val;
    reg  [`HBIT_DATA:0]    tgt_gp_val;
    reg  [`HBIT_ADDR:0]    src_ar_val;
    reg  [`HBIT_ADDR:0]    tgt_ar_val;
    reg  [`HBIT_ADDR:0]    src_sr_val;
    reg  [`HBIT_ADDR:0]    tgt_sr_val;
    reg                    flush;
    reg                    stall;
    reg                    mode_kernel;
    reg  [`HBIT_ADDR:0]    pstate;

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
        .ow_branch_taken(branch_taken),
        .ow_branch_pc(branch_pc),
        .ow_trap_pending(trap_pending),
        .ow_halt(halt),
        .iw_src_gp_val(src_gp_val),
        .iw_tgt_gp_val(tgt_gp_val),
        .iw_src_ar_val(src_ar_val),
        .iw_tgt_ar_val(tgt_ar_val),
        .iw_src_sr_val(src_sr_val),
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

    localparam [23:0] PERM_SB = (24'd1 << `CR_PERM_SB_BIT);
    localparam [23:0] PERM_RW = (24'd1 << `CR_PERM_R_BIT) | (24'd1 << `CR_PERM_W_BIT);

    task automatic step;
        begin
            @(posedge clk);
            @(posedge clk);
        end
    endtask

    task automatic expect_no_trap(input string label);
        begin
            step();
            if (branch_taken) begin
                $display("FAIL (%s): unexpected branch/trap", label);
                $fatal;
            end
            if (trap_pending) begin
                $display("FAIL (%s): trap_pending asserted", label);
                $fatal;
            end
            if (halt) begin
                $display("FAIL (%s): halt asserted", label);
                $fatal;
            end
        end
    endtask

    task automatic expect_trap(input [7:0] cause, input string label);
        begin
            step();
            if (!branch_taken) begin
                $display("FAIL (%s): expected branch_taken on trap", label);
                $fatal;
            end
            if (!trap_pending) begin
                $display("FAIL (%s): trap_pending not asserted", label);
                $fatal;
            end
            if (halt) begin
                $display("FAIL (%s): halt asserted on trap", label);
                $fatal;
            end
            if (dut.r_trap_cause !== cause) begin
                $display("FAIL (%s): trap cause %02h != expected %02h", label, dut.r_trap_cause, cause);
                $fatal;
            end
        end
    endtask

    task automatic idle_cycle;
        begin
            opc = `OPC_NOP;
            root_opc = `OPC_NOP;
            tgt_gp_we = 1'b0;
            src_gp_val = 24'd0;
            imm14_val = 14'd0;
            step();
        end
    endtask

    task automatic set_cr_s(
        input [47:0] base,
        input [47:0] len,
        input [47:0] cur,
        input [23:0] perms,
        input [23:0] attr,
        input        tag
    );
        begin
            cr_s_base  = base;
            cr_s_len   = len;
            cr_s_cur   = cur;
            cr_s_perms = perms;
            cr_s_attr  = attr;
            cr_s_tag   = tag;
        end
    endtask

    task automatic set_cr_t(
        input [47:0] base,
        input [47:0] len,
        input [47:0] cur,
        input [23:0] perms,
        input [23:0] attr,
        input        tag
    );
        begin
            cr_t_base  = base;
            cr_t_len   = len;
            cr_t_cur   = cur;
            cr_t_perms = perms;
            cr_t_attr  = attr;
            cr_t_tag   = tag;
        end
    endtask

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        stall = 1'b0;
        flush = 1'b0;
        mode_kernel = 1'b1;
        pc = 48'h0000_0500;
        instr = 24'd0;
        opc = `OPC_NOP;
        root_opc = `OPC_NOP;
        sgn_en = 1'b1;
        imm_en = 1'b1;
        imm14_val = 14'd0;
        imm12_val = 12'd0;
        imm10_val = 10'd0;
        imm16_val = 16'd0;
        cc = `CC_RA;
        tgt_gp = 0;
        tgt_gp_we = 1'b0;
        tgt_sr = 0;
        tgt_sr_we = 1'b0;
        tgt_ar = 0;
        src_gp = 0;
        src_ar = 0;
        src_sr = 0;
        src_gp_val = 24'd0;
        tgt_gp_val = 24'd0;
        src_ar_val = 48'd0;
        tgt_ar_val = 48'd0;
        src_sr_val = 48'd0;
        tgt_sr_val = 48'd0;
        pstate = 48'd0;
        set_cr_s(48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b0);
        set_cr_t(48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b0);

        #12 rst = 1'b0;

        // CINC (reg) positive delta
        set_cr_t(48'd100, 48'd200, 48'd120, PERM_RW, 24'd0, 1'b1);
        tgt_ar = 2'b10;
        tgt_ar_val = 48'd120;
        src_gp_val = 24'd5;
        opc = `OPC_CINC;
        root_opc = `OPC_CINC;
        expect_no_trap("CINC +5");
        if (!cr_we_cur || (cr_cur !== 48'd125)) begin
            $display("FAIL: CINC +5 cursor %0d", cr_cur);
            $fatal;
        end
        if (!ex_tgt_ar_we || (ex_ar_result !== 48'd125)) begin
            $display("FAIL: CINC +5 ar_result %0d", ex_ar_result);
            $fatal;
        end
        if (cr_write_addr !== tgt_ar) begin
            $display("FAIL: CINC +5 write addr %0d", cr_write_addr);
            $fatal;
        end
        idle_cycle();

        // CINC (reg) negative delta in-bounds
        set_cr_t(48'd10, 48'd100, 48'd50, PERM_RW, 24'd0, 1'b1);
        tgt_ar = 2'b01;
        tgt_ar_val = 48'd50;
        src_gp_val = -24'sd10;
        opc = `OPC_CINC;
        root_opc = `OPC_CINC;
        expect_no_trap("CINC -10");
        if (!cr_we_cur || (cr_cur !== 48'd40)) begin
            $display("FAIL: CINC -10 cursor %0d", cr_cur);
            $fatal;
        end
        idle_cycle();

        // CINCv success at upper bound (base+len-1)
        set_cr_t(48'd0, 48'd50, 48'd20, PERM_RW, 24'd0, 1'b1);
        tgt_ar = 2'b11;
        tgt_ar_val = 48'd20;
        src_gp_val = 24'd29;
        opc = `OPC_CINCv;
        root_opc = `OPC_CINCv;
        expect_no_trap("CINCv upper bound");
        if (cr_cur !== 48'd49) begin
            $display("FAIL: CINCv upper bound cursor %0d", cr_cur);
            $fatal;
        end
        idle_cycle();

        // CINCv trap on upper overflow (== base+len)
        set_cr_t(48'd30, 48'd40, 48'd50, PERM_RW, 24'd0, 1'b1);
        tgt_ar = 2'b00;
        tgt_ar_val = 48'd50;
        src_gp_val = 24'd20;
        opc = `OPC_CINCv;
        root_opc = `OPC_CINCv;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "CINCv overflow");
        if (cr_we_cur || ex_tgt_ar_we) begin
            $display("FAIL: CINCv overflow wrote cursor");
            $fatal;
        end
        idle_cycle();

        // CINCv trap on lower underflow (< base)
        set_cr_t(48'd100, 48'd30, 48'd110, PERM_RW, 24'd0, 1'b1);
        tgt_ar = 2'b01;
        tgt_ar_val = 48'd110;
        src_gp_val = -24'sd20;
        opc = `OPC_CINCv;
        root_opc = `OPC_CINCv;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "CINCv underflow");
        idle_cycle();

        // CINCi immediate positive
        set_cr_t(48'd200, 48'd100, 48'd205, PERM_RW, 24'd0, 1'b1);
        tgt_ar = 2'b10;
        tgt_ar_val = 48'd205;
        imm14_val = 14'sd10;
        opc = `OPC_CINCi;
        root_opc = `OPC_CINCi;
        expect_no_trap("CINCi +10");
        if (cr_cur !== 48'd215) begin
            $display("FAIL: CINCi +10 cursor %0d", cr_cur);
            $fatal;
        end
        idle_cycle();

        // CINCiv immediate negative within bounds
        set_cr_t(48'd0, 48'd8192, 48'd4096, PERM_RW, 24'd0, 1'b1);
        tgt_ar = 2'b00;
        tgt_ar_val = 48'd4096;
        imm14_val = -14'sd4096;
        opc = `OPC_CINCiv;
        root_opc = `OPC_CINCiv;
        expect_no_trap("CINCiv -4096");
        if (cr_cur !== 48'd0) begin
            $display("FAIL: CINCiv -4096 cursor %0d", cr_cur);
            $fatal;
        end
        idle_cycle();

        // CINCiv trap out of upper bounds
        set_cr_t(48'd1000, 48'd100, 48'd1050, PERM_RW, 24'd0, 1'b1);
        tgt_ar = 2'b01;
        tgt_ar_val = 48'd1050;
        imm14_val = 14'sd60;
        opc = `OPC_CINCiv;
        root_opc = `OPC_CINCiv;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "CINCiv overflow");
        idle_cycle();

        // CMOV copies all fields
        set_cr_s(48'd500, 48'd64, 48'd520, PERM_SB | PERM_RW, 24'h00AA_FF, 1'b1);
        set_cr_t(48'd0, 48'd1, 48'd2, PERM_RW, 24'h0000_00, 1'b0);
        src_ar = 2'b01;
        tgt_ar = 2'b10;
        opc = `OPC_CMOV;
        root_opc = `OPC_CMOV;
        expect_no_trap("CMOV copy");
        if (!(cr_we_base && cr_we_len && cr_we_cur && cr_we_perms && cr_we_attr && cr_we_tag)) begin
            $display("FAIL: CMOV missing write enables");
            $fatal;
        end
        if ((cr_base !== 48'd500) || (cr_len !== 48'd64) || (cr_cur !== 48'd520)) begin
            $display("FAIL: CMOV base/len/cur %0d %0d %0d", cr_base, cr_len, cr_cur);
            $fatal;
        end
        if (cr_perms !== (PERM_SB | PERM_RW)) begin
            $display("FAIL: CMOV perms %06h", cr_perms);
            $fatal;
        end
        if (cr_attr !== 24'h00AA_FF || cr_tag !== 1'b1) begin
            $display("FAIL: CMOV attr/tag %06h %0d", cr_attr, cr_tag);
            $fatal;
        end
        idle_cycle();

        // CSETB (reg) success
        set_cr_s(48'd0, 48'd0, 48'd600, PERM_RW, 24'd0, 1'b1);
        set_cr_t(48'd400, 48'd30, 48'd610, PERM_SB | PERM_RW, 24'd0, 1'b1);
        src_ar = 2'b00;
        src_ar_val = 48'd600;
        tgt_ar = 2'b01;
        tgt_ar_val = 48'd610;
        src_gp_val = 24'd20;
        opc = `OPC_CSETB;
        root_opc = `OPC_CSETB;
        expect_no_trap("CSETB reg ok");
        if (!cr_we_base || !cr_we_len) begin
            $display("FAIL: CSETB reg missing writes");
            $fatal;
        end
        if (cr_base !== 48'd600 || cr_len !== 48'd20) begin
            $display("FAIL: CSETB reg base/len %0d %0d", cr_base, cr_len);
            $fatal;
        end
        if (cr_we_cur) begin
            $display("FAIL: CSETB reg should not write cur");
            $fatal;
        end
        idle_cycle();

        // CSETB missing SB permission -> trap CAP_PERM
        set_cr_s(48'd0, 48'd0, 48'd700, PERM_RW, 24'd0, 1'b1);
        set_cr_t(48'd100, 48'd10, 48'd705, PERM_RW, 24'd0, 1'b1);
        src_ar_val = 48'd700;
        tgt_ar = 2'b10;
        tgt_ar_val = 48'd705;
        src_gp_val = 24'd15;
        opc = `OPC_CSETB;
        root_opc = `OPC_CSETB;
        expect_trap(`PSTATE_CAUSE_CAP_PERM, "CSETB perm trap");
        if (cr_we_base || cr_we_len) begin
            $display("FAIL: CSETB perm trap wrote bounds");
            $fatal;
        end
        idle_cycle();

        // CSETBv reg success with cursor inside new bounds
        set_cr_s(48'd0, 48'd0, 48'd800, PERM_RW, 24'd0, 1'b1);
        set_cr_t(48'd750, 48'd40, 48'd805, PERM_SB | PERM_RW, 24'd0, 1'b1);
        src_ar_val = 48'd800;
        tgt_ar = 2'b00;
        tgt_ar_val = 48'd805;
        src_gp_val = 24'd32;
        opc = `OPC_CSETBv;
        root_opc = `OPC_CSETBv;
        expect_no_trap("CSETBv reg ok");
        if (cr_base !== 48'd800 || cr_len !== 48'd32) begin
            $display("FAIL: CSETBv reg base/len %0d %0d", cr_base, cr_len);
            $fatal;
        end
        idle_cycle();

        // CSETBv reg trap on len <= 0 -> CAP_CFG
        set_cr_s(48'd0, 48'd0, 48'd820, PERM_RW, 24'd0, 1'b1);
        set_cr_t(48'd810, 48'd5, 48'd815, PERM_SB | PERM_RW, 24'd0, 1'b1);
        src_ar_val = 48'd820;
        tgt_ar = 2'b01;
        tgt_ar_val = 48'd815;
        src_gp_val = 24'd0;
        opc = `OPC_CSETBv;
        root_opc = `OPC_CSETBv;
        expect_trap(`PSTATE_CAUSE_CAP_CFG, "CSETBv zero len");
        idle_cycle();

        // CSETBv reg trap on cursor outside new bounds -> CAP_OOB
        set_cr_s(48'd0, 48'd0, 48'd830, PERM_RW, 24'd0, 1'b1);
        set_cr_t(48'd820, 48'd10, 48'd825, PERM_SB | PERM_RW, 24'd0, 1'b1);
        src_ar_val = 48'd700;
        tgt_ar = 2'b10;
        tgt_ar_val = 48'd825;
        src_gp_val = 24'd12;
        opc = `OPC_CSETBv;
        root_opc = `OPC_CSETBv;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "CSETBv cursor OOB");
        idle_cycle();

        // CSETBi immediate success
        set_cr_s(48'd0, 48'd0, 48'd900, PERM_RW, 24'd0, 1'b1);
        set_cr_t(48'd850, 48'd30, 48'd905, PERM_SB | PERM_RW, 24'd0, 1'b1);
        src_ar_val = 48'd900;
        tgt_ar = 2'b11;
        tgt_ar_val = 48'd905;
        imm14_val = 14'sd40;
        opc = `OPC_CSETBi;
        root_opc = `OPC_CSETBi;
        expect_no_trap("CSETBi ok");
        if (cr_base !== 48'd900 || cr_len !== 48'd40) begin
            $display("FAIL: CSETBi base/len %0d %0d", cr_base, cr_len);
            $fatal;
        end
        idle_cycle();

        // CSETBiv immediate success
        set_cr_s(48'd0, 48'd0, 48'd950, PERM_RW, 24'd0, 1'b1);
        set_cr_t(48'd940, 48'd20, 48'd952, PERM_SB | PERM_RW, 24'd0, 1'b1);
        src_ar_val = 48'd950;
        tgt_ar = 2'b01;
        tgt_ar_val = 48'd952;
        imm14_val = 14'sd25;
        opc = `OPC_CSETBiv;
        root_opc = `OPC_CSETBiv;
        expect_no_trap("CSETBiv ok");
        if (cr_base !== 48'd950 || cr_len !== 48'd25) begin
            $display("FAIL: CSETBiv base/len %0d %0d", cr_base, cr_len);
            $fatal;
        end
        idle_cycle();

        // CSETBiv immediate trap on zero len -> CAP_CFG
        set_cr_s(48'd0, 48'd0, 48'd960, PERM_RW, 24'd0, 1'b1);
        set_cr_t(48'd960, 48'd10, 48'd962, PERM_SB | PERM_RW, 24'd0, 1'b1);
        src_ar_val = 48'd960;
        tgt_ar = 2'b10;
        tgt_ar_val = 48'd962;
        imm14_val = 14'sd0;
        opc = `OPC_CSETBiv;
        root_opc = `OPC_CSETBiv;
        expect_trap(`PSTATE_CAUSE_CAP_CFG, "CSETBiv zero len");
        idle_cycle();

        // CSETBiv immediate trap on cursor outside -> CAP_OOB
        set_cr_s(48'd0, 48'd0, 48'd970, PERM_RW, 24'd0, 1'b1);
        set_cr_t(48'd965, 48'd10, 48'd900, PERM_SB | PERM_RW, 24'd0, 1'b1);
        src_ar_val = 48'd970;
        tgt_ar = 2'b11;
        tgt_ar_val = 48'd900;
        imm14_val = 14'sd12;
        opc = `OPC_CSETBiv;
        root_opc = `OPC_CSETBiv;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "CSETBiv cursor OOB");
        idle_cycle();

        // CANDP mask perms
        set_cr_t(48'd0, 48'd0, 48'd0, PERM_SB | 24'h00FF_F0, 24'd0, 1'b1);
        src_gp_val = 24'h0F0F_0F;
        tgt_ar = 2'b01;
        opc = `OPC_CANDP;
        root_opc = `OPC_CANDP;
        expect_no_trap("CANDP");
        if (!cr_we_perms || (cr_perms !== ((PERM_SB | 24'h00FF_F0) & 24'h0F0F_0F))) begin
            $display("FAIL: CANDP perms %06h", cr_perms);
            $fatal;
        end
        idle_cycle();

        // CGETP returns perms mask
        set_cr_s(48'd0, 48'd0, 48'd0, 24'h00AA_55, 24'd0, 1'b1);
        src_ar = 2'b10;
        tgt_gp = 4'd3;
        tgt_gp_we = 1'b1;
        opc = `OPC_CGETP;
        root_opc = `OPC_CGETP;
        expect_no_trap("CGETP");
        if (!ex_tgt_gp_we || ex_result !== 24'h00AA_55) begin
            $display("FAIL: CGETP result %06h", ex_result);
            $fatal;
        end
        idle_cycle();

        // CGETT tag=1
        set_cr_s(48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b1);
        tgt_gp = 4'd4;
        tgt_gp_we = 1'b1;
        opc = `OPC_CGETT;
        root_opc = `OPC_CGETT;
        expect_no_trap("CGETT tag1");
        if (ex_result !== 24'h000001) begin
            $display("FAIL: CGETT tag1 result %06h", ex_result);
            $fatal;
        end
        idle_cycle();

        // CGETT tag=0
        set_cr_s(48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b0);
        tgt_gp = 4'd5;
        tgt_gp_we = 1'b1;
        opc = `OPC_CGETT;
        root_opc = `OPC_CGETT;
        expect_no_trap("CGETT tag0");
        if (ex_result !== 24'h000000) begin
            $display("FAIL: CGETT tag0 result %06h", ex_result);
            $fatal;
        end
        idle_cycle();

        // CCLRT clears tag
        set_cr_t(48'd0, 48'd0, 48'd0, PERM_RW, 24'd0, 1'b1);
        tgt_ar = 2'b00;
        opc = `OPC_CCLRT;
        root_opc = `OPC_CCLRT;
        expect_no_trap("CCLRT");
        if (!cr_we_tag || (cr_tag !== 1'b0)) begin
            $display("FAIL: CCLRT tag %0d", cr_tag);
            $fatal;
        end
        idle_cycle();

        $display("opclass5_ex_tb PASS");
        $finish;
    end
endmodule

