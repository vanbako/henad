`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/flags.vh"
`include "src/pstate.vh"
`include "src/sr.vh"

module ex_alu_unsigned_tb;
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
    wire                   sr_aux_we;
    wire [`HBIT_TGT_SR:0]  sr_aux_addr;
    wire [`HBIT_ADDR:0]    sr_aux_result;
    reg  [`HBIT_ADDR:0]    pstate;
    reg                    mode_kernel;
    reg  [`HBIT_DATA:0]    src_gp_val;
    reg  [`HBIT_DATA:0]    tgt_gp_val;
    reg  [`HBIT_ADDR:0]    src_ar_val;
    reg  [`HBIT_ADDR:0]    tgt_ar_val;
    reg  [`HBIT_ADDR:0]    src_sr_val;
    reg  [`HBIT_ADDR:0]    tgt_sr_val;
    reg                    flush;
    reg                    stall;

    stg_ex dut(
        .iw_clk(clk),
        .iw_rst(rst),
        .iw_pc(pc),
        .ow_pc(ex_pc),
        .iw_instr(instr),
        .ow_instr(ex_instr),
        .iw_opc(opc),
        .ow_opc(ex_opc),
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
        .iw_tgt_ar(tgt_ar),
        .ow_tgt_ar(ex_tgt_ar),
        .ow_tgt_ar_we(ex_tgt_ar_we),
        .iw_src_gp(src_gp),
        .iw_src_ar(src_ar),
        .iw_src_sr(src_sr),
        .ow_addr(ex_addr),
        .ow_result(ex_result),
        .ow_ar_result(ex_ar_result),
        .ow_sr_result(ex_sr_result),
        .ow_sr_aux_we(sr_aux_we),
        .ow_sr_aux_addr(sr_aux_addr),
        .ow_sr_aux_result(sr_aux_result),
        .ow_branch_taken(branch_taken),
        .ow_branch_pc(branch_pc),
        .iw_src_gp_val(src_gp_val),
        .iw_tgt_gp_val(tgt_gp_val),
        .iw_src_ar_val(src_ar_val),
        .iw_tgt_ar_val(tgt_ar_val),
        .iw_src_sr_val(src_sr_val),
        .iw_tgt_sr_val(tgt_sr_val),
        .iw_pstate_val(pstate),
        .iw_flush(flush),
        .iw_mode_kernel(mode_kernel),
        .iw_stall(stall)
    );

    task step; begin @(posedge clk); @(posedge clk); end endtask

    initial begin
        clk = 0; forever #5 clk = ~clk; end

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
                $display("FAIL (%s): flag addr mismatch %0d", label, sr_aux_addr);
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

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pstate <= {(`HBIT_ADDR+1){1'b0}};
        end else if (sr_aux_we) begin
            pstate <= sr_aux_result;
        end
    end

    initial begin
        rst = 1; stall = 0; flush = 0;
        pc = 0; instr = 0; opc = 0; sgn_en = 0; imm_en = 0;
        imm14_val = 0; imm12_val = 0; imm10_val = 0; imm16_val = 0;
        cc = 0; tgt_gp = 0; tgt_gp_we = 1; tgt_sr = 0; tgt_sr_we = 0; tgt_ar = 0;
        src_gp = 0; src_ar = 0; src_sr = 0;
        src_gp_val = 0; tgt_gp_val = 0; src_ar_val = 0; tgt_ar_val = 0; src_sr_val = 0; tgt_sr_val = 0;
        pstate = {(`HBIT_ADDR+1){1'b0}};
        mode_kernel = 1'b1;

        #12 rst = 0;

        // MOVur: DRt = DRs
        opc = `OPC_MOVur; src_gp_val = 24'h123456; tgt_gp_val = 24'hDEADBE; step();
        if (ex_result !== 24'h123456) $fatal;
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "MOVur flags");

        // MCCur: take when CC=EQ and Z=1
        // Provide flags via SR[FL]
        src_sr = 2'b10; // SR[FL]
        src_sr_val = {44'b0, 4'b0001}; // Z=1
        cc = `CC_EQ; opc = `OPC_MCCur; src_gp_val = 24'hAAAAAA; tgt_gp_val = 24'hBBBBBB; step();
        if (ex_result !== 24'hAAAAAA) $fatal;
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "MCCur take flags");
        // Not taken when Z=0
        src_sr_val = {44'b0, 4'b0000}; step();
        if (ex_result !== 24'hBBBBBB) $fatal;
        expect_flags(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "MCCur skip flags");

        // ADDur: result and flags Z,C
        opc = `OPC_ADDur; src_gp_val = 24'h000001; tgt_gp_val = 24'hFFFFFF; step();
        if (ex_result !== 24'h000000) $fatal;
        expect_flags(1'b1, 1'b1, 1'b0, 1'b1, 1'b0, "ADDur flags");

        // SUBur: 0 - 1 => borrow (C=1) and Z=0
        opc = `OPC_SUBur; src_gp_val = 24'h000001; tgt_gp_val = 24'h000000; step();
        if (ex_result !== 24'hFFFFFF) $fatal;
        expect_flags(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, "SUBur flags");

        // NOTur
        opc = `OPC_NOTur; tgt_gp_val = 24'h00FF00; step();
        if (ex_result !== 24'hFF00FF) $fatal;
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "NOTur flags");

        // AND/OR/XOR
        opc = `OPC_ANDur; src_gp_val = 24'h0F0F0F; tgt_gp_val = 24'h33CC33; step(); if (ex_result !== 24'h030C03) $fatal;
        opc = `OPC_ORur;  src_gp_val = 24'h0F0F0F; tgt_gp_val = 24'h33CC33; step(); if (ex_result !== 24'h3FCF3F) $fatal;
        opc = `OPC_XORur; src_gp_val = 24'h0F0F0F; tgt_gp_val = 24'h33CC33; step(); if (ex_result !== 24'h3CC33C) $fatal;

        // SHLur by variable amount; e.g. 1
        opc = `OPC_SHLur; src_gp_val = 24'h000001; tgt_gp_val = 24'h800001; step();
        if (ex_result !== 24'h000002) $fatal;

        // SHRur by variable amount; e.g. 1
        opc = `OPC_SHRur; src_gp_val = 24'h000001; tgt_gp_val = 24'h800001; step();
        if (ex_result !== 24'h400000) $fatal;

        // ROLur and RORur by 1
        opc = `OPC_ROLur; src_gp_val = 24'h000001; tgt_gp_val = 24'h800000; step();
        if (ex_result !== 24'h000001) $fatal;
        opc = `OPC_RORur; src_gp_val = 24'h000001; tgt_gp_val = 24'h000001; step();
        if (ex_result !== 24'h800000) $fatal;

        // CMPur: Z=1, C=1 when equal
        opc = `OPC_CMPur; src_gp_val = 24'h123456; tgt_gp_val = 24'h123456; step();
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "CMPur flags");

        // TSTur: Z reflects zero
        opc = `OPC_TSTur; tgt_gp_val = 24'h000000; step();
        expect_flags(1'b1, 1'b1, 1'b0, 1'b0, 1'b0, "TSTur flags");

        // ---- Immediate (OPCLASS_1) ----
        // LUIui bank0=0xABC; MOVui low=0xDEF => ir=0xABCDEF
        opc = `OPC_LUIui; instr[15:14] = 2'b00; imm12_val = 12'hABC; step(); // program bank0
        opc = `OPC_MOVui; imm12_val = 12'hDEF; step();
        if (ex_result !== 24'hABCDEF) $fatal;

        // For clarity, reprogram uimm to 0 and use small immediates
        opc = `OPC_LUIui; instr[15:14] = 2'b00; imm12_val = 12'h000; step();
        tgt_gp_val = 24'h000010; opc = `OPC_ADDui; imm12_val = 12'h001; step(); if (ex_result !== 24'h000011) $fatal;
        tgt_gp_val = 24'h000010; opc = `OPC_SUBui; imm12_val = 12'h002; step(); if (ex_result !== 24'h00000E) $fatal;
        tgt_gp_val = 24'h00FF00; opc = `OPC_ANDui; imm12_val = 12'hF00; step(); if (ex_result !== 24'h000F00) $fatal;
        tgt_gp_val = 24'h000F00; opc = `OPC_ORui;  imm12_val = 12'h00F; step(); if (ex_result !== 24'h000F0F) $fatal;
        tgt_gp_val = 24'h00F0F0; opc = `OPC_XORui; imm12_val = 12'h0F0; step(); if (ex_result !== 24'h00F000) $fatal;

        // SHLui/SHRui/ROLui/RORui with imm5 in low bits
        tgt_gp_val = 24'h000001; opc = `OPC_SHLui; imm12_val = 12'h001; step(); if (ex_result !== 24'h000002) $fatal;
        tgt_gp_val = 24'h000002; opc = `OPC_SHRui; imm12_val = 12'h001; step(); if (ex_result !== 24'h000001) $fatal;
        tgt_gp_val = 24'h800000; opc = `OPC_ROLui; imm12_val = 12'h001; step(); if (ex_result !== 24'h000001) $fatal;
        tgt_gp_val = 24'h000001; opc = `OPC_RORui; imm12_val = 12'h001; step(); if (ex_result !== 24'h800000) $fatal;

        // CMPui: compare target vs imm
        tgt_gp_val = 24'h001000; opc = `OPC_CMPui; imm12_val = 12'h001; step();
        expect_flags(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "CMPui flags");

        $display("ex_alu_unsigned_tb PASS");
        $finish;
    end
endmodule
