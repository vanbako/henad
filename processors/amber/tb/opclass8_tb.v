`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/sizes.vh"
`include "src/flags.vh"
`include "src/sr.vh"
`include "src/pstate.vh"

module opclass8_tb;
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
    wire                   sr_aux_we;
    wire [`HBIT_TGT_SR:0]  sr_aux_addr;
    wire [`HBIT_ADDR:0]    sr_aux_result;
    wire                   branch_taken;
    wire [`HBIT_ADDR:0]    branch_pc;
    wire                   trap_pending;
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
        .iw_instr(instr), .ow_instr(ex_instr), .iw_opc(opc), .iw_root_opc(opc), .ow_opc(ex_opc), .ow_root_opc(),
        .iw_sgn_en(sgn_en), .iw_imm_en(imm_en),
        .iw_imm14_val(imm14_val), .iw_imm12_val(imm12_val), .iw_imm10_val(imm10_val), .iw_imm16_val(imm16_val),
        .iw_cc(cc),
        .iw_tgt_gp(tgt_gp), .iw_tgt_gp_we(tgt_gp_we), .ow_tgt_gp(ex_tgt_gp), .ow_tgt_gp_we(ex_tgt_gp_we),
        .iw_tgt_sr(tgt_sr), .iw_tgt_sr_we(tgt_sr_we), .ow_tgt_sr(ex_tgt_sr), .ow_tgt_sr_we(ex_tgt_sr_we),
        .iw_tgt_ar(tgt_ar), .ow_tgt_ar(ex_tgt_ar), .ow_tgt_ar_we(ex_tgt_ar_we),
        .iw_src_gp(src_gp), .iw_src_ar(src_ar), .iw_src_sr(src_sr),
        .ow_addr(ex_addr), .ow_result(ex_result), .ow_ar_result(ex_ar_result), .ow_sr_result(ex_sr_result),
        .ow_sr_aux_we(sr_aux_we), .ow_sr_aux_addr(sr_aux_addr), .ow_sr_aux_result(sr_aux_result),
        .ow_branch_taken(branch_taken), .ow_branch_pc(branch_pc),
        .ow_trap_pending(trap_pending), .ow_halt(),
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
            pc = 48'h0000_2000;
            instr = 24'd0;
            opc = `OPC_NOP;
            sgn_en = 1'b1;
            imm_en = 1'b1;
            imm14_val = 0;
            imm12_val = 0;
            imm10_val = 0;
            imm16_val = 0;
            cc = 0;
            tgt_gp = 0;
            tgt_gp_we = 0;
            tgt_sr = 0;
            tgt_sr_we = 0;
            tgt_ar = 0;
            src_gp = 0;
            src_ar = 0;
            src_sr = 0;
            tgt_gp_val = 0;
            src_gp_val = 0;
            src_ar_val = 0;
            tgt_ar_val = 0;
            src_sr_val = 0;
            tgt_sr_val = 0;
            pstate_val = 48'h0000_0000_0100; // MODE=1 kernel
        end
    endtask

    task automatic expect_no_branch;
        begin
            if (branch_taken) begin
                $display("FAIL: unexpected branch (pc=%h)" , branch_pc);
                $fatal;
            end
            if (trap_pending) begin
                $display("FAIL: unexpected trap pending");
                $fatal;
            end
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

        // CSRWR should forward DRs value to writeback without modifying flags.
        reset_inputs();
        opc = `OPC_CSRWR;
        instr = {`OPC_CSRWR, 4'd1, 12'h321};
        src_gp = 4'd1;
        src_gp_val = 24'h00EF12;
        step();
        expect_no_branch();
        if (ex_result !== 24'h00EF12) begin
            $display("FAIL: CSRWR result %h expected 00EF12", ex_result);
            $fatal;
        end
        if (sr_aux_we) begin
            $display("FAIL: CSRWR should not update PSTATE");
            $fatal;
        end

        // Another CSRWR to confirm multiple values propagate correctly.
        reset_inputs();
        opc = `OPC_CSRWR;
        instr = {`OPC_CSRWR, 4'd7, 12'h222};
        src_gp = 4'd7;
        src_gp_val = 24'h000001;
        step();
        expect_no_branch();
        if (ex_result !== 24'h000001) begin
            $display("FAIL: CSRWR result %h expected 000001", ex_result);
            $fatal;
        end

        // CSRRD non-zero value should clear Z flag.
        reset_inputs();
        opc = `OPC_CSRRD;
        instr = {`OPC_CSRRD, 4'd2, 12'h321};
        src_sr = `SR_IDX_PC;
        src_sr_val = 48'h00000000A5B6;
        pstate_val = 48'h000000000100; // MODE=1
        step();
        expect_no_branch();
        if (ex_result !== 24'h00A5B6) begin
            $display("FAIL: CSRRD value %h expected 00A5B6", ex_result);
            $fatal;
        end
        if (!sr_aux_we) begin
            $display("FAIL: CSRRD should update PSTATE flags");
            $fatal;
        end
        if (sr_aux_result[`PSTATE_BIT_Z] !== 1'b0) begin
            $display("FAIL: CSRRD non-zero should clear Z (value %b)", sr_aux_result[`PSTATE_BIT_Z]);
            $fatal;
        end

        // CSRRD zero value should set Z flag.
        reset_inputs();
        opc = `OPC_CSRRD;
        instr = {`OPC_CSRRD, 4'd3, 12'h322};
        src_sr = `SR_IDX_PC;
        src_sr_val = 48'h000000000000;
        pstate_val = 48'h000000000100;
        step();
        expect_no_branch();
        if (ex_result !== 24'h000000) begin
            $display("FAIL: CSRRD zero expected 0 got %h", ex_result);
            $fatal;
        end
        if (!sr_aux_we || sr_aux_result[`PSTATE_BIT_Z] !== 1'b1) begin
            $display("FAIL: CSRRD zero should set Z flag (we=%b z=%b)", sr_aux_we, sr_aux_result[`PSTATE_BIT_Z]);
            $fatal;
        end

        // CSRRD PSTATE should return the provided PSTATE value (low word).
        reset_inputs();
        opc = `OPC_CSRRD;
        instr = {`OPC_CSRRD, 4'd4, 12'h000};
        src_sr = `SR_IDX_PSTATE;
        src_sr_val = 48'h000000010123;
        step();
        expect_no_branch();
        if (ex_result !== 24'h010123) begin
            $display("FAIL: CSRRD PSTATE value %h expected 010123", ex_result);
            $fatal;
        end

        // CSRRD PCC cursor low word should propagate.
        reset_inputs();
        opc = `OPC_CSRRD;
        instr = {`OPC_CSRRD, 4'd5, 12'h034};
        src_sr = `SR_IDX_PC;
        src_sr_val = 48'h00000000FEDC;
        step();
        expect_no_branch();
        if (ex_result !== 24'h00FEDC) begin
            $display("FAIL: CSRRD PCC value %h expected 00FEDC", ex_result);
            $fatal;
        end

        $display("opclass8_tb PASS");
        $finish;
    end
endmodule
