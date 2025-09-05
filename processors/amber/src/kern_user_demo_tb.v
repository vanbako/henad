`timescale 1ns/1ps

`define DEBUGPC
`define DEBUGOPC
`define DEBUGBRANCH
`ifndef TICKS
`define TICKS 120
`endif

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/flags.vh"

module kern_user_demo_tb;
    reg r_clk;
    reg r_rst;
    amber u_amber (
        .iw_clk(r_clk),
        .iw_rst(r_rst)
    );

    initial r_clk = 1'b0;
    always #5 r_clk = ~r_clk;

    initial begin
        r_rst = 1'b1;
        #10;
        r_rst = 1'b0;
        repeat (`TICKS) @(posedge r_clk);
        $display("Final: DR1=%h DR2=%h DR3=%h PC=%h",
            u_amber.u_reggp.r_gp[1],
            u_amber.u_reggp.r_gp[2],
            u_amber.u_reggp.r_gp[3],
            u_amber.r_ia_pc);
        #9;
        $finish;
    end

    integer tick = 0;
    always @(posedge r_clk) begin
`ifdef DEBUGPC
        $display("tick %03d : rst=%b PC  IA=%h IAIF=%h IFID=%h IDEX=%h     EXMA=%h     MAMO=%h     MOWB=%h     WB=%h",
            tick, r_rst,
            u_amber.r_ia_pc,
            u_amber.w_iaif_pc,
            u_amber.w_ifxt_pc,
            u_amber.w_idex_pc,
            u_amber.w_exma_pc,
            u_amber.w_mamo_pc,
            u_amber.w_mowb_pc,
            u_amber.w_wb_pc);
`endif
`ifdef DEBUGOPC
        $display("tick %03d : rst=%b OPC                                   IDEX=%-10s EXMA=%-10s MAMO=%-10s MOWB=%-10s WB=%-10s",
            tick, r_rst,
            opc2str(u_amber.w_opc),
            opc2str(u_amber.w_exma_opc),
            opc2str(u_amber.w_mamo_opc),
            opc2str(u_amber.w_mowb_opc),
            opc2str(u_amber.w_wb_opc));
`endif
        tick = tick + 1;
    end
endmodule
