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

    task automatic expect_common(
        input [`HBIT_OPC:0] exp_opc,
        input [`HBIT_OPC:0] exp_root_opc,
        input [`HBIT_ADDR:0] exp_pc,
        input [`HBIT_DATA:0] exp_instr
    );
        begin
            if (id_opc !== exp_opc) begin
                $display("FAIL: id_opc=%0h expected %0h", id_opc, exp_opc);
                $fatal;
            end
            if (id_root_opc !== exp_root_opc) begin
                $display("FAIL: id_root_opc=%0h expected %0h", id_root_opc, exp_root_opc);
                $fatal;
            end
            if (id_pc !== exp_pc) begin
                $display("FAIL: id_pc=%0h expected %0h", id_pc, exp_pc);
                $fatal;
            end
            if (id_instr !== exp_instr) begin
                $display("FAIL: id_instr=%0h expected %0h", id_instr, exp_instr);
                $fatal;
            end
        end
    endtask

    function automatic [23:0] make_srmovur;
        input [1:0] src_sr;
        input [1:0] tgt_sr;
        begin
            make_srmovur = { `OPC_SRMOVur, tgt_sr, src_sr, 12'd0 };
        end
    endfunction

    function automatic [23:0] make_srmovaur;
        input [1:0] src_ar;
        input [1:0] tgt_sr;
        begin
            make_srmovaur = { `OPC_SRMOVAur, tgt_sr, src_ar, 12'd0 };
        end
    endfunction

    function automatic [23:0] make_sraddsi;
        input [1:0] tgt_sr;
        input [13:0] imm14;
        begin
            make_sraddsi = { `OPC_SRADDsi, tgt_sr, imm14 };
        end
    endfunction

    function automatic [23:0] make_srsubsi;
        input [1:0] tgt_sr;
        input [13:0] imm14;
        begin
            make_srsubsi = { `OPC_SRSUBsi, tgt_sr, imm14 };
        end
    endfunction

    function automatic [23:0] make_srstso;
        input [1:0] tgt_sr;
        input [1:0] src_sr;
        input [11:0] imm12;
        begin
            make_srstso = { `OPC_SRSTso, tgt_sr, src_sr, imm12 };
        end
    endfunction

    function automatic [23:0] make_srldso;
        input [1:0] tgt_sr;
        input [1:0] src_sr;
        input [11:0] imm12;
        begin
            make_srldso = { `OPC_SRLDso, tgt_sr, src_sr, imm12 };
        end
    endfunction

    function automatic [23:0] make_cr2sr;
        input [1:0] tgt_sr;
        input [1:0] src_cr;
        input [3:0] fld;
        begin
            make_cr2sr = { `OPC_CR2SR, tgt_sr, src_cr, fld, 8'b0 };
        end
    endfunction

    function automatic [23:0] make_sr2cr;
        input [1:0] tgt_cr;
        input [1:0] src_sr;
        input [3:0] fld;
        begin
            make_sr2cr = { `OPC_SR2CR, tgt_cr, src_sr, fld, 8'b0 };
        end
    endfunction

    function automatic [23:0] make_srjccso;
        input [1:0] tgt_sr;
        input [3:0] cc_val;
        input [9:0] imm10;
        begin
            make_srjccso = { `OPC_SRJCCso, tgt_sr, cc_val, imm10 };
        end
    endfunction

    localparam [23:0] INSTR_NOP = { `OPC_NOP, 16'h0000 };
    localparam [13:0] IMM14_POS_MAX = 14'h1FFF;
    localparam [13:0] IMM14_NEG_ONE = 14'h3FFF;
    localparam [11:0] IMM12_POS_MAX = 12'h7FF;
    localparam [11:0] IMM12_NEG_MIN = 12'h800;
    localparam [9:0]  IMM10_POS_FIVE = 10'd5;
    localparam [9:0]  IMM10_NEG_ONE = 10'h3FF;

    initial begin
        rst   = 1'b1;
        flush = 1'b0;
        stall = 1'b0;
        pc    = 48'h0000_0000;
        instr = INSTR_NOP;
        root_opc = `OPC_NOP;

        step();
        step();
        rst = 1'b0;

        instr = INSTR_NOP;
        root_opc = `OPC_NOP;
        pc = 48'h0000_0010;
        step();

        // SRMOVur SRs=FL -> SRt=PC
        pc    = 48'h0000_0100;
        instr = make_srmovur(`SR_IDX_FL, `SR_IDX_PC);
        root_opc = `OPC_SRMOVur;
        step();
        expect_common(`OPC_SRMOVur, `OPC_SRMOVur, pc, instr);
        if (!has_src_sr) begin
            $display("FAIL: SRMOVur missing has_src_sr");
            $fatal;
        end
        if (src_sr !== `SR_IDX_FL) begin
            $display("FAIL: SRMOVur src_sr=%0d expected FL", src_sr);
            $fatal;
        end
        if (tgt_sr !== `SR_IDX_PC) begin
            $display("FAIL: SRMOVur tgt_sr=%0d expected PC", tgt_sr);
            $fatal;
        end
        if (tgt_sr_we !== 1'b1) begin
            $display("FAIL: SRMOVur expected tgt_sr_we=1");
            $fatal;
        end
        if (imm_en !== 1'b0) begin
            $display("FAIL: SRMOVur imm_en asserted");
            $fatal;
        end
        if (sgn_en !== 1'b0) begin
            $display("FAIL: SRMOVur sgn_en asserted");
            $fatal;
        end
        if (imm14_val !== 14'd0) begin
            $display("FAIL: SRMOVur imm14=%0d expected 0", imm14_val);
            $fatal;
        end
        if (imm12_val !== 12'd0) begin
            $display("FAIL: SRMOVur imm12=%0d expected 0", imm12_val);
            $fatal;
        end
        if (imm10_val !== 10'd0) begin
            $display("FAIL: SRMOVur imm10=%0d expected 0", imm10_val);
            $fatal;
        end
        if (imm16_val !== 16'd0) begin
            $display("FAIL: SRMOVur imm16=%0d expected 0", imm16_val);
            $fatal;
        end
        if (cc !== 4'd0) begin
            $display("FAIL: SRMOVur cc=%0d expected 0", cc);
            $fatal;
        end
        if (has_src_ar !== 1'b0) begin
            $display("FAIL: SRMOVur has_src_ar asserted");
            $fatal;
        end
        if (has_tgt_ar !== 1'b0) begin
            $display("FAIL: SRMOVur has_tgt_ar asserted");
            $fatal;
        end
        if (has_src_gp !== 1'b0) begin
            $display("FAIL: SRMOVur has_src_gp asserted");
            $fatal;
        end
        if (tgt_gp_we !== 1'b0) begin
            $display("FAIL: SRMOVur tgt_gp_we asserted");
            $fatal;
        end

        instr = INSTR_NOP;
        root_opc = `OPC_NOP;
        pc = 48'h0000_0000;
        step();

        // SRMOVAur AR3 -> SRt=SSP
        pc    = 48'h0000_0110;
        instr = make_srmovaur(2'd3, `SR_IDX_SSP);
        root_opc = `OPC_SRMOVAur;
        step();
        expect_common(`OPC_SRMOVAur, `OPC_SRMOVAur, pc, instr);
        if (has_src_sr !== 1'b0) begin
            $display("FAIL: SRMOVAur has_src_sr asserted");
            $fatal;
        end
        if (!has_src_ar) begin
            $display("FAIL: SRMOVAur missing has_src_ar");
            $fatal;
        end
        if (src_ar !== 2'd3) begin
            $display("FAIL: SRMOVAur src_ar=%0d expected 3", src_ar);
            $fatal;
        end
        if (tgt_sr !== `SR_IDX_SSP) begin
            $display("FAIL: SRMOVAur tgt_sr=%0d expected SSP", tgt_sr);
            $fatal;
        end
        if (tgt_sr_we !== 1'b1) begin
            $display("FAIL: SRMOVAur expected tgt_sr_we=1");
            $fatal;
        end
        if (has_tgt_ar !== 1'b0) begin
            $display("FAIL: SRMOVAur has_tgt_ar asserted");
            $fatal;
        end
        if (imm_en !== 1'b0) begin
            $display("FAIL: SRMOVAur imm_en asserted");
            $fatal;
        end
        if (sgn_en !== 1'b0) begin
            $display("FAIL: SRMOVAur sgn_en asserted");
            $fatal;
        end
        if (imm14_val !== 14'd0) begin
            $display("FAIL: SRMOVAur imm14=%0d expected 0", imm14_val);
            $fatal;
        end
        if (imm12_val !== 12'd0) begin
            $display("FAIL: SRMOVAur imm12=%0d expected 0", imm12_val);
            $fatal;
        end
        if (imm10_val !== 10'd0) begin
            $display("FAIL: SRMOVAur imm10=%0d expected 0", imm10_val);
            $fatal;
        end
        if (imm16_val !== 16'd0) begin
            $display("FAIL: SRMOVAur imm16=%0d expected 0", imm16_val);
            $fatal;
        end
        if (cc !== 4'd0) begin
            $display("FAIL: SRMOVAur cc=%0d expected 0", cc);
            $fatal;
        end
        if (has_src_gp !== 1'b0) begin
            $display("FAIL: SRMOVAur has_src_gp asserted");
            $fatal;
        end
        if (tgt_gp_we !== 1'b0) begin
            $display("FAIL: SRMOVAur tgt_gp_we asserted");
            $fatal;
        end

        instr = INSTR_NOP;
        root_opc = `OPC_NOP;
        pc = 48'h0000_0000;
        step();

        // SRADDsi imm14=+8191 to LR
        pc    = 48'h0000_0120;
        instr = make_sraddsi(`SR_IDX_LR, IMM14_POS_MAX);
        root_opc = `OPC_SRADDsi;
        step();
        expect_common(`OPC_SRADDsi, `OPC_SRADDsi, pc, instr);
        if (has_src_sr !== 1'b0) begin
            $display("FAIL: SRADDsi has_src_sr asserted");
            $fatal;
        end
        if (tgt_sr !== `SR_IDX_LR) begin
            $display("FAIL: SRADDsi tgt_sr=%0d expected LR", tgt_sr);
            $fatal;
        end
        if (tgt_sr_we !== 1'b1) begin
            $display("FAIL: SRADDsi expected tgt_sr_we=1");
            $fatal;
        end
        if (imm_en !== 1'b1) begin
            $display("FAIL: SRADDsi imm_en expected 1");
            $fatal;
        end
        if (sgn_en !== 1'b1) begin
            $display("FAIL: SRADDsi sgn_en expected 1");
            $fatal;
        end
        if (imm14_val !== IMM14_POS_MAX) begin
            $display("FAIL: SRADDsi imm14=%0h expected %0h", imm14_val, IMM14_POS_MAX);
            $fatal;
        end
        if (imm12_val !== 12'd0) begin
            $display("FAIL: SRADDsi imm12=%0d expected 0", imm12_val);
            $fatal;
        end
        if (imm10_val !== 10'd0) begin
            $display("FAIL: SRADDsi imm10=%0d expected 0", imm10_val);
            $fatal;
        end
        if (imm16_val !== 16'd0) begin
            $display("FAIL: SRADDsi imm16=%0d expected 0", imm16_val);
            $fatal;
        end
        if (cc !== 4'd0) begin
            $display("FAIL: SRADDsi cc=%0d expected 0", cc);
            $fatal;
        end
        if (has_src_ar !== 1'b0) begin
            $display("FAIL: SRADDsi has_src_ar asserted");
            $fatal;
        end
        if (has_tgt_ar !== 1'b0) begin
            $display("FAIL: SRADDsi has_tgt_ar asserted");
            $fatal;
        end
        if (has_src_gp !== 1'b0) begin
            $display("FAIL: SRADDsi has_src_gp asserted");
            $fatal;
        end
        if (tgt_gp_we !== 1'b0) begin
            $display("FAIL: SRADDsi tgt_gp_we asserted");
            $fatal;
        end

        instr = INSTR_NOP;
        root_opc = `OPC_NOP;
        pc = 48'h0000_0000;
        step();

        // SRSUBsi imm14=-1 to PC
        pc    = 48'h0000_0130;
        instr = make_srsubsi(`SR_IDX_PC, IMM14_NEG_ONE);
        root_opc = `OPC_SRSUBsi;
        step();
        expect_common(`OPC_SRSUBsi, `OPC_SRSUBsi, pc, instr);
        if (has_src_sr !== 1'b0) begin
            $display("FAIL: SRSUBsi has_src_sr asserted");
            $fatal;
        end
        if (tgt_sr !== `SR_IDX_PC) begin
            $display("FAIL: SRSUBsi tgt_sr=%0d expected PC", tgt_sr);
            $fatal;
        end
        if (tgt_sr_we !== 1'b1) begin
            $display("FAIL: SRSUBsi expected tgt_sr_we=1");
            $fatal;
        end
        if (imm_en !== 1'b1) begin
            $display("FAIL: SRSUBsi imm_en expected 1");
            $fatal;
        end
        if (sgn_en !== 1'b1) begin
            $display("FAIL: SRSUBsi sgn_en expected 1");
            $fatal;
        end
        if (imm14_val !== IMM14_NEG_ONE) begin
            $display("FAIL: SRSUBsi imm14=%0h expected %0h", imm14_val, IMM14_NEG_ONE);
            $fatal;
        end
        if (imm12_val !== 12'd0) begin
            $display("FAIL: SRSUBsi imm12=%0d expected 0", imm12_val);
            $fatal;
        end
        if (imm10_val !== 10'd0) begin
            $display("FAIL: SRSUBsi imm10=%0d expected 0", imm10_val);
            $fatal;
        end
        if (imm16_val !== 16'd0) begin
            $display("FAIL: SRSUBsi imm16=%0d expected 0", imm16_val);
            $fatal;
        end
        if (cc !== 4'd0) begin
            $display("FAIL: SRSUBsi cc=%0d expected 0", cc);
            $fatal;
        end
        if (has_src_ar !== 1'b0) begin
            $display("FAIL: SRSUBsi has_src_ar asserted");
            $fatal;
        end
        if (has_tgt_ar !== 1'b0) begin
            $display("FAIL: SRSUBsi has_tgt_ar asserted");
            $fatal;
        end
        if (has_src_gp !== 1'b0) begin
            $display("FAIL: SRSUBsi has_src_gp asserted");
            $fatal;
        end
        if (tgt_gp_we !== 1'b0) begin
            $display("FAIL: SRSUBsi tgt_gp_we asserted");
            $fatal;
        end

        instr = INSTR_NOP;
        root_opc = `OPC_NOP;
        pc = 48'h0000_0000;
        step();

        // SRSTso SRs=LR -> [PC+imm12]
        pc    = 48'h0000_0140;
        instr = make_srstso(`SR_IDX_PC, `SR_IDX_LR, IMM12_NEG_MIN);
        root_opc = `OPC_SRSTso;
        step();
        expect_common(`OPC_SRSTso, `OPC_SRSTso, pc, instr);
        if (!has_src_sr) begin
            $display("FAIL: SRSTso missing has_src_sr");
            $fatal;
        end
        if (src_sr !== `SR_IDX_LR) begin
            $display("FAIL: SRSTso src_sr=%0d expected LR", src_sr);
            $fatal;
        end
        if (tgt_sr !== `SR_IDX_PC) begin
            $display("FAIL: SRSTso tgt_sr=%0d expected PC", tgt_sr);
            $fatal;
        end
        if (tgt_sr_we !== 1'b0) begin
            $display("FAIL: SRSTso unexpectedly asserted tgt_sr_we");
            $fatal;
        end
        if (imm_en !== 1'b1) begin
            $display("FAIL: SRSTso imm_en expected 1");
            $fatal;
        end
        if (sgn_en !== 1'b1) begin
            $display("FAIL: SRSTso sgn_en expected 1");
            $fatal;
        end
        if (imm12_val !== IMM12_NEG_MIN) begin
            $display("FAIL: SRSTso imm12=%0h expected %0h", imm12_val, IMM12_NEG_MIN);
            $fatal;
        end
        if (imm14_val !== 14'd0) begin
            $display("FAIL: SRSTso imm14=%0d expected 0", imm14_val);
            $fatal;
        end
        if (imm10_val !== 10'd0) begin
            $display("FAIL: SRSTso imm10=%0d expected 0", imm10_val);
            $fatal;
        end
        if (imm16_val !== 16'd0) begin
            $display("FAIL: SRSTso imm16=%0d expected 0", imm16_val);
            $fatal;
        end
        if (cc !== 4'd0) begin
            $display("FAIL: SRSTso cc=%0d expected 0", cc);
            $fatal;
        end
        if (has_src_ar !== 1'b0) begin
            $display("FAIL: SRSTso has_src_ar asserted");
            $fatal;
        end
        if (has_tgt_ar !== 1'b0) begin
            $display("FAIL: SRSTso has_tgt_ar asserted");
            $fatal;
        end
        if (has_src_gp !== 1'b0) begin
            $display("FAIL: SRSTso has_src_gp asserted");
            $fatal;
        end
        if (tgt_gp_we !== 1'b0) begin
            $display("FAIL: SRSTso tgt_gp_we asserted");
            $fatal;
        end

        instr = INSTR_NOP;
        root_opc = `OPC_NOP;
        pc = 48'h0000_0000;
        step();

        // SRLDso [SSP+imm12] -> SRt=LR
        pc    = 48'h0000_0150;
        instr = make_srldso(`SR_IDX_LR, `SR_IDX_SSP, IMM12_POS_MAX);
        root_opc = `OPC_SRLDso;
        step();
        expect_common(`OPC_SRLDso, `OPC_SRLDso, pc, instr);
        if (!has_src_sr) begin
            $display("FAIL: SRLDso missing has_src_sr");
            $fatal;
        end
        if (src_sr !== `SR_IDX_SSP) begin
            $display("FAIL: SRLDso src_sr=%0d expected SSP", src_sr);
            $fatal;
        end
        if (tgt_sr !== `SR_IDX_LR) begin
            $display("FAIL: SRLDso tgt_sr=%0d expected LR", tgt_sr);
            $fatal;
        end
        if (tgt_sr_we !== 1'b1) begin
            $display("FAIL: SRLDso expected tgt_sr_we=1");
            $fatal;
        end
        if (imm_en !== 1'b1) begin
            $display("FAIL: SRLDso imm_en expected 1");
            $fatal;
        end
        if (sgn_en !== 1'b1) begin
            $display("FAIL: SRLDso sgn_en expected 1");
            $fatal;
        end
        if (imm12_val !== IMM12_POS_MAX) begin
            $display("FAIL: SRLDso imm12=%0h expected %0h", imm12_val, IMM12_POS_MAX);
            $fatal;
        end
        if (imm14_val !== 14'd0) begin
            $display("FAIL: SRLDso imm14=%0d expected 0", imm14_val);
            $fatal;
        end
        if (imm10_val !== 10'd0) begin
            $display("FAIL: SRLDso imm10=%0d expected 0", imm10_val);
            $fatal;
        end
        if (imm16_val !== 16'd0) begin
            $display("FAIL: SRLDso imm16=%0d expected 0", imm16_val);
            $fatal;
        end
        if (cc !== 4'd0) begin
            $display("FAIL: SRLDso cc=%0d expected 0", cc);
            $fatal;
        end
        if (has_src_ar !== 1'b0) begin
            $display("FAIL: SRLDso has_src_ar asserted");
            $fatal;
        end
        if (has_tgt_ar !== 1'b0) begin
            $display("FAIL: SRLDso has_tgt_ar asserted");
            $fatal;
        end
        if (has_src_gp !== 1'b0) begin
            $display("FAIL: SRLDso has_src_gp asserted");
            $fatal;
        end
        if (tgt_gp_we !== 1'b0) begin
            $display("FAIL: SRLDso tgt_gp_we asserted");
            $fatal;
        end

        instr = INSTR_NOP;
        root_opc = `OPC_NOP;
        pc = 48'h0000_0000;
        step();

        // CR2SR CR1 field=PERMS -> SRt=PC
        pc    = 48'h0000_0160;
        instr = make_cr2sr(`SR_IDX_PC, 2'd1, `CR_FLD_PERMS);
        root_opc = `OPC_CR2SR;
        step();
        expect_common(`OPC_CR2SR, `OPC_CR2SR, pc, instr);
        if (has_src_sr !== 1'b0) begin
            $display("FAIL: CR2SR has_src_sr asserted");
            $fatal;
        end
        if (!has_src_ar) begin
            $display("FAIL: CR2SR missing has_src_ar");
            $fatal;
        end
        if (src_ar !== 2'd1) begin
            $display("FAIL: CR2SR src_ar=%0d expected 1", src_ar);
            $fatal;
        end
        if (has_tgt_ar !== 1'b0) begin
            $display("FAIL: CR2SR has_tgt_ar asserted");
            $fatal;
        end
        if (tgt_sr !== `SR_IDX_PC) begin
            $display("FAIL: CR2SR tgt_sr=%0d expected PC", tgt_sr);
            $fatal;
        end
        if (tgt_sr_we !== 1'b1) begin
            $display("FAIL: CR2SR expected tgt_sr_we=1");
            $fatal;
        end
        if (imm_en !== 1'b0) begin
            $display("FAIL: CR2SR imm_en asserted");
            $fatal;
        end
        if (sgn_en !== 1'b0) begin
            $display("FAIL: CR2SR sgn_en asserted");
            $fatal;
        end
        if (imm14_val !== 14'd0) begin
            $display("FAIL: CR2SR imm14=%0d expected 0", imm14_val);
            $fatal;
        end
        if (imm12_val !== 12'd0) begin
            $display("FAIL: CR2SR imm12=%0d expected 0", imm12_val);
            $fatal;
        end
        if (imm10_val !== 10'd0) begin
            $display("FAIL: CR2SR imm10=%0d expected 0", imm10_val);
            $fatal;
        end
        if (imm16_val !== 16'd0) begin
            $display("FAIL: CR2SR imm16=%0d expected 0", imm16_val);
            $fatal;
        end
        if (cc !== 4'd0) begin
            $display("FAIL: CR2SR cc=%0d expected 0", cc);
            $fatal;
        end
        if (has_src_gp !== 1'b0) begin
            $display("FAIL: CR2SR has_src_gp asserted");
            $fatal;
        end
        if (tgt_gp_we !== 1'b0) begin
            $display("FAIL: CR2SR tgt_gp_we asserted");
            $fatal;
        end

        instr = INSTR_NOP;
        root_opc = `OPC_NOP;
        pc = 48'h0000_0000;
        step();

        // SR2CR SRs=LR -> CR2 field=BASE
        pc    = 48'h0000_0170;
        instr = make_sr2cr(2'd2, `SR_IDX_LR, `CR_FLD_BASE);
        root_opc = `OPC_SR2CR;
        step();
        expect_common(`OPC_SR2CR, `OPC_SR2CR, pc, instr);
        if (!has_src_sr) begin
            $display("FAIL: SR2CR missing has_src_sr");
            $fatal;
        end
        if (src_sr !== `SR_IDX_LR) begin
            $display("FAIL: SR2CR src_sr=%0d expected LR", src_sr);
            $fatal;
        end
        if (!has_tgt_ar) begin
            $display("FAIL: SR2CR missing has_tgt_ar");
            $fatal;
        end
        if (tgt_ar !== 2'd2) begin
            $display("FAIL: SR2CR tgt_ar=%0d expected 2", tgt_ar);
            $fatal;
        end
        if (has_src_ar !== 1'b0) begin
            $display("FAIL: SR2CR has_src_ar asserted");
            $fatal;
        end
        if (tgt_sr !== 2'd0) begin
            $display("FAIL: SR2CR tgt_sr=%0d expected 0", tgt_sr);
            $fatal;
        end
        if (tgt_sr_we !== 1'b0) begin
            $display("FAIL: SR2CR unexpectedly asserted tgt_sr_we");
            $fatal;
        end
        if (imm_en !== 1'b0) begin
            $display("FAIL: SR2CR imm_en asserted");
            $fatal;
        end
        if (sgn_en !== 1'b0) begin
            $display("FAIL: SR2CR sgn_en asserted");
            $fatal;
        end
        if (imm14_val !== 14'd0) begin
            $display("FAIL: SR2CR imm14=%0d expected 0", imm14_val);
            $fatal;
        end
        if (imm12_val !== 12'd0) begin
            $display("FAIL: SR2CR imm12=%0d expected 0", imm12_val);
            $fatal;
        end
        if (imm10_val !== 10'd0) begin
            $display("FAIL: SR2CR imm10=%0d expected 0", imm10_val);
            $fatal;
        end
        if (imm16_val !== 16'd0) begin
            $display("FAIL: SR2CR imm16=%0d expected 0", imm16_val);
            $fatal;
        end
        if (cc !== 4'd0) begin
            $display("FAIL: SR2CR cc=%0d expected 0", cc);
            $fatal;
        end
        if (has_src_gp !== 1'b0) begin
            $display("FAIL: SR2CR has_src_gp asserted");
            $fatal;
        end
        if (tgt_gp_we !== 1'b0) begin
            $display("FAIL: SR2CR tgt_gp_we asserted");
            $fatal;
        end

        instr = INSTR_NOP;
        root_opc = `OPC_NOP;
        pc = 48'h0000_0000;
        step();

        // SRJCCso CC=NE, imm10=+5
        pc    = 48'h0000_0180;
        instr = make_srjccso(`SR_IDX_PC, `CC_NE, IMM10_POS_FIVE);
        root_opc = `OPC_SRJCCso;
        step();
        expect_common(`OPC_SRJCCso, `OPC_SRJCCso, pc, instr);
        if (!has_src_sr) begin
            $display("FAIL: SRJCCso(+5) missing has_src_sr");
            $fatal;
        end
        if (src_sr !== `SR_IDX_FL) begin
            $display("FAIL: SRJCCso(+5) src_sr=%0d expected FL", src_sr);
            $fatal;
        end
        if (tgt_sr !== `SR_IDX_PC) begin
            $display("FAIL: SRJCCso(+5) tgt_sr=%0d expected PC", tgt_sr);
            $fatal;
        end
        if (tgt_sr_we !== 1'b0) begin
            $display("FAIL: SRJCCso(+5) unexpectedly asserted tgt_sr_we");
            $fatal;
        end
        if (imm_en !== 1'b1) begin
            $display("FAIL: SRJCCso(+5) imm_en expected 1");
            $fatal;
        end
        if (sgn_en !== 1'b1) begin
            $display("FAIL: SRJCCso(+5) sgn_en expected 1");
            $fatal;
        end
        if (imm10_val !== IMM10_POS_FIVE) begin
            $display("FAIL: SRJCCso(+5) imm10=%0h expected %0h", imm10_val, IMM10_POS_FIVE);
            $fatal;
        end
        if (imm12_val !== 12'd0) begin
            $display("FAIL: SRJCCso(+5) imm12=%0d expected 0", imm12_val);
            $fatal;
        end
        if (imm14_val !== 14'd0) begin
            $display("FAIL: SRJCCso(+5) imm14=%0d expected 0", imm14_val);
            $fatal;
        end
        if (imm16_val !== 16'd0) begin
            $display("FAIL: SRJCCso(+5) imm16=%0d expected 0", imm16_val);
            $fatal;
        end
        if (cc !== `CC_NE) begin
            $display("FAIL: SRJCCso(+5) cc=%0d expected CC_NE", cc);
            $fatal;
        end
        if (has_src_ar !== 1'b0) begin
            $display("FAIL: SRJCCso(+5) has_src_ar asserted");
            $fatal;
        end
        if (has_tgt_ar !== 1'b0) begin
            $display("FAIL: SRJCCso(+5) has_tgt_ar asserted");
            $fatal;
        end
        if (has_src_gp !== 1'b0) begin
            $display("FAIL: SRJCCso(+5) has_src_gp asserted");
            $fatal;
        end
        if (tgt_gp_we !== 1'b0) begin
            $display("FAIL: SRJCCso(+5) tgt_gp_we asserted");
            $fatal;
        end

        instr = INSTR_NOP;
        root_opc = `OPC_NOP;
        pc = 48'h0000_0000;
        step();

        // SRJCCso CC=GE, imm10=-1
        pc    = 48'h0000_0190;
        instr = make_srjccso(`SR_IDX_PC, `CC_GE, IMM10_NEG_ONE);
        root_opc = `OPC_SRJCCso;
        step();
        expect_common(`OPC_SRJCCso, `OPC_SRJCCso, pc, instr);
        if (!has_src_sr) begin
            $display("FAIL: SRJCCso(-1) missing has_src_sr");
            $fatal;
        end
        if (src_sr !== `SR_IDX_FL) begin
            $display("FAIL: SRJCCso(-1) src_sr=%0d expected FL", src_sr);
            $fatal;
        end
        if (tgt_sr !== `SR_IDX_PC) begin
            $display("FAIL: SRJCCso(-1) tgt_sr=%0d expected PC", tgt_sr);
            $fatal;
        end
        if (tgt_sr_we !== 1'b0) begin
            $display("FAIL: SRJCCso(-1) unexpectedly asserted tgt_sr_we");
            $fatal;
        end
        if (imm_en !== 1'b1) begin
            $display("FAIL: SRJCCso(-1) imm_en expected 1");
            $fatal;
        end
        if (sgn_en !== 1'b1) begin
            $display("FAIL: SRJCCso(-1) sgn_en expected 1");
            $fatal;
        end
        if (imm10_val !== IMM10_NEG_ONE) begin
            $display("FAIL: SRJCCso(-1) imm10=%0h expected %0h", imm10_val, IMM10_NEG_ONE);
            $fatal;
        end
        if (imm12_val !== 12'd0) begin
            $display("FAIL: SRJCCso(-1) imm12=%0d expected 0", imm12_val);
            $fatal;
        end
        if (imm14_val !== 14'd0) begin
            $display("FAIL: SRJCCso(-1) imm14=%0d expected 0", imm14_val);
            $fatal;
        end
        if (imm16_val !== 16'd0) begin
            $display("FAIL: SRJCCso(-1) imm16=%0d expected 0", imm16_val);
            $fatal;
        end
        if (cc !== `CC_GE) begin
            $display("FAIL: SRJCCso(-1) cc=%0d expected CC_GE", cc);
            $fatal;
        end
        if (has_src_ar !== 1'b0) begin
            $display("FAIL: SRJCCso(-1) has_src_ar asserted");
            $fatal;
        end
        if (has_tgt_ar !== 1'b0) begin
            $display("FAIL: SRJCCso(-1) has_tgt_ar asserted");
            $fatal;
        end
        if (has_src_gp !== 1'b0) begin
            $display("FAIL: SRJCCso(-1) has_src_gp asserted");
            $fatal;
        end
        if (tgt_gp_we !== 1'b0) begin
            $display("FAIL: SRJCCso(-1) tgt_gp_we asserted");
            $fatal;
        end

        $display("opclassf_id_tb PASS");
        $finish;
    end
endmodule
