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
    // Upper immediate banks for LUIui x∈{0,1,2}
    reg [`HBIT_IMM12:0] r_uimm_bank0; // bits [23:12] for 24-bit immediates
    reg [`HBIT_IMM12:0] r_uimm_bank1; // bits [35:24] lower-half of 48-bit
    reg [`HBIT_IMM12:0] r_uimm_bank2; // bits [47:36] upper-half of 48-bit
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
    reg                  r_tgt_sr_we;
    reg                  r_flags_we;
    // Current flags come from SR[FL] via SR read port 1 (forwarded)
    wire [`HBIT_FLAG:0]  w_fl_in = iw_src_sr_val[`HBIT_FLAG:0];
    // Latch for upper immediate banks (cleared on reset/flush)
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_uimm_bank0 <= {(`HBIT_IMM12+1){1'b0}};
            r_uimm_bank1 <= {(`HBIT_IMM12+1){1'b0}};
            r_uimm_bank2 <= {(`HBIT_IMM12+1){1'b0}};
        end else if (!iw_stall) begin
            if (iw_flush) begin
                // Prevent cross-path mixing after branch/flush
                r_uimm_bank0 <= {(`HBIT_IMM12+1){1'b0}};
                r_uimm_bank1 <= {(`HBIT_IMM12+1){1'b0}};
                r_uimm_bank2 <= {(`HBIT_IMM12+1){1'b0}};
            end else if (iw_opc == `OPC_LUIui) begin
                case (iw_instr[15:14])
                    2'b00: r_uimm_bank0 <= iw_imm12_val;
                    2'b01: r_uimm_bank1 <= iw_imm12_val;
                    2'b10: r_uimm_bank2 <= iw_imm12_val;
                    default: r_uimm_bank0 <= iw_imm12_val; // treat others as bank0
                endcase
            end
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
            r_tgt_sr_we    = 1'b0;
        end
        // By default, clear computed flags each cycle; set only when op defines them
        r_fl             = {`SIZE_FLAG{1'b0}};
        r_flags_we       = 1'b0;
        // Default 24-bit immediate: high 12 bits from bank0
        r_ir            = {r_uimm_bank0, iw_imm12_val};
        r_se_imm12_val  = {{12{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val};
        r_se_imm14_val  = {{10{iw_imm14_val[`HBIT_IMM14]}}, iw_imm14_val};
        r_se_imm10_val  = {{14{iw_imm10_val[`HBIT_IMM10]}}, iw_imm10_val};
        r_se_imm16_val  = {{8{iw_imm16_val[`HBIT_IMM16]}},  iw_imm16_val};
        if ((iw_opc == `OPC_JCCur  || iw_opc == `OPC_BCCsr  ||
             iw_opc == `OPC_JCCui  || iw_opc == `OPC_BCCso ||
             iw_opc == `OPC_SRJCCso)) begin
            case (iw_cc)
                `CC_RA: r_branch_taken = 1'b1;
                `CC_EQ: r_branch_taken =  w_fl_in[`FLAG_Z];
                `CC_NE: r_branch_taken = ~w_fl_in[`FLAG_Z];
                `CC_LT: r_branch_taken =  w_fl_in[`FLAG_N] ^   w_fl_in[`FLAG_V];
                `CC_GT: r_branch_taken = ~w_fl_in[`FLAG_Z] & (~w_fl_in[`FLAG_N] ^ w_fl_in[`FLAG_V]);
                `CC_GE: r_branch_taken = ~w_fl_in[`FLAG_N] ^   w_fl_in[`FLAG_V];
                `CC_LE: r_branch_taken =  w_fl_in[`FLAG_Z] | ( w_fl_in[`FLAG_N] ^ w_fl_in[`FLAG_V]);
                `CC_BT: r_branch_taken =  w_fl_in[`FLAG_C];
                `CC_AT: r_branch_taken = ~w_fl_in[`FLAG_Z] &  ~w_fl_in[`FLAG_C];
                `CC_BE: r_branch_taken =  w_fl_in[`FLAG_C] |   w_fl_in[`FLAG_Z];
                `CC_AE: r_branch_taken = ~w_fl_in[`FLAG_C];
            endcase
        end
        case (iw_opc)
            `OPC_LUIui: begin
                // r_ui_latch updated in sequential block
            end
            `OPC_MOVur: begin
                r_result = iw_src_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_ROLur: begin
                // Rotate left by variable amount (mod 24)
                reg [4:0] amt;
                reg [4:0] amt_mod;
                reg [4:0] carry_idx;
                amt = iw_src_gp_val[4:0];
                amt_mod = amt % `SIZE_DATA;
                // Compute result regardless of flag updates
                if (amt_mod == 5'd0)
                    r_result = iw_tgt_gp_val;
                else
                    r_result = (iw_tgt_gp_val << amt_mod) | (iw_tgt_gp_val >> (`SIZE_DATA - amt_mod));
                // Flags are only updated if source amount is non-zero (per spec)
                if (iw_src_gp_val != {`SIZE_DATA{1'b0}}) begin
                    // For full-width multiples, the last bit shifted out corresponds to bit 0
                    carry_idx = (amt_mod == 5'd0) ? 5'd0 : (`SIZE_DATA - amt_mod);
                    r_fl[`FLAG_C] = (iw_tgt_gp_val >> carry_idx) & 1'b1;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end
            end
            `OPC_RORur: begin
                // Rotate right by variable amount (mod 24)
                reg [4:0] amt;
                reg [4:0] amt_mod;
                reg [4:0] carry_idx;
                amt = iw_src_gp_val[4:0];
                amt_mod = amt % `SIZE_DATA;
                if (amt_mod == 5'd0)
                    r_result = iw_tgt_gp_val;
                else
                    r_result = (iw_tgt_gp_val >> amt_mod) | (iw_tgt_gp_val << (`SIZE_DATA - amt_mod));
                if (iw_src_gp_val != {`SIZE_DATA{1'b0}}) begin
                    // For full-width multiples, the last shift-out comes from bit SIZE-1
                    carry_idx = (amt_mod == 5'd0) ? (`SIZE_DATA-1) : (amt_mod-1);
                    r_fl[`FLAG_C] = (iw_tgt_gp_val >> carry_idx) & 1'b1;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end
            end
            `OPC_MOVDur: begin
                // H|L bit = instr[9]; H=1 means use [47:24], L=0 means use [23:0]
                if (iw_instr[9])
                    r_result = iw_src_ar_val[`HBIT_ADDR:`HBIT_ADDR-23];
                else
                    r_result = iw_src_ar_val[23:0];
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                r_flags_we = 1'b1;
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
                r_flags_we = 1'b1;
            end
            `OPC_SUBur: begin
                r_result = iw_tgt_gp_val - iw_src_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_tgt_gp_val < iw_src_gp_val) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_NOTur: begin
                r_result = ~iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_ANDur: begin
                r_result = iw_src_gp_val & iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_ORur: begin
                r_result = iw_src_gp_val | iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_XORur: begin
                r_result = iw_src_gp_val ^ iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_SHLur: begin
                reg [4:0] n;
                reg [4:0] n_eff;
                n = iw_src_gp_val[4:0];
                if (n >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    // Flags updated only if amount is non-zero (true here)
                    r_fl[`FLAG_C] = 1'b0;
                    r_fl[`FLAG_Z] = 1'b1;
                    r_flags_we = 1'b1;
                end else begin
                    n_eff = n;
                    r_result = iw_tgt_gp_val << n_eff;
                    if (iw_src_gp_val != {`SIZE_DATA{1'b0}}) begin
                        r_fl[`FLAG_C] = (n_eff == 5'd0) ? 1'b0 : ((iw_tgt_gp_val >> (`SIZE_DATA - n_eff)) & 1'b1);
                        r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                        r_flags_we = 1'b1;
                    end
                end
            end
            `OPC_SHRur: begin
                reg [4:0] n;
                reg [4:0] n_eff;
                n = iw_src_gp_val[4:0];
                if (n >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    // Flags updated only if amount is non-zero (true here)
                    r_fl[`FLAG_C] = 1'b0;
                    r_fl[`FLAG_Z] = 1'b1;
                    r_flags_we = 1'b1;
                end else begin
                    n_eff = n;
                    r_result = iw_tgt_gp_val >> n_eff;
                    if (iw_src_gp_val != {`SIZE_DATA{1'b0}}) begin
                        r_fl[`FLAG_C] = (n_eff == 5'd0) ? 1'b0 : ((iw_tgt_gp_val >> (n_eff-1)) & 1'b1);
                        r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                        r_flags_we = 1'b1;
                    end
                end
            end
            `OPC_CMPur: begin
                r_fl[`FLAG_Z] = (iw_src_gp_val == iw_tgt_gp_val) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_src_gp_val < iw_tgt_gp_val) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_TSTur: begin
                // Unsigned test: Z if zero
                r_fl[`FLAG_Z] = (iw_tgt_gp_val == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_LDur: begin
                r_addr = iw_src_ar_val;
            end
            `OPC_STur: begin
                r_addr = iw_tgt_ar_val;
                r_result = iw_src_gp_val;
            end
            `OPC_LDso: begin
                // 24-bit load with signed 10-bit offset into DRt
                r_addr = $signed(iw_src_ar_val) + $signed({{38{iw_imm10_val[`HBIT_IMM10]}}, iw_imm10_val});
            end
            `OPC_STso: begin
                // 24-bit store with signed 10-bit offset from DRs
                r_addr   = $signed(iw_tgt_ar_val) + $signed({{38{iw_imm10_val[`HBIT_IMM10]}}, iw_imm10_val});
                r_result = iw_src_gp_val;
            end
            `OPC_STui: begin
                // Store 24-bit zero-extended immediate to (ARt)
                r_addr   = iw_tgt_ar_val;
                r_result = r_ir;
            end
            `OPC_STsi: begin
                // Store 24-bit sign-extended immediate to (ARt)
                r_addr   = iw_tgt_ar_val;
                r_result = r_se_imm14_val;
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
            `OPC_CMPAur: begin
                // Unsigned compare ARs vs ARt
                r_fl[`FLAG_Z] = (iw_src_ar_val == iw_tgt_ar_val);
                r_fl[`FLAG_C] = (iw_src_ar_val < iw_tgt_ar_val);
                r_flags_we = 1'b1;
            end
            `OPC_TSTAur: begin
                r_fl[`FLAG_Z] = (iw_tgt_ar_val == {`SIZE_ADDR{1'b0}});
                r_flags_we = 1'b1;
            end
            `OPC_ADDsr: begin
                r_result = $signed(iw_src_gp_val) + $signed(iw_tgt_gp_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                // Signed overflow: operands have same sign, result differs
                r_fl[`FLAG_V] =
                    ((~(iw_src_gp_val[`HBIT_DATA] ^ iw_tgt_gp_val[`HBIT_DATA])) &&
                    (iw_src_gp_val[`HBIT_DATA] ^ r_result[`HBIT_DATA])) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_SUBsr: begin
                r_result = $signed(iw_tgt_gp_val) - $signed(iw_src_gp_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                // Signed overflow: operands have different signs and result differs from minuend
                r_fl[`FLAG_V] =
                    ((iw_src_gp_val[`HBIT_DATA] ^ iw_tgt_gp_val[`HBIT_DATA]) &&
                    (iw_tgt_gp_val[`HBIT_DATA] ^ r_result[`HBIT_DATA])) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_NEGsr: begin
                // Signed negate: r = -dt
                r_result = $signed(24'd0) - $signed(iw_tgt_gp_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                r_fl[`FLAG_N] = ($signed(r_result) < 0);
                // Overflow if operand is most negative value
                r_fl[`FLAG_V] = (iw_tgt_gp_val == 24'h800000);
                r_flags_we = 1'b1;
            end
            `OPC_SHRsr: begin
                // Arithmetic right shift by variable amount; flags {Z,N,C} only if amount != 0
                reg [4:0] n;
                reg [4:0] n_eff;
                n = iw_src_gp_val[4:0];
                if (n == 5'd0) begin
                    // No-op, flags unchanged
                    r_result = iw_tgt_gp_val;
                end else if (n >= `SIZE_DATA) begin
                    // Shift by width or more: result all sign bits; carry=0 per policy
                    r_result = (iw_tgt_gp_val[`HBIT_DATA]) ? {`SIZE_DATA{1'b1}} : {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_C] = 1'b0;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_fl[`FLAG_N] = r_result[`HBIT_DATA];
                    r_flags_we = 1'b1;
                end else begin
                    n_eff = n;
                    r_result = $signed(iw_tgt_gp_val) >>> n_eff;
                    r_fl[`FLAG_C] = ((iw_tgt_gp_val >> (n_eff-1)) & 1'b1);
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_fl[`FLAG_N] = r_result[`HBIT_DATA];
                    r_flags_we = 1'b1;
                end
            end
            `OPC_CMPsr: begin
                reg signed [`HBIT_DATA:0] s_diff;
                s_diff = $signed(iw_tgt_gp_val) - $signed(iw_src_gp_val);
                r_fl[`FLAG_Z] = (iw_src_gp_val == iw_tgt_gp_val) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = (s_diff < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((iw_src_gp_val[`HBIT_DATA] ^ iw_tgt_gp_val[`HBIT_DATA]) &
                    (iw_src_gp_val[`HBIT_DATA] ^ s_diff[`HBIT_DATA]));
                r_flags_we = 1'b1;
            end
            `OPC_MCCur: begin
                // Conditional move reg->reg based on CC
                reg take;
                take = 1'b0;
                case (iw_cc)
                    `CC_RA: take = 1'b1;
                    `CC_EQ: take =  w_fl_in[`FLAG_Z];
                    `CC_NE: take = ~w_fl_in[`FLAG_Z];
                    `CC_LT: take =  w_fl_in[`FLAG_N] ^   w_fl_in[`FLAG_V];
                    `CC_GT: take = ~w_fl_in[`FLAG_Z] & (~w_fl_in[`FLAG_N] ^ w_fl_in[`FLAG_V]);
                    `CC_GE: take = ~w_fl_in[`FLAG_N] ^   w_fl_in[`FLAG_V];
                    `CC_LE: take =  w_fl_in[`FLAG_Z] | ( w_fl_in[`FLAG_N] ^ w_fl_in[`FLAG_V]);
                    `CC_BT: take =  w_fl_in[`FLAG_C];
                    `CC_AT: take = ~w_fl_in[`FLAG_Z] &  ~w_fl_in[`FLAG_C];
                    `CC_BE: take =  w_fl_in[`FLAG_C] |   w_fl_in[`FLAG_Z];
                    `CC_AE: take = ~w_fl_in[`FLAG_C];
                endcase
                if (take) begin
                    r_result = iw_src_gp_val;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1; // update Z only when move happens
                end else begin
                    // Write back original value (no-op)
                    r_result = iw_tgt_gp_val;
                end
            end
            `OPC_BCCsr: begin
                if (r_branch_taken)
                    r_branch_pc = iw_pc + $signed(iw_tgt_gp_val);
            end
            `OPC_MOVui: begin
                r_result = r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_ADDui: begin
                r_result = iw_tgt_gp_val + r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (r_result < iw_tgt_gp_val) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_SUBui: begin
                r_result = iw_tgt_gp_val - r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_tgt_gp_val < r_ir) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_ANDui: begin
                r_result = iw_tgt_gp_val & r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_ORui: begin
                r_result = iw_tgt_gp_val | r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_XORui: begin
                r_result = iw_tgt_gp_val ^ r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_SHLui: begin
                reg [4:0] n;
                n = r_ir[4:0];
                if (n == 5'd0) begin
                    // No-op, flags unchanged
                    r_result = iw_tgt_gp_val;
                end else if (n >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_C] = 1'b0;
                    r_fl[`FLAG_Z] = 1'b1;
                    r_flags_we = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val << n;
                    r_fl[`FLAG_C] = ((iw_tgt_gp_val >> (`SIZE_DATA - n)) & 1'b1);
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end
            end
            `OPC_ROLui: begin
                // Rotate left by immediate (use low 5 bits of r_ir)
                reg [4:0] amt;
                reg [4:0] amt_mod;
                amt = r_ir[4:0];
                amt_mod = amt % `SIZE_DATA;
                if (amt_mod == 5'd0) begin
                    r_result = iw_tgt_gp_val;
                    // flags unchanged
                end else begin
                    r_result = (iw_tgt_gp_val << amt_mod) | (iw_tgt_gp_val >> (`SIZE_DATA - amt_mod));
                    r_fl[`FLAG_C] = (iw_tgt_gp_val >> (`SIZE_DATA - amt_mod)) & 1'b1;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end
            end
            `OPC_RORui: begin
                // Rotate right by immediate (use low 5 bits of r_ir)
                reg [4:0] amt;
                reg [4:0] amt_mod;
                amt = r_ir[4:0];
                amt_mod = amt % `SIZE_DATA;
                if (amt_mod == 5'd0) begin
                    r_result = iw_tgt_gp_val;
                    // flags unchanged
                end else begin
                    r_result = (iw_tgt_gp_val >> amt_mod) | (iw_tgt_gp_val << (`SIZE_DATA - amt_mod));
                    r_fl[`FLAG_C] = (iw_tgt_gp_val >> (amt_mod-1)) & 1'b1;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end
            end
            `OPC_SHRui: begin
                reg [4:0] n;
                n = r_ir[4:0];
                if (n == 5'd0) begin
                    // No-op, flags unchanged
                    r_result = iw_tgt_gp_val;
                end else if (n >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_C] = 1'b0;
                    r_fl[`FLAG_Z] = 1'b1;
                    r_flags_we = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val >> n;
                    r_fl[`FLAG_C] = ((iw_tgt_gp_val >> (n-1)) & 1'b1);
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end
            end
            `OPC_CMPui: begin
                r_fl[`FLAG_Z] = (iw_tgt_gp_val == r_ir) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_tgt_gp_val < r_ir) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_JCCui: begin
                if (r_branch_taken)
                    // Assemble 48-bit absolute from banks and imm12
                    r_branch_pc = {r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, iw_imm12_val};
            end
            `OPC_JCCur: begin
                if (r_branch_taken)
                    r_branch_pc = iw_tgt_ar_val;
            end
            `OPC_MOVsi: begin
                r_result = r_se_imm12_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_MCCsi: begin
                // Conditional move imm8 (sign-extended) -> DRt
                reg [23:0] seimm8;
                reg take;
                seimm8 = {{16{iw_instr[7]}}, iw_instr[7:0]};
                take = 1'b0;
                case (iw_cc)
                    `CC_RA: take = 1'b1;
                    `CC_EQ: take =  w_fl_in[`FLAG_Z];
                    `CC_NE: take = ~w_fl_in[`FLAG_Z];
                    `CC_LT: take =  w_fl_in[`FLAG_N] ^   w_fl_in[`FLAG_V];
                    `CC_GT: take = ~w_fl_in[`FLAG_Z] & (~w_fl_in[`FLAG_N] ^ w_fl_in[`FLAG_V]);
                    `CC_GE: take = ~w_fl_in[`FLAG_N] ^   w_fl_in[`FLAG_V];
                    `CC_LE: take =  w_fl_in[`FLAG_Z] | ( w_fl_in[`FLAG_N] ^ w_fl_in[`FLAG_V]);
                    `CC_BT: take =  w_fl_in[`FLAG_C];
                    `CC_AT: take = ~w_fl_in[`FLAG_Z] &  ~w_fl_in[`FLAG_C];
                    `CC_BE: take =  w_fl_in[`FLAG_C] |   w_fl_in[`FLAG_Z];
                    `CC_AE: take = ~w_fl_in[`FLAG_C];
                endcase
                if (take) begin
                    r_result = seimm8;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val;
                end
            end
            `OPC_ADDsi: begin
                r_result = $signed(iw_tgt_gp_val) + $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((~(iw_tgt_gp_val[`HBIT_DATA-1] ^ r_se_imm12_val[`HBIT_DATA-1])) &&
                    (iw_tgt_gp_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_SUBsi: begin
                r_result = $signed(iw_tgt_gp_val) - $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((r_se_imm12_val[`HBIT_DATA-1] ^ iw_tgt_gp_val[`HBIT_DATA-1]) &&
                    (iw_tgt_gp_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_SHRsi: begin
                // Arithmetic right shift by immediate imm5; flags {Z,N,C} only if imm5 != 0
                reg [4:0] n;
                n = iw_imm12_val[4:0];
                if (n == 5'd0) begin
                    // No-op, flags unchanged
                    r_result = iw_tgt_gp_val;
                end else if (n >= `SIZE_DATA) begin
                    // Overshift: all sign bits; carry=0 per policy
                    r_result = (iw_tgt_gp_val[`HBIT_DATA]) ? {`SIZE_DATA{1'b1}} : {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_C] = 1'b0;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_fl[`FLAG_N] = r_result[`HBIT_DATA];
                    r_flags_we = 1'b1;
                end else begin
                    r_result = $signed(iw_tgt_gp_val) >>> n;
                    r_fl[`FLAG_C] = ((iw_tgt_gp_val >> (n-1)) & 1'b1);
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_fl[`FLAG_N] = r_result[`HBIT_DATA];
                    r_flags_we = 1'b1;
                end
            end
            `OPC_CMPsi: begin
                reg signed [`HBIT_DATA:0] s_diff;
                s_diff = $signed(iw_tgt_gp_val) - $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (iw_tgt_gp_val == r_se_imm12_val) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = (s_diff < 0) ? 1'b1 : 1'b0;
                // Signed overflow detection for a - b: V=1 when sign(a)!=sign(b) and sign(a)!=sign(a-b)
                r_fl[`FLAG_V] = ((iw_tgt_gp_val[`HBIT_DATA-1] ^ r_se_imm12_val[`HBIT_DATA-1]) &
                                 (iw_tgt_gp_val[`HBIT_DATA-1] ^ s_diff[`HBIT_DATA-1]));
                r_flags_we = 1'b1;
            end
            `OPC_TSTsr: begin
                // Signed test: set Z and N from dt
                r_fl[`FLAG_Z] = (iw_tgt_gp_val == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = (iw_tgt_gp_val[`HBIT_DATA] == 1'b1) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_BCCso: begin
                if (r_branch_taken)
                    r_branch_pc = iw_pc + $signed(r_se_imm12_val);
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
                // Drive full 48-bit SR source into sr_result for MO stage store
                r_sr_result = iw_src_sr_val;
                // Optionally also present low 24b on the generic result bus (not written back)
                r_result = iw_src_sr_val[23:0]; 
                // $display("SRSTu: addr=%h result=%h", r_addr, r_result);
            end
            `OPC_SRMOVAur: begin
                // Move ARs (48-bit) into SRt
                r_sr_result = iw_src_ar_val;
                r_result    = r_sr_result[23:0];
            end
            `OPC_SRHLT: begin
                // Halt: keep PC where it is
                r_branch_taken = 1'b1;
                r_branch_pc    = iw_pc;
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
        // After computing r_fl, if flags updated then write to SR[FL]
        if (r_flags_we) begin
            r_tgt_sr_we = 1'b1;
            r_sr_result = { {(`SIZE_ADDR-`SIZE_FLAG){1'b0}}, r_fl };
        end
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
            r_tgt_sr_latch       <= (r_tgt_sr_we ? 2'b10 : iw_tgt_sr);
            r_tgt_sr_we_latch    <= (iw_tgt_sr_we | r_tgt_sr_we);
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
