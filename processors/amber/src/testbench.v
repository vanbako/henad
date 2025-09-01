`timescale 1ns/1ps

`define DEBUGPC
`define DEBUGOPC
`ifndef TICKS
`define TICKS 100
`endif

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/flags.vh"

module testbench;
    reg r_clk;
    reg r_rst;
    amber u_amber (
        .iw_clk(r_clk),
        .iw_rst(r_rst)
    );
    // Tiny ROM program to exercise flags + branch:
    // 0: MOVsi #0, DR1         ; set Z=1
    // 1: JCCui EQ, #3          ; jump to 3 if Z==1
    // 2: MOVsi #1, DR2         ; should be skipped
    // 3: MOVsi #2, DR3         ; taken path
    // 4: SRHLT                 ; halt
    initial begin
        // Preload instruction memory directly (after mem init)
        #1;
        u_amber.u_imem.r_mem[0] = 24'h301000; // MOVsi #0, DR1
        u_amber.u_imem.r_mem[1] = 24'h721003; // JCCui EQ, #3
        u_amber.u_imem.r_mem[2] = 24'h302001; // MOVsi #1, DR2
        u_amber.u_imem.r_mem[3] = 24'h303002; // MOVsi #2, DR3
        u_amber.u_imem.r_mem[4] = 24'hA00000; // SRHLT
    end
    initial r_clk = 1'b0;
    always #5 r_clk = ~r_clk;
    initial begin
        r_rst = 1'b1;
        #10;
        r_rst = 1'b0;
        repeat (`TICKS) @(posedge r_clk);
        $display("Final: DR1=%h DR2=%h DR3=%h FLAGS=%b PC=%h",
            u_amber.u_reggp.r_gp[1],
            u_amber.u_reggp.r_gp[2],
            u_amber.u_reggp.r_gp[3],
            u_amber.u_regsr.r_sr[`SR_IDX_FL][`HBIT_FLAG:0],
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
`ifdef DEBUGGP
        $display("tick %03d : rst=%b GP  0=%h 1=%h 2=%h 3=%h 4=%h 5=%h 6=%h 7=%h 8=%h 9=%h a=%h b=%h c=%h d=%h e=%h f=%h",
            tick, r_rst,
            u_amber.u_reggp.r_gp[0],
            u_amber.u_reggp.r_gp[1],
            u_amber.u_reggp.r_gp[2],
            u_amber.u_reggp.r_gp[3],
            u_amber.u_reggp.r_gp[4],
            u_amber.u_reggp.r_gp[5],
            u_amber.u_reggp.r_gp[6],
            u_amber.u_reggp.r_gp[7],
            u_amber.u_reggp.r_gp[8],
            u_amber.u_reggp.r_gp[9],
            u_amber.u_reggp.r_gp[10],
            u_amber.u_reggp.r_gp[11],
            u_amber.u_reggp.r_gp[12],
            u_amber.u_reggp.r_gp[13],
            u_amber.u_reggp.r_gp[14],
            u_amber.u_reggp.r_gp[15]);
`endif
`ifdef DEBUGSR
        $display("tick %03d : rst=%b SR  FL=%h LR=%h ST=%h SSP=%h 4=%h 5=%h 6=%h 7=%h",
            tick, r_rst,
            u_amber.u_regsr.r_sr[0],
            u_amber.u_regsr.r_sr[1],
            u_amber.u_regsr.r_sr[2],
            u_amber.u_regsr.r_sr[3],
            u_amber.u_regsr.r_sr[4],
            u_amber.u_regsr.r_sr[5],
            u_amber.u_regsr.r_sr[6],
            u_amber.u_regsr.r_sr[7]);
`endif
`ifdef DEBUGINSTR
        $display("tick %03d : rst=%b INSTR                     IFID=%h IDEX=%h     EXMA=%h     MAMO=%h     MOWB=%h     WB=%h",
            tick, r_rst,
            u_amber.w_ifxt_instr,
            u_amber.w_idex_instr,
            u_amber.w_exma_instr,
            u_amber.w_mamo_instr,
            u_amber.w_mowb_instr,
            u_amber.w_wb_instr);
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
`ifdef DEBUGTGT_GP
        $display("tick %03d : rst=%b TGT_GP                                IDEX=%h          EXMA=%h          MAMO=%h          MOWB=%h          WB=%h",
            tick, r_rst,
            u_amber.w_tgt_gp,
            u_amber.w_exma_tgt_gp,
            u_amber.w_mamo_tgt_gp,
            u_amber.w_mowb_tgt_gp,
            u_amber.w_wb_tgt_gp);
`endif
`ifdef DEBUGTGT_SR
        $display("tick %03d : rst=%b TGT_SR                                IDEX=%h          EXMA=%h          MAMO=%h          MOWB=%h          WB=%h",
            tick, r_rst,
            u_amber.w_tgt_sr,
            u_amber.w_exma_tgt_sr,
            u_amber.w_mamo_tgt_sr,
            u_amber.w_mowb_tgt_sr,
            u_amber.w_wb_tgt_sr);
`endif
`ifdef DEBUGRESULT
        $display("tick %03d : rst=%b RESULT                                                EXMA=%h     MAMO=%h     MOWB=%h     WB=%h",
            tick, r_rst,
            u_amber.w_exma_result,
            u_amber.w_mamo_result,
            u_amber.w_mowb_result,
            u_amber.w_wb_result);
`endif
`ifdef DEBUGFLAGS
        $display("tick %03d : rst=%b FLAGS zero=%s negative=%s carry=%s overflow=%s",
            tick, r_rst,
            (u_amber.u_stg_ex.r_fl[`FLAG_Z]) ? "yes" : "no ",
            (u_amber.u_stg_ex.r_fl[`FLAG_N]) ? "yes" : "no ",
            (u_amber.u_stg_ex.r_fl[`FLAG_C]) ? "yes" : "no ",
            (u_amber.u_stg_ex.r_fl[`FLAG_V]) ? "yes" : "no ");
`endif
`ifdef DEBUGDECODE
        $display("tick %03d : rst=%b DECODE OPC=%-8s SGN_EN=%b IMM_EN=%b IMM_VAL=%h IMMSR_VAL=%h CC=%2s TGT_GP=%h TGT_SR=%h SRC_GP=%h SRC_SR=%h",
            tick, r_rst,
            opc2str(u_amber.w_opc),
            u_amber.w_sgn_en,
            u_amber.w_imm_en,
            /* imm display fields were customized in older bench, omit here */
            24'h0,
            48'h0,
            cc2str(u_amber.w_cc),
            u_amber.w_tgt_gp,
            u_amber.w_tgt_sr,
            u_amber.w_src_gp,
            u_amber.w_src_sr);
`endif
`ifdef DEBUGADDR
        $display("tick %03d : rst=%b ADDR %h %h",
            tick, r_rst,
            u_amber.u_stg_ex.r_addr,
            u_amber.w_exma_addr);
`endif
`ifdef DEBUGBRANCH
        $display("tick %03d : rst=%b BRANCH TAKEN=%b PC=%h",
            tick, r_rst,
            u_amber.w_branch_taken,
            u_amber.w_branch_pc);
`endif
`ifdef DEBUGMEM
        $display("tick %03d : rst=%b MEM 0=%h 1=%h 2=%h 3=%h 4=%h 5=%h 6=%h 7=%h",
            tick, r_rst,
            u_amber.u_dmem.r_mem[0],
            u_amber.u_dmem.r_mem[1],
            u_amber.u_dmem.r_mem[2],
            u_amber.u_dmem.r_mem[3],
            u_amber.u_dmem.r_mem[4],
            u_amber.u_dmem.r_mem[5],
            u_amber.u_dmem.r_mem[6],
            u_amber.u_dmem.r_mem[7]);
`endif
`ifdef DEBUGMEMSSP
        $display("tick %03d : rst=%b MEM ff8=%h ff9=%h ffa=%h ffb=%h ffc=%h ffd=%h ffe=%h fff=%h",
            tick, r_rst,
            u_amber.u_dmem.r_mem['hff8],
            u_amber.u_dmem.r_mem['hff9],
            u_amber.u_dmem.r_mem['hffa],
            u_amber.u_dmem.r_mem['hffb],
            u_amber.u_dmem.r_mem['hffc],
            u_amber.u_dmem.r_mem['hffd],
            u_amber.u_dmem.r_mem['hffe],
            u_amber.u_dmem.r_mem['hfff]);
`endif
`ifdef DEBUGMEMIF
        $display("tick %03d : rst=%b MEMIF 0=%h 1=%h",
            tick, r_rst,
            u_amber.w_dmem_rdata[0],
            u_amber.w_dmem_rdata[1]);
`endif
        tick = tick + 1;
    end
endmodule
