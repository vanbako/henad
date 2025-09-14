`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/opcodes.vh"

module xt_translate_tb;
    reg clk;
    reg rst;

    // DUT
    reg  [`HBIT_ADDR:0] pc_in;
    wire [`HBIT_ADDR:0] pc_out;
    reg  [`HBIT_DATA:0] instr_in;
    wire [`HBIT_DATA:0] instr_out;

    stg_xt dut(
        .iw_clk  (clk),
        .iw_rst  (rst),
        .iw_pc   (pc_in),
        .ow_pc   (pc_out),
        .iw_instr(instr_in),
        .ow_instr(instr_out),
        .iw_flush(1'b0),
        .iw_stall(1'b0)
    );

    // Local packers (replicate helpers for expected µops)
    function automatic [`HBIT_DATA:0] pack_sr_imm14;
        input [`HBIT_OPC:0] opc;
        input [1:0]         tgt_sr;
        input [13:0]        imm14;
        begin
            pack_sr_imm14 = { opc, tgt_sr, imm14 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_sr_sr_imm12;
        input [`HBIT_OPC:0] opc;
        input [1:0]         tgt_sr;
        input [1:0]         src_sr;
        input [11:0]        imm12;
        begin
            pack_sr_sr_imm12 = { opc, tgt_sr, src_sr, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_sr_sr;
        input [`HBIT_OPC:0] opc;
        input [1:0]         tgt_sr;
        input [1:0]         src_sr;
        begin
            pack_sr_sr = { opc, tgt_sr, src_sr, 12'b0 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_sr_cc_imm10;
        input [`HBIT_OPC:0] opc;
        input [1:0]         tgt_sr;
        input [3:0]         cc;
        input [9:0]         imm10;
        begin
            pack_sr_cc_imm10 = { opc, tgt_sr, cc, imm10 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_jccui;
        input [3:0]         cc;
        input [11:0]        imm12;
        begin
            pack_jccui = { `OPC_JCCui, cc, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_bccsr;
        input [3:0]         tgt_dr;
        input [3:0]         cc;
        begin
            pack_bccsr = { `OPC_BCCsr, tgt_dr, cc, 8'b0 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_balso;
        input [15:0]        imm16;
        begin
            pack_balso = { `OPC_BALso, imm16 };
        end
    endfunction

    // Utilities
    task tick; begin #5 clk = 1; #5 clk = 0; end endtask

    initial begin
        clk = 0; rst = 1; pc_in = 0; instr_in = 0;
        tick(); rst = 0;

        // 1) BTP turns into a NOP micro-op (pass-through as NOP)
        instr_in = { `OPC_BTP, 16'b0 };
        tick(); // present
        if (instr_out !== {`OPC_NOP, 16'b0}) begin
            $display("BTP->NOP FAIL: got=%h", instr_out);
            $fatal;
        end

        // 2) JSRui expands to: SRSSP-=2; SRSTso SSP, LR, #0; SRMOVur LR, PC; JCCui AL, #imm12
        instr_in = { `OPC_JSRui, 4'h0, 12'hABC };
        tick(); if (instr_out !== pack_sr_imm14(`OPC_SRSUBsi, `SR_IDX_SSP, 14'd2)) $fatal;
        tick(); if (instr_out !== pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd0)) $fatal;
        tick(); if (instr_out !== pack_sr_sr(`OPC_SRMOVur, `SR_IDX_LR, `SR_IDX_PC)) $fatal;
        tick(); if (instr_out !== pack_jccui(4'b0000, 12'hABC)) $fatal;

        // 3) BSRsr expands to LR push + BCCsr
        instr_in = { `OPC_BSRsr, 4'h3, 4'b0000, 8'b0 };
        tick(); if (instr_out !== pack_sr_imm14(`OPC_SRSUBsi, `SR_IDX_SSP, 14'd2)) $fatal;
        tick(); if (instr_out !== pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd0)) $fatal;
        tick(); if (instr_out !== pack_sr_sr(`OPC_SRMOVur, `SR_IDX_LR, `SR_IDX_PC)) $fatal;
        tick(); if (instr_out !== pack_bccsr(4'h3, 4'b0000)) $fatal;

        // 4) BSRso expands to LR push + BALso
        instr_in = { `OPC_BSRso, 16'h00F0 };
        tick(); if (instr_out !== pack_sr_imm14(`OPC_SRSUBsi, `SR_IDX_SSP, 14'd2)) $fatal;
        tick(); if (instr_out !== pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd0)) $fatal;
        tick(); if (instr_out !== pack_sr_sr(`OPC_SRMOVur, `SR_IDX_LR, `SR_IDX_PC)) $fatal;
        tick(); if (instr_out !== pack_balso(16'h00F0)) $fatal;

        // 5) RET expands to: SRSSP+=2; SRLDso LR, -2(SSP); SRJCCso LR+#1 (AL)
        instr_in = { `OPC_RET, 16'b0 };
        tick(); if (instr_out !== pack_sr_imm14(`OPC_SRADDsi, `SR_IDX_SSP, 14'd2)) $fatal;
        tick(); if (instr_out !== pack_sr_sr_imm12(`OPC_SRLDso, `SR_IDX_LR, `SR_IDX_SSP, -12'sd2)) $fatal;
        tick(); if (instr_out !== pack_sr_cc_imm10(`OPC_SRJCCso, `SR_IDX_LR, 4'b0000, 10'sd1)) $fatal;
        // leave one idle tick to drop busy before next macro
        instr_in = { `OPC_NOP, 16'h0000 };
        tick();
        // 6) SETSSP: SRMOVAur ARs -> SR[SSP]
        instr_in = { `OPC_SETSSP, 2'b01, 14'b0 };
        tick(); if (instr_out !== { `OPC_SRMOVAur, `SR_IDX_SSP, 2'b01, 12'b0 }) $fatal;
        
        // 7) Pass-through ones (JCCui/BCCsr/BCCso/BALso)
        instr_in = { `OPC_JCCui, 4'b1010, 12'h123 };
        tick(); if (instr_out !== instr_in) $fatal;
        instr_in = { `OPC_BCCsr, 4'h3, 4'b0001, 8'b0 };
        tick(); if (instr_out !== instr_in) $fatal;
        instr_in = { `OPC_BCCso, 4'b0110, 12'hFE0 };
        tick(); if (instr_out !== instr_in) $fatal;
        instr_in = { `OPC_BALso, 16'h0001 };
        tick(); if (instr_out !== instr_in) $fatal;

        $display("xt_translate_tb PASS");
        $finish;
    end
endmodule
