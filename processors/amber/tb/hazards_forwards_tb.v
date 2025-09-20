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

    function automatic [`HBIT_DATA:0] pack_cinci;
        input signed [13:0] imm14;
        input [1:0]         tgt_cr;
        begin
            pack_cinci = { `OPC_CINCi, tgt_cr, imm14[13:0] };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_stui;
        input [1:0]  tgt_ar;
        input [11:0] imm12;
        begin
            pack_stui = { `OPC_STui, tgt_ar, 2'b00, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_ldcso;
        input [3:0]         tgt_gp;
        input [1:0]         src_cr;
        input signed [11:0] imm10;
        begin
            pack_ldcso = { `OPC_LDcso, tgt_gp, src_cr, imm10[9:0] };
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

    task automatic wait_for_hlt_or_timeout;
        input integer max_cycles;
        integer ii;
        begin : wait_loop
            for (ii = 0; ii < max_cycles; ii = ii + 1) begin
                @(posedge clk);
                if (u_amber.w_wb_opc == `OPC_HLT)
                    disable wait_loop;
            end
            $display("Timeout waiting for HLT after %0d cycles", max_cycles);
            dump_pipeline_state("hlt_timeout");
            dump_register_state("hlt_timeout");
            dump_memory_state("hlt_timeout");
            $fatal;
        end
    endtask

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

    task automatic dump_pipeline_state;
        input string label;
        begin
            $display("[hazards:%s] PCs: IA=%h IAIF=%h IFXT=%h IDEX=%h EXMA=%h MAMO=%h MOWB=%h", label,
                     u_amber.r_ia_pc, u_amber.w_iaif_pc, u_amber.w_ifxt_pc,
                     u_amber.w_idex_pc, u_amber.w_exma_pc, u_amber.w_mamo_pc, u_amber.w_mowb_pc);
            $display("[hazards:%s] WB opc=%h hazard_stall=%b prev_stall=%b stall_len=%0d stall_pc=%h branch_taken=%b branch_pc=%h", label,
                     u_amber.w_wb_opc, u_amber.w_hazard_stall, prev_stall, stall_len, stall_pc,
                     u_amber.w_branch_taken, u_amber.w_branch_pc);
        end
    endtask

    task automatic dump_register_state;
        input string label;
        begin
            $display("[hazards:%s] GP regs: r0=%0d r1=%0d r2=%0d r3=%0d r4=%0d r5=%0d r6=%0d r7=%0d r8=%0d r9=%0d",
                     label,
                     u_amber.u_reggp.r_gp[0], u_amber.u_reggp.r_gp[1], u_amber.u_reggp.r_gp[2],
                     u_amber.u_reggp.r_gp[3], u_amber.u_reggp.r_gp[4], u_amber.u_reggp.r_gp[5],
                     u_amber.u_reggp.r_gp[6], u_amber.u_reggp.r_gp[7], u_amber.u_reggp.r_gp[8],
                     u_amber.u_reggp.r_gp[9]);
            $display("[hazards:%s] SR[LR]=%0d SR[SSP]=%0d CR0.base=%h cur=%h", label,
                     u_amber.u_regsr.r_sr[`SR_IDX_LR], u_amber.u_regsr.r_sr[`SR_IDX_SSP],
                     u_amber.u_regcr.r_base[0], u_amber.u_regcr.r_cur[0]);
        end
    endtask

    task automatic dump_memory_state;
        input string label;
        integer i;
        begin
            $display("[hazards:%s] DMEM window 16..24:", label);
            for (i = 16; i <= 24; i = i + 1)
                $display("    mem[%0d]=%h", i, u_amber.u_dmem.r_mem[i]);
        end
    endtask

    integer idx;
    initial begin
        // Small delay to ensure memories exist
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
        u_amber.u_imem.r_mem[17] = pack_cinci(14'sd20, 2'd0);         // CR0 += 20 (alias of legacy AR0)
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
        u_amber.u_imem.r_mem[30] = pack_cinci(14'sd1, 2'd0);          // CR0 += 1
        u_amber.u_imem.r_mem[31] = pack_cinci(14'sd2, 2'd0);          // CR0 += 2 (cursor fwd)
        u_amber.u_imem.r_mem[32] = pack_ldcso(4'd7, 2'd0, 12'sd0);     // DR7 <- *(CR0) (cursor src fwd)
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
        // Provide a default capability for CR0 so cursor operations have valid permissions
        u_amber.u_regcr.r_base[0]  = 48'd0;
        u_amber.u_regcr.r_len[0]   = 48'd4096;
        u_amber.u_regcr.r_cur[0]   = 48'd0;
        u_amber.u_regcr.r_perms[0] = (24'd1 << `CR_PERM_R_BIT) |
                                     (24'd1 << `CR_PERM_W_BIT) |
                                     (24'd1 << `CR_PERM_LC_BIT) |
                                     (24'd1 << `CR_PERM_SC_BIT);
        u_amber.u_regcr.r_attr[0]  = 24'd0;
        u_amber.u_regcr.r_tag[0]   = 1'b1;
        u_amber.u_reggp.r_gp[0]    = 24'd7;
        u_amber.u_reggp.r_gp[1]    = 24'd5;
        u_amber.u_reggp.r_gp[2]    = 24'd1;
        u_amber.u_reggp.r_gp[3]    = 24'd9;
        u_amber.u_reggp.r_gp[4]    = 24'd2;
        u_amber.u_reggp.r_gp[5]    = 24'd0;
        u_amber.u_reggp.r_gp[6]    = 24'd0;
        u_amber.u_reggp.r_gp[7]    = 24'd0;
        u_amber.u_reggp.r_gp[8]    = 24'd3;
        u_amber.u_reggp.r_gp[9]    = 24'd4;
        u_amber.u_regsr.r_sr[`SR_IDX_SSP] = 48'd30;
        u_amber.u_regsr.r_sr[`SR_IDX_LR]  = 48'd0;

        // Preload instruction and data caches now that reset finished so they
        // retain the seeded contents.
        for (idx = 0; idx < 16; idx = idx + 1)
            u_amber.u_icache.data[{4'd0, idx[3:0]}] = u_amber.u_imem.r_mem[idx];
        u_amber.u_icache.valid[0] = 1'b1;
        u_amber.u_icache.tag[0]   = {40{1'b0}};

        for (idx = 0; idx < 64; idx = idx + 1)
            u_amber.u_dcache.data[idx] = u_amber.u_dmem.r_mem[idx];
        u_amber.u_dcache.valid[0] = 1'b1;
        u_amber.u_dcache.tag[0]   = {40{1'b0}};
        u_amber.u_dcache.valid[1] = 1'b1;
        u_amber.u_dcache.tag[1]   = {40{1'b0}};
        u_amber.u_dcache.miss_active      = 1'b0;
        u_amber.u_dcache.miss_issue       = 1'b0;
        u_amber.u_dcache.miss_need_second = 1'b0;
        u_amber.u_dcache.pend_store       = 1'b0;
    end
    // Reset + run -------------------------------------------------------------
    integer tick;
    initial begin
        rst = 1'b1; tick = 0;
        repeat (2) @(posedge clk);
        rst = 1'b0;
        wait_for_hlt_or_timeout(2000);
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
                    if (u_amber.w_branch_taken_eff) begin
                        stall_pc <= stall_pc;
                    end else if (u_amber.r_ia_pc !== stall_pc) begin
                        $display("ERROR: PC changed during stall: %h -> %h", stall_pc, u_amber.r_ia_pc);
                        dump_pipeline_state("stall_pc_drift");
                        dump_register_state("stall_pc_drift");
                        dump_memory_state("stall_pc_drift");
                        $fatal;
                    end
                    stall_len <= stall_len + 1;
                end
            end else if (prev_stall) begin
                if (stall_len !== 3) begin
                    $display("ERROR: Stall length %0d (expected 3)", stall_len);
                    dump_pipeline_state("stall_len_mismatch");
                    dump_register_state("stall_len_mismatch");
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
                if (stall_count !== 3) begin
                    $display("STALL count FAIL: saw %0d events (expected 3)", stall_count);
                    dump_pipeline_state("stall_count_mismatch");
                    dump_register_state("stall_count_mismatch");
                    $fatal;
                end
                // Forwarding results
                if (u_amber.u_reggp.r_gp[1] !== 24'd12) begin
                    $display("FORWARD GP tgt (EXMA) FAIL: DR1=%0d exp=12", u_amber.u_reggp.r_gp[1]);
                    dump_pipeline_state("gp1_mismatch");
                    dump_register_state("gp1_mismatch");
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[2] !== 24'd13) begin
                    $display("FORWARD GP src (EXMA) FAIL: DR2=%0d exp=13", u_amber.u_reggp.r_gp[2]);
                    dump_pipeline_state("gp2_mismatch");
                    dump_register_state("gp2_mismatch");
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[3] !== 24'd16) begin
                    $display("FORWARD GP tgt (MAMO) FAIL: DR3=%0d exp=16", u_amber.u_reggp.r_gp[3]);
                    dump_pipeline_state("gp3_mismatch");
                    dump_register_state("gp3_mismatch");
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[8] !== 24'd19) begin
                    $display("FORWARD GP src (MAMO) FAIL: DR8=%0d exp=19", u_amber.u_reggp.r_gp[8]);
                    dump_pipeline_state("gp8_mismatch");
                    dump_register_state("gp8_mismatch");
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[4] !== 24'd9) begin
                    $display("FORWARD GP tgt (MOWB) FAIL: DR4=%0d exp=9", u_amber.u_reggp.r_gp[4]);
                    dump_pipeline_state("gp4_mismatch");
                    dump_register_state("gp4_mismatch");
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[9] !== 24'd13) begin
                    $display("FORWARD GP src (MOWB) FAIL: DR9=%0d exp=13", u_amber.u_reggp.r_gp[9]);
                    dump_pipeline_state("gp9_mismatch");
                    dump_register_state("gp9_mismatch");
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[6] !== 24'd7) begin
                    $display("FORWARD SR flags to branch FAIL: DR6=%0d exp=7", u_amber.u_reggp.r_gp[6]);
                    dump_pipeline_state("gp6_mismatch");
                    dump_register_state("gp6_mismatch");
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[7] !== 24'd23) begin
                    $display("FORWARD AR src/tgt FAIL: DR7=%0d exp=23", u_amber.u_reggp.r_gp[7]);
                    dump_pipeline_state("gp7_mismatch");
                    dump_register_state("gp7_mismatch");
                    dump_memory_state("gp7_mismatch");
                    $fatal;
                end
                // Memory and SR results
                if (u_amber.u_dmem.r_mem[20] !== 24'h000055) begin
                    $display("STORE verify FAIL: mem[20]=%h exp=000055", u_amber.u_dmem.r_mem[20]);
                    dump_pipeline_state("store_verify_mismatch");
                    dump_register_state("store_verify_mismatch");
                    dump_memory_state("store_verify_mismatch");
                    $fatal;
                end
                if (u_amber.u_regsr.r_sr[`SR_IDX_LR] !== 48'd19) begin
                    $display("SR load+forward FAIL: LR=%0d exp=19", u_amber.u_regsr.r_sr[`SR_IDX_LR]);
                    dump_pipeline_state("lr_mismatch");
                    dump_register_state("lr_mismatch");
                    dump_memory_state("lr_mismatch");
                    $fatal;
                end
                $display("All hazard+forward checks PASSED");
                #5; $finish;
            end
        end
    end

    // Simple progress counter (optional)
    always @(posedge clk) if (!rst) tick <= tick + 1;

    // Debug: observe branch target calculations in EX stage
    always @(posedge clk) begin
        if (!rst && u_amber.w_exma_opc == `OPC_BCCso) begin
            $display("[DBG BCCso] pc=%0d instr=%h imm12=%h branch_pc=%h taken=%b stall=%b", 
                     u_amber.w_exma_pc, u_amber.w_exma_instr, u_amber.u_stg_ex.iw_imm12_val,
                     u_amber.u_stg_ex.r_branch_pc, u_amber.u_stg_ex.r_branch_taken, u_amber.w_hazard_stall);
        end
        if (!rst && u_amber.w_mamo_opc == `OPC_LDcso) begin
            $display("[DBG LDcso] pc=%0d addr0=%0d addr1=%0d mp=%b data=%h", u_amber.w_mamo_pc,
                     u_amber.w_dmem_addr[0], u_amber.w_dmem_addr[1], u_amber.w_mem_mp,
                     u_amber.w_mamo_result);
            $display("[DBG LDcso] dcache_word=%h valid0=%b valid1=%b miss=%b rdata0=%h rdata1=%h", u_amber.u_dcache.data[23],
                     u_amber.u_dcache.valid[0], u_amber.u_dcache.valid[1], u_amber.u_dcache.miss_active,
                     u_amber.w_dmem_rdata[0], u_amber.w_dmem_rdata[1]);
        end
    end
endmodule
