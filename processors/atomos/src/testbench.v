`timescale 1ns/1ps

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/flags.vh"

module testbench;
    reg r_clk;
    reg r_rst;
    atomos u_atomos (
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
        #9;
        $finish;
    end
    integer tick = 0;
    always @(posedge r_clk) begin
`ifdef DEBUGPC
        $display("tick %03d : rst=%b PC  IA=%h IAIF=%h IFID=%h IDEX=%h     EXMA=%h     MAMO=%h     MOWB=%h     WB=%h",
            tick, r_rst,
            u_diad.r_ia_pc,
            u_diad.w_iaif_pc,
            u_diad.w_ifid_pc,
            u_diad.w_idex_pc,
            u_diad.w_exma_pc,
            u_diad.w_mamo_pc,
            u_diad.w_mowb_pc,
            u_diad.w_wb_pc);
`endif
`ifdef DEBUGGP
        $display("tick %03d : rst=%b GP  0=%h 1=%h 2=%h 3=%h 4=%h 5=%h 6=%h 7=%h 8=%h 9=%h a=%h b=%h c=%h d=%h e=%h f=%h",
            tick, r_rst,
            u_diad.u_reggp.r_gp[0],
            u_diad.u_reggp.r_gp[1],
            u_diad.u_reggp.r_gp[2],
            u_diad.u_reggp.r_gp[3],
            u_diad.u_reggp.r_gp[4],
            u_diad.u_reggp.r_gp[5],
            u_diad.u_reggp.r_gp[6],
            u_diad.u_reggp.r_gp[7],
            u_diad.u_reggp.r_gp[8],
            u_diad.u_reggp.r_gp[9],
            u_diad.u_reggp.r_gp[10],
            u_diad.u_reggp.r_gp[11],
            u_diad.u_reggp.r_gp[12],
            u_diad.u_reggp.r_gp[13],
            u_diad.u_reggp.r_gp[14],
            u_diad.u_reggp.r_gp[15]);
`endif
`ifdef DEBUGSR
        $display("tick %03d : rst=%b SR  FL=%h LR=%h ST=%h SSP=%h 4=%h 5=%h 6=%h 7=%h",
            tick, r_rst,
            u_diad.u_regsr.r_sr[0],
            u_diad.u_regsr.r_sr[1],
            u_diad.u_regsr.r_sr[2],
            u_diad.u_regsr.r_sr[3],
            u_diad.u_regsr.r_sr[4],
            u_diad.u_regsr.r_sr[5],
            u_diad.u_regsr.r_sr[6],
            u_diad.u_regsr.r_sr[7]);
`endif
`ifdef DEBUGINSTR
        $display("tick %03d : rst=%b INSTR                     IFID=%h IDEX=%h     EXMA=%h     MAMO=%h     MOWB=%h     WB=%h",
            tick, r_rst,
            u_diad.w_ifid_instr,
            u_diad.w_idex_instr,
            u_diad.w_exma_instr,
            u_diad.w_mamo_instr,
            u_diad.w_mowb_instr,
            u_diad.w_wb_instr);
`endif
`ifdef DEBUGOPC
        $display("tick %03d : rst=%b OPC                                   IDEX=%-10s EXMA=%-10s MAMO=%-10s MOWB=%-10s WB=%-10s",
            tick, r_rst,
            opc2str(u_diad.w_opc),
            opc2str(u_diad.w_exma_opc),
            opc2str(u_diad.w_mamo_opc),
            opc2str(u_diad.w_mowb_opc),
            opc2str(u_diad.w_wb_opc));
`endif
`ifdef DEBUGTGT_GP
        $display("tick %03d : rst=%b TGT_GP                                IDEX=%h          EXMA=%h          MAMO=%h          MOWB=%h          WB=%h",
            tick, r_rst,
            u_diad.w_tgt_gp,
            u_diad.w_exma_tgt_gp,
            u_diad.w_mamo_tgt_gp,
            u_diad.w_mowb_tgt_gp,
            u_diad.w_wb_tgt_gp);
