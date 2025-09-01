`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/flags.vh"
`include "src/opcodes.vh"
`include "src/cc.vh"

module stg_ex(
    input wire                   iw_clk,
    input wire                   iw_rst,
    input wire  [`HBIT_ADDR:0]   iw_pc,
    output wire [`HBIT_ADDR:0]   ow_pc,
    input wire  [`HBIT_DATA:0]   iw_instr,
    output wire [`HBIT_DATA:0]   ow_instr,
    input wire  [`HBIT_OPC:0]    iw_opc,
    output wire [`HBIT_OPC:0]    ow_opc,
    input wire                   iw_sgn_en,
    input wire                   iw_imm_en,
    input wire  [`HBIT_IMM14:0]  iw_imm14_val,
    input wire  [`HBIT_IMM12:0]  iw_imm12_val,
    input wire  [`HBIT_IMM10:0]  iw_imm10_val,
    input wire  [`HBIT_IMM16:0]  iw_imm16_val,
    input wire  [`HBIT_CC:0]     iw_cc,
    input wire  [`HBIT_TGT_GP:0] iw_tgt_gp,
    input wire                   iw_tgt_gp_we,
    output wire [`HBIT_TGT_GP:0] ow_tgt_gp,
    output wire                  ow_tgt_gp_we,
    input wire  [`HBIT_TGT_SR:0] iw_tgt_sr,
    input wire                   iw_tgt_sr_we,
    output wire [`HBIT_TGT_SR:0] ow_tgt_sr,
    output wire                  ow_tgt_sr_we,
    input wire  [`HBIT_SRC_GP:0] iw_src_gp,
    input wire  [`HBIT_TGT_AR:0] iw_src_ar,
    input wire  [`HBIT_SRC_SR:0] iw_src_sr,
    input wire  [`HBIT_TGT_AR:0] iw_tgt_ar,
    output wire [`HBIT_TGT_AR:0] ow_tgt_ar,
    output wire                  ow_tgt_ar_we,
    output wire [`HBIT_ADDR:0]   ow_addr,
    output wire [`HBIT_DATA:0]   ow_result,
    output wire [`HBIT_ADDR:0]   ow_ar_result,
    output wire [`HBIT_ADDR:0]   ow_sr_result,
    output wire                  ow_branch_taken,
    output wire [`HBIT_ADDR:0]   ow_branch_pc,
    input wire  [`HBIT_DATA:0]   iw_src_gp_val,
    input wire  [`HBIT_DATA:0]   iw_tgt_gp_val,
    input wire  [`HBIT_ADDR:0]   iw_src_ar_val,
    input wire  [`HBIT_ADDR:0]   iw_tgt_ar_val,
    input wire  [`HBIT_ADDR:0]   iw_src_sr_val,
    input wire  [`HBIT_ADDR:0]   iw_tgt_sr_val,
    input wire                   iw_flush,
    input wire                   iw_stall
);
    reg [`HBIT_IMM12:0] r_ui_latch;
    reg [`HBIT_DATA:0]  r_ir;
    reg [`HBIT_DATA:0]  r_se_imm12_val;
    reg [`HBIT_DATA:0]  r_se_imm14_val;
    reg [`HBIT_DATA:0]  r_se_imm10_val;
    reg [`HBIT_DATA:0]  r_se_imm16_val;
    reg [`HBIT_ADDR:0]  r_addr;
    reg [`HBIT_DATA:0]  r_result;
    reg [`HBIT_ADDR:0]  r_ar_result;
    reg [`HBIT_ADDR:0]  r_sr_result;
    reg [`HBIT_FLAG:0]  r_fl;
    reg                 r_branch_taken;
    reg [`HBIT_ADDR:0]  r_branch_pc;
    reg                  r_tgt_ar_we;
    // Latch for upper immediate bank
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_ui_latch <= {(`HBIT_IMM12+1){1'b0}};
        end else if (!iw_stall) begin
            if (iw_opc == `OPC_LUIui)
                r_ui_latch <= iw_imm12_val;
        end
    end

    always @* begin
        if (!iw_stall) begin
            r_branch_taken = 1'b0;
            r_addr         = {`SIZE_ADDR{1'b0}};
            r_result       = {`SIZE_DATA{1'b0}};
            r_ar_result    = {`SIZE_ADDR{1'b0}};
            r_sr_result    = {`SIZE_ADDR{1'b0}};
            r_tgt_ar_we    = 1'b0;
        end
        r_ir            = {r_ui_latch, iw_imm12_val};
        r_se_imm12_val  = {{12{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val};
        r_se_imm14_val  = {{10{iw_imm14_val[`HBIT_IMM14]}}, iw_imm14_val};
        r_se_imm10_val  = {{14{iw_imm10_val[`HBIT_IMM10]}}, iw_imm10_val};
        r_se_imm16_val  = {{8{iw_imm16_val[`HBIT_IMM16]}},  iw_imm16_val};
        if ((iw_opc == `OPC_JCCur  || iw_opc == `OPC_BCCsr  ||
             iw_opc == `OPC_JCCui  || iw_opc == `OPC_BCCso ||
             iw_opc == `OPC_SRJCCso)) begin
            case (iw_cc)
                `CC_RA: r_branch_taken = 1'b1;
                `CC_EQ: r_branch_taken =  r_fl[`FLAG_Z];
                `CC_NE: r_branch_taken = ~r_fl[`FLAG_Z];
                `CC_LT: r_branch_taken =  r_fl[`FLAG_N] ^   r_fl[`FLAG_V];
                `CC_GT: r_branch_taken = ~r_fl[`FLAG_Z] & (~r_fl[`FLAG_N] ^ r_fl[`FLAG_V]);
                `CC_GE: r_branch_taken = ~r_fl[`FLAG_N] ^   r_fl[`FLAG_V];
                `CC_LE: r_branch_taken =  r_fl[`FLAG_Z] | ( r_fl[`FLAG_N] ^ r_fl[`FLAG_V]);
                `CC_BT: r_branch_taken =  r_fl[`FLAG_C];
                `CC_AT: r_branch_taken = ~r_fl[`FLAG_Z] &  ~r_fl[`FLAG_C];
                `CC_BE: r_branch_taken =  r_fl[`FLAG_C] |   r_fl[`FLAG_Z];
                `CC_AE: r_branch_taken = ~r_fl[`FLAG_C];
            endcase
        end
        case (iw_opc)
            `OPC_LUIui: begin
                // r_ui_latch updated in sequential block
            end
            `OPC_MOVur: begin
                r_result = iw_src_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_MOVDur: begin
                // H|L bit = instr[9]; H=1 means use [47:24], L=0 means use [23:0]
                if (iw_instr[9])
                    r_result = iw_src_ar_val[`HBIT_ADDR:`HBIT_ADDR-23];
                else
                    r_result = iw_src_ar_val[23:0];
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
            end
            `OPC_MOVAur: begin
                // Write DRs half into ARt
                r_tgt_ar_we = 1'b1;
                if (iw_instr[9]) // H=1
                    r_ar_result = {iw_src_gp_val, iw_tgt_ar_val[23:0]};
                else // L=0
                    r_ar_result = {iw_tgt_ar_val[`HBIT_ADDR:`HBIT_ADDR-23], iw_src_gp_val};
            end
            `OPC_ADDur: begin
                r_result = iw_src_gp_val + iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (r_result < iw_src_gp_val) ? 1'b1 : 1'b0;
            end
            `OPC_SUBur: begin
                r_result = iw_tgt_gp_val - iw_src_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_tgt_gp_val < iw_src_gp_val) ? 1'b1 : 1'b0;
            end
            `OPC_NOTur: begin
                r_result = ~iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_ANDur: begin
                r_result = iw_src_gp_val & iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_ORur: begin
                r_result = iw_src_gp_val | iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_XORur: begin
                r_result = iw_src_gp_val ^ iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_SHLur: begin
                if (iw_src_gp_val >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_V] = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val << iw_src_gp_val[4:0];
                    r_fl[`FLAG_V] = 1'b0;
                end
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_SHRur: begin
                if (iw_src_gp_val >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_V] = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val >> iw_src_gp_val[4:0];
                    r_fl[`FLAG_V] = 1'b0;
                end
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_CMPur: begin
                r_fl[`FLAG_Z] = (iw_src_gp_val == iw_tgt_gp_val) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_src_gp_val < iw_tgt_gp_val) ? 1'b1 : 1'b0;
            end
            `OPC_LDur: begin
                r_addr = iw_src_ar_val;
            end
            `OPC_STur: begin
                r_addr = iw_tgt_ar_val;
                r_result = iw_src_gp_val;
            end
            `OPC_LDso: begin
                r_addr = iw_src_ar_val + r_se_imm10_val;
            end
            `OPC_STso: begin
                r_addr = iw_tgt_ar_val + r_se_imm10_val;
                r_result = iw_src_gp_val;
            end
            `OPC_ADDAur: begin
                r_tgt_ar_we = 1'b1;
                r_ar_result = iw_tgt_ar_val + {24'b0, iw_src_gp_val};
            end
            `OPC_SUBAur: begin
                r_tgt_ar_we = 1'b1;
                r_ar_result = iw_tgt_ar_val - {24'b0, iw_src_gp_val};
            end
            `OPC_ADDAsr: begin
                r_tgt_ar_we = 1'b1;
                r_ar_result = $signed(iw_tgt_ar_val) + $signed({{24{iw_src_gp_val[`HBIT_DATA-1]}}, iw_src_gp_val});
            end
            `OPC_SUBAsr: begin
                r_tgt_ar_we = 1'b1;
                r_ar_result = $signed(iw_tgt_ar_val) - $signed({{24{iw_src_gp_val[`HBIT_DATA-1]}}, iw_src_gp_val});
            end
            `OPC_ADDAsi: begin
                r_tgt_ar_we = 1'b1;
                r_ar_result = $signed(iw_tgt_ar_val) + $signed({{36{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val});
            end
            `OPC_SUBAsi: begin
                r_tgt_ar_we = 1'b1;
                r_ar_result = $signed(iw_tgt_ar_val) - $signed({{36{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val});
            end
            `OPC_LEAso: begin
                r_tgt_ar_we = 1'b1;
                r_ar_result = $signed(iw_src_ar_val) + $signed({{36{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val});
            end
            `OPC_LDAso: begin
                // 48-bit memory load into ARt: compute address now; value assembled in MO stage
                r_addr      = $signed(iw_src_ar_val) + $signed({{36{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val});
                r_tgt_ar_we = 1'b1;
            end
            `OPC_STAso: begin
                // 48-bit memory store of ARs: compute address and pass full 48-bit source via ar_result
                r_addr      = $signed(iw_tgt_ar_val) + $signed({{36{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val});
                r_ar_result = iw_src_ar_val;
            end
            `OPC_ADRAso: begin
                r_tgt_ar_we = 1'b1;
                r_ar_result = $signed(iw_pc) + $signed({{34{iw_imm14_val[`HBIT_IMM14]}}, iw_imm14_val});
            end
            `OPC_ADDsr: begin
                r_result = $signed(iw_src_gp_val) + $signed(iw_tgt_gp_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((~(iw_src_gp_val[`HBIT_DATA-1] ^ iw_tgt_gp_val[`HBIT_DATA-1])) &&
                    (iw_src_gp_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
            end
            `OPC_SUBsr: begin
                r_result = $signed(iw_tgt_gp_val) - $signed(iw_src_gp_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((iw_src_gp_val[`HBIT_DATA-1] ^ iw_tgt_gp_val[`HBIT_DATA-1]) &&
                    (iw_tgt_gp_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
            end
            `OPC_SHRsr: begin
                if (iw_src_gp_val >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_V] = 1'b1;
                end else begin
                    r_result = $signed(iw_tgt_gp_val) >>> iw_src_gp_val[4:0];
                    r_fl[`FLAG_V] = 1'b0;
                end
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = (r_result[`HBIT_DATA] == 1'b1) ? 1'b1 : 1'b0;
            end
            `OPC_CMPsr: begin
                reg signed [`HBIT_DATA:0] s_diff;
                s_diff = $signed(iw_tgt_gp_val) - $signed(iw_src_gp_val);
                r_fl[`FLAG_Z] = (iw_src_gp_val == iw_tgt_gp_val) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = (s_diff < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((iw_src_gp_val[`HBIT_DATA] ^ iw_tgt_gp_val[`HBIT_DATA]) &
                    (iw_src_gp_val[`HBIT_DATA] ^ s_diff[`HBIT_DATA]));
            end
            `OPC_BCCsr: begin
                if (r_branch_taken)
                    r_branch_pc = iw_pc + $signed(iw_tgt_gp_val);
            end
            `OPC_MOVui: begin
                r_result = r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_ADDui: begin
                r_result = iw_tgt_gp_val + r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (r_result < iw_tgt_gp_val) ? 1'b1 : 1'b0;
            end
            `OPC_SUBui: begin
                r_result = iw_tgt_gp_val - r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_tgt_gp_val < r_ir) ? 1'b1 : 1'b0;
            end
            `OPC_ANDui: begin
                r_result = iw_tgt_gp_val & r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_ORui: begin
                r_result = iw_tgt_gp_val | r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_XORui: begin
                r_result = iw_tgt_gp_val ^ r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_SHLui: begin
                if (r_ir >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_V] = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val << r_ir[4:0];
                    r_fl[`FLAG_V] = 1'b0;
                end
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_SHRui: begin
                if (r_ir >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_V] = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val >> r_ir[4:0];
                    r_fl[`FLAG_V] = 1'b0;
                end
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_CMPui: begin
                r_fl[`FLAG_Z] = (iw_tgt_gp_val == r_ir) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_tgt_gp_val < r_ir) ? 1'b1 : 1'b0;
            end
            `OPC_JCCui: begin
                if (r_branch_taken)
                    r_branch_pc = r_ir;
            end
            `OPC_JCCur: begin
                if (r_branch_taken)
                    r_branch_pc = iw_tgt_ar_val;
            end
            `OPC_STui: begin
                r_addr = iw_tgt_gp_val;
                r_result = r_ir;
            end
            `OPC_MOVsi: begin
                r_result = r_se_imm12_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_ADDsi: begin
                r_result = $signed(iw_tgt_gp_val) + $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((~(iw_tgt_gp_val[`HBIT_DATA-1] ^ r_se_imm12_val[`HBIT_DATA-1])) &&
                    (iw_tgt_gp_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
            end
            `OPC_SUBsi: begin
                r_result = $signed(iw_tgt_gp_val) - $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((r_se_imm12_val[`HBIT_DATA-1] ^ iw_tgt_gp_val[`HBIT_DATA-1]) &&
                    (iw_tgt_gp_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
            end
            `OPC_SHRsi: begin
                if (iw_imm12_val >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_V] = 1'b1;
                end else begin
                    r_result = $signed(iw_tgt_gp_val) >>> iw_imm12_val[4:0];
                    r_fl[`FLAG_V] = 1'b0;
                end
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = (r_result[`HBIT_DATA] == 1'b1) ? 1'b1 : 1'b0;
            end
            `OPC_CMPsi: begin
                reg signed [`HBIT_DATA:0] s_diff;
                s_diff = $signed(iw_tgt_gp_val) - $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (iw_tgt_gp_val == r_se_imm12_val) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = (s_diff < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] = ((iw_tgt_gp_val[`HBIT_DATA] ^ r_se_imm12_val[`HBIT_DATA]) &
                                 (iw_tgt_gp_val[`HBIT_DATA] ^ s_diff[`HBIT_DATA]));
            end
            `OPC_BCCso: begin
                if (r_branch_taken)
                    r_branch_pc = iw_pc + $signed(r_se_imm12_val);
            end
            `OPC_STsi: begin
                r_addr = iw_tgt_gp_val;
                // STsi uses imm14 signed
                r_result = r_se_imm14_val;
            end
            `OPC_SRMOVur: begin
                r_sr_result = (iw_src_sr == `SR_IDX_PC) ? iw_pc : iw_src_sr_val;
                r_result    = r_sr_result[23:0];
            end
            `OPC_SRADDsi: begin
                r_sr_result = $signed(iw_tgt_sr_val) + $signed({{34{iw_imm14_val[`HBIT_IMM14]}}, iw_imm14_val});
                r_result    = r_sr_result[23:0];
            end
            `OPC_SRSUBsi: begin
                r_sr_result = $signed(iw_tgt_sr_val) - $signed({{34{iw_imm14_val[`HBIT_IMM14]}}, iw_imm14_val});
                r_result    = r_sr_result[23:0];
            end
            `OPC_SRJCCso: begin
                if (r_branch_taken) begin
                    r_branch_pc = $signed(iw_tgt_sr_val) + $signed({{38{iw_imm10_val[`HBIT_IMM10]}}, iw_imm10_val});
                end
            end
            `OPC_SRLDso: begin
                r_addr = $signed(iw_src_sr_val) + $signed({{36{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val});
                // $display("SRLDu: addr=%h", r_addr);
            end
            `OPC_SRSTso: begin
                r_addr   = $signed(iw_tgt_sr_val) + $signed({{36{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val});
                r_result = iw_src_sr_val[23:0]; 
                // $display("SRSTu: addr=%h result=%h", r_addr, r_result);
            end
            `OPC_BALso: begin
                r_branch_taken = 1'b1;
                r_branch_pc    = iw_pc + r_se_imm16_val;
            end
            default: begin
                r_result = `SIZE_DATA'b0;
                r_fl     = `SIZE_FLAG'b0;
            end
        endcase
    end

    reg [`HBIT_ADDR:0]   r_pc_latch;
    reg [`HBIT_DATA:0]   r_instr_latch;
    reg [`HBIT_OPC:0]    r_opc_latch;
    reg [`HBIT_TGT_GP:0] r_tgt_gp_latch;
    reg                  r_tgt_gp_we_latch;
    reg [`HBIT_TGT_SR:0] r_tgt_sr_latch;
    reg                  r_tgt_sr_we_latch;
    reg [`HBIT_TGT_AR:0] r_tgt_ar_latch;
    reg                  r_tgt_ar_we_latch;
    reg [`HBIT_ADDR:0]   r_addr_latch;
    reg [`HBIT_DATA:0]   r_result_latch;
    reg [`HBIT_ADDR:0]   r_ar_result_latch;
    reg [`HBIT_ADDR:0]   r_sr_result_latch;
    reg                  r_branch_taken_latch;
    reg [`HBIT_ADDR:0]   r_branch_pc_latch;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_pc_latch           <= `SIZE_ADDR'b0;
            r_instr_latch        <= `SIZE_DATA'b0;
            r_opc_latch          <= `SIZE_OPC'b0;
            r_tgt_gp_latch       <= `SIZE_TGT_GP'b0;
            r_tgt_gp_we_latch    <= 1'b0;
            r_tgt_sr_latch       <= `SIZE_TGT_SR'b0;
            r_tgt_sr_we_latch    <= 1'b0;
            r_tgt_ar_latch       <= `SIZE_TGT_AR'b0;
            r_tgt_ar_we_latch    <= 1'b0;
            r_addr_latch         <= `SIZE_ADDR'b0;
            r_result_latch       <= `SIZE_DATA'b0;
            r_ar_result_latch    <= `SIZE_ADDR'b0;
            r_sr_result_latch    <= `SIZE_ADDR'b0;
            r_branch_taken_latch <= 1'b0;
            r_branch_pc_latch    <= `SIZE_ADDR'b0;
        end else if (iw_flush) begin
            r_pc_latch           <= `SIZE_ADDR'b0;
            r_instr_latch        <= `SIZE_DATA'b0;
            r_opc_latch          <= `SIZE_OPC'b0;
            r_tgt_gp_latch       <= `SIZE_TGT_GP'b0;
            r_tgt_gp_we_latch    <= 1'b0;
            r_tgt_sr_latch       <= `SIZE_TGT_SR'b0;
            r_tgt_sr_we_latch    <= 1'b0;
            r_tgt_ar_latch       <= `SIZE_TGT_AR'b0;
            r_tgt_ar_we_latch    <= 1'b0;
            r_addr_latch         <= `SIZE_ADDR'b0;
            r_result_latch       <= `SIZE_DATA'b0;
            r_ar_result_latch    <= `SIZE_ADDR'b0;
            r_sr_result_latch    <= `SIZE_ADDR'b0;
            r_branch_taken_latch <= 1'b0;
            r_branch_pc_latch    <= `SIZE_ADDR'b0;
        end else if (iw_stall) begin
            r_pc_latch           <= r_pc_latch;
            r_instr_latch        <= r_instr_latch;
            r_opc_latch          <= r_opc_latch;
            r_tgt_gp_latch       <= r_tgt_gp_latch;
            r_tgt_gp_we_latch    <= r_tgt_gp_we_latch;
            r_tgt_sr_latch       <= r_tgt_sr_latch;
            r_tgt_sr_we_latch    <= r_tgt_sr_we_latch;
            r_tgt_ar_latch       <= r_tgt_ar_latch;
            r_tgt_ar_we_latch    <= r_tgt_ar_we_latch;
            r_addr_latch         <= r_addr_latch;
            r_result_latch       <= r_result_latch;
            r_ar_result_latch    <= r_ar_result_latch;
            r_sr_result_latch    <= r_sr_result_latch;
            r_branch_taken_latch <= r_branch_taken_latch;
            r_branch_pc_latch    <= r_branch_pc_latch;
        end else begin
            r_pc_latch           <= iw_pc;
            r_instr_latch        <= iw_instr;
            r_opc_latch          <= iw_opc;
            r_tgt_gp_latch       <= iw_tgt_gp;
            r_tgt_gp_we_latch    <= iw_tgt_gp_we;
            r_tgt_sr_latch       <= iw_tgt_sr;
            r_tgt_sr_we_latch    <= iw_tgt_sr_we;
            r_tgt_ar_latch       <= iw_tgt_ar;
            r_tgt_ar_we_latch    <= r_tgt_ar_we;
            r_addr_latch         <= r_addr;
            r_result_latch       <= r_result;
            r_ar_result_latch    <= r_ar_result;
            r_sr_result_latch    <= r_sr_result;
            r_branch_taken_latch <= r_branch_taken;
            r_branch_pc_latch    <= r_branch_pc;
        end
    end
    assign ow_pc           = r_pc_latch;
    assign ow_instr        = r_instr_latch;
    assign ow_opc          = r_opc_latch;
    assign ow_tgt_gp       = r_tgt_gp_latch;
    assign ow_tgt_gp_we    = r_tgt_gp_we_latch;
    assign ow_tgt_sr       = r_tgt_sr_latch;
    assign ow_tgt_sr_we    = r_tgt_sr_we_latch;
    assign ow_tgt_ar       = r_tgt_ar_latch;
    assign ow_tgt_ar_we    = r_tgt_ar_we_latch;
    assign ow_addr         = r_addr_latch;
    assign ow_result       = r_result_latch;
    assign ow_ar_result    = r_ar_result_latch;
    assign ow_sr_result    = r_sr_result_latch;
    assign ow_branch_taken = r_branch_taken_latch;
    assign ow_branch_pc    = r_branch_pc_latch;
endmodule
