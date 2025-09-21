`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/flags.vh"

module opclass6_ex_tb;
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

    reg  [`HBIT_ADDR:0]    expected;
    reg  [`HBIT_ADDR:0]    call_pc;
    reg  [`HBIT_ADDR:0]    ssp;
    reg  [`HBIT_ADDR:0]    lr;

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

    task automatic step;
        begin
            @(posedge clk);
            @(posedge clk);
        end
    endtask

    task automatic set_flags(input bit z, input bit n, input bit c, input bit v);
        begin
            src_sr_val = {44'b0, v, c, n, z};
        end
    endtask

    task automatic load_uimm_bank(input [1:0] bank, input [11:0] value);
        begin
            instr = 24'h0;
            case (bank)
                2'b00: instr[15:14] = 2'b00;
                2'b01: instr[15:14] = 2'b01;
                2'b10: instr[15:14] = 2'b10;
                default: instr[15:14] = 2'b00;
            endcase
            opc = `OPC_LUIui;
            imm12_val = value;
            step();
            if (branch_taken || trap_pending || halt) begin
                $display("FAIL: LUIui bank=%0d unexpected control response", bank);
                $fatal;
            end
            instr = 24'h0;
        end
    endtask

    task automatic program_uimm(input [11:0] bank2, input [11:0] bank1, input [11:0] bank0);
        begin
            load_uimm_bank(2'd2, bank2);
            load_uimm_bank(2'd1, bank1);
            load_uimm_bank(2'd0, bank0);
        end
    endtask

    task automatic clear_uimm;
        begin
            flush = 1'b1;
            step();
            flush = 1'b0;
        end
    endtask

    function automatic [47:0] sext24(input [23:0] value);
        begin
            sext24 = {{24{value[23]}}, value};
        end
    endfunction

    function automatic [47:0] sext16(input [15:0] value);
        begin
            sext16 = {{32{value[15]}}, value};
        end
    endfunction

    function automatic [47:0] sext12(input [11:0] value);
        begin
            sext12 = {{36{value[11]}}, value};
        end
    endfunction

    function automatic [47:0] sext10(input [9:0] value);
        begin
            sext10 = {{38{value[9]}}, value};
        end
    endfunction

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        stall = 1'b0;
        flush = 1'b0;
        mode_kernel = 1'b1;
        pc = 48'h0;
        instr = 24'h0;
        opc = {`SIZE_OPC{1'b0}};
        root_opc = {`SIZE_OPC{1'b0}};
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
        src_sr = `SR_IDX_FL;
        src_gp_val = 24'd0;
        tgt_gp_val = 24'd0;
        src_ar_val = 48'd0;
        tgt_ar_val = 48'd0;
        src_sr_val = 48'd0;
        tgt_sr_val = 48'd0;
        pstate = 48'd0;
        cr_s_base = 48'd0;
        cr_s_len  = 48'd0;
        cr_s_cur  = 48'd0;
        cr_s_perms= 24'd0;
        cr_s_attr = 24'd0;
        cr_s_tag  = 1'b0;
        cr_t_base = 48'd0;
        cr_t_len  = 48'd0;
        cr_t_cur  = 48'd0;
        cr_t_perms= 24'd0;
        cr_t_attr = 24'd0;
        cr_t_tag  = 1'b0;
        expected = 48'd0;
        call_pc = 48'd0;
        ssp = 48'd0;
        lr = 48'd0;

        #12 rst = 1'b0;

        clear_uimm();
        set_flags(1'b1, 1'b0, 1'b0, 1'b0);

        // BTP should not branch and must preserve uimm banks
        program_uimm(12'h012, 12'h345, 12'h678);
        pc = 48'h0000_0010;
        call_pc = pc;
        cc = `CC_RA;
        opc = `OPC_BTP;
        step();
        if (branch_taken || trap_pending || halt) begin
            $display("FAIL: BTP altered control flow");
            $fatal;
        end

        // JCCui taken with valid banks
        pc = 48'h0000_0100;
        call_pc = pc;
        cc = `CC_EQ;
        imm12_val = 12'h9AB;
        opc = `OPC_JCCui;
        step();
        expected = {12'h012, 12'h345, 12'h678, 12'h9AB};
        if (!branch_taken || trap_pending || halt || branch_pc !== expected) begin
            $display("FAIL: JCCui taken: branch_taken=%b branch_pc=%h", branch_taken, branch_pc);
            $fatal;
        end

        // JCCui not taken when condition fails
        pc = 48'h0000_0108;
        call_pc = pc;
        set_flags(1'b1, 1'b0, 1'b0, 1'b0); // Z=1 ⇒ NE false
        cc = `CC_NE;
        imm12_val = 12'h123;
        opc = `OPC_JCCui;
        step();
        if (branch_taken || trap_pending || halt) begin
            $display("FAIL: JCCui not-taken incorrectly branched");
            $fatal;
        end

        // JCCui trap when upper immediates not fully programmed
        clear_uimm();
        load_uimm_bank(2'd0, 12'h055);
        set_flags(1'b0, 1'b0, 1'b0, 1'b0);
        pc = 48'h0000_0200;
        call_pc = pc;
        cc = `CC_RA;
        imm12_val = 12'h012;
        opc = `OPC_JCCui;
        step();
        expected = {12'h000, 12'h000, 12'h055, 12'h000};
        if (!branch_taken || halt || branch_pc !== expected) begin
            $display("FAIL: JCCui trap vector mismatch branch=%b pc=%h trap=%b", branch_taken, branch_pc, trap_pending);
            $fatal;
        end
        if (ex_sr_result !== (call_pc + 48'd1)) begin
            $display("FAIL: JCCui trap LR=%h expected=%h", ex_sr_result, call_pc + 48'd1);
            $fatal;
        end

        // BCCsr positive offset
        clear_uimm();
        set_flags(1'b1, 1'b0, 1'b0, 1'b0);
        pc = 48'h0000_0300;
        call_pc = pc;
        tgt_gp_val = 24'sd64;
        cc = `CC_EQ;
        opc = `OPC_BCCsr;
        step();
        expected = $signed(call_pc) + $signed(sext24(tgt_gp_val));
        if (!branch_taken || trap_pending || halt || branch_pc !== expected) begin
            $display("FAIL: BCCsr +offset branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BCCsr negative offset
        pc = 48'h0000_0400;
        call_pc = pc;
        tgt_gp_val = -24'sd32;
        cc = `CC_EQ;
        opc = `OPC_BCCsr;
        step();
        expected = $signed(call_pc) + $signed(sext24(tgt_gp_val));
        if (!branch_taken || branch_pc !== expected || trap_pending || halt) begin
            $display("FAIL: BCCsr -offset branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BCCsr extreme negative offset
        pc = 48'h0000_0500;
        call_pc = pc;
        tgt_gp_val = 24'h800000; // -2^23
        cc = `CC_EQ;
        opc = `OPC_BCCsr;
        step();
        expected = $signed(call_pc) + $signed(sext24(tgt_gp_val));
        if (!branch_taken || branch_pc !== expected || trap_pending || halt) begin
            $display("FAIL: BCCsr min offset branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BCCsr not taken when Z=0
        set_flags(1'b0, 1'b0, 1'b0, 1'b0);
        pc = 48'h0000_0600;
        cc = `CC_EQ;
        tgt_gp_val = 24'sd4;
        opc = `OPC_BCCsr;
        step();
        if (branch_taken || trap_pending || halt) begin
            $display("FAIL: BCCsr unexpected branch when condition false");
            $fatal;
        end

        // BCCso positive immediate
        set_flags(1'b1, 1'b0, 1'b0, 1'b0);
        pc = 48'h0000_0700;
        call_pc = pc;
        imm12_val = 12'h7FF;
        cc = `CC_EQ;
        opc = `OPC_BCCso;
        step();
        expected = $signed(call_pc) + $signed(sext12(imm12_val));
        if (!branch_taken || trap_pending || halt || branch_pc !== expected) begin
            $display("FAIL: BCCso +imm branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BCCso zero immediate (should hold PC)
        pc = 48'h0000_0710;
        call_pc = pc;
        imm12_val = 12'h000;
        cc = `CC_EQ;
        opc = `OPC_BCCso;
        step();
        expected = $signed(call_pc) + $signed(sext12(imm12_val));
        if (!branch_taken || branch_pc !== expected || trap_pending || halt) begin
            $display("FAIL: BCCso zero imm branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BCCso negative immediate
        pc = 48'h0000_0720;
        call_pc = pc;
        imm12_val = 12'h800; // -2048
        cc = `CC_EQ;
        opc = `OPC_BCCso;
        step();
        expected = $signed(call_pc) + $signed(sext12(imm12_val));
        if (!branch_taken || branch_pc !== expected || trap_pending || halt) begin
            $display("FAIL: BCCso -imm branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BCCso not taken when condition false
        set_flags(1'b0, 1'b0, 1'b0, 1'b0);
        pc = 48'h0000_0730;
        imm12_val = 12'h001;
        cc = `CC_EQ;
        opc = `OPC_BCCso;
        step();
        if (branch_taken || trap_pending || halt) begin
            $display("FAIL: BCCso unexpected branch when condition false");
            $fatal;
        end

        // BALso positive offset (max)
        pc = 48'h0000_0800;
        call_pc = pc;
        imm16_val = 16'h7FFF;
        opc = `OPC_BALso;
        step();
        expected = $signed(call_pc) + $signed(sext16(imm16_val));
        if (!branch_taken || branch_pc !== expected || trap_pending || halt) begin
            $display("FAIL: BALso +imm branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BALso zero offset
        pc = 48'h0000_0810;
        call_pc = pc;
        imm16_val = 16'h0000;
        opc = `OPC_BALso;
        step();
        expected = call_pc;
        if (!branch_taken || branch_pc !== expected || trap_pending || halt) begin
            $display("FAIL: BALso zero imm branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BALso negative offset
        pc = 48'h0000_0820;
        call_pc = pc;
        imm16_val = 16'h8000; // -32768
        opc = `OPC_BALso;
        step();
        expected = $signed(call_pc) + $signed(sext16(imm16_val));
        if (!branch_taken || branch_pc !== expected || trap_pending || halt) begin
            $display("FAIL: BALso -imm branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // JSRui macro sequence with valid banks
        program_uimm(12'h0AA, 12'h0BB, 12'h0CC);
        set_flags(1'b0, 1'b0, 1'b0, 1'b0);
        call_pc = 48'h0000_2000;
        ssp = 48'h0000_1200;
        lr  = 48'h0000_3333;

        // SRSUBsi SSP, #2
        pc = call_pc;
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_val = ssp;
        imm14_val = 14'd2;
        opc = `OPC_SRSUBsi;
        step();
        if (branch_taken || trap_pending || halt || ex_sr_result !== (ssp - 48'd2)) begin
            $display("FAIL: JSR SRSUB new_ssp=%h expected=%h", ex_sr_result, ssp - 48'd2);
            $fatal;
        end
        ssp = ex_sr_result;

        // SRSTso LR, #0(SSP)
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_val = ssp;
        src_sr = `SR_IDX_LR;
        src_sr_val = lr;
        imm12_val = 12'h000;
        opc = `OPC_SRSTso;
        step();
        if (branch_taken || trap_pending || halt || ex_addr !== ssp || ex_sr_result !== lr) begin
            $display("FAIL: JSR SRST addr=%h lr_val=%h", ex_addr, ex_sr_result);
            $fatal;
        end

        // SRMOVur PC -> LR
        tgt_sr = `SR_IDX_LR;
        src_sr = `SR_IDX_PC;
        pc = call_pc;
        opc = `OPC_SRMOVur;
        step();
        if (branch_taken || trap_pending || halt || ex_sr_result !== call_pc) begin
            $display("FAIL: JSR SRMOVur lr=%h expected=%h", ex_sr_result, call_pc);
            $fatal;
        end
        lr = ex_sr_result;

        // JCCui AL -> absolute target
        src_sr = `SR_IDX_FL;
        set_flags(1'b0, 1'b0, 1'b0, 1'b0);
        imm12_val = 12'h0DD;
        cc = `CC_RA;
        pc = call_pc;
        opc = `OPC_JCCui;
        step();
        expected = {12'h0AA, 12'h0BB, 12'h0CC, 12'h0DD};
        if (!branch_taken || trap_pending || halt || branch_pc !== expected) begin
            $display("FAIL: JSR final branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // JSRui trap when banks invalid
        clear_uimm();
        load_uimm_bank(2'd0, 12'h055);
        set_flags(1'b0, 1'b0, 1'b0, 1'b0);
        call_pc = 48'h0000_2200;
        ssp = 48'h0000_1400;
        lr  = 48'h0000_4000;

        // SRSUBsi
        pc = call_pc;
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_val = ssp;
        imm14_val = 14'd2;
        opc = `OPC_SRSUBsi;
        step();
        if (branch_taken || trap_pending || halt) begin
            $display("FAIL: JSR trap SRSUB unexpected control");
            $fatal;
        end
        ssp = ex_sr_result;

        // SRSTso
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_val = ssp;
        src_sr = `SR_IDX_LR;
        src_sr_val = lr;
        imm12_val = 12'h000;
        opc = `OPC_SRSTso;
        step();
        if (branch_taken || trap_pending || halt || ex_addr !== ssp || ex_sr_result !== lr) begin
            $display("FAIL: JSR trap SRST addr=%h lr=%h", ex_addr, ex_sr_result);
            $fatal;
        end

        // SRMOVur
        tgt_sr = `SR_IDX_LR;
        src_sr = `SR_IDX_PC;
        pc = call_pc;
        opc = `OPC_SRMOVur;
        step();
        if (branch_taken || trap_pending || halt || ex_sr_result !== call_pc) begin
            $display("FAIL: JSR trap SRMOV lr=%h expected=%h", ex_sr_result, call_pc);
            $fatal;
        end

        // JCCui should trap
        src_sr = `SR_IDX_FL;
        set_flags(1'b0, 1'b0, 1'b0, 1'b0);
        cc = `CC_RA;
        imm12_val = 12'h012;
        pc = call_pc;
        opc = `OPC_JCCui;
        step();
        expected = {12'h000, 12'h000, 12'h055, 12'h000};
        if (!branch_taken || halt || branch_pc !== expected) begin
            $display("FAIL: JSR trap branch_pc=%h expected=%h trap=%b", branch_pc, expected, trap_pending);
            $fatal;
        end
        if (ex_sr_result !== (call_pc + 48'd1)) begin
            $display("FAIL: JSR trap LR=%h expected=%h", ex_sr_result, call_pc + 48'd1);
            $fatal;
        end

        // BSRsr positive offset
        clear_uimm();
        set_flags(1'b0, 1'b0, 1'b0, 1'b0);
        call_pc = 48'h0000_3000;
        ssp = 48'h0000_1500;
        lr  = 48'h0000_5000;

        // SRSUBsi
        pc = call_pc;
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_val = ssp;
        imm14_val = 14'd2;
        opc = `OPC_SRSUBsi;
        step();
        ssp = ex_sr_result;

        // SRSTso
        tgt_sr_val = ssp;
        src_sr = `SR_IDX_LR;
        src_sr_val = lr;
        imm12_val = 12'h000;
        opc = `OPC_SRSTso;
        step();
        if (ex_addr !== ssp || ex_sr_result !== lr) begin
            $display("FAIL: BSRsr SRST addr=%h lr=%h", ex_addr, ex_sr_result);
            $fatal;
        end

        // SRMOVur
        tgt_sr = `SR_IDX_LR;
        src_sr = `SR_IDX_PC;
        pc = call_pc;
        opc = `OPC_SRMOVur;
        step();
        if (ex_sr_result !== call_pc) begin
            $display("FAIL: BSRsr SRMOV lr=%h expected=%h", ex_sr_result, call_pc);
            $fatal;
        end

        // BCCsr AL with positive offset
        src_sr = `SR_IDX_FL;
        cc = `CC_RA;
        tgt_gp_val = 24'sd96;
        pc = call_pc;
        opc = `OPC_BCCsr;
        step();
        expected = $signed(call_pc) + $signed(sext24(tgt_gp_val));
        if (!branch_taken || trap_pending || halt || branch_pc !== expected) begin
            $display("FAIL: BSRsr branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BSRsr negative offset
        call_pc = 48'h0000_3100;
        ssp = 48'h0000_1510;
        lr  = 48'h0000_5001;

        // SRSUBsi
        pc = call_pc;
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_val = ssp;
        imm14_val = 14'd2;
        opc = `OPC_SRSUBsi;
        step();
        ssp = ex_sr_result;

        // SRSTso
        tgt_sr_val = ssp;
        src_sr = `SR_IDX_LR;
        src_sr_val = lr;
        imm12_val = 12'h000;
        opc = `OPC_SRSTso;
        step();

        // SRMOVur
        tgt_sr = `SR_IDX_LR;
        src_sr = `SR_IDX_PC;
        pc = call_pc;
        opc = `OPC_SRMOVur;
        step();

        // BCCsr with negative offset
        src_sr = `SR_IDX_FL;
        cc = `CC_RA;
        tgt_gp_val = -24'sd128;
        pc = call_pc;
        opc = `OPC_BCCsr;
        step();
        expected = $signed(call_pc) + $signed(sext24(tgt_gp_val));
        if (!branch_taken || trap_pending || halt || branch_pc !== expected) begin
            $display("FAIL: BSRsr neg branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BSRso positive immediate
        call_pc = 48'h0000_3200;
        ssp = 48'h0000_1600;
        lr  = 48'h0000_5100;

        // SRSUBsi
        pc = call_pc;
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_val = ssp;
        imm14_val = 14'd2;
        opc = `OPC_SRSUBsi;
        step();
        ssp = ex_sr_result;

        // SRSTso
        tgt_sr_val = ssp;
        src_sr = `SR_IDX_LR;
        src_sr_val = lr;
        imm12_val = 12'h000;
        opc = `OPC_SRSTso;
        step();

        // SRMOVur
        tgt_sr = `SR_IDX_LR;
        src_sr = `SR_IDX_PC;
        pc = call_pc;
        opc = `OPC_SRMOVur;
        step();

        // BALso immediate positive
        src_sr = `SR_IDX_FL;
        cc = `CC_RA;
        imm16_val = 16'sd1024;
        pc = call_pc;
        opc = `OPC_BALso;
        step();
        expected = $signed(call_pc) + $signed(sext16(imm16_val));
        if (!branch_taken || trap_pending || halt || branch_pc !== expected) begin
            $display("FAIL: BSRso +imm branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // BSRso negative immediate
        call_pc = 48'h0000_3300;
        ssp = 48'h0000_1610;
        lr  = 48'h0000_5101;

        // SRSUBsi
        pc = call_pc;
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_val = ssp;
        imm14_val = 14'd2;
        opc = `OPC_SRSUBsi;
        step();
        ssp = ex_sr_result;

        // SRSTso
        tgt_sr_val = ssp;
        src_sr = `SR_IDX_LR;
        src_sr_val = lr;
        imm12_val = 12'h000;
        opc = `OPC_SRSTso;
        step();

        // SRMOVur
        tgt_sr = `SR_IDX_LR;
        src_sr = `SR_IDX_PC;
        pc = call_pc;
        opc = `OPC_SRMOVur;
        step();

        // BALso negative immediate
        src_sr = `SR_IDX_FL;
        cc = `CC_RA;
        imm16_val = -16'sd768;
        pc = call_pc;
        opc = `OPC_BALso;
        step();
        expected = $signed(call_pc) + $signed(sext16(imm16_val));
        if (!branch_taken || trap_pending || halt || branch_pc !== expected) begin
            $display("FAIL: BSRso -imm branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        // RET sequence
        clear_uimm();
        set_flags(1'b0, 1'b0, 1'b0, 1'b0);
        call_pc = 48'h0000_4000;
        ssp = 48'h0000_1700; // current SSP before RET
        lr  = 48'h0000_6000; // value that should be popped into LR

        // SRADDsi SSP, #2
        pc = call_pc;
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_val = ssp;
        imm14_val = 14'd2;
        opc = `OPC_SRADDsi;
        step();
        expected = ssp + 48'd2;
        if (branch_taken || trap_pending || halt || ex_sr_result !== expected) begin
            $display("FAIL: RET SRADD new_ssp=%h expected=%h", ex_sr_result, expected);
            $fatal;
        end
        ssp = ex_sr_result;

        // SRLDso LR, #-2(SSP)
        tgt_sr = `SR_IDX_LR;
        src_sr = `SR_IDX_SSP;
        src_sr_val = ssp;
        imm12_val = 12'hFFE; // -2
        opc = `OPC_SRLDso;
        step();
        expected = $signed(ssp) + $signed(sext12(imm12_val));
        if (branch_taken || trap_pending || halt || ex_addr !== expected) begin
            $display("FAIL: RET SRLD addr=%h expected=%h", ex_addr, expected);
            $fatal;
        end

        // SRJCCso AL, LR+#1
        tgt_sr = `SR_IDX_LR;
        tgt_sr_val = lr;
        src_sr = `SR_IDX_FL;
        set_flags(1'b0, 1'b0, 1'b0, 1'b0);
        imm10_val = 10'h001;
        cc = `CC_RA;
        opc = `OPC_SRJCCso;
        step();
        expected = $signed(lr) + $signed(sext10(imm10_val));
        if (!branch_taken || trap_pending || halt || branch_pc !== expected) begin
            $display("FAIL: RET SRJCC branch_pc=%h expected=%h", branch_pc, expected);
            $fatal;
        end

        $display("opclass6_ex_tb PASS");
        $finish;
    end
endmodule
