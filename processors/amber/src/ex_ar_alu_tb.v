`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/sizes.vh"
`include "src/flags.vh"

module ex_ar_alu_tb;
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
        .iw_flush(flush), .iw_stall(stall)
    );

    task step; begin @(posedge clk); @(posedge clk); end endtask

    initial begin clk = 0; forever #5 clk = ~clk; end

    initial begin
        rst = 1; stall = 0; flush = 0;
        pc = 48'h000010; instr = 0; opc = 0; sgn_en = 1; imm_en = 1;
        imm14_val = 0; imm12_val = 0; imm10_val = 0; imm16_val = 0;
        cc = 0; tgt_gp = 0; tgt_gp_we = 1; tgt_sr = 0; tgt_sr_we = 0; tgt_ar = 0;
        src_gp = 0; src_ar = 0; src_sr = 0;
        src_gp_val = 0; tgt_gp_val = 0; src_ar_val = 0; tgt_ar_val = 0; src_sr_val = 0; tgt_sr_val = 0;
        #12 rst = 0;

        // MOVAur: write DRs into ARt low half (L=0)
        opc = `OPC_MOVAur; instr[9] = 1'b0; src_gp_val = 24'hAAAAAA; tgt_ar_val = 48'h111122_333344; step();
        if (!ex_tgt_ar_we || ex_ar_result !== 48'h111122_AAAAAA) $fatal;
        // MOVAur: high half (H=1)
        opc = `OPC_MOVAur; instr[9] = 1'b1; src_gp_val = 24'hBBBBBB; tgt_ar_val = 48'h111122_333344; step();
        if (!ex_tgt_ar_we || ex_ar_result !== 48'hBBBBBB_333344) $fatal;

        // MOVDur: read low half (L=0)
        opc = `OPC_MOVDur; instr[9] = 1'b0; src_ar_val = 48'hABCDEF_012345; step(); if (ex_result !== 24'h012345) $fatal;
        // MOVDur: high half (H=1)
        opc = `OPC_MOVDur; instr[9] = 1'b1; src_ar_val = 48'hABCDEF_012345; step(); if (ex_result !== 24'hABCDEF) $fatal;

        // ADDAur/SUBAur (unsigned)
        opc = `OPC_ADDAur; tgt_ar_val = 48'h000000_000100; src_gp_val = 24'h000002; step(); if (!ex_tgt_ar_we || ex_ar_result !== 48'h000000_000102) $fatal;
        opc = `OPC_SUBAur; tgt_ar_val = 48'h000000_000100; src_gp_val = 24'h000002; step(); if (!ex_tgt_ar_we || ex_ar_result !== 48'h000000_0000FE) $fatal;

        // ADDAsr/SUBAsr (signed)
        opc = `OPC_ADDAsr; tgt_ar_val = 48'h000000_000100; src_gp_val = 24'hFFFFFF; step(); if (!ex_tgt_ar_we || ex_ar_result !== 48'h000000_0000FF) $fatal;
        opc = `OPC_SUBAsr; tgt_ar_val = 48'h000000_000100; src_gp_val = 24'hFFFFFF; step(); if (!ex_tgt_ar_we || ex_ar_result !== 48'h000000_000101) $fatal;

        // ADDAsi/SUBAsi
        opc = `OPC_ADDAsi; tgt_ar_val = 48'h000000_000100; imm12_val = -12'sd2; step(); if (!ex_tgt_ar_we || ex_ar_result !== 48'h000000_0000FE) $fatal;
        opc = `OPC_SUBAsi; tgt_ar_val = 48'h000000_000100; imm12_val = -12'sd2; step(); if (!ex_tgt_ar_we || ex_ar_result !== 48'h000000_000102) $fatal;

        // LEAso: ARt = ARs + sext(imm12)
        opc = `OPC_LEAso; src_ar_val = 48'h000000_000200; imm12_val = -12'sd3; step(); if (!ex_tgt_ar_we || ex_ar_result !== 48'h000000_0001FD) $fatal;

        // LDAso: address computed; AR write enable asserted (value assembled in MO later)
        opc = `OPC_LDAso; src_ar_val = 48'h000000_000010; imm12_val = 12'sd4; step();
        if (!ex_tgt_ar_we || ex_addr !== 48'h000000_000014) $fatal;

        // ADRAso: PC + sext(imm14)
        opc = `OPC_ADRAso; imm14_val = 14'sd8; pc = 48'h000000_001000; step();
        if (!ex_tgt_ar_we || ex_ar_result !== 48'h000000_001008) $fatal;

        // CMPAur/TSTAur
        opc = `OPC_CMPAur; src_ar_val = 48'h1; tgt_ar_val = 48'h2; step(); if (!ex_tgt_sr_we) $fatal;
        opc = `OPC_TSTAur; tgt_ar_val = 48'h0; step(); if (!ex_tgt_sr_we || ex_sr_result[0] !== 1'b1) $fatal;

        $display("ex_ar_alu_tb PASS");
        $finish;
    end
endmodule