`endif
`ifdef DEBUGTGT_SR
        $display("tick %03d : rst=%b TGT_SR                                IDEX=%h          EXMA=%h          MAMO=%h          MOWB=%h          WB=%h",
            tick, r_rst,
            u_diad.w_tgt_sr,
            u_diad.w_exma_tgt_sr,
            u_diad.w_mamo_tgt_sr,
            u_diad.w_mowb_tgt_sr,
            u_diad.w_wb_tgt_sr);
`endif
`ifdef DEBUGRESULT
        $display("tick %03d : rst=%b RESULT                                                EXMA=%h     MAMO=%h     MOWB=%h     WB=%h",
            tick, r_rst,
            u_diad.w_exma_result,
            u_diad.w_mamo_result,
            u_diad.w_mowb_result,
            u_diad.w_wb_result);
`endif
`ifdef DEBUGFLAGS
        $display("tick %03d : rst=%b FLAGS zero=%s negative=%s carry=%s overflow=%s",
            tick, r_rst,
            (u_diad.u_stg_ex.r_fl[`FLAG_Z]) ? "yes" : "no ",
            (u_diad.u_stg_ex.r_fl[`FLAG_N]) ? "yes" : "no ",
            (u_diad.u_stg_ex.r_fl[`FLAG_C]) ? "yes" : "no ",
            (u_diad.u_stg_ex.r_fl[`FLAG_V]) ? "yes" : "no ");
`endif
`ifdef DEBUGDECODE
        $display("tick %03d : rst=%b DECODE OPC=%-8s SGN_EN=%b IMM_EN=%b IMM_VAL=%h IMMSR_VAL=%h CC=%2s TGT_GP=%h TGT_SR=%h SRC_GP=%h SRC_SR=%h",
            tick, r_rst,
            opc2str(u_diad.w_opc),
            u_diad.w_sgn_en,
            u_diad.w_imm_en,
            u_diad.w_imm_val,
            u_diad.w_immsr_val,
            cc2str(u_diad.w_cc),
            u_diad.w_tgt_gp,
            u_diad.w_tgt_sr,
            u_diad.w_src_gp,
            u_diad.w_src_sr);
`endif
`ifdef DEBUGADDR
        $display("tick %03d : rst=%b ADDR %h %h",
            tick, r_rst,
            u_diad.u_stg_ex.r_addr,
            u_diad.w_exma_addr);
`endif
`ifdef DEBUGBRANCH
        $display("tick %03d : rst=%b BRANCH TAKEN=%b PC=%h",
            tick, r_rst,
            u_diad.w_branch_taken,
            u_diad.w_branch_pc);
`endif
`ifdef DEBUGMEM
        $display("tick %03d : rst=%b MEM 0=%h 1=%h 2=%h 3=%h 4=%h 5=%h 6=%h 7=%h",
            tick, r_rst,
            u_diad.u_dmem.r_mem[0],
            u_diad.u_dmem.r_mem[1],
            u_diad.u_dmem.r_mem[2],
            u_diad.u_dmem.r_mem[3],
            u_diad.u_dmem.r_mem[4],
            u_diad.u_dmem.r_mem[5],
            u_diad.u_dmem.r_mem[6],
            u_diad.u_dmem.r_mem[7]);
`endif
`ifdef DEBUGMEMSSP
        $display("tick %03d : rst=%b MEM ff8=%h ff9=%h ffa=%h ffb=%h ffc=%h ffd=%h ffe=%h fff=%h",
            tick, r_rst,
            u_diad.u_dmem.r_mem['hff8],
            u_diad.u_dmem.r_mem['hff9],
            u_diad.u_dmem.r_mem['hffa],
            u_diad.u_dmem.r_mem['hffb],
            u_diad.u_dmem.r_mem['hffc],
            u_diad.u_dmem.r_mem['hffd],
            u_diad.u_dmem.r_mem['hffe],
            u_diad.u_dmem.r_mem['hfff]);
`endif
`ifdef DEBUGMEMIF
        $display("tick %03d : rst=%b MEMIF 0=%h 1=%h",
            tick, r_rst,
            u_diad.w_dmem_rdata[0],
            u_diad.w_dmem_rdata[1]);
`endif
        tick = tick + 1;
    end
endmodule
