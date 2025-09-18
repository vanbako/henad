`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/sizes.vh"
`include "src/flags.vh"
`include "src/sr.vh"
`include "src/pstate.vh"

module opclass9_tb;
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
    reg  [`HBIT_ADDR:0]    pstate_val;
    reg                    flush;
    reg                    stall;
    reg                    mode_kernel;

    stg_ex dut(
        .iw_clk(clk), .iw_rst(rst), .iw_pc(pc), .ow_pc(ex_pc),
        .iw_instr(instr), .ow_instr(ex_instr),
        .iw_opc(opc), .iw_root_opc(root_opc), .ow_opc(ex_opc), .ow_root_opc(ex_root_opc),
        .iw_sgn_en(sgn_en), .iw_imm_en(imm_en),
        .iw_imm14_val(imm14_val), .iw_imm12_val(imm12_val),
        .iw_imm10_val(imm10_val), .iw_imm16_val(imm16_val),
        .iw_cc(cc),
        .iw_tgt_gp(tgt_gp), .iw_tgt_gp_we(tgt_gp_we), .ow_tgt_gp(ex_tgt_gp), .ow_tgt_gp_we(ex_tgt_gp_we),
        .iw_tgt_sr(tgt_sr), .iw_tgt_sr_we(tgt_sr_we), .ow_tgt_sr(ex_tgt_sr), .ow_tgt_sr_we(ex_tgt_sr_we),
        .iw_tgt_ar(tgt_ar), .ow_tgt_ar(ex_tgt_ar), .ow_tgt_ar_we(ex_tgt_ar_we),
        .iw_src_gp(src_gp), .iw_src_ar(src_ar), .iw_src_sr(src_sr),
        .ow_addr(ex_addr), .ow_result(ex_result), .ow_ar_result(ex_ar_result), .ow_sr_result(ex_sr_result),
        .ow_sr_aux_we(sr_aux_we), .ow_sr_aux_addr(sr_aux_addr), .ow_sr_aux_result(sr_aux_result),
        .ow_branch_taken(branch_taken), .ow_branch_pc(branch_pc),
        .ow_trap_pending(trap_pending), .ow_halt(halt),
        .iw_src_gp_val(src_gp_val), .iw_tgt_gp_val(tgt_gp_val),
        .iw_src_ar_val(src_ar_val), .iw_tgt_ar_val(tgt_ar_val),
        .iw_src_sr_val(src_sr_val), .iw_tgt_sr_val(tgt_sr_val),
        .iw_pstate_val(pstate_val),
        .ow_cr_write_addr(), .ow_cr_we_base(), .ow_cr_base(), .ow_cr_we_len(), .ow_cr_len(),
        .ow_cr_we_cur(), .ow_cr_cur(), .ow_cr_we_perms(), .ow_cr_perms(),
        .ow_cr_we_attr(), .ow_cr_attr(), .ow_cr_we_tag(), .ow_cr_tag(),
        .iw_cr_s_base(48'd0), .iw_cr_s_len(48'd0), .iw_cr_s_cur(48'd0),
        .iw_cr_s_perms(24'd0), .iw_cr_s_attr(24'd0), .iw_cr_s_tag(1'b0),
        .iw_cr_t_base(48'd0), .iw_cr_t_len(48'd0), .iw_cr_t_cur(48'd0),
        .iw_cr_t_perms(24'd0), .iw_cr_t_attr(24'd0), .iw_cr_t_tag(1'b0),
        .iw_flush(flush), .iw_mode_kernel(mode_kernel), .iw_stall(stall)
    );

    task automatic step;
        begin
            @(posedge clk);
            @(posedge clk);
        end
    endtask

    task automatic reset_inputs;
        begin
            pc = 48'h0000_1000;
            instr = 24'd0;
            opc = `OPC_NOP;
            root_opc = `OPC_NOP;
            sgn_en = 1'b1;
            imm_en = 1'b1;
            imm14_val = {(`HBIT_IMM14+1){1'b0}};
            imm12_val = {(`HBIT_IMM12+1){1'b0}};
            imm10_val = {(`HBIT_IMM10+1){1'b0}};
            imm16_val = {(`HBIT_IMM16+1){1'b0}};
            cc = {(`HBIT_CC+1){1'b0}};
            tgt_gp = {(`HBIT_TGT_GP+1){1'b0}};
            tgt_gp_we = 1'b0;
            tgt_sr = {(`HBIT_TGT_SR+1){1'b0}};
            tgt_sr_we = 1'b0;
            tgt_ar = {(`HBIT_TGT_AR+1){1'b0}};
            src_gp = {(`HBIT_SRC_GP+1){1'b0}};
            src_ar = {(`HBIT_TGT_AR+1){1'b0}};
            src_sr = {(`HBIT_SRC_SR+1){1'b0}};
            src_gp_val = {(`HBIT_DATA+1){1'b0}};
            tgt_gp_val = {(`HBIT_DATA+1){1'b0}};
            src_ar_val = {(`HBIT_ADDR+1){1'b0}};
            tgt_ar_val = {(`HBIT_ADDR+1){1'b0}};
            src_sr_val = {(`HBIT_ADDR+1){1'b0}};
            tgt_sr_val = {(`HBIT_ADDR+1){1'b0}};
            pstate_val = 48'h0000_0000_0100; // MODE=1 kernel by default
            flush = 1'b0;
            stall = 1'b0;
            mode_kernel = 1'b1;
        end
    endtask

    task automatic expect_no_branch;
        begin
            if (branch_taken) begin
                $display("FAIL: unexpected branch to %h", branch_pc);
                $fatal;
            end
        end
    endtask

    task automatic expect_no_trap;
        begin
            if (trap_pending) begin
                $display("FAIL: unexpected trap pending (cause candidate=%h)", sr_aux_result[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO]);
                $fatal;
            end
        end
    endtask

    task automatic program_uimm(input [1:0] bank, input [11:0] value);
        begin
            opc = `OPC_LUIui;
            root_opc = `OPC_LUIui;
            instr = {`OPC_LUIui, bank, 14'd0};
            imm12_val = value;
            step();
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
        reset_inputs();
        #12 rst = 1'b0;

        // 1) HLT should assert halt without branching or trapping.
        reset_inputs();
        pc = 48'h0000_2000;
        opc = `OPC_HLT;
        root_opc = `OPC_HLT;
        instr = {`OPC_HLT, 16'h0000};
        step();
        if (!halt) begin
            $display("FAIL: HLT did not assert halt");
            $fatal;
        end
        expect_no_branch();
        expect_no_trap();
        if (ex_tgt_sr_we || ex_tgt_gp_we || sr_aux_we) begin
            $display("FAIL: HLT should not write back (sr_we=%b gp_we=%b sr_aux_we=%b)", ex_tgt_sr_we, ex_tgt_gp_we, sr_aux_we);
            $fatal;
        end

        // 2) SETSSP should copy AR value into SSP with 48-bit fidelity.
        reset_inputs();
        pc = 48'h0000_2100;
        opc = `OPC_SRMOVAur;
        root_opc = `OPC_SETSSP;
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_we = 1'b1;
        src_ar = 2'd0;
        src_ar_val = 48'h0000_0000_0FF0;
        step();
        expect_no_branch();
        expect_no_trap();
        if (!ex_tgt_sr_we || (ex_tgt_sr !== `SR_IDX_SSP)) begin
            $display("FAIL: SETSSP target mismatch (we=%b tgt=%h)", ex_tgt_sr_we, ex_tgt_sr);
            $fatal;
        end
        if (ex_sr_result !== src_ar_val) begin
            $display("FAIL: SETSSP value mismatch %h != %h", ex_sr_result, src_ar_val);
            $fatal;
        end
        if (ex_result !== src_ar_val[23:0]) begin
            $display("FAIL: SETSSP low 24b mismatch %h != %h", ex_result, src_ar_val[23:0]);
            $fatal;
        end

        // 3) SETSSP second edge case: highest AR index and negative value propagate correctly.
        reset_inputs();
        pc = 48'h0000_2110;
        opc = `OPC_SRMOVAur;
        root_opc = `OPC_SETSSP;
        tgt_sr = `SR_IDX_SSP;
        tgt_sr_we = 1'b1;
        src_ar = 2'd3;
        src_ar_val = 48'hFFFF_FFFF_F000;
        step();
        if (ex_sr_result !== src_ar_val) begin
            $display("FAIL: SETSSP sign-extended value lost (%h != %h)", ex_sr_result, src_ar_val);
            $fatal;
        end
        expect_no_branch();
        expect_no_trap();

        // 4) KRET should branch to LR contents.
        reset_inputs();
        pc = 48'h0000_2200;
        opc = `OPC_KRET;
        root_opc = `OPC_KRET;
        tgt_sr_val = 48'h0000_0ABC_DEF0;
        step();
        if (!branch_taken || (branch_pc !== tgt_sr_val)) begin
            $display("FAIL: KRET branch incorrect (taken=%b pc=%h expected=%h)", branch_taken, branch_pc, tgt_sr_val);
            $fatal;
        end
        expect_no_trap();
        if (halt) begin
            $display("FAIL: KRET should not assert halt");
            $fatal;
        end

        // 5) SYSCALL from user mode should branch to absolute target and write LR.
        reset_inputs();
        mode_kernel = 1'b0;
        pstate_val = 48'h0000_0000_0000;
        pc = 48'h0000_2300;
        program_uimm(2'b10, 12'h012);
        program_uimm(2'b01, 12'h345);
        program_uimm(2'b00, 12'h678);
        pc = 48'h0000_2310;
        opc = `OPC_SYSCALL;
        root_opc = `OPC_SYSCALL;
        instr = {`OPC_SYSCALL, 4'b0000, 12'h9AB};
        imm12_val = 12'h9AB;
        tgt_sr = `SR_IDX_LR;
        tgt_sr_we = 1'b1;
        step();
        if (!branch_taken) begin
            $display("FAIL: SYSCALL did not branch (valid banks)");
            $fatal;
        end
        if (branch_pc !== 48'h0123_4567_89AB) begin
            $display("FAIL: SYSCALL branch_pc %h expected 0123456789AB", branch_pc);
            $fatal;
        end
        if (!ex_tgt_sr_we || (ex_tgt_sr !== `SR_IDX_LR)) begin
            $display("FAIL: SYSCALL should target LR (we=%b tgt=%h)", ex_tgt_sr_we, ex_tgt_sr);
            $fatal;
        end
        if (ex_sr_result !== (pc + 48'd1)) begin
            $display("FAIL: SYSCALL LR write %h expected %h", ex_sr_result, pc + 48'd1);
            $fatal;
        end
        expect_no_trap();
        if (sr_aux_we) begin
            $display("FAIL: SYSCALL (valid banks) should not update PSTATE");
            $fatal;
        end

        // 6) SYSCALL with incomplete UIMM banks triggers trap and zero target.
        // Clear any cached UIMM banks to guarantee the validity bits are reset.
        reset_inputs();
        flush = 1'b1;
        opc = `OPC_NOP;
        root_opc = `OPC_NOP;
        step();
        flush = 1'b0;

        reset_inputs();
        mode_kernel = 1'b0;
        pstate_val = 48'h0000_0000_0000;
        pc = 48'h0000_2400;
        // Intentionally program only bank0 to leave others invalid.
        program_uimm(2'b00, 12'hAAA);
        pc = 48'h0000_2410;
        opc = `OPC_SYSCALL;
        root_opc = `OPC_SYSCALL;
        instr = {`OPC_SYSCALL, 4'b0000, 12'h055};
        imm12_val = 12'h055;
        tgt_sr = `SR_IDX_LR;
        tgt_sr_we = 1'b1;
        tgt_gp_we = 1'b1; // should be squashed by trap
        step();
        if (!branch_taken) begin
            $display("FAIL: SYSCALL trap should branch");
            $fatal;
        end
        if (!trap_pending) begin
            $display("FAIL: SYSCALL trap not flagged");
            $fatal;
        end
        if (branch_pc !== {36'd0, 12'hAAA, 12'h000}) begin
            $display("FAIL: SYSCALL trap branch_pc %h expected 000000AAA000", branch_pc);
            $fatal;
        end
        if (ex_sr_result !== (pc + 48'd1)) begin
            $display("FAIL: SYSCALL trap LR %h expected %h", ex_sr_result, pc + 48'd1);
            $fatal;
        end
        if (!ex_tgt_sr_we || (ex_tgt_sr !== `SR_IDX_LR)) begin
            $display("FAIL: SYSCALL trap should still write LR (we=%b tgt=%h)", ex_tgt_sr_we, ex_tgt_sr);
            $fatal;
        end
        if (ex_tgt_gp_we) begin
            $display("FAIL: SYSCALL trap should cancel GP writeback");
            $fatal;
        end
        if (!sr_aux_we || (sr_aux_addr !== `SR_IDX_PSTATE)) begin
            $display("FAIL: SYSCALL trap must update PSTATE (we=%b addr=%h)", sr_aux_we, sr_aux_addr);
            $fatal;
        end
        if (sr_aux_result[`PSTATE_BIT_TPE] !== 1'b1) begin
            $display("FAIL: SYSCALL trap missing TPE bit");
            $fatal;
        end
        if (sr_aux_result[`PSTATE_BIT_MODE] !== 1'b1) begin
            $display("FAIL: SYSCALL trap did not force kernel mode");
            $fatal;
        end
        if (sr_aux_result[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO] !== `PSTATE_CAUSE_UIMM_STATE) begin
            $display("FAIL: SYSCALL trap cause %h expected %h",
                sr_aux_result[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO], `PSTATE_CAUSE_UIMM_STATE);
            $fatal;
        end

        $display("opclass9_tb PASS");
        $finish;
    end
endmodule

