`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/cr.vh"

module opclassf_id_tb;
    reg                    clk;
    reg                    rst;
    reg  [`HBIT_ADDR:0]    pc;
    wire [`HBIT_ADDR:0]    id_pc;
    reg  [`HBIT_DATA:0]    instr;
    wire [`HBIT_DATA:0]    id_instr;
    reg  [`HBIT_OPC:0]     root_opc;
    wire [`HBIT_OPC:0]     id_opc;
    wire [`HBIT_OPC:0]     id_root_opc;
    wire                   sgn_en;
    wire                   imm_en;
    wire [`HBIT_IMM14:0]   imm14_val;
    wire [`HBIT_IMM12:0]   imm12_val;
    wire [`HBIT_IMM10:0]   imm10_val;
    wire [`HBIT_IMM16:0]   imm16_val;
    wire [`HBIT_CC:0]      cc;
    wire                   has_src_gp;
    wire [`HBIT_ADDR_GP:0] src_gp;
    wire [`HBIT_ADDR_GP:0] tgt_gp;
    wire                   tgt_gp_we;
    wire                   has_src_ar;
    wire [`HBIT_TGT_AR:0]  src_ar;
    wire                   has_tgt_ar;
    wire [`HBIT_TGT_AR:0]  tgt_ar;
    wire                   has_src_sr;
    wire [`HBIT_ADDR_SR:0] src_sr;
    wire [`HBIT_ADDR_SR:0] tgt_sr;
    wire                   tgt_sr_we;
    reg                    flush;
    reg                    stall;

    stg_id dut(
        .iw_clk       (clk),
        .iw_rst       (rst),
        .iw_pc        (pc),
        .ow_pc        (id_pc),
        .iw_instr     (instr),
        .iw_root_opc  (root_opc),
        .ow_instr     (id_instr),
        .ow_opc       (id_opc),
        .ow_root_opc  (id_root_opc),
        .ow_sgn_en    (sgn_en),
        .ow_imm_en    (imm_en),
        .ow_imm14_val (imm14_val),
        .ow_imm12_val (imm12_val),
        .ow_imm10_val (imm10_val),
        .ow_imm16_val (imm16_val),
        .ow_cc        (cc),
        .ow_has_src_gp(has_src_gp),
        .ow_src_gp    (src_gp),
        .ow_tgt_gp    (tgt_gp),
        .ow_tgt_gp_we (tgt_gp_we),
        .ow_has_src_ar(has_src_ar),
        .ow_src_ar    (src_ar),
        .ow_has_tgt_ar(has_tgt_ar),
        .ow_tgt_ar    (tgt_ar),
        .ow_has_src_sr(has_src_sr),
        .ow_src_sr    (src_sr),
        .ow_tgt_sr    (tgt_sr),
        .ow_tgt_sr_we (tgt_sr_we),
        .iw_flush     (flush),
        .iw_stall     (stall)
    );

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task automatic step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    localparam [23:0] INSTR_SRJCC = { `OPC_SRJCCso, `SR_IDX_PC, `CC_EQ, 10'd3 };
    localparam [23:0] INSTR_SR2CR = { `OPC_SR2CR,  2'd2,        `SR_IDX_SSP, `CR_FLD_CUR, 8'h00 };

    initial begin
        rst   = 1'b1;
        flush = 1'b0;
        stall = 1'b0;
        pc    = 48'h0000_0100;
        instr = { `OPC_NOP, 16'h0000 };
        root_opc = `OPC_NOP;

        step();
        step();
        rst = 1'b0;

        // Hold a cycle after reset deassertion
        instr = { `OPC_NOP, 16'h0000 };
        root_opc = `OPC_NOP;
        step();

        // ---- Test SRJCCso ----
        instr    = INSTR_SRJCC;
        root_opc = `OPC_SRJCCso;
        pc       = 48'h0000_0200;
        step();

        if (!has_src_sr) begin
            $display("FAIL: SRJCCso did not assert has_src_sr");
            $fatal;
        end
        if (src_sr !== `SR_IDX_FL) begin
            $display("FAIL: SRJCCso src_sr=%0d expected FL(%0d)", src_sr, `SR_IDX_FL);
            $fatal;
        end
        if (tgt_sr !== `SR_IDX_PC) begin
            $display("FAIL: SRJCCso tgt_sr=%0d expected PC(%0d)", tgt_sr, `SR_IDX_PC);
            $fatal;
        end
        if (tgt_sr_we !== 1'b0) begin
            $display("FAIL: SRJCCso unexpectedly asserted tgt_sr_we");
            $fatal;
        end
        if (imm10_val !== 10'd3) begin
            $display("FAIL: SRJCCso imm10=%0d expected 3", imm10_val);
            $fatal;
        end
        if (cc !== `CC_EQ) begin
            $display("FAIL: SRJCCso cc=%0d expected CC_EQ", cc);
            $fatal;
        end

        // Clear instruction between tests
        instr    = { `OPC_NOP, 16'h0000 };
        root_opc = `OPC_NOP;
        step();

        // ---- Test SR2CR ----
        instr    = INSTR_SR2CR;
        root_opc = `OPC_SR2CR;
        step();

        if (!has_src_sr) begin
            $display("FAIL: SR2CR did not assert has_src_sr");
            $fatal;
        end
        if (src_sr !== `SR_IDX_SSP) begin
            $display("FAIL: SR2CR src_sr=%0d expected SSP(%0d)", src_sr, `SR_IDX_SSP);
            $fatal;
        end
        if (!has_tgt_ar) begin
            $display("FAIL: SR2CR did not assert has_tgt_ar");
            $fatal;
        end
        if (tgt_ar !== 2'd2) begin
            $display("FAIL: SR2CR tgt_ar=%0d expected 2", tgt_ar);
            $fatal;
        end
        if (tgt_sr_we !== 1'b0) begin
            $display("FAIL: SR2CR unexpectedly asserted tgt_sr_we");
            $fatal;
        end

        $display("opclassf_id_tb PASS");
        $finish;
    end
endmodule
