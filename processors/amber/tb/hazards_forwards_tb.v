`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cc.vh"
`include "src/sr.vh"

module hazards_forwards_tb;
    reg clk;
    reg rst;

    amber u_amber (
        .iw_clk(clk),
        .iw_rst(rst)
    );

    // Clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Helpers -----------------------------------------------------------------
    localparam [`HBIT_DATA:0] INSTR_NOP = { `OPC_NOP, 16'h0000 };
    localparam [7:0] LEGACY_OP_ADDASI = 8'h67;
    localparam [7:0] LEGACY_OP_MOVDUR = 8'h62;


    function automatic [`HBIT_DATA:0] pack_movsi;
        input [3:0]         tgt_gp;
        input signed [11:0] imm12;
        begin
            pack_movsi = { `OPC_MOVsi, tgt_gp, imm12[11:0] };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_addur;
        input [3:0] src_gp;
        input [3:0] tgt_gp;
        begin
            pack_addur = { `OPC_ADDur, tgt_gp, src_gp, 8'b0 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_addasi;
        input signed [11:0] imm12;
        input [1:0]         tgt_ar;
        begin
            pack_addasi = { LEGACY_OP_ADDASI, tgt_ar, imm12[11:0] };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_stui;
        input [1:0]  tgt_ar;
        input [11:0] imm12;
        begin
            pack_stui = { `OPC_STui, tgt_ar, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_movdur;
        input [3:0] tgt_gp;
        input [1:0] src_ar;
        input       high_sel;
        begin
            pack_movdur = { LEGACY_OP_MOVDUR, tgt_gp, src_ar, high_sel, 9'b0 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_jccui;
        input [3:0]  cc;
        input [11:0] imm12;
        begin
            pack_jccui = { `OPC_JCCui, cc, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_bccso;
        input [3:0]  cc;
        input signed [11:0] imm12;
        begin
            pack_bccso = { `OPC_BCCso, cc, imm12[11:0] };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_sr_imm14;
        input [`HBIT_OPC:0] opc;
        input [1:0]         tgt_sr;
        input signed [13:0] imm14;
        begin
            pack_sr_imm14 = { opc, tgt_sr, imm14[13:0] };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_sr_sr_imm12;
        input [`HBIT_OPC:0] opc;
        input [1:0]         tgt_sr;
        input [1:0]         src_sr;
        input signed [11:0] imm12;
        begin
            pack_sr_sr_imm12 = { opc, tgt_sr, src_sr, imm12[11:0] };
        end
    endfunction

    integer idx;
    initial begin
        // Small delay to ensure memories exist
        #1;
        for (idx = 0; idx < 64; idx = idx + 1)
            u_amber.u_imem.r_mem[idx] = INSTR_NOP;

        // Program -------------------------------------------------------------
        u_amber.u_imem.r_mem[ 0] = pack_movsi(4'd0, 12'sd7);          // DR0 <- 7
        u_amber.u_imem.r_mem[ 1] = pack_movsi(4'd2, 12'sd1);          // DR2 <- 1
        u_amber.u_imem.r_mem[ 2] = pack_movsi(4'd1, 12'sd5);          // DR1 <- 5
        u_amber.u_imem.r_mem[ 3] = pack_movsi(4'd8, 12'sd3);          // DR8 <- 3
        u_amber.u_imem.r_mem[ 4] = pack_addur(4'd0, 4'd1);            // DR1 <- DR1 + DR0 (EXMA tgt)
        u_amber.u_imem.r_mem[ 5] = pack_addur(4'd1, 4'd2);            // DR2 <- DR2 + DR1 (EXMA src)
        u_amber.u_imem.r_mem[ 6] = pack_movsi(4'd3, 12'sd9);          // DR3 <- 9
        u_amber.u_imem.r_mem[ 7] = INSTR_NOP;
        u_amber.u_imem.r_mem[ 8] = pack_addur(4'd0, 4'd3);            // DR3 <- DR3 + DR0 (MAMO tgt)
        u_amber.u_imem.r_mem[ 9] = INSTR_NOP;
        u_amber.u_imem.r_mem[10] = pack_addur(4'd3, 4'd8);            // DR8 <- DR8 + DR3 (MAMO src)
        u_amber.u_imem.r_mem[11] = pack_movsi(4'd4, 12'sd2);          // DR4 <- 2
        u_amber.u_imem.r_mem[12] = pack_movsi(4'd9, 12'sd4);          // DR9 <- 4
        u_amber.u_imem.r_mem[13] = INSTR_NOP;
        u_amber.u_imem.r_mem[14] = INSTR_NOP;
        u_amber.u_imem.r_mem[15] = pack_addur(4'd0, 4'd4);            // DR4 <- DR4 + DR0 (MOWB tgt)
        u_amber.u_imem.r_mem[16] = pack_addur(4'd4, 4'd9);            // DR9 <- DR9 + DR4 (MOWB src)
        u_amber.u_imem.r_mem[17] = pack_addasi(12'sd20, 2'd0);        // AR0 += 20
        u_amber.u_imem.r_mem[18] = pack_stui(2'd0, 12'h055);          // *(AR0) = 0x55 (hazard #1)
        u_amber.u_imem.r_mem[19] = INSTR_NOP;
        u_amber.u_imem.r_mem[20] = INSTR_NOP;
        u_amber.u_imem.r_mem[21] = pack_sr_imm14(`OPC_SRADDsi, `SR_IDX_LR, 14'sd5);    // LR += 5
        u_amber.u_imem.r_mem[22] = pack_sr_imm14(`OPC_SRADDsi, `SR_IDX_LR, -14'sd2);   // LR += -2 (tgt fwd)
        u_amber.u_imem.r_mem[23] = INSTR_NOP;                                           // observe writeback
        u_amber.u_imem.r_mem[24] = pack_sr_sr_imm12(`OPC_SRLDso, `SR_IDX_LR, `SR_IDX_SSP, 12'sd0); // LR <- mem (hazard #2)
        u_amber.u_imem.r_mem[25] = pack_sr_imm14(`OPC_SRADDsi, `SR_IDX_LR, 14'sd1);    // LR += 1 (load fwd)
        u_amber.u_imem.r_mem[26] = pack_movsi(4'd5, 12'sd0);          // DR5 <- 0 (sets Z)
        u_amber.u_imem.r_mem[27] = pack_bccso(`CC_EQ, 12'd2);        // branch if Z -> skip next instruction
        u_amber.u_imem.r_mem[28] = pack_movsi(4'd6, 12'sd9);          // DR6 <- 9 (fallthrough)
        u_amber.u_imem.r_mem[29] = pack_movsi(4'd6, 12'sd7);          // DR6 <- 7 (taken)
        u_amber.u_imem.r_mem[30] = pack_addasi(12'sd1, 2'd0);         // AR0 += 1
        u_amber.u_imem.r_mem[31] = pack_addasi(12'sd2, 2'd0);         // AR0 += 2 (AR tgt fwd)
        u_amber.u_imem.r_mem[32] = pack_movdur(4'd7, 2'd0, 1'b0);     // DR7 <- L(AR0) (AR src fwd)
        u_amber.u_imem.r_mem[33] = { `OPC_HLT, 16'h0000 };

        // Seed uIMM banks so JCCui absolute target works without traps
        u_amber.u_stg_ex.r_uimm_bank0_valid = 1'b1;
        u_amber.u_stg_ex.r_uimm_bank1_valid = 1'b1;
        u_amber.u_stg_ex.r_uimm_bank2_valid = 1'b1;
        u_amber.u_stg_ex.r_uimm_bank0 = 12'd0;
        u_amber.u_stg_ex.r_uimm_bank1 = 12'd0;
        u_amber.u_stg_ex.r_uimm_bank2 = 12'd0;

        // Prefill data memory for forwarding checks
        u_amber.u_dmem.r_mem[23] = 24'd23;        // for MOVDur
        u_amber.u_dmem.r_mem[30] = 24'h000012;    // SRLDso low 24 bits
        u_amber.u_dmem.r_mem[31] = 24'h000000;    // SRLDso high 24 bits

        // Seed SR base registers for SRLDso
        u_amber.u_regsr.r_sr[`SR_IDX_SSP] = 48'd30;
        u_amber.u_regsr.r_sr[`SR_IDX_LR]  = 48'd0;
    end


    initial begin
        @(negedge rst);
        u_amber.u_stg_ex.r_uimm_bank0_valid = 1'b1;
        u_amber.u_stg_ex.r_uimm_bank1_valid = 1'b1;
        u_amber.u_stg_ex.r_uimm_bank2_valid = 1'b1;
        u_amber.u_stg_ex.r_uimm_bank0 = 12'd0;
        u_amber.u_stg_ex.r_uimm_bank1 = 12'd0;
        u_amber.u_stg_ex.r_uimm_bank2 = 12'd0;
    end
    // Reset + run -------------------------------------------------------------
    integer tick;
    initial begin
        rst = 1'b1; tick = 0;
        repeat (2) @(posedge clk);
        rst = 1'b0;
        repeat (400) @(posedge clk);
        $display("Timeout waiting for HLT");
        $fatal;
    end

    // Stall tracking ----------------------------------------------------------
    reg prev_stall;
    integer stall_len;
    integer stall_count;
    reg [47:0] stall_pc;
    initial begin
        prev_stall = 1'b0;
        stall_len = 0;
        stall_count = 0;
        stall_pc = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            prev_stall  <= 1'b0;
            stall_len   <= 0;
            stall_count <= 0;
            stall_pc    <= 0;
        end else begin
            if (u_amber.w_hazard_stall) begin
                if (!prev_stall) begin
                    stall_len <= 1;
                    stall_pc  <= u_amber.r_ia_pc;
                end else begin
                    if (u_amber.r_ia_pc !== stall_pc) begin
                        $display("ERROR: PC changed during stall: %h -> %h", stall_pc, u_amber.r_ia_pc);
                        $fatal;
                    end
                    stall_len <= stall_len + 1;
                end
            end else if (prev_stall) begin
                if (stall_len !== 3) begin
                    $display("ERROR: Stall length %0d (expected 3)", stall_len);
                    $fatal;
                end else begin
                    $display("Stall observed: length=3, PC=%h held", stall_pc);
                    stall_count <= stall_count + 1;
                end
                stall_len <= 0;
            end
            prev_stall <= u_amber.w_hazard_stall;
        end
    end

    // Detect HLT and validate architectural state --------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            if (u_amber.w_wb_opc == `OPC_HLT) begin
                if (stall_count !== 2) begin
                    $display("STALL count FAIL: saw %0d events (expected 2)", stall_count);
                    $fatal;
                end
                // Forwarding results
                if (u_amber.u_reggp.r_gp[1] !== 24'd12) begin
                    $display("FORWARD GP tgt (EXMA) FAIL: DR1=%0d exp=12", u_amber.u_reggp.r_gp[1]);
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[2] !== 24'd13) begin
                    $display("FORWARD GP src (EXMA) FAIL: DR2=%0d exp=13", u_amber.u_reggp.r_gp[2]);
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[3] !== 24'd16) begin
                    $display("FORWARD GP tgt (MAMO) FAIL: DR3=%0d exp=16", u_amber.u_reggp.r_gp[3]);
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[8] !== 24'd19) begin
                    $display("FORWARD GP src (MAMO) FAIL: DR8=%0d exp=19", u_amber.u_reggp.r_gp[8]);
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[4] !== 24'd9) begin
                    $display("FORWARD GP tgt (MOWB) FAIL: DR4=%0d exp=9", u_amber.u_reggp.r_gp[4]);
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[9] !== 24'd13) begin
                    $display("FORWARD GP src (MOWB) FAIL: DR9=%0d exp=13", u_amber.u_reggp.r_gp[9]);
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[6] !== 24'd7) begin
                    $display("FORWARD SR flags to branch FAIL: DR6=%0d exp=7", u_amber.u_reggp.r_gp[6]);
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[7] !== 24'd23) begin
                    $display("FORWARD AR src/tgt FAIL: DR7=%0d exp=23", u_amber.u_reggp.r_gp[7]);
                    $fatal;
                end
                // Memory and SR results
                if (u_amber.u_dmem.r_mem[20] !== 24'h000055) begin
                    $display("STORE verify FAIL: mem[20]=%h exp=000055", u_amber.u_dmem.r_mem[20]);
                    $fatal;
                end
                if (u_amber.u_regsr.r_sr[`SR_IDX_LR] !== 48'd19) begin
                    $display("SR load+forward FAIL: LR=%0d exp=19", u_amber.u_regsr.r_sr[`SR_IDX_LR]);
                    $fatal;
                end
                $display("All hazard+forward checks PASSED");
                #5; $finish;
            end
        end
    end

    // Simple progress counter (optional)
    always @(posedge clk) if (!rst) tick <= tick + 1;
endmodule
