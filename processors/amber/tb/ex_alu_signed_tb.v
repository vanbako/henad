`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/flags.vh"
`include "src/cr.vh"
`include "src/pstate.vh"

module ex_alu_signed_tb;
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
    wire                   trap_pending;
    wire                   halt;
    wire                   branch_taken;
    wire [`HBIT_ADDR:0]    branch_pc;
    reg  [`HBIT_DATA:0]    src_gp_val;
    reg  [`HBIT_DATA:0]    tgt_gp_val;
    reg  [`HBIT_ADDR:0]    src_ar_val;
    reg  [`HBIT_ADDR:0]    tgt_ar_val;
    reg  [`HBIT_ADDR:0]    src_sr_val;
    reg  [`HBIT_ADDR:0]    tgt_sr_val;
    reg  [`HBIT_ADDR:0]    pstate_val;
    reg                    flush;
    reg                    stall;

    // CHERI capability view inputs (unused for these tests but must be driven)
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
    reg                    mode_kernel;
    reg                    mmu_d_fault;
    reg  [2:0]             mmu_d_fault_code;
    reg  [`HBIT_ADDR:0]    mmu_d_fault_va;

    // Track previous PSTATE value so tests can detect updates
    reg  [`HBIT_ADDR:0]    pstate_before;

    stg_ex dut(
        .iw_clk(clk), .iw_rst(rst), .iw_pc(pc), .ow_pc(ex_pc),
        .iw_instr(instr), .ow_instr(ex_instr), .iw_opc(opc), .ow_opc(ex_opc),
        .iw_root_opc(root_opc), .ow_root_opc(ex_root_opc),
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
        .ow_trap_pending(trap_pending), .ow_halt(halt),
        .iw_src_gp_val(src_gp_val), .iw_tgt_gp_val(tgt_gp_val),
        .iw_src_ar_val(src_ar_val), .iw_tgt_ar_val(tgt_ar_val),
        .iw_src_sr_val(src_sr_val), .iw_tgt_sr_val(tgt_sr_val),
        .iw_pstate_val(pstate_val),
        .ow_cr_write_addr(), .ow_cr_we_base(), .ow_cr_base(),
        .ow_cr_we_len(), .ow_cr_len(), .ow_cr_we_cur(), .ow_cr_cur(),
        .ow_cr_we_perms(), .ow_cr_perms(), .ow_cr_we_attr(), .ow_cr_attr(),
        .ow_cr_we_tag(), .ow_cr_tag(),
        .iw_cr_s_base(cr_s_base), .iw_cr_s_len(cr_s_len), .iw_cr_s_cur(cr_s_cur),
        .iw_cr_s_perms(cr_s_perms), .iw_cr_s_attr(cr_s_attr), .iw_cr_s_tag(cr_s_tag),
        .iw_cr_t_base(cr_t_base), .iw_cr_t_len(cr_t_len), .iw_cr_t_cur(cr_t_cur),
        .iw_cr_t_perms(cr_t_perms), .iw_cr_t_attr(cr_t_attr), .iw_cr_t_tag(cr_t_tag),
        .iw_flush(flush), .iw_mode_kernel(mode_kernel),
        .iw_mmu_d_fault(mmu_d_fault), .iw_mmu_d_fault_code(mmu_d_fault_code),
        .iw_mmu_d_fault_va(mmu_d_fault_va),
        .iw_stall(stall)
    );

    task step;
        begin
            @(posedge clk);
            @(posedge clk);
            stall = 1'b1;
            @(posedge clk);
            stall = 1'b0;
        end
    endtask

    task automatic dump_ex_state;
        input string label;
        begin
            $display("[ex_alu_signed:%s] opc=%h root_opc=%h imm12=%h imm10=%h imm14=%h imm16=%h", label,
                     opc, root_opc, imm12_val, imm10_val, imm14_val, imm16_val);
            $display("[ex_alu_signed:%s] tgt_gp_val=%h src_gp_val=%h tgt_sr_val=%h src_sr_val=%h", label,
                     tgt_gp_val, src_gp_val, tgt_sr_val, src_sr_val);
            $display("[ex_alu_signed:%s] ex_result=%h ex_sr_result=%h ex_ar_result=%h branch_taken=%b branch_pc=%h", label,
                     ex_result, ex_sr_result, ex_ar_result, branch_taken, branch_pc);
            $display("[ex_alu_signed:%s] sr_aux_we=%b sr_aux_addr=%0d sr_aux_result=%h", label,
                     sr_aux_we, sr_aux_addr, sr_aux_result);
        end
    endtask

    task automatic fail_check;
        input string label;
        input string reason;
        begin
            $display("[ex_alu_signed] %s", reason);
            dump_ex_state(label);
            $fatal;
        end
    endtask

    initial begin clk = 0; forever #5 clk = ~clk; end

    task automatic begin_instruction;
        begin
            root_opc = opc;
            pstate_before = pstate_val;
        end
    endtask

    task automatic expect_flags_update;
        input string label;
        input logic exp_z;
        input logic exp_n;
        input logic exp_c;
        input logic exp_v;
        logic [`HBIT_ADDR:0] sample;
        logic actual_z;
        logic actual_n;
        logic actual_c;
        logic actual_v;
        bit   saw_update;
        begin
            saw_update = (sr_aux_we && sr_aux_addr == `SR_IDX_PSTATE);
            sample     = saw_update ? sr_aux_result : pstate_val;
            if (!saw_update && sample == pstate_before) begin
                fail_check(label, "PSTATE flags not updated");
            end
            actual_z = sample[`PSTATE_BIT_Z];
            actual_n = sample[`PSTATE_BIT_N];
            actual_c = sample[`PSTATE_BIT_C];
            actual_v = sample[`PSTATE_BIT_V];
            if ((exp_z !== 1'bx) && (actual_z !== exp_z))
                fail_check(label, $sformatf("Z flag mismatch: got %0b expected %0b", actual_z, exp_z));
            if ((exp_n !== 1'bx) && (actual_n !== exp_n))
                fail_check(label, $sformatf("N flag mismatch: got %0b expected %0b", actual_n, exp_n));
            if ((exp_c !== 1'bx) && (actual_c !== exp_c))
                fail_check(label, $sformatf("C flag mismatch: got %0b expected %0b", actual_c, exp_c));
            if ((exp_v !== 1'bx) && (actual_v !== exp_v))
                fail_check(label, $sformatf("V flag mismatch: got %0b expected %0b", actual_v, exp_v));
        end
    endtask

    task automatic expect_no_flag_update;
        input string label;
        begin
            if (sr_aux_we && sr_aux_addr == `SR_IDX_PSTATE)
                fail_check(label, "Unexpected PSTATE update");
            if (pstate_val != pstate_before)
                fail_check(label, "PSTATE changed unexpectedly");
        end
    endtask

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pstate_val = {`SIZE_ADDR{1'b0}};
        end else if (sr_aux_we && sr_aux_addr == `SR_IDX_PSTATE) begin
            pstate_val = sr_aux_result;
        end
    end


    initial begin
        rst = 1; stall = 0; flush = 0;
        pc = 0; instr = 0; opc = 0; root_opc = 0;
        sgn_en = 1; imm_en = 1;
        imm14_val = 0; imm12_val = 0; imm10_val = 0; imm16_val = 0;
        cc = 0; tgt_gp = 0; tgt_gp_we = 1; tgt_sr = 0; tgt_sr_we = 0; tgt_ar = 0;
        src_gp = 0; src_ar = 0; src_sr = 0;
        src_gp_val = 0; tgt_gp_val = 0; src_ar_val = 0; tgt_ar_val = 0; src_sr_val = 0; tgt_sr_val = 0;
        pstate_val = {`SIZE_ADDR{1'b0}};
        pstate_before = {`SIZE_ADDR{1'b0}};
        cr_s_base = 0; cr_s_len = 0; cr_s_cur = 0; cr_s_perms = 0; cr_s_attr = 0; cr_s_tag = 1'b0;
        cr_t_base = 0; cr_t_len = 0; cr_t_cur = 0; cr_t_perms = 0; cr_t_attr = 0; cr_t_tag = 1'b0;
        mode_kernel = 1'b1;
        mmu_d_fault = 1'b0; mmu_d_fault_code = 3'd0; mmu_d_fault_va = 0;
        #12 rst = 0;

        // NEGsr: -1 -> 0xFFFFFF with N=1, Z=0, V=0
        opc = `OPC_NEGsr; tgt_gp_val = 24'h000001; src_gp_val = 24'd0; begin_instruction(); step();
        if (ex_result !== 24'hFFFFFF)
            fail_check("NEGsr", "Result mismatch (expected FFFFFF)");
        expect_flags_update("NEGsr", 1'b0, 1'b1, 1'bx, 1'b0);

        // ADDsr signed overflow case: 0x7FFFFF + 1 => V=1, N=1
        opc = `OPC_ADDsr; tgt_gp_val = 24'h7FFFFF; src_gp_val = 24'h000001; begin_instruction(); step();
        expect_flags_update("ADDsr", 1'b0, 1'b1, 1'bx, 1'b1);

        // SUBsr signed overflow case: (-2^23) - 1 => V=1
        opc = `OPC_SUBsr; tgt_gp_val = 24'h800000; src_gp_val = 24'h000001; begin_instruction(); step();
        expect_flags_update("SUBsr", 1'b0, 1'b0, 1'bx, 1'b1);

        // SHRsr variable: arithmetic shift keeps sign
        opc = `OPC_SHRsr; tgt_gp_val = 24'h800002; src_gp_val = 24'h000001; begin_instruction(); step();
        if (ex_result[23] !== 1'b1)
            fail_check("SHRsr", "Arithmetic shift did not preserve sign bit");
        expect_flags_update("SHRsr", 1'b0, 1'b1, 1'b0, 1'bx);

        // CMPsr: Z,N,V set appropriately (compare -1 vs 1)
        opc = `OPC_CMPsr; tgt_gp_val = 24'hFFFFFF; src_gp_val = 24'h000001; begin_instruction(); step();
        expect_flags_update("CMPsr", 1'b0, 1'b1, 1'bx, 1'b1);

        // TSTsr: N reflects sign, Z reflects zero
        opc = `OPC_TSTsr; tgt_gp_val = 24'h800000; src_gp_val = 24'd0; begin_instruction(); step();
        expect_flags_update("TSTsr", 1'b0, 1'b1, 1'bx, 1'bx);

        // MOVsi: sign-extend imm12
        opc = `OPC_MOVsi; imm12_val = 12'hF80; begin_instruction(); step();
        if (ex_result !== 24'hFFFF80)
            fail_check("MOVsi", "Sign-extended immediate result mismatch");
        expect_flags_update("MOVsi", 1'b0, 1'b1, 1'bx, 1'bx);

        // MCCsi: take if CC and flags say so (use Z=1)
        src_sr = 2'b10; src_sr_val = {44'b0, 4'b0001};
        cc = `CC_EQ; opc = `OPC_MCCsi; instr[7:0] = 8'h80; begin_instruction(); step();
        if (ex_result !== 24'hFFFF80)
            fail_check("MCCsi", "Conditional move immediate result mismatch"); // sext(0x80)
        expect_flags_update("MCCsi", 1'b0, 1'bx, 1'bx, 1'bx);
        src_sr = 0; src_sr_val = 0; cc = 0;

        // ADDsi and SUBsi
        opc = `OPC_ADDsi; tgt_gp_val = 24'h000010; imm12_val = 12'h002; begin_instruction(); step();
        if (ex_result !== 24'h000012)
            fail_check("ADDsi", "Immediate add result mismatch");
        expect_flags_update("ADDsi", 1'b0, 1'b0, 1'bx, 1'b0);

        opc = `OPC_SUBsi; tgt_gp_val = 24'h000010; imm12_val = 12'h004; begin_instruction(); step();
        if (ex_result !== 24'h00000C)
            fail_check("SUBsi", "Immediate sub result mismatch");
        expect_flags_update("SUBsi", 1'b0, 1'b0, 1'bx, 1'b0);

        // SHRsi immediate arithmetic shift
        opc = `OPC_SHRsi; tgt_gp_val = 24'h800000; imm12_val = 12'h001; begin_instruction(); step();
        if (ex_result !== 24'hC00000)
            fail_check("SHRsi", "Immediate arithmetic shift result mismatch");
        expect_flags_update("SHRsi", 1'b0, 1'b1, 1'bx, 1'bx);

        // CMPsi
        opc = `OPC_CMPsi; tgt_gp_val = 24'h000000; imm12_val = 12'h000; begin_instruction(); step();
        expect_flags_update("CMPsi", 1'b1, 1'b0, 1'bx, 1'b0);

        $display("ex_alu_signed_tb PASS");
        $finish;
    end
endmodule
