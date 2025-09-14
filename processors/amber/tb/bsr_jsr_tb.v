`timescale 1ns/1ps

`define DEBUGPC
`define DEBUGOPC
`ifndef TICKS
`define TICKS 400
`endif

`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/flags.vh"

// Program description:
// - Initialize SSP to 0x0FF0 (safe top-of-RAM) via AR0 and SETSSP
// - Initialize DR0=5 (loop counter), DR1=1, DR2=2
// - Loop body calls SUB1 via BSR (PC-relative); SUB1 calls SUB2 via JSR (absolute)
//   SUB1: DR1 += 3; JSR SUB2; DR2 -= 1; RET
//   SUB2: DR1 += 2; RET
// - After return to main: DR0 -= 1; branch if NE back to loop
// - Halt and print results
//
// Expected effect after 5 iterations:
// - Each iteration: DR1 += (3 + 2) = 5, DR2 -= 1
// - Start DR1=1, DR2=2 ⇒ final DR1 = 1 + 5*5 = 26 (0x1A), DR2 = 2 - 5 = -3 (0xFFFFFD)
// - DR0 ends at 0
module bsr_jsr_tb;
    reg r_clk;
    reg r_rst;
    amber u_amber (
        .iw_clk(r_clk),
        .iw_rst(r_rst)
    );

    // Assembly layout (word addresses):
    //  00: LUIui   bank0=0                ; clear banks (not strictly needed, but explicit)
    //  01: LUIui   bank1=0
    //  02: LUIui   bank2=0
    //  03: NOP                            ; AR0 cursor initialized via TB into CR0.cur
    //  04: NOP
    //  05: NOP
    //  06: NOP
    //  07: SETSSP  AR0                    ; SSP = AR0 = 0x000000_000FF0 (from CR0.cur)
    //  08: MOVsi   #5, DR0                ; loop counter
    //  09: MOVsi   #1, DR1                ; accum 1
    //  0A: MOVsi   #2, DR2                ; accum 2
    // L0:
    //  0B: BSRso   SUB1                   ; call sub1 (PC-rel)
    //  0C: SUBsi   #1, DR0                ; DR0--
    //  0D: BCCso   NE, L0                 ; loop if DR0 != 0
    //  0E: SRHLT
    //
    // SUB1 at 0x10:
    //  10: ADDsi   #3, DR1
    //  11: LUIui   bank2=0                ; absolute JSR to SUB2 (banks all 0, imm12=sub2)
    //  12: LUIui   bank1=0
    //  13: LUIui   bank0=0
    //  14: JSRui   #SUB2
    //  15: SUBsi   #1, DR2
    //  16: RET
    //
    // SUB2 at 0x18:
    //  18: ADDsi   #2, DR1
    //  19: RET
    initial begin
        // Preload instruction memory and initialize AR0 via CR0 cursor
        #1;
        // Initialize CR0 cursor used by SETSSP to 0x0FF0
        u_amber.u_regcr.r_cur[0] = 48'h000000_000FF0;
        // 00-02: LUIui bank clears
        u_amber.u_imem.r_mem[24'h000000] = 24'h100000; // LUIui bank0=0
        u_amber.u_imem.r_mem[24'h000001] = 24'h104000; // LUIui bank1=0
        u_amber.u_imem.r_mem[24'h000002] = 24'h108000; // LUIui bank2=0
        // 03-06: nops (placeholders)
        u_amber.u_imem.r_mem[24'h000003] = 24'h000000; // NOP
        u_amber.u_imem.r_mem[24'h000004] = 24'h000000; // NOP
        u_amber.u_imem.r_mem[24'h000005] = 24'h000000; // NOP
        u_amber.u_imem.r_mem[24'h000006] = 24'h000000; // NOP
        u_amber.u_imem.r_mem[24'h000007] = 24'hA10000; // SETSSP AR0
        // 08-0A: init regs
        u_amber.u_imem.r_mem[24'h000008] = 24'h300005; // MOVsi #5, DR0
        u_amber.u_imem.r_mem[24'h000009] = 24'h301001; // MOVsi #1, DR1
        u_amber.u_imem.r_mem[24'h00000A] = 24'h302002; // MOVsi #2, DR2
        // 0B: BSRso to SUB1 at 0x10 => imm16 = 0x10 - 0x0B = +5
        u_amber.u_imem.r_mem[24'h00000B] = 24'h790005; // BSRso +5
        // 0C: DR0--
        u_amber.u_imem.r_mem[24'h00000C] = 24'h340001; // SUBsi #1, DR0
        // 0D: branch NE back to 0x0B => imm12 = 0x0B - 0x0D = -2 = 0xFFE
        u_amber.u_imem.r_mem[24'h00000D] = 24'h742FFE; // BCCso NE, -2
        // 0E: halt
        u_amber.u_imem.r_mem[24'h00000E] = 24'hA00000; // SRHLT

        // SUB1 at 0x10
        u_amber.u_imem.r_mem[24'h000010] = 24'h331003; // ADDsi #3, DR1
        u_amber.u_imem.r_mem[24'h000011] = 24'h108000; // LUIui bank2=0
        u_amber.u_imem.r_mem[24'h000012] = 24'h104000; // LUIui bank1=0
        u_amber.u_imem.r_mem[24'h000013] = 24'h100000; // LUIui bank0=0
        // 0x14: JSRui to SUB2 at 0x18 (banks=0 => absolute = imm12)
        u_amber.u_imem.r_mem[24'h000014] = 24'h770018; // JSRui #0x18
        u_amber.u_imem.r_mem[24'h000015] = 24'h342001; // SUBsi #1, DR2
        u_amber.u_imem.r_mem[24'h000016] = 24'h7A0000; // RET

        // SUB2 at 0x18
        u_amber.u_imem.r_mem[24'h000018] = 24'h331002; // ADDsi #2, DR1
        u_amber.u_imem.r_mem[24'h000019] = 24'h7A0000; // RET
    end

    initial r_clk = 1'b0;
    always #5 r_clk = ~r_clk;

    initial begin
        r_rst = 1'b1;
        #10;
        r_rst = 1'b0;
        // Run long enough to complete nested calls across 5 iterations
        repeat (`TICKS) @(posedge r_clk);
        $display("Final: DR0=%h DR1=%h DR2=%h SSP=%h PC=%h",
            u_amber.u_reggp.r_gp[0],
            u_amber.u_reggp.r_gp[1],
            u_amber.u_reggp.r_gp[2],
            u_amber.u_regsr.r_sr[`SR_IDX_SSP],
            u_amber.r_ia_pc);
        $display("Mem[0x0FF0..0x0FF3]: %h %h %h %h",
            u_amber.u_dmem.r_mem[24'h000FF0],
            u_amber.u_dmem.r_mem[24'h000FF1],
            u_amber.u_dmem.r_mem[24'h000FF2],
            u_amber.u_dmem.r_mem[24'h000FF3]);
        #9;
        $finish;
    end

    integer tick = 0;
    always @(posedge r_clk) begin
`ifdef DEBUGPC
        $display("tick %03d : rst=%b PC  IA=%h IAIF=%h IFXT=%h ID=%h EX=%h MA=%h MO=%h WB=%h",
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
        $display("tick %03d : rst=%b OPC                                   ID=%-10s EX=%-10s MA=%-10s MO=%-10s WB=%-10s",
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
