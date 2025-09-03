`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"

module mem_ldst_tb;
    reg clk;
    reg rst;

    // Data memory
    wire                w_dmem_we    [0:1];
    wire [`HBIT_ADDR:0] w_dmem_addr  [0:1];
    wire [`HBIT_DATA:0] w_dmem_wdata [0:1];
    wire [`HBIT_DATA:0] w_dmem_rdata [0:1];

    mem #(.READ_MEM(0)) u_dmem(
        .iw_clk  (clk),
        .iw_we   (w_dmem_we),
        .iw_addr (w_dmem_addr),
        .iw_wdata(w_dmem_wdata),
        .or_rdata(w_dmem_rdata)
    );

    // Minimal wires between MA and MO (drive like EX stage)
    reg  [`HBIT_ADDR:0]   r_pc;
    reg  [`HBIT_DATA:0]   r_instr;
    reg  [`HBIT_OPC:0]    r_opc;
    reg  [`HBIT_ADDR:0]   r_addr;
    reg  [`HBIT_DATA:0]   r_result;
    reg  [`HBIT_ADDR:0]   r_sr_result;
    reg  [`HBIT_ADDR:0]   r_ar_result;

    wire [`HBIT_ADDR:0]   w_mamo_pc;
    wire [`HBIT_DATA:0]   w_mamo_instr;
    wire [`HBIT_OPC:0]    w_mamo_opc;
    wire                   w_mem_mp;

    stg_ma u_stg_ma(
        .iw_clk      (clk),
        .iw_rst      (rst),
        .iw_pc       (r_pc),
        .ow_pc       (w_mamo_pc),
        .iw_instr    (r_instr),
        .ow_instr    (w_mamo_instr),
        .iw_opc      (r_opc),
        .ow_opc      (w_mamo_opc),
        .iw_tgt_gp   ({(`HBIT_TGT_GP+1){1'b0}}),
        .iw_tgt_gp_we(1'b0),
        .ow_tgt_gp   (),
        .ow_tgt_gp_we(),
        .iw_tgt_sr   ({(`HBIT_TGT_SR+1){1'b0}}),
        .iw_tgt_sr_we(1'b0),
        .ow_tgt_sr   (),
        .ow_tgt_sr_we(),
        .iw_tgt_ar   ({(`HBIT_TGT_AR+1){1'b0}}),
        .iw_tgt_ar_we(1'b0),
        .ow_tgt_ar   (),
        .ow_tgt_ar_we(),
        .ow_mem_mp   (w_mem_mp),
        .ow_mem_addr (w_dmem_addr),
        .iw_addr     (r_addr),
        .iw_result   (r_result),
        .ow_result   (),
        .iw_sr_result(r_sr_result),
        .ow_sr_result(),
        .iw_ar_result(r_ar_result),
        .ow_ar_result()
    );

    wire [`HBIT_ADDR:0]   w_mowb_pc;
    wire [`HBIT_DATA:0]   w_mowb_instr;
    wire [`HBIT_OPC:0]    w_mowb_opc;
    wire [`HBIT_DATA:0]   w_mowb_result;
    wire [`HBIT_ADDR:0]   w_mowb_sr_result;
    wire [`HBIT_ADDR:0]   w_mowb_ar_result;

    stg_mo u_stg_mo(
        .iw_clk      (clk),
        .iw_rst      (rst),
        .iw_pc       (w_mamo_pc),
        .ow_pc       (w_mowb_pc),
        .iw_instr    (w_mamo_instr),
        .ow_instr    (w_mowb_instr),
        .iw_opc      (w_mamo_opc),
        .ow_opc      (w_mowb_opc),
        .iw_tgt_gp   ({(`HBIT_TGT_GP+1){1'b0}}),
        .iw_tgt_gp_we(1'b0),
        .ow_tgt_gp   (),
        .ow_tgt_gp_we(),
        .iw_tgt_sr   ({(`HBIT_TGT_SR+1){1'b0}}),
        .iw_tgt_sr_we(1'b0),
        .ow_tgt_sr   (),
        .ow_tgt_sr_we(),
        .iw_tgt_ar   ({(`HBIT_TGT_AR+1){1'b0}}),
        .iw_tgt_ar_we(1'b0),
        .ow_tgt_ar   (),
        .ow_tgt_ar_we(),
        .iw_mem_mp   (w_mem_mp),
        .ow_mem_we   (w_dmem_we),
        .ow_mem_wdata(w_dmem_wdata),
        .iw_mem_rdata(w_dmem_rdata),
        .iw_result   (r_result),
        .ow_result   (w_mowb_result),
        .iw_sr_result(r_sr_result),
        .ow_sr_result(w_mowb_sr_result),
        .iw_ar_result(r_ar_result),
        .ow_ar_result(w_mowb_ar_result)
    );

    task tick; begin #5 clk = 1; #5 clk = 0; end endtask

    initial begin
        clk = 0; rst = 1;
        r_pc = 0; r_instr = 0; r_opc = 0; r_addr = 0; r_result = 0; r_sr_result = 0; r_ar_result = 0;
        tick(); rst = 0;

        // STur: store 24-bit value
        r_opc = `OPC_STur; r_addr = 48'd40; r_result = 24'hA1B2C3; tick();
        // idle
        r_opc = `OPC_NOP; tick();
        if (u_dmem.r_mem[40] !== 24'hA1B2C3) begin $display("STur FAIL: %h", u_dmem.r_mem[40]); $fatal; end

        // LDur: load 24-bit value
        u_dmem.r_mem[50] = 24'h00C0DE; // preload
        r_opc = `OPC_LDur; r_addr = 48'd50; tick();
        r_opc = `OPC_LDur; r_addr = 48'd50; tick();
        r_opc = `OPC_NOP; tick();
        if (w_mowb_result !== 24'h00C0DE) begin $display("LDur FAIL: %h", w_mowb_result); $fatal; end

        // STui: store immediate (we directly drive result here)
        r_opc = `OPC_STui; r_addr = 48'd41; r_result = 24'h000123; tick(); r_opc = `OPC_NOP; tick();
        if (u_dmem.r_mem[41] !== 24'h000123) $fatal;

        // STsi: store sign-extended imm (drive via result)
        r_opc = `OPC_STsi; r_addr = 48'd42; r_result = 24'hFFF800; tick(); r_opc = `OPC_NOP; tick();
        if (u_dmem.r_mem[42] !== 24'hFFF800) $fatal;

        // STso: store with offset (we just provide computed r_addr)
        r_opc = `OPC_STso; r_addr = 48'd60; r_result = 24'h112233; tick(); r_opc = `OPC_NOP; tick();
        if (u_dmem.r_mem[60] !== 24'h112233) $fatal;

        // LDso: load with offset
        u_dmem.r_mem[61] = 24'hABCD01;
        r_opc = `OPC_LDso; r_addr = 48'd61; tick();
        r_opc = `OPC_LDso; r_addr = 48'd61; tick();
        r_opc = `OPC_NOP; tick();
        if (w_mowb_result !== 24'hABCD01) $fatal;

        $display("mem_ldst_tb PASS");
        $finish;
    end
endmodule

