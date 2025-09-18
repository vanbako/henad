`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"

module ar48_tb;
    reg clk;
    reg rst;

    // Data memory (24-bit storage, 24/48-bit access via 48-bit buses)
    wire                w_dmem_we    [0:1];
    wire [`HBIT_ADDR:0] w_dmem_addr  [0:1];
    wire [`HBIT_ADDR:0] w_dmem_wdata [0:1];
    wire                w_dmem_is48  [0:1];
    wire [`HBIT_ADDR:0] w_dmem_rdata [0:1];

    mem #(.READ_MEM(0)) u_dmem(
        .iw_clk  (clk),
        .iw_we   (w_dmem_we),
        .iw_addr (w_dmem_addr),
        .iw_wdata(w_dmem_wdata),
        .iw_is48 (w_dmem_is48),
        .or_rdata(w_dmem_rdata)
    );

    // Minimal wires between MA and MO
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
        .iw_stall    (1'b0),
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
        .ow_mem_is48 (w_dmem_is48),
        .iw_mem_rdata(w_dmem_rdata),
        .iw_result   (r_result),
        .ow_result   (w_mowb_result),
        .iw_sr_result(r_sr_result),
        .ow_sr_result(w_mowb_sr_result),
        .iw_ar_result(r_ar_result),
        .ow_ar_result(w_mowb_ar_result)
    );

    initial begin
        clk = 0; rst = 1;
        r_pc = 0; r_instr = 0; r_opc = 0; r_addr = 0; r_result = 0; r_sr_result = 0; r_ar_result = 0;
        #5; clk = 1; #5; clk = 0; // reset edge
        rst = 0;

        // 48-bit store via SR path: SRSTso to addr 20 with value 0xCAFEBE_987654
        r_opc = `OPC_SRSTso; r_addr = 48'd20; r_sr_result = 48'hCAFEBE_987654;
        #5; clk = 1; #5; clk = 0;
        $display("AR store: we0=%b we1=%b addr0=%0d addr1=%0d wdata0=%h wdata1=%h ar_in=%h opc=%h",
                 w_dmem_we[0], w_dmem_we[1], w_dmem_addr[0], w_dmem_addr[1], w_dmem_wdata[0], w_dmem_wdata[1], u_stg_mo.iw_sr_result, u_stg_mo.iw_opc);
        // idle cycle
        r_opc = `OPC_NOP; r_sr_result = 0; r_addr = 0;
        #5; clk = 1; #5; clk = 0;
        $display("after AR store: mem[%0d]=%h mem[%0d]=%h", 20, u_dmem.r_mem[20], 21, u_dmem.r_mem[21]);

        if (u_dmem.r_mem[20] !== 24'h987654 || u_dmem.r_mem[21] !== 24'hCAFEBE) begin
            $display("AR48 STORE FAIL: lo=%h hi=%h", u_dmem.r_mem[20], u_dmem.r_mem[21]);
            $fatal;
        end

        // 48-bit load via SR path: SRLDso from addr 20
        // Like SR test: two cycles to drive addr and capture, one NOP to latch output
        r_opc = `OPC_SRLDso; r_addr = 48'd20;
        #5; clk = 1; #5; clk = 0;
        $display("cycle3: we0=%b we1=%b addr0=%0d addr1=%0d",
                 w_dmem_we[0], w_dmem_we[1], w_dmem_addr[0], w_dmem_addr[1]);
        r_opc = `OPC_SRLDso; r_addr = 48'd20;
        #5; clk = 1; #5; clk = 0;
        $display("cycle4: we0=%b we1=%b addr0=%0d addr1=%0d rdata0=%h rdata1=%h",
                 w_dmem_we[0], w_dmem_we[1], w_dmem_addr[0], w_dmem_addr[1], w_dmem_rdata[0], w_dmem_rdata[1]);
        r_opc = `OPC_NOP; r_addr = 0;
        #5; clk = 1; #5; clk = 0;

        if (w_mowb_sr_result !== 48'hCAFEBE_987654) begin
            $display("SR48 LOAD FAIL: got=%h exp=%h", w_mowb_sr_result, 48'hCAFEBE_987654);
            $fatal;
        end else begin
            $display("SR48 LOAD PASS: %h", w_mowb_sr_result);
        end
        $finish;
    end
endmodule
