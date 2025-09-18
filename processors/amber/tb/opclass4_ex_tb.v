`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/cr.vh"
`include "src/pstate.vh"

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
        .ow_trap_pending(trap_pending), .ow_halt(halt),
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

    localparam [23:0] PERM_R  = (24'd1 << `CR_PERM_R_BIT);
    localparam [23:0] PERM_W  = (24'd1 << `CR_PERM_W_BIT);
    localparam [23:0] PERM_LC = (24'd1 << `CR_PERM_LC_BIT);
    localparam [23:0] PERM_SC = (24'd1 << `CR_PERM_SC_BIT);
    localparam [23:0] ATTR_SEALED = (24'd1 << `CR_ATTR_SEALED_BIT);

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

    task automatic expect_no_trap(input string label);
        begin
            step();
            if (branch_taken) begin
                $display("FAIL (%s): unexpected trap", label);
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

    task automatic expect_trap(
        input [7:0] cause,
        input string label,
        input bit require_pending = 1'b1,
        input bit check_cause = 1'b1
    );
        begin
            step();
            if (!branch_taken) begin
                $display("FAIL (%s): expected trap", label);
                $fatal;
            end
            if (require_pending && !trap_pending) begin
                $display("FAIL (%s): trap_pending not asserted", label);
                $fatal;
            end
            if (halt) begin
                $display("FAIL (%s): halt asserted during trap", label);
                $fatal;
            end
            if (check_cause && (dut.r_trap_cause !== cause)) begin
                $display("FAIL (%s): trap cause %02h != expected %02h", label, dut.r_trap_cause, cause);
                $fatal;
            end
        end
    endtask

    task step; begin @(posedge clk); @(posedge clk); end endtask
    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        rst = 1'b1;
        stall = 1'b0;
        flush = 1'b0;
        pc = 48'h0000_0600;
        instr = 24'd0;
        opc = 8'd0;
        sgn_en = 1'b1;
        imm_en = 1'b1;
        imm14_val = 14'd0;
        imm12_val = 12'd0;
        imm10_val = 10'd0;
        imm16_val = 16'd0;
        cc = `CC_RA;
        tgt_gp = 0;
        tgt_gp_we = 1'b1;
        tgt_sr = 0;
        tgt_sr_we = 1'b0;
        tgt_ar = 0;
        src_gp = 0;
        src_ar = 0;
        src_sr = 2'b10;
        src_gp_val = 24'd0;
        tgt_gp_val = 24'd0;
        src_ar_val = 48'd0;
        tgt_ar_val = 48'd0;
        src_sr_val = 48'd0;
        tgt_sr_val = 48'd0;
        set_cr_s(48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b0);
        set_cr_t(48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b0);
        #12 rst = 1'b0;

        // LDcso checks
        opc = `OPC_LDcso;
        set_cr_s(48'd100, 48'd32, 48'd105, PERM_R, 24'd0, 1'b1);
        imm10_val = 10'd1;
        expect_no_trap("LDcso +1 within bounds");
        if (ex_addr !== 48'd106) begin
            $display("FAIL: LDcso addr %0d", ex_addr);
            $fatal;
        end

        set_cr_s(48'd100, 48'd32, 48'd110, PERM_R, 24'd0, 1'b1);
        imm10_val = -5;
        opc = `OPC_LDcso;
        expect_no_trap("LDcso -5 within bounds");
        if (ex_addr !== 48'd105) begin
            $display("FAIL: LDcso addr %0d", ex_addr);
            $fatal;
        end

        set_cr_s(48'd100, 48'd32, 48'd105, PERM_R, 24'd0, 1'b0);
        imm10_val = 10'd0;
        opc = `OPC_LDcso;
        expect_trap(`PSTATE_CAUSE_CAP_TAG, "LDcso missing tag");

        set_cr_s(48'd100, 48'd32, 48'd105, PERM_R, ATTR_SEALED, 1'b1);
        imm10_val = 10'd0;
        opc = `OPC_LDcso;
        expect_trap(`PSTATE_CAUSE_CAP_SEAL, "LDcso sealed");

        set_cr_s(48'd100, 48'd32, 48'd105, 24'd0, 24'd0, 1'b1);
        imm10_val = 10'd0;
        opc = `OPC_LDcso;
        expect_trap(`PSTATE_CAUSE_CAP_PERM, "LDcso missing R perm");

        set_cr_s(48'd100, 48'd32, 48'd105, PERM_R, 24'd0, 1'b1);
        imm10_val = -12;
        opc = `OPC_LDcso;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "LDcso underflow");

        set_cr_s(48'd100, 48'd32, 48'd125, PERM_R, 24'd0, 1'b1);
        imm10_val = 10'd10;
        opc = `OPC_LDcso;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "LDcso overflow");

        // STcso checks
        opc = `OPC_STcso;
        set_cr_t(48'd200, 48'd32, 48'd205, PERM_W, 24'd0, 1'b1);
        src_gp_val = 24'h112233;
        imm10_val = 10'd1;
        expect_no_trap("STcso +1 within bounds");
        if (ex_addr !== 48'd206) begin
            $display("FAIL: STcso addr %0d", ex_addr);
            $fatal;
        end
        if (ex_result !== 24'h112233) begin
            $display("FAIL: STcso data %06h", ex_result);
            $fatal;
        end

        set_cr_t(48'd200, 48'd32, 48'd220, PERM_W, 24'd0, 1'b1);
        src_gp_val = 24'hA5A5A5;
        imm10_val = -5;
        opc = `OPC_STcso;
        expect_no_trap("STcso -5 within bounds");
        if (ex_addr !== 48'd215) begin
            $display("FAIL: STcso addr %0d", ex_addr);
            $fatal;
        end
        if (ex_result !== 24'hA5A5A5) begin
            $display("FAIL: STcso data %06h", ex_result);
            $fatal;
        end

        set_cr_t(48'd200, 48'd32, 48'd205, PERM_W, 24'd0, 1'b0);
        imm10_val = 10'd0;
        opc = `OPC_STcso;
        expect_trap(`PSTATE_CAUSE_CAP_TAG, "STcso missing tag");

        set_cr_t(48'd200, 48'd32, 48'd205, PERM_W, ATTR_SEALED, 1'b1);
        imm10_val = 10'd0;
        opc = `OPC_STcso;
        expect_trap(`PSTATE_CAUSE_CAP_SEAL, "STcso sealed");

        set_cr_t(48'd200, 48'd32, 48'd205, 24'd0, 24'd0, 1'b1);
        imm10_val = 10'd0;
        opc = `OPC_STcso;
        expect_trap(`PSTATE_CAUSE_CAP_PERM, "STcso missing W perm");

        set_cr_t(48'd200, 48'd32, 48'd205, PERM_W, 24'd0, 1'b1);
        imm10_val = -12;
        opc = `OPC_STcso;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "STcso underflow");

        set_cr_t(48'd200, 48'd32, 48'd225, PERM_W, 24'd0, 1'b1);
        imm10_val = 10'd10;
        opc = `OPC_STcso;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "STcso overflow");

        // STui immediate stores
        set_cr_t(48'd300, 48'd16, 48'd304, PERM_W, 24'd0, 1'b1);
        opc = `OPC_LUIui;
        instr = 24'd0;
        instr[15:14] = 2'b00;
        imm12_val = 12'hABC;
        expect_no_trap("LUIui preload for STui");
        opc = `OPC_STui;
        instr = 24'd0;
        instr[15:14] = 2'b01;
        imm12_val = 12'h123;
        expect_no_trap("STui immediate store");
        if (ex_addr !== 48'd304) begin
            $display("FAIL: STui addr %0d", ex_addr);
            $fatal;
        end
        if (ex_result !== 24'hABC123) begin
            $display("FAIL: STui data %06h", ex_result);
            $fatal;
        end

        opc = `OPC_STui;
        set_cr_t(48'd300, 48'd16, 48'd304, PERM_W, 24'd0, 1'b0);
        imm12_val = 12'h055;
        expect_trap(`PSTATE_CAUSE_CAP_TAG, "STui missing tag", 1'b0, 1'b0);

        opc = `OPC_STui;
        set_cr_t(48'd300, 48'd16, 48'd304, PERM_W, ATTR_SEALED, 1'b1);
        imm12_val = 12'h0AA;
        expect_trap(`PSTATE_CAUSE_CAP_SEAL, "STui sealed", 1'b0, 1'b0);

        opc = `OPC_STui;
        set_cr_t(48'd300, 48'd16, 48'd304, 24'd0, 24'd0, 1'b1);
        imm12_val = 12'h0FF;
        expect_trap(`PSTATE_CAUSE_CAP_PERM, "STui missing W perm", 1'b0, 1'b0);

        opc = `OPC_STui;
        set_cr_t(48'd300, 48'd4, 48'd304, PERM_W, 24'd0, 1'b1);
        imm12_val = 12'h100;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "STui cursor out of bounds", 1'b0, 1'b0);

        // STsi sign-extended stores
        set_cr_t(48'd400, 48'd32, 48'd408, PERM_W, 24'd0, 1'b1);
        opc = `OPC_STsi;
        instr = 24'd0;
        instr[15:14] = 2'b10;
        imm14_val = 14'd127;
        expect_no_trap("STsi +127 immediate");
        if (ex_addr !== 48'd408) begin
            $display("FAIL: STsi addr %0d", ex_addr);
            $fatal;
        end
        if (ex_result !== 24'h00007F) begin
            $display("FAIL: STsi data %06h", ex_result);
            $fatal;
        end

        imm14_val = -8;
        opc = `OPC_STsi;
        expect_no_trap("STsi -8 immediate");
        if (ex_result !== 24'hFFFFF8) begin
            $display("FAIL: STsi data %06h", ex_result);
            $fatal;
        end

        opc = `OPC_STsi;
        set_cr_t(48'd400, 48'd32, 48'd408, PERM_W, 24'd0, 1'b0);
        imm14_val = 14'd0;
        expect_trap(`PSTATE_CAUSE_CAP_TAG, "STsi missing tag", 1'b0, 1'b0);

        opc = `OPC_STsi;
        set_cr_t(48'd400, 48'd32, 48'd408, 24'd0, 24'd0, 1'b1);
        imm14_val = 14'd0;
        expect_trap(`PSTATE_CAUSE_CAP_PERM, "STsi missing W perm", 1'b0, 1'b0);

        opc = `OPC_STsi;
        set_cr_t(48'd400, 48'd8, 48'd408, PERM_W, 24'd0, 1'b1);
        imm14_val = 14'd0;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "STsi cursor out of bounds", 1'b0, 1'b0);

        // CLDcso capability loads
        opc = `OPC_CLDcso;
        set_cr_s(48'd500, 48'd64, 48'd520, (PERM_R | PERM_LC), 24'd0, 1'b1);
        imm10_val = -4;
        expect_no_trap("CLDcso -4 within bounds");
        imm10_val = 10'd8;
        opc = `OPC_CLDcso;
        expect_no_trap("CLDcso +8 within bounds");

        set_cr_s(48'd500, 48'd64, 48'd520, (PERM_R | PERM_LC), 24'd0, 1'b0);
        imm10_val = 10'd0;
        opc = `OPC_CLDcso;
        expect_trap(`PSTATE_CAUSE_CAP_TAG, "CLDcso missing tag");

        set_cr_s(48'd500, 48'd64, 48'd520, (PERM_R | PERM_LC), ATTR_SEALED, 1'b1);
        imm10_val = 10'd0;
        opc = `OPC_CLDcso;
        expect_trap(`PSTATE_CAUSE_CAP_SEAL, "CLDcso sealed");

        set_cr_s(48'd500, 48'd64, 48'd520, PERM_R, 24'd0, 1'b1);
        imm10_val = 10'd0;
        opc = `OPC_CLDcso;
        expect_trap(`PSTATE_CAUSE_CAP_PERM, "CLDcso missing LC perm");

        set_cr_s(48'd500, 48'd64, 48'd520, (PERM_R | PERM_LC), 24'd0, 1'b1);
        imm10_val = -25;
        opc = `OPC_CLDcso;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "CLDcso underflow");

        set_cr_s(48'd500, 48'd64, 48'd550, (PERM_R | PERM_LC), 24'd0, 1'b1);
        imm10_val = 10'd20;
        opc = `OPC_CLDcso;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "CLDcso overflow span");

        // CSTcso capability stores
        opc = `OPC_CSTcso;
        set_cr_t(48'd600, 48'd64, 48'd608, PERM_SC, 24'd0, 1'b1);
        imm10_val = -4;
        expect_no_trap("CSTcso -4 within bounds");
        imm10_val = 10'd8;
        opc = `OPC_CSTcso;
        expect_no_trap("CSTcso +8 within bounds");

        set_cr_t(48'd600, 48'd64, 48'd608, PERM_SC, 24'd0, 1'b0);
        imm10_val = 10'd0;
        opc = `OPC_CSTcso;
        expect_trap(`PSTATE_CAUSE_CAP_TAG, "CSTcso missing tag");

        set_cr_t(48'd600, 48'd64, 48'd608, PERM_SC, ATTR_SEALED, 1'b1);
        imm10_val = 10'd0;
        opc = `OPC_CSTcso;
        expect_trap(`PSTATE_CAUSE_CAP_SEAL, "CSTcso sealed");

        set_cr_t(48'd600, 48'd64, 48'd608, PERM_W, 24'd0, 1'b1);
        imm10_val = 10'd0;
        opc = `OPC_CSTcso;
        expect_trap(`PSTATE_CAUSE_CAP_PERM, "CSTcso missing SC perm");

        set_cr_t(48'd600, 48'd64, 48'd608, PERM_SC, 24'd0, 1'b1);
        imm10_val = -25;
        opc = `OPC_CSTcso;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "CSTcso underflow");

        set_cr_t(48'd600, 48'd64, 48'd650, PERM_SC, 24'd0, 1'b1);
        imm10_val = 10'd20;
        opc = `OPC_CSTcso;
        expect_trap(`PSTATE_CAUSE_CAP_OOB, "CSTcso overflow span");

        $display("opclass4_ex_tb PASS");
        $finish;
    end
endmodule
