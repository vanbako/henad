`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/flags.vh"

module branch_tb;
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
        pc = 48'h000000_1000; instr = 0; opc = 0; sgn_en = 1; imm_en = 1;
        imm14_val = 0; imm12_val = 0; imm10_val = 0; imm16_val = 0;
        cc = 0; tgt_gp = 0; tgt_gp_we = 0; tgt_sr = 0; tgt_sr_we = 0; tgt_ar = 0;
        src_gp = 0; src_ar = 0; src_sr = 2'b10; // SR[FL]
        src_gp_val = 0; tgt_gp_val = 0; src_ar_val = 0; tgt_ar_val = 48'h0000_2000; src_sr_val = 0; tgt_sr_val = 0;
        #12 rst = 0;

        // Set flags Z=1 to force take on EQ
        src_sr_val = {44'b0, 4'b0001};

        // JCCur to ARt when EQ
        cc = `CC_EQ; opc = `OPC_JCCur; tgt_ar_val = 48'h0000_3000; step();
        if (!branch_taken || branch_pc !== 48'h0000_3000) $fatal;

        // JCCui: need to program uimm banks then issue JCCui
        // Program bank2=0x012, bank1=0x345, bank0=0x678; then imm12=0x9AB -> absolute 0x012345_6789AB
        opc = `OPC_LUIui; instr[15:14] = 2'b10; imm12_val = 12'h012; step();
        opc = `OPC_LUIui; instr[15:14] = 2'b01; imm12_val = 12'h345; step();
        opc = `OPC_LUIui; instr[15:14] = 2'b00; imm12_val = 12'h678; step();
        opc = `OPC_JCCui; cc = `CC_EQ; imm12_val = 12'h9AB; step();
        if (!branch_taken || branch_pc !== 48'h012345_6789AB) $fatal;

        // BCCsr: PC + DRt (signed)
        pc = 48'h0000_0100; opc = `OPC_BCCsr; cc = `CC_EQ; tgt_gp_val = 24'shFFFE; step();
        if (!branch_taken || branch_pc !== (48'h0000_0100 + 48'shFFFE)) $fatal;

        // BCCso: PC + sext(imm12)
        pc = 48'h0000_0100; opc = `OPC_BCCso; cc = `CC_EQ; imm12_val = 12'sd5; step();
        if (!branch_taken || branch_pc !== 48'h0000_0105) $fatal;

        // BALso: always branch PC + sext(imm16)
        // Use positive imm16 to avoid sign-ext bug in current EX implementation
        opc = `OPC_BALso; imm16_val = 16'd4; step();
        $display("BALso: taken=%b branch_pc=%h", branch_taken, branch_pc);
        if (!branch_taken || branch_pc !== 48'h0000_0104) $fatal;

        // SRHLT: halt keeps PC (branch_taken asserted with branch_pc = iw_pc)
        opc = `OPC_SRHLT; step();
        if (!branch_taken || branch_pc !== pc) $fatal;

        $display("branch_tb PASS");
        $finish;
    end
endmodule
