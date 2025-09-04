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
    localparam integer MAX_SEQ = 4;

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

    function automatic [`HBIT_DATA:0] pack_ar_imm12;
        input [`HBIT_OPC:0] opc;
        input [1:0]         tgt_ar;
        input [11:0]        imm12;
        begin
            pack_ar_imm12 = { opc, tgt_ar, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_sta_so;
        input [1:0]         tgt_ar;
        input [1:0]         src_ar;
        input [11:0]        imm12;
        begin
            pack_sta_so = { `OPC_STAso, tgt_ar, src_ar, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_stur;
        input [1:0]         tgt_ar;
        input [3:0]         src_dr;
        begin
            pack_stur = { `OPC_STur, tgt_ar, src_dr, 10'b0 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_stso;
        input [1:0]         tgt_ar;
        input [3:0]         src_dr;
        input [9:0]         imm10;
        begin
            pack_stso = { `OPC_STso, tgt_ar, src_dr, imm10 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_ldso;
        input [3:0]         tgt_dr;
        input [1:0]         src_ar;
        input [9:0]         imm10;
        begin
            pack_ldso = { `OPC_LDso, tgt_dr, src_ar, imm10 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_ldur;
        input [3:0]         tgt_dr;
        input [1:0]         src_ar;
        begin
            pack_ldur = { `OPC_LDur, tgt_dr, src_ar, 10'b0 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_lda_so;
        input [1:0]         tgt_ar;
        input [1:0]         src_ar;
        input [11:0]        imm12;
        begin
            pack_lda_so = { `OPC_LDAso, tgt_ar, src_ar, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_addasi;
        input [1:0]         tgt_ar;
        input [11:0]        imm12;
        begin
            // OPCLASS_6 immediate encoding: [23:16]=OPC, [15:14]=ARt, [13:12]=resv0, [11:0]=imm12
            pack_addasi = { `OPC_ADDAsi, tgt_ar, 2'b00, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_subasi;
        input [1:0]         tgt_ar;
        input [11:0]        imm12;
        begin
            // OPCLASS_6 immediate encoding: [23:16]=OPC, [15:14]=ARt, [13:12]=resv0, [11:0]=imm12
            pack_subasi = { `OPC_SUBAsi, tgt_ar, 2'b00, imm12 };
        end
    endfunction

    function automatic [`HBIT_DATA:0] pack_jccur;
        input [1:0]         tgt_ar;
        input [3:0]         cc;
        begin
            pack_jccur = { `OPC_JCCur, tgt_ar, cc, 10'b0 };
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

    // Working registers and sequence buffers
    reg [`HBIT_ADDR:0] r_pc;
    reg [`HBIT_DATA:0] r_instr;
    reg                 r_busy;
    reg  [2:0]          r_idx;
    reg  [2:0]          r_cnt;
    reg  [`HBIT_DATA:0] r_instr_list [0:MAX_SEQ-1];
    reg  [`HBIT_ADDR:0] r_pc_hold;

    // Next sequence (combinational) when starting a new ISA op
    reg                 w_seq_start;
    reg  [2:0]          w_seq_len;
    reg  [`HBIT_DATA:0] w_seq_list [0:MAX_SEQ-1];

    // Combinational translation
    always @(*) begin
        // Defaults for a potential new sequence
        w_seq_start   = 1'b0;
        w_seq_len     = 3'd0;
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
                `OPCLASS_4, `OPCLASS_5, `OPCLASS_6: begin
                    r_instr = iw_instr;
                end
                `OPCLASS_7: begin
                    case (w_subop)
                        `SUBOP_BTP: begin
                            r_instr = pack_nop();
                        end
                        `SUBOP_JCCur, `SUBOP_JCCui, `SUBOP_BCCsr, `SUBOP_BCCso, `SUBOP_BALso: begin
                            r_instr = iw_instr;
                        end
                        `SUBOP_JSRur: begin
                            w_seq_start   = 1'b1;
                            w_seq_len     = 3'd4;
                            w_seq_list[0] = pack_sr_imm14(`OPC_SRSUBsi, `SR_IDX_SSP, 14'd2);
                            w_seq_list[1] = pack_sr_sr_imm12(`OPC_SRSTso, `SR_IDX_SSP, `SR_IDX_LR, 12'sd0);
                            w_seq_list[2] = pack_sr_sr(`OPC_SRMOVur, `SR_IDX_LR, `SR_IDX_PC);
                            w_seq_list[3] = pack_jccur(iw_instr[15:14], 4'b0000);
                            r_instr       = w_seq_list[0];
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
                `OPCLASS_8: begin
                    case (w_subop)
                        `SUBOP_PUSHur: begin
                            w_seq_start   = 1'b1;
                            w_seq_len     = 3'd2;
                            w_seq_list[0] = pack_subasi(iw_instr[15:14], 12'sd1);
                            w_seq_list[1] = pack_stur(iw_instr[15:14], iw_instr[13:10]);
                            r_instr       = w_seq_list[0];
                        end
                        `SUBOP_PUSHAur: begin
                            w_seq_start   = 1'b1;
                            w_seq_len     = 3'd2;
                            w_seq_list[0] = pack_subasi(iw_instr[15:14], 12'sd2);
                            w_seq_list[1] = pack_sta_so(iw_instr[15:14], iw_instr[13:12], 12'sd0);
                            r_instr       = w_seq_list[0];
                        end
                        `SUBOP_POPur: begin
                            w_seq_start   = 1'b1;
                            w_seq_len     = 3'd2;
                            w_seq_list[0] = pack_addasi(iw_instr[11:10], 12'sd1);
                            w_seq_list[1] = pack_ldso(iw_instr[15:12], iw_instr[11:10], -10'sd1);
                            r_instr       = w_seq_list[0];
                        end
                        `SUBOP_POPAur: begin
                            w_seq_start   = 1'b1;
                            w_seq_len     = 3'd2;
                            w_seq_list[0] = pack_addasi(iw_instr[13:12], 12'sd2);
                            w_seq_list[1] = pack_lda_so(iw_instr[15:14], iw_instr[13:12], -12'sd2);
                            r_instr       = w_seq_list[0];
                        end
                        default: begin
                            r_instr = {`SIZE_DATA{1'b0}};
                        end
                    endcase
                end
                `OPCLASS_A: begin
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
        end
    end

    // Output latches and sequence control
    reg [`HBIT_ADDR:0] r_pc_latch;
    reg [`HBIT_DATA:0] r_instr_latch;

    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_busy       <= 1'b0;
            r_idx        <= 3'd0;
            r_cnt        <= 3'd0;
            r_pc_hold    <= {`SIZE_ADDR{1'b0}};
            r_instr_list[0] <= {`SIZE_DATA{1'b0}};
            r_instr_list[1] <= {`SIZE_DATA{1'b0}};
            r_instr_list[2] <= {`SIZE_DATA{1'b0}};
            r_instr_list[3] <= {`SIZE_DATA{1'b0}};
            r_pc_latch    <= `SIZE_ADDR'b0;
            r_instr_latch <= `SIZE_DATA'b0;
        end else if (iw_flush) begin
            // Cancel any in-flight macro translation
            r_busy       <= 1'b0;
            r_idx        <= 3'd0;
            r_cnt        <= 3'd0;
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
                if ((r_idx + 3'd1) < r_cnt) begin
                    r_idx <= r_idx + 3'd1;
                end else begin
                    // Finished last micro-op
                    r_busy <= 1'b0;
                    r_idx  <= 3'd0;
                    r_cnt  <= 3'd0;
                end
            end else if (w_seq_start) begin
                // Begin a new multi-uop expansion. We already emitted element 0.
                r_busy    <= 1'b1;
                r_idx     <= 3'd1;
                r_cnt     <= w_seq_len;
                r_pc_hold <= iw_pc;
                r_instr_list[0] <= w_seq_list[0];
                r_instr_list[1] <= w_seq_list[1];
                r_instr_list[2] <= w_seq_list[2];
                r_instr_list[3] <= w_seq_list[3];
            end else begin
                // No sequence, maintain idle state
                r_busy <= 1'b0;
                r_idx  <= 3'd0;
                r_cnt  <= 3'd0;
            end
        end
    end

    assign ow_pc    = r_pc_latch;
    assign ow_instr = r_instr_latch;
endmodule

