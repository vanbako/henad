`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/flags.vh"

module ex_alu_signed_tb;
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
        pc = 0; instr = 0; opc = 0; sgn_en = 1; imm_en = 1;
        imm14_val = 0; imm12_val = 0; imm10_val = 0; imm16_val = 0;
        cc = 0; tgt_gp = 0; tgt_gp_we = 1; tgt_sr = 0; tgt_sr_we = 0; tgt_ar = 0;
        src_gp = 0; src_ar = 0; src_sr = 0;
        src_gp_val = 0; tgt_gp_val = 0; src_ar_val = 0; tgt_ar_val = 0; src_sr_val = 0; tgt_sr_val = 0;
        #12 rst = 0;

        // NEGsr: -1 -> 0xFFFFFF with N=1, Z=0, V=0
        opc = `OPC_NEGsr; tgt_gp_val = 24'h000001; step();
        if (ex_result !== 24'hFFFFFF) $fatal;
        if (!ex_tgt_sr_we || ex_sr_result[0] !== 1'b0 /*Z*/ || ex_sr_result[1] !== 1'b1 /*N*/ || ex_sr_result[3] !== 1'b0 /*V*/) $fatal;

        // ADDsr signed overflow case: 0x7FFFFF + 1 => V=1, N=1
        opc = `OPC_ADDsr; tgt_gp_val = 24'h7FFFFF; src_gp_val = 24'h000001; step();
        if (!ex_tgt_sr_we || ex_sr_result[1] !== 1'b1 || ex_sr_result[3] !== 1'b1) $fatal;

        // SUBsr signed overflow case: (-2^23) - 1 => V=1
        opc = `OPC_SUBsr; tgt_gp_val = 24'h800000; src_gp_val = 24'h000001; step();
        if (!ex_tgt_sr_we || ex_sr_result[3] !== 1'b1) $fatal;

        // SHRsr variable: arithmetic shift keeps sign
        opc = `OPC_SHRsr; tgt_gp_val = 24'h800002; src_gp_val = 24'h000001; step();
        if (ex_result[23] !== 1'b1) $fatal;

        // CMPsr: Z,N,V set appropriately (compare -1 vs 1)
        opc = `OPC_CMPsr; tgt_gp_val = 24'hFFFFFF; src_gp_val = 24'h000001; step();
        if (!ex_tgt_sr_we) $fatal;

        // TSTsr: N reflects sign, Z reflects zero
        opc = `OPC_TSTsr; tgt_gp_val = 24'h800000; step(); if (!ex_tgt_sr_we || ex_sr_result[1] !== 1'b1) $fatal;

        // MOVsi: sign-extend imm12
        opc = `OPC_MOVsi; imm12_val = 12'hF80; step(); if (ex_result !== 24'hFFFF80) $fatal;
        // MCCsi: take if CC and flags say so (use Z=1)
        src_sr = 2'b10; src_sr_val = {44'b0, 4'b0001}; cc = `CC_EQ; opc = `OPC_MCCsi; instr[7:0] = 8'h80; step();
        if (ex_result !== 24'hFFFF80) $fatal; // sext(0x80)

        // ADDsi and SUBsi
        opc = `OPC_ADDsi; tgt_gp_val = 24'h000010; imm12_val = 12'h002; step(); if (ex_result !== 24'h000012) $fatal;
        opc = `OPC_SUBsi; tgt_gp_val = 24'h000010; imm12_val = 12'h004; step(); if (ex_result !== 24'h00000C) $fatal;

        // SHRsi immediate arithmetic shift
        opc = `OPC_SHRsi; tgt_gp_val = 24'h800000; imm12_val = 12'h001; step(); if (ex_result !== 24'hC00000) $fatal;

        // CMPsi
        opc = `OPC_CMPsi; tgt_gp_val = 24'h000000; imm12_val = 12'h000; step(); if (!ex_tgt_sr_we || ex_sr_result[0] !== 1'b1) $fatal;

        $display("ex_alu_signed_tb PASS");
        $finish;
    end
endmodule
