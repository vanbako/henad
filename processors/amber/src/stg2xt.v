`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/opcodes.vh"

module stg_xt(
    input wire                 iw_clk,
    input wire                 iw_rst,
    input wire  [`HBIT_ADDR:0] iw_pc,
    output wire [`HBIT_ADDR:0] ow_pc,
    input wire  [`HBIT_DATA:0] iw_instr,
    output wire [`HBIT_DATA:0] ow_instr,
    input wire                 iw_flush,
    input wire                 iw_stall
);
    // Translate stage: expand ISA macros into micro-ops.
    localparam integer MAX_SEQ = 64;

    // Decode convenience wires from incoming instruction
    wire [`HBIT_OPC:0]     w_opc       = iw_instr[`HBIT_INSTR_OPC:`LBIT_INSTR_OPC];
    wire [`HBIT_OPCLASS:0] w_opclass   = iw_instr[`HBIT_INSTR_OPCLASS:`LBIT_INSTR_OPCLASS];
    wire [`HBIT_SUBOP:0]   w_subop     = iw_instr[`HBIT_INSTR_SUBOP:`LBIT_INSTR_SUBOP];
    wire [`HBIT_IMM14:0]   w_imm14_val = iw_instr[`HBIT_INSTR_IMM14:0];
    wire [`HBIT_IMM12:0]   w_imm12_val = iw_instr[`HBIT_INSTR_IMM12:0];
    wire [`HBIT_IMM10:0]   w_imm10_val = iw_instr[`HBIT_INSTR_IMM10:0];
    wire [`HBIT_IMM8:0]    w_imm8_val  = iw_instr[`HBIT_INSTR_IMM8:0];

    // Packing helpers for composing micro-ops
    function automatic [`HBIT_DATA:0] pack_nop;
        begin
            pack_nop = { `OPC_NOP, 16'b0 };
        end
    endfunction

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

    // AR/legacy packers removed with deprecation of undocumented AR ops

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

    function automatic [`HBIT_DATA:0] pack_bccso;
        input [3:0]         cc;
        input [11:0]        imm12;
        begin
            pack_bccso = { `OPC_BCCso, cc, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_balso;
        input [15:0]        imm16;
        begin
            pack_balso = { `OPC_BALso, imm16 };
        end
    endfunction

    // New micro-op packers for CR<->SR moves
    function automatic [`HBIT_DATA:0] pack_cr2sr;
        input [1:0] tgt_sr;
        input [1:0] src_cr;
        input [3:0] fld;
        begin
            // {OPC_CR2SR, tgt_sr[1:0], src_cr[1:0], fld[3:0], 8'b0}
            pack_cr2sr = { `OPC_CR2SR, tgt_sr, src_cr, fld, 8'b0 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_sr2cr;
        input [1:0] tgt_cr;
        input [1:0] src_sr;
        input [3:0] fld;
        begin
            // {OPC_SR2CR, tgt_cr[1:0], src_sr[1:0], fld[3:0], 8'b0}
            pack_sr2cr = { `OPC_SR2CR, tgt_cr, src_sr, fld, 8'b0 };
        end
    endfunction

    // Working registers and sequence buffers
    reg [`HBIT_ADDR:0] r_pc;
    reg [`HBIT_DATA:0] r_instr;
    reg                 r_busy;
    reg  [5:0]          r_idx;
    reg  [5:0]          r_cnt;
    reg  [`HBIT_DATA:0] r_instr_list [0:MAX_SEQ-1];
    reg  [`HBIT_ADDR:0] r_pc_hold;

    // Next sequence (combinational) when starting a new ISA op
    reg                 w_seq_start;
    reg  [5:0]          w_seq_len;
    reg  [`HBIT_DATA:0] w_seq_list [0:MAX_SEQ-1];
    integer ii;

    // Combinational translation
    always @(*) begin
        // Defaults for a potential new sequence
        w_seq_start   = 1'b0;
        w_seq_len     = 6'd0;
        w_seq_list[0] = {`SIZE_DATA{1'b0}};
        w_seq_list[1] = {`SIZE_DATA{1'b0}};
        w_seq_list[2] = {`SIZE_DATA{1'b0}};
        w_seq_list[3] = {`SIZE_DATA{1'b0}};

        // Hold original PC during expansion sequences
        r_pc = (r_busy) ? r_pc_hold : iw_pc;

        if (r_busy) begin
            // Emit current micro-op from active sequence
            r_instr = r_instr_list[r_idx];
        end else begin
            // Not in a sequence: either pass-through or start one
            case (w_opclass)
                `OPCLASS_0, `OPCLASS_1, `OPCLASS_2, `OPCLASS_3,
                `OPCLASS_4: begin
                    // Pass-through except CLD/CST which expand
                    if (w_subop == `SUBOP_CLDcso) begin
                        // CLDcso #offs(CRs), CRt
                        // Build a widened sequence using LR as base pointer and SSP as temp data SR.
                        // Insert 6 NOPs between producer/consumer to avoid needing forwarding.
                        w_seq_start   = 1'b1;
                        w_seq_len     = 6'd50;
                        // indices per encoding
                        // CRs at [13:12], CRt at [15:14]
                        w_seq_list[0] = pack_cr2sr(`SR_IDX_LR, iw_instr[13:12], `CR_FLD_CUR);
                        w_seq_list[1] = pack_sr_imm14(`OPC_SRADDsi, `SR_IDX_LR, {{4{w_imm10_val[9]}}, w_imm10_val});
                        // BASE
                        w_seq_list[2]  = pack_sr_sr_imm12(`OPC_SRLDso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd0);
                        w_seq_list[3]  = pack_nop();
                        w_seq_list[4]  = pack_nop();
                        w_seq_list[5]  = pack_nop();
                        w_seq_list[6]  = pack_nop();
                        w_seq_list[7]  = pack_nop();
                        w_seq_list[8]  = pack_nop();
                        w_seq_list[9]  = pack_sr2cr(iw_instr[15:14], `SR_IDX_SSP, `CR_FLD_BASE);
                        // LEN
                        w_seq_list[10] = pack_sr_sr_imm12(`OPC_SRLDso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd2);
                        w_seq_list[11] = pack_nop();
                        w_seq_list[12] = pack_nop();
                        w_seq_list[13] = pack_nop();
                        w_seq_list[14] = pack_nop();
                        w_seq_list[15] = pack_nop();
                        w_seq_list[16] = pack_nop();
                        w_seq_list[17] = pack_sr2cr(iw_instr[15:14], `SR_IDX_SSP, `CR_FLD_LEN);
                        // CUR
                        w_seq_list[18] = pack_sr_sr_imm12(`OPC_SRLDso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd4);
                        w_seq_list[19] = pack_nop();
                        w_seq_list[20] = pack_nop();
                        w_seq_list[21] = pack_nop();
                        w_seq_list[22] = pack_nop();
                        w_seq_list[23] = pack_nop();
                        w_seq_list[24] = pack_nop();
                        w_seq_list[25] = pack_sr2cr(iw_instr[15:14], `SR_IDX_SSP, `CR_FLD_CUR);
                        // PERMS
                        w_seq_list[26] = pack_sr_sr_imm12(`OPC_SRLDso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd6);
                        w_seq_list[27] = pack_nop();
                        w_seq_list[28] = pack_nop();
                        w_seq_list[29] = pack_nop();
                        w_seq_list[30] = pack_nop();
                        w_seq_list[31] = pack_nop();
                        w_seq_list[32] = pack_nop();
                        w_seq_list[33] = pack_sr2cr(iw_instr[15:14], `SR_IDX_SSP, `CR_FLD_PERMS);
                        // ATTR
                        w_seq_list[34] = pack_sr_sr_imm12(`OPC_SRLDso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd8);
                        w_seq_list[35] = pack_nop();
                        w_seq_list[36] = pack_nop();
                        w_seq_list[37] = pack_nop();
                        w_seq_list[38] = pack_nop();
                        w_seq_list[39] = pack_nop();
                        w_seq_list[40] = pack_nop();
                        w_seq_list[41] = pack_sr2cr(iw_instr[15:14], `SR_IDX_SSP, `CR_FLD_ATTR);
                        // TAG
                        w_seq_list[42] = pack_sr_sr_imm12(`OPC_SRLDso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd10);
                        w_seq_list[43] = pack_nop();
                        w_seq_list[44] = pack_nop();
                        w_seq_list[45] = pack_nop();
                        w_seq_list[46] = pack_nop();
                        w_seq_list[47] = pack_nop();
                        w_seq_list[48] = pack_nop();
                        w_seq_list[49] = pack_sr2cr(iw_instr[15:14], `SR_IDX_SSP, `CR_FLD_TAG);
                        r_instr       = w_seq_list[0];
                    end else if (w_subop == `SUBOP_CSTcso) begin
                        // CSTcso CRs, #offs(CRt)
                        w_seq_start   = 1'b1;
                        w_seq_len     = 6'd50;
                        // Effective address from CRt.cur + off into LR
                        w_seq_list[0] = pack_cr2sr(`SR_IDX_LR, iw_instr[15:14], `CR_FLD_CUR);
                        w_seq_list[1] = pack_sr_imm14(`OPC_SRADDsi, `SR_IDX_LR, {{4{w_imm10_val[9]}}, w_imm10_val});
                        // BASE
                        w_seq_list[2]  = pack_cr2sr(`SR_IDX_SSP, iw_instr[13:12], `CR_FLD_BASE);
                        w_seq_list[3]  = pack_nop();
                        w_seq_list[4]  = pack_nop();
                        w_seq_list[5]  = pack_nop();
                        w_seq_list[6]  = pack_nop();
                        w_seq_list[7]  = pack_nop();
                        w_seq_list[8]  = pack_nop();
                        w_seq_list[9]  = pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_LR, `SR_IDX_SSP, 12'sd0);
                        // LEN
                        w_seq_list[10] = pack_cr2sr(`SR_IDX_SSP, iw_instr[13:12], `CR_FLD_LEN);
                        w_seq_list[11] = pack_nop();
                        w_seq_list[12] = pack_nop();
                        w_seq_list[13] = pack_nop();
                        w_seq_list[14] = pack_nop();
                        w_seq_list[15] = pack_nop();
                        w_seq_list[16] = pack_nop();
                        w_seq_list[17] = pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_LR, `SR_IDX_SSP, 12'sd2);
                        // CUR
                        w_seq_list[18] = pack_cr2sr(`SR_IDX_SSP, iw_instr[13:12], `CR_FLD_CUR);
                        w_seq_list[19] = pack_nop();
                        w_seq_list[20] = pack_nop();
                        w_seq_list[21] = pack_nop();
                        w_seq_list[22] = pack_nop();
                        w_seq_list[23] = pack_nop();
                        w_seq_list[24] = pack_nop();
                        w_seq_list[25] = pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_LR, `SR_IDX_SSP, 12'sd4);
                        // PERMS
                        w_seq_list[26] = pack_cr2sr(`SR_IDX_SSP, iw_instr[13:12], `CR_FLD_PERMS);
                        w_seq_list[27] = pack_nop();
                        w_seq_list[28] = pack_nop();
                        w_seq_list[29] = pack_nop();
                        w_seq_list[30] = pack_nop();
                        w_seq_list[31] = pack_nop();
                        w_seq_list[32] = pack_nop();
                        w_seq_list[33] = pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_LR, `SR_IDX_SSP, 12'sd6);
                        // ATTR
                        w_seq_list[34] = pack_cr2sr(`SR_IDX_SSP, iw_instr[13:12], `CR_FLD_ATTR);
                        w_seq_list[35] = pack_nop();
                        w_seq_list[36] = pack_nop();
                        w_seq_list[37] = pack_nop();
                        w_seq_list[38] = pack_nop();
                        w_seq_list[39] = pack_nop();
                        w_seq_list[40] = pack_nop();
                        w_seq_list[41] = pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_LR, `SR_IDX_SSP, 12'sd8);
                        // TAG
                        w_seq_list[42] = pack_cr2sr(`SR_IDX_SSP, iw_instr[13:12], `CR_FLD_TAG);
                        w_seq_list[43] = pack_nop();
                        w_seq_list[44] = pack_nop();
                        w_seq_list[45] = pack_nop();
                        w_seq_list[46] = pack_nop();
                        w_seq_list[47] = pack_nop();
                        w_seq_list[48] = pack_nop();
                        w_seq_list[49] = pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_LR, `SR_IDX_SSP, 12'sd10);
                        r_instr       = w_seq_list[0];
                    end else begin
                        r_instr = iw_instr;
                    end
                end
                `OPCLASS_5: begin
                    r_instr = iw_instr;
                end
                // OPCLASS_6: Control flow (per updated documentation)
                `OPCLASS_6: begin
                    case (w_subop)
                        `SUBOP_BTP: begin
                            r_instr = pack_nop();
                        end
                        // Pass-through ISA ops for control flow
                        `SUBOP_JCCui, `SUBOP_BCCsr, `SUBOP_BCCso, `SUBOP_BALso: begin
                            r_instr = iw_instr;
                        end
                        `SUBOP_JSRui: begin
                            w_seq_start   = 1'b1;
                            w_seq_len     = 3'd4;
                            w_seq_list[0] = pack_sr_imm14(`OPC_SRSUBsi, `SR_IDX_SSP, 14'd2);
                            w_seq_list[1] = pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd0);
                            w_seq_list[2] = pack_sr_sr(`OPC_SRMOVur, `SR_IDX_LR, `SR_IDX_PC);
                            w_seq_list[3] = pack_jccui(4'b0000, w_imm12_val);
                            r_instr       = w_seq_list[0];
                        end
                        `SUBOP_BSRsr: begin
                            w_seq_start   = 1'b1;
                            w_seq_len     = 3'd4;
                            w_seq_list[0] = pack_sr_imm14(`OPC_SRSUBsi, `SR_IDX_SSP, 14'd2);
                            w_seq_list[1] = pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd0);
                            w_seq_list[2] = pack_sr_sr(`OPC_SRMOVur, `SR_IDX_LR, `SR_IDX_PC);
                            w_seq_list[3] = pack_bccsr(iw_instr[15:12], 4'b0000);
                            r_instr       = w_seq_list[0];
                        end
                        `SUBOP_BSRso: begin
                            w_seq_start   = 1'b1;
                            w_seq_len     = 3'd4;
                            w_seq_list[0] = pack_sr_imm14(`OPC_SRSUBsi, `SR_IDX_SSP, 14'd2);
                            w_seq_list[1] = pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd0);
                            w_seq_list[2] = pack_sr_sr(`OPC_SRMOVur, `SR_IDX_LR, `SR_IDX_PC);
                            w_seq_list[3] = pack_balso(iw_instr[15:0]);
                            r_instr       = w_seq_list[0];
                        end
                        `SUBOP_RET: begin
                            w_seq_start   = 1'b1;
                            w_seq_len     = 3'd3;
                            w_seq_list[0] = pack_sr_imm14(`OPC_SRADDsi, `SR_IDX_SSP, 14'd2);
                            w_seq_list[1] = pack_sr_sr_imm12(`OPC_SRLDso, `SR_IDX_LR, `SR_IDX_SSP, -12'sd2);
                            w_seq_list[2] = pack_sr_cc_imm10(`OPC_SRJCCso, `SR_IDX_LR, 4'b0000, 10'sd1);
                            r_instr       = w_seq_list[0];
                        end
                        default: begin
                            r_instr = {`SIZE_DATA{1'b0}};
                        end
                    endcase
                end
                // OPCLASS_7: Stack helpers (deprecated legacy AR expansion removed)
                `OPCLASS_7: begin
                    r_instr = iw_instr; // pass-through (no expansion in this build)
                end
                // OPCLASS_9: privileged
                `OPCLASS_9: begin
                    if (w_subop == `SUBOP_SETSSP) begin
                        r_instr = { `OPC_SRMOVAur, `SR_IDX_SSP, iw_instr[15:14], 12'b0 };
                    end else begin
                        r_instr = iw_instr;
                    end
                end
                `OPCLASS_F: begin
                    r_instr = iw_instr;
                end
                default: begin
                    r_instr = {`SIZE_DATA{1'b0}};
                end
            endcase
            if (w_seq_start) begin
                // debug: show expansion
                $display("[XT] expand op=%h len=%0d", iw_instr, w_seq_len);
            end
        end
    end

    // Output latches and sequence control
    reg [`HBIT_ADDR:0] r_pc_latch;
    reg [`HBIT_DATA:0] r_instr_latch;

    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_busy       <= 1'b0;
            r_idx        <= 4'd0;
            r_cnt        <= 4'd0;
            r_pc_hold    <= {`SIZE_ADDR{1'b0}};
            for (ii = 0; ii < MAX_SEQ; ii = ii + 1) begin
                r_instr_list[ii] <= {`SIZE_DATA{1'b0}};
            end
            r_pc_latch    <= `SIZE_ADDR'b0;
            r_instr_latch <= `SIZE_DATA'b0;
        end else if (iw_flush) begin
            // Cancel any in-flight macro translation
            r_busy       <= 1'b0;
            r_idx        <= 4'd0;
            r_cnt        <= 4'd0;
            r_pc_hold    <= {`SIZE_ADDR{1'b0}};
            r_pc_latch    <= `SIZE_ADDR'b0;
            r_instr_latch <= `SIZE_DATA'b0;
        end else if (iw_stall) begin
            r_pc_latch    <= r_pc_latch;
            r_instr_latch <= r_instr_latch;
            // Hold sequence index while stalled
            r_idx         <= r_idx;
            r_busy        <= r_busy;
            r_cnt         <= r_cnt;
            r_pc_hold     <= r_pc_hold;
        end else begin
            // Latch current outputs
            r_pc_latch    <= r_pc;
            r_instr_latch <= r_instr;
            // Advance or start sequence machinery
            if (r_busy) begin
                if ((r_idx + 6'd1) < r_cnt) begin
                    r_idx <= r_idx + 6'd1;
                end else begin
                    // Finished last micro-op
                    r_busy <= 1'b0;
                    r_idx  <= 6'd0;
                    r_cnt  <= 6'd0;
                end
            end else if (w_seq_start) begin
                // Begin a new multi-uop expansion. We already emitted element 0.
                r_busy    <= 1'b1;
                r_idx     <= 6'd1;
                r_cnt     <= w_seq_len;
                r_pc_hold <= iw_pc;
                for (ii = 0; ii < MAX_SEQ; ii = ii + 1) begin
                    r_instr_list[ii] <= w_seq_list[ii];
                end
            end else begin
                // No sequence, maintain idle state
                r_busy <= 1'b0;
                r_idx  <= 6'd0;
                r_cnt  <= 6'd0;
            end
        end
    end

    assign ow_pc    = r_pc_latch;
    assign ow_instr = r_instr_latch;
endmodule
