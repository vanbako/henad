`include "src/sizes.vh"
`include "src/opcodes.vh"

module stg_id(
    input wire                    iw_clk,
    input wire                    iw_rst,
    input wire  [`HBIT_ADDR:0]    iw_pc,
    output wire [`HBIT_ADDR:0]    ow_pc,
    input wire  [`HBIT_DATA:0]    iw_instr,
    output wire [`HBIT_DATA:0]    ow_instr,
    output wire [`HBIT_OPC:0]     ow_opc,
    output wire                   ow_sgn_en,
    output wire                   ow_imm_en,
    output wire [`HBIT_IMM14:0]   ow_imm14_val,
    output wire [`HBIT_IMM12:0]   ow_imm12_val,
    output wire [`HBIT_IMM10:0]   ow_imm10_val,
    output wire [`HBIT_IMM16:0]   ow_imm16_val,
    output wire [`HBIT_CC:0]      ow_cc,
    output wire                   ow_has_src_gp,
    output wire [`HBIT_ADDR_GP:0] ow_src_gp,
    output wire [`HBIT_ADDR_GP:0] ow_tgt_gp,
    output wire                   ow_tgt_gp_we,
    output wire                   ow_has_src_ar,
    output wire [`HBIT_TGT_AR:0]  ow_src_ar,
    output wire                   ow_has_tgt_ar,
    output wire [`HBIT_TGT_AR:0]  ow_tgt_ar,
    output wire                   ow_has_src_sr,
    output wire [`HBIT_ADDR_SR:0] ow_src_sr,
    output wire [`HBIT_ADDR_SR:0] ow_tgt_sr,
    output wire                   ow_tgt_sr_we,
    input wire                    iw_flush,
    input wire                    iw_stall
);
    wire [`HBIT_OPC:0]     w_opc     = iw_instr[`HBIT_INSTR_OPC:16];
    wire [`HBIT_OPCLASS:0] w_opclass = iw_instr[`HBIT_INSTR_OPCLASS:`LBIT_INSTR_OPCLASS];
    wire [`HBIT_SUBOP:0]   w_subop   = iw_instr[`HBIT_INSTR_SUBOP:`LBIT_INSTR_SUBOP];

    // Signed immediates present
    wire w_sgn_en =
        (w_opclass == `OPCLASS_2) || (w_opclass == `OPCLASS_3) || (w_opclass == `OPCLASS_5) ||
        (w_opc == `OPC_STsi)      ||
        (w_opc == `OPC_ADDAsr)    || (w_opc == `OPC_SUBAsr)    || (w_opc == `OPC_ADDAsi)    ||
        (w_opc == `OPC_SUBAsi)    || (w_opc == `OPC_LEAso)     || (w_opc == `OPC_ADRAso)    ||
        (w_opc == `OPC_BCCsr)     || (w_opc == `OPC_BCCso)     || (w_opc == `OPC_BALso)     ||
        (w_opc == `OPC_SRJCCso)   || (w_opc == `OPC_SRADDsi)   || (w_opc == `OPC_SRSUBsi)   ||
        (w_opc == `OPC_SRSTso)    || (w_opc == `OPC_SRLDso);

    // Immediates present (any size)
    wire w_imm_en =
        (w_opclass == `OPCLASS_1) || (w_opclass == `OPCLASS_3) || (w_opclass == `OPCLASS_5) ||
        (w_opc == `OPC_ADDAsi)    || (w_opc == `OPC_SUBAsi)    || (w_opc == `OPC_LEAso)     ||
        (w_opc == `OPC_ADRAso)    || (w_opc == `OPC_STui)      || (w_opc == `OPC_STsi)      ||
        (w_opc == `OPC_JCCui)     || (w_opc == `OPC_BCCso)     || (w_opc == `OPC_BALso)     ||
        (w_opc == `OPC_SRJCCso)   || (w_opc == `OPC_SRADDsi)   || (w_opc == `OPC_SRSUBsi)   ||
        (w_opc == `OPC_SRSTso)    || (w_opc == `OPC_SRLDso)    ||
        (w_opc == `OPC_ROLui)     || (w_opc == `OPC_RORui);

    // Branch classification
    wire w_is_branch =
        (w_opc == `OPC_JCCur)     || (w_opc == `OPC_JCCui)     || (w_opc == `OPC_BCCsr)     ||
        (w_opc == `OPC_BCCso)     || (w_opc == `OPC_BALso)     || (w_opc == `OPC_SRJCCso);
    // Consumers of FLAGS (use SR[FL] as implicit source)
    wire w_uses_flags = w_is_branch || (w_opc == `OPC_MCCur) || (w_opc == `OPC_MCCsi);

    // GP target write enable
    wire w_tgt_gp_we =
        (w_opc == `OPC_MOVur)     || (w_opc == `OPC_ADDur)     || (w_opc == `OPC_SUBur)   ||
        (w_opc == `OPC_NOTur)     || (w_opc == `OPC_ANDur)     || (w_opc == `OPC_ORur)    ||
        (w_opc == `OPC_XORur)     || (w_opc == `OPC_SHLur)     || (w_opc == `OPC_SHRur)   ||
        (w_opc == `OPC_ROLur)     || (w_opc == `OPC_RORur)     ||
        (w_opc == `OPC_LDur)      ||
        (w_opc == `OPC_ADDsr)     || (w_opc == `OPC_SUBsr)     || (w_opc == `OPC_SHRsr)   || (w_opc == `OPC_NEGsr) ||
        (w_opc == `OPC_MOVui)     || (w_opc == `OPC_ADDui)     || (w_opc == `OPC_SUBui)   ||
        (w_opc == `OPC_ANDui)     || (w_opc == `OPC_ORui)      || (w_opc == `OPC_XORui)   ||
        (w_opc == `OPC_SHLui)     || (w_opc == `OPC_SHRui)     || (w_opc == `OPC_ROLui)   || (w_opc == `OPC_RORui) ||
        (w_opc == `OPC_MOVsi)     || (w_opc == `OPC_ADDsi)     || (w_opc == `OPC_SUBsi)   ||
        (w_opc == `OPC_SHRsi)     || (w_opc == `OPC_MCCur)     || (w_opc == `OPC_MCCsi)   ||
        // AR->DR move writes DRt
        (w_opc == `OPC_MOVDur);

    // Has GP target field present (even if not writing, e.g. CMP, ST)
    wire w_has_tgt_gp =
        w_tgt_gp_we                || (w_opc == `OPC_CMPur)     || (w_opc == `OPC_STur)     ||
        (w_opc == `OPC_CMPsr)     || (w_opc == `OPC_CMPui)     || (w_opc == `OPC_STui)     ||
        (w_opc == `OPC_STsi)      || (w_opc == `OPC_TSTur)     || (w_opc == `OPC_TSTsr)    ||
        (w_opc == `OPC_MCCur)     || (w_opc == `OPC_MCCsi);

    // SR target write enable
    wire w_tgt_sr_we =
        (w_opc == `OPC_SRMOVur)   || (w_opc == `OPC_SRADDsi)   ||
        (w_opc == `OPC_SRSUBsi)   || (w_opc == `OPC_SRLDso)    || (w_opc == `OPC_SRMOVAur);

    wire w_has_tgt_sr =
        w_tgt_sr_we               || (w_opc == `OPC_SRSTso);

    // Has GP source
    wire w_has_src_gp =
        (w_opc == `OPC_MOVur)     || (w_opc == `OPC_ADDur)     || (w_opc == `OPC_SUBur)   ||
        (w_opc == `OPC_ANDur)     || (w_opc == `OPC_ORur)      || (w_opc == `OPC_XORur)   ||
        (w_opc == `OPC_SHLur)     || (w_opc == `OPC_SHRur)     || (w_opc == `OPC_ROLur)   || (w_opc == `OPC_RORur) || (w_opc == `OPC_CMPur)   ||
        (w_opc == `OPC_LDur)      || (w_opc == `OPC_STur)      ||
        (w_opc == `OPC_ADDsr)     || (w_opc == `OPC_SUBsr)     || (w_opc == `OPC_SHRsr)   || (w_opc == `OPC_CMPsr) ||
        (w_opc == `OPC_BCCsr)     || (w_opc == `OPC_MCCur);

    // Has SR source
    wire w_has_src_sr =
        (w_opc == `OPC_SRMOVur)   || (w_opc == `OPC_SRJCCso) ||
        (w_opc == `OPC_SRLDso)    || (w_opc == `OPC_SRSTso)  ||
        w_uses_flags;

    // Default field extraction based on spec bit locations
    wire [`HBIT_IMM12:0] w_imm12_all = iw_instr[`HBIT_INSTR_IMM12:0];
    wire [`HBIT_IMM14:0] w_imm14_all = iw_instr[`HBIT_INSTR_IMM14:0];
    wire [`HBIT_IMM10:0] w_imm10_all = iw_instr[`HBIT_INSTR_IMM10:0];
    wire [`HBIT_IMM8:0]  w_imm8_all  = iw_instr[`HBIT_INSTR_IMM8:0];
    wire [`HBIT_IMM16:0] w_imm16_all = iw_instr[15:0];

    // Per-op immediate selection
    reg [`HBIT_IMM12:0] r_imm12_val;
    reg [`HBIT_IMM14:0] r_imm14_val;
    reg [`HBIT_IMM10:0] r_imm10_val;
    reg [`HBIT_IMM16:0] r_imm16_val;
    always @* begin
        r_imm12_val = {(`HBIT_IMM12+1){1'b0}};
        r_imm14_val = {(`HBIT_IMM14+1){1'b0}};
        r_imm10_val = {(`HBIT_IMM10+1){1'b0}};
        r_imm16_val = {(`HBIT_IMM16+1){1'b0}};
        case (w_opc)
            // 12-bit immediates
            `OPC_MOVui, `OPC_ADDui, `OPC_SUBui, `OPC_ANDui, `OPC_ORui, `OPC_XORui, `OPC_SHLui, `OPC_SHRui,
            `OPC_MOVsi, `OPC_ADDsi, `OPC_SUBsi, `OPC_SHRsi, `OPC_CMPsi,
            `OPC_JCCui,
            `OPC_LDAso, `OPC_STAso, `OPC_LEAso, `OPC_ADDAsi, `OPC_SUBAsi,
            `OPC_STui, `OPC_SRSTso, `OPC_SRLDso: begin
                r_imm12_val = w_imm12_all;
            end
            // 14-bit immediates
            `OPC_STsi, `OPC_ADRAso, `OPC_SRADDsi, `OPC_SRSUBsi: begin
                r_imm14_val = w_imm14_all;
            end
            // 10-bit immediate
            `OPC_SRJCCso, `OPC_LDso, `OPC_STso: begin
                r_imm10_val = w_imm10_all;
            end
            // 16-bit immediate
            `OPC_BALso: begin
                r_imm16_val = w_imm16_all;
            end
        endcase
    end

    // Branch condition code extraction (per encoding)
    reg [`HBIT_CC:0] r_cc;
    always @* begin
        r_cc = {(`HBIT_CC+1){1'b0}};
        case (w_opc)
            `OPC_JCCur: r_cc = iw_instr[13:10];
            `OPC_JCCui: r_cc = iw_instr[15:12];
            `OPC_BCCsr: r_cc = iw_instr[11:8];
            `OPC_BCCso: r_cc = iw_instr[15:12];
            `OPC_SRJCCso: r_cc = iw_instr[13:10];
            `OPC_MCCur:   r_cc = iw_instr[7:4];
            `OPC_MCCsi:   r_cc = iw_instr[11:8];
            default: r_cc = {(`HBIT_CC+1){1'b0}};
        endcase
    end

    // Register field extraction (spec bit positions)
    wire [`HBIT_TGT_GP:0] w_tgt_gp = w_has_tgt_gp ? iw_instr[15:12] : `SIZE_TGT_GP'b0;
    wire [`HBIT_SRC_GP:0] w_src_gp = w_has_src_gp ? iw_instr[11:8]  : `SIZE_SRC_GP'b0;
    wire [`HBIT_TGT_SR:0] w_tgt_sr = w_has_tgt_sr ? iw_instr[15:14] : `SIZE_TGT_SR'b0;
    wire [`HBIT_SRC_SR:0] w_src_sr = w_has_src_sr ? (w_uses_flags ? 2'b10 : iw_instr[13:12]) : `SIZE_SRC_SR'b0;

    // Address register fields (normalized per op)
    reg                   r_has_src_ar;
    reg [`HBIT_TGT_AR:0]  r_src_ar;
    reg                   r_has_tgt_ar;
    reg [`HBIT_TGT_AR:0]  r_tgt_ar;
    always @* begin
        r_has_src_ar = 1'b0; r_src_ar = {(`HBIT_TGT_AR+1){1'b0}};
        r_has_tgt_ar = 1'b0; r_tgt_ar = {(`HBIT_TGT_AR+1){1'b0}};
        case (w_opc)
            // OPCLASS_4 base
            `OPC_LDur:   begin r_has_src_ar = 1'b1; r_src_ar = iw_instr[11:10]; end
            `OPC_STur:   begin r_has_tgt_ar = 1'b1; r_tgt_ar = iw_instr[15:14]; end
            // OPCLASS_5 base + offset
            `OPC_LDso:   begin r_has_src_ar = 1'b1; r_src_ar = iw_instr[11:10]; end
            `OPC_STso:   begin r_has_tgt_ar = 1'b1; r_tgt_ar = iw_instr[15:14]; end
            `OPC_LDAso:  begin r_has_src_ar = 1'b1; r_src_ar = iw_instr[13:12]; r_has_tgt_ar = 1'b1; r_tgt_ar = iw_instr[15:14]; end
            `OPC_STAso:  begin r_has_src_ar = 1'b1; r_src_ar = iw_instr[13:12]; r_has_tgt_ar = 1'b1; r_tgt_ar = iw_instr[15:14]; end
            // OPCLASS_6 address ALU & moves
            `OPC_MOVAur, `OPC_ADDAur, `OPC_SUBAur, `OPC_ADDAsr, `OPC_SUBAsr, `OPC_ADDAsi, `OPC_SUBAsi,
            `OPC_LEAso, `OPC_ADRAso: begin r_has_tgt_ar = 1'b1; r_tgt_ar = iw_instr[15:14]; end
            `OPC_MOVDur: begin r_has_src_ar = 1'b1; r_src_ar = iw_instr[11:10]; end
            `OPC_CMPAur: begin r_has_src_ar = 1'b1; r_src_ar = iw_instr[13:12]; r_has_tgt_ar = 1'b1; r_tgt_ar = iw_instr[15:14]; end
            `OPC_TSTAur: begin r_has_tgt_ar = 1'b1; r_tgt_ar = iw_instr[15:14]; end
            // OPCLASS_7 control flow
            `OPC_JCCur: begin r_has_tgt_ar = 1'b1; r_tgt_ar = iw_instr[15:14]; end
            // OPCLASS_F SR/AR µops
            `OPC_SRMOVAur: begin r_has_src_ar = 1'b1; r_src_ar = iw_instr[13:12]; end
        endcase
    end

    reg [`HBIT_ADDR:0]   r_pc_latch;
    reg [`HBIT_DATA:0]   r_instr_latch;
    reg [`HBIT_OPC:0]    r_opc_latch;
    reg                  r_sgn_en_latch;
    reg                  r_imm_en_latch;
    reg [`HBIT_IMM14:0]  r_imm14_val_latch;
    reg [`HBIT_IMM12:0]  r_imm12_val_latch;
    reg [`HBIT_IMM10:0]  r_imm10_val_latch;
    reg [`HBIT_IMM16:0]  r_imm16_val_latch;
    reg [`HBIT_CC:0]     r_cc_latch;
    reg                  r_has_src_gp_latch;
    reg [`HBIT_TGT_GP:0] r_tgt_gp_latch;
    reg                  r_tgt_gp_we_latch;
    reg                  r_has_src_ar_latch;
    reg [`HBIT_TGT_AR:0] r_src_ar_latch;
    reg                  r_has_tgt_ar_latch;
    reg [`HBIT_TGT_AR:0] r_tgt_ar_latch;
    reg                  r_has_src_sr_latch;
    reg [`HBIT_TGT_SR:0] r_tgt_sr_latch;
    reg                  r_tgt_sr_we_latch;
    reg [`HBIT_SRC_GP:0] r_src_gp_latch;
    reg [`HBIT_SRC_SR:0] r_src_sr_latch;

    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_pc_latch         <= `SIZE_ADDR'b0;
            r_instr_latch      <= `SIZE_DATA'b0;
            r_opc_latch        <= `SIZE_OPC'b0;
            r_sgn_en_latch     <= 1'b0;
            r_imm_en_latch     <= 1'b0;
            r_imm14_val_latch  <= `SIZE_IMM14'b0;
            r_imm12_val_latch  <= `SIZE_IMM12'b0;
            r_imm10_val_latch  <= `SIZE_IMM10'b0;
            r_imm16_val_latch  <= `SIZE_IMM16'b0;
            r_cc_latch         <= `SIZE_CC'b0;
            r_has_src_gp_latch <= 1'b0;
            r_tgt_gp_latch     <= `SIZE_TGT_GP'b0;
            r_tgt_gp_we_latch  <= 1'b0;
            r_has_src_ar_latch <= 1'b0;
            r_src_ar_latch     <= `SIZE_TGT_AR'b0;
            r_has_tgt_ar_latch <= 1'b0;
            r_tgt_ar_latch     <= `SIZE_TGT_AR'b0;
            r_has_src_sr_latch <= 1'b0;
            r_tgt_sr_latch     <= `SIZE_TGT_SR'b0;
            r_tgt_sr_we_latch  <= 1'b0;
            r_src_gp_latch     <= `SIZE_SRC_GP'b0;
            r_src_sr_latch     <= `SIZE_SRC_SR'b0;
        end else if (iw_flush) begin
            r_pc_latch         <= `SIZE_ADDR'b0;
            r_instr_latch      <= `SIZE_DATA'b0;
            r_opc_latch        <= `SIZE_OPC'b0;
            r_sgn_en_latch     <= 1'b0;
            r_imm_en_latch     <= 1'b0;
            r_imm14_val_latch  <= `SIZE_IMM14'b0;
            r_imm12_val_latch  <= `SIZE_IMM12'b0;
            r_imm10_val_latch  <= `SIZE_IMM10'b0;
            r_imm16_val_latch  <= `SIZE_IMM16'b0;
            r_cc_latch         <= `SIZE_CC'b0;
            r_has_src_gp_latch <= 1'b0;
            r_tgt_gp_latch     <= `SIZE_TGT_GP'b0;
            r_tgt_gp_we_latch  <= 1'b0;
            r_has_src_ar_latch <= 1'b0;
            r_src_ar_latch     <= `SIZE_TGT_AR'b0;
            r_has_tgt_ar_latch <= 1'b0;
            r_tgt_ar_latch     <= `SIZE_TGT_AR'b0;
            r_has_src_sr_latch <= 1'b0;
            r_tgt_sr_latch     <= `SIZE_TGT_SR'b0;
            r_tgt_sr_we_latch  <= 1'b0;
            r_src_gp_latch     <= `SIZE_SRC_GP'b0;
            r_src_sr_latch     <= `SIZE_SRC_SR'b0;
        end else if (iw_stall) begin
            r_pc_latch         <= r_pc_latch;
            r_instr_latch      <= r_instr_latch;
            r_opc_latch        <= r_opc_latch;
            r_sgn_en_latch     <= r_sgn_en_latch;
            r_imm_en_latch     <= r_imm_en_latch;
            r_imm14_val_latch  <= r_imm14_val_latch;
            r_imm12_val_latch  <= r_imm12_val_latch;
            r_imm10_val_latch  <= r_imm10_val_latch;
            r_imm16_val_latch  <= r_imm16_val_latch;
            r_cc_latch         <= r_cc_latch;
            r_has_src_gp_latch <= r_has_src_gp_latch;
            r_tgt_gp_latch     <= r_tgt_gp_latch;
            r_tgt_gp_we_latch  <= r_tgt_gp_we_latch;
            r_has_src_ar_latch <= r_has_src_ar_latch;
            r_src_ar_latch     <= r_src_ar_latch;
            r_has_tgt_ar_latch <= r_has_tgt_ar_latch;
            r_tgt_ar_latch     <= r_tgt_ar_latch;
            r_has_src_sr_latch <= r_has_src_sr_latch;
            r_tgt_sr_latch     <= r_tgt_sr_latch;
            r_tgt_sr_we_latch  <= r_tgt_sr_we_latch;
            r_src_gp_latch     <= r_src_gp_latch;
            r_src_sr_latch     <= r_src_sr_latch;
        end else begin
            r_pc_latch         <= iw_pc;
            r_instr_latch      <= iw_instr;
            r_opc_latch        <= w_opc;
            r_sgn_en_latch     <= w_sgn_en;
            r_imm_en_latch     <= w_imm_en;
            r_imm14_val_latch  <= r_imm14_val;
            r_imm12_val_latch  <= r_imm12_val;
            r_imm10_val_latch  <= r_imm10_val;
            r_imm16_val_latch  <= r_imm16_val;
            r_cc_latch         <= r_cc;
            r_has_src_gp_latch <= w_has_src_gp;
            r_tgt_gp_latch     <= w_tgt_gp;
            r_tgt_gp_we_latch  <= w_tgt_gp_we;
            r_has_src_ar_latch <= r_has_src_ar;
            r_src_ar_latch     <= r_src_ar;
            r_has_tgt_ar_latch <= r_has_tgt_ar;
            r_tgt_ar_latch     <= r_tgt_ar;
            r_has_src_sr_latch <= w_has_src_sr;
            r_tgt_sr_latch     <= w_tgt_sr;
            r_tgt_sr_we_latch  <= w_tgt_sr_we;
            r_src_gp_latch     <= w_src_gp;
            r_src_sr_latch     <= w_src_sr;
        end
    end

    assign ow_pc         = r_pc_latch;
    assign ow_instr      = r_instr_latch;
    assign ow_opc        = r_opc_latch;
    assign ow_sgn_en     = r_sgn_en_latch;
    assign ow_imm_en     = r_imm_en_latch;
    assign ow_imm14_val  = r_imm14_val_latch;
    assign ow_imm12_val  = r_imm12_val_latch;
    assign ow_imm10_val  = r_imm10_val_latch;
    assign ow_imm16_val  = r_imm16_val_latch;
    assign ow_cc         = r_cc_latch;
    assign ow_has_src_gp = r_has_src_gp_latch;
    assign ow_tgt_gp     = r_tgt_gp_latch;
    assign ow_tgt_gp_we  = r_tgt_gp_we_latch;
    assign ow_has_src_ar = r_has_src_ar_latch;
    assign ow_src_ar     = r_src_ar_latch;
    assign ow_has_tgt_ar = r_has_tgt_ar_latch;
    assign ow_tgt_ar     = r_tgt_ar_latch;
    assign ow_has_src_sr = r_has_src_sr_latch;
    assign ow_tgt_sr     = r_tgt_sr_latch;
    assign ow_tgt_sr_we  = r_tgt_sr_we_latch;
    assign ow_src_gp     = r_src_gp_latch;
    assign ow_src_sr     = r_src_sr_latch;
endmodule
