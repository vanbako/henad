`include "src/sizes.vh"
`include "src/sr.vh"
`include "src/flags.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"
`include "src/cc.vh"

module stg_ex(
    input wire                   iw_clk,
    input wire                   iw_rst,
    input wire  [`HBIT_ADDR:0]   iw_pc,
    output wire [`HBIT_ADDR:0]   ow_pc,
    input wire  [`HBIT_DATA:0]   iw_instr,
    output wire [`HBIT_DATA:0]   ow_instr,
    input wire  [`HBIT_OPC:0]    iw_opc,
    input wire  [`HBIT_OPC:0]    iw_root_opc,
    output wire [`HBIT_OPC:0]    ow_opc,
    output wire [`HBIT_OPC:0]    ow_root_opc,
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
    output wire                  ow_sr_aux_we,
    output wire [`HBIT_TGT_SR:0] ow_sr_aux_addr,
    output wire [`HBIT_ADDR:0]   ow_sr_aux_result,
    output wire                  ow_branch_taken,
    output wire [`HBIT_ADDR:0]   ow_branch_pc,
    output wire                  ow_trap_pending,
    output wire                  ow_halt,
    input wire  [`HBIT_DATA:0]   iw_src_gp_val,
    input wire  [`HBIT_DATA:0]   iw_tgt_gp_val,
    input wire  [`HBIT_ADDR:0]   iw_src_ar_val,
    input wire  [`HBIT_ADDR:0]   iw_tgt_ar_val,
    input wire  [`HBIT_ADDR:0]   iw_src_sr_val,
    input wire  [`HBIT_ADDR:0]   iw_tgt_sr_val,
    input wire  [`HBIT_ADDR:0]   iw_pstate_val,
    // CR writeback controls (to regcr via top-level)
    output wire [`HBIT_TGT_CR:0] ow_cr_write_addr,
    output wire                  ow_cr_we_base,
    output wire [`HBIT_ADDR:0]   ow_cr_base,
    output wire                  ow_cr_we_len,
    output wire [`HBIT_ADDR:0]   ow_cr_len,
    output wire                  ow_cr_we_cur,
    output wire [`HBIT_ADDR:0]   ow_cr_cur,
    output wire                  ow_cr_we_perms,
    output wire [`HBIT_DATA:0]   ow_cr_perms,
    output wire                  ow_cr_we_attr,
    output wire [`HBIT_DATA:0]   ow_cr_attr,
    output wire                  ow_cr_we_tag,
    output wire                  ow_cr_tag,
    // CHERI: CR read views for the CR indices selected in ID
    input wire  [`HBIT_ADDR:0]   iw_cr_s_base,
    input wire  [`HBIT_ADDR:0]   iw_cr_s_len,
    input wire  [`HBIT_ADDR:0]   iw_cr_s_cur,
    input wire  [`HBIT_DATA:0]   iw_cr_s_perms,
    input wire  [`HBIT_DATA:0]   iw_cr_s_attr,
    input wire                   iw_cr_s_tag,
    input wire  [`HBIT_ADDR:0]   iw_cr_t_base,
    input wire  [`HBIT_ADDR:0]   iw_cr_t_len,
    input wire  [`HBIT_ADDR:0]   iw_cr_t_cur,
    input wire  [`HBIT_DATA:0]   iw_cr_t_perms,
    input wire  [`HBIT_DATA:0]   iw_cr_t_attr,
    input wire                   iw_cr_t_tag,
    input wire                   iw_flush,
    input wire                   iw_mode_kernel,
    input wire                   iw_stall
);
    // Upper immediate banks for LUIui x∈{0,1,2}
    reg [`HBIT_IMM12:0] r_uimm_bank0; // bits [23:12] for 24-bit immediates
    reg [`HBIT_IMM12:0] r_uimm_bank1; // bits [35:24] lower-half of 48-bit
    reg [`HBIT_IMM12:0] r_uimm_bank2; // bits [47:36] upper-half of 48-bit
    // Valid bits for uimm banks (cleared on reset/flush, set by LUIui)
    reg                  r_uimm_bank0_valid;
    reg                  r_uimm_bank1_valid;
    reg                  r_uimm_bank2_valid;
    reg [`HBIT_DATA:0]  r_ir;
    reg [`HBIT_DATA:0]  r_se_imm12_val;
    reg [`HBIT_DATA:0]  r_se_imm14_val;
    reg [`HBIT_DATA:0]  r_se_imm10_val;
    reg [`HBIT_ADDR:0]  r_addr;
    reg [`HBIT_DATA:0]  r_result;
    reg [`HBIT_ADDR:0]  r_ar_result;
    reg [`HBIT_ADDR:0]  r_sr_result;
    reg [`HBIT_FLAG:0]  r_fl;
    reg                 r_branch_taken;
    reg [`HBIT_ADDR:0]  r_branch_pc;
    reg                 r_halt;
    reg                  r_tgt_ar_we;
    reg                  r_tgt_sr_we;
    reg                  r_flags_we;
    // Trap control: request LR write and kill GP write when taking a trap
    reg                  r_trap_lr_we;
    reg [`HBIT_ADDR:0]   r_trap_lr_value;
    reg [7:0]            r_trap_cause;
    reg [15:0]           r_trap_info;
    reg                  r_trap_pending;
    reg                  r_kill_gp_we;
    reg [`HBIT_ADDR:0]   r_pstate_next;
    reg                  r_pstate_dirty;
    reg                  r_sr_aux_we;
    reg [`HBIT_TGT_SR:0] r_sr_aux_addr;
    reg [`HBIT_ADDR:0]   r_sr_aux_result;
    // CR writeback controls
    reg [`HBIT_TGT_CR:0] r_cr_write_addr;
    reg                  r_cr_we_base;
    reg [`HBIT_ADDR:0]   r_cr_base;
    reg                  r_cr_we_len;
    reg [`HBIT_ADDR:0]   r_cr_len;
    reg                  r_cr_we_cur;
    reg [`HBIT_ADDR:0]   r_cr_cur;
    reg                  r_cr_we_perms;
    reg [`HBIT_DATA:0]   r_cr_perms;
    reg                  r_cr_we_attr;
    reg [`HBIT_DATA:0]   r_cr_attr;
    reg                  r_cr_we_tag;
    reg                  r_cr_tag;
    // Current flags come from SR[FL] via SR read port 1 (forwarded)
    wire [`HBIT_FLAG:0]  w_fl_in = iw_src_sr_val[`HBIT_FLAG:0];

    function automatic [`HBIT_ADDR:0] extend_data_to_addr(input [`HBIT_DATA:0] value);
        extend_data_to_addr = {{(`SIZE_ADDR-`SIZE_DATA){value[`HBIT_DATA]}}, value};
    endfunction

    function automatic [`HBIT_ADDR:0] extend_imm12_to_addr(input [`HBIT_IMM12:0] value);
        extend_imm12_to_addr = {{(`SIZE_ADDR-`SIZE_IMM12){value[`HBIT_IMM12]}}, value};
    endfunction

    function automatic [`HBIT_ADDR:0] extend_imm16_to_addr(input [`HBIT_IMM16:0] value);
        extend_imm16_to_addr = {{(`SIZE_ADDR-`SIZE_IMM16){value[`HBIT_IMM16]}}, value};
    endfunction

    function automatic [`HBIT_ADDR:0] extend_imm10_to_addr(input [`HBIT_IMM10:0] value);
        extend_imm10_to_addr = {{(`SIZE_ADDR-`SIZE_IMM10){value[`HBIT_IMM10]}}, value};
    endfunction
    // Latch for upper immediate banks (cleared on reset/flush)
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_uimm_bank0 <= {(`HBIT_IMM12+1){1'b0}};
            r_uimm_bank1 <= {(`HBIT_IMM12+1){1'b0}};
            r_uimm_bank2 <= {(`HBIT_IMM12+1){1'b0}};
            r_uimm_bank0_valid <= 1'b0;
            r_uimm_bank1_valid <= 1'b0;
            r_uimm_bank2_valid <= 1'b0;
        end else if (!iw_stall) begin
            if (iw_flush) begin
                // Prevent cross-path mixing after branch/flush
                r_uimm_bank0 <= {(`HBIT_IMM12+1){1'b0}};
                r_uimm_bank1 <= {(`HBIT_IMM12+1){1'b0}};
                r_uimm_bank2 <= {(`HBIT_IMM12+1){1'b0}};
                r_uimm_bank0_valid <= 1'b0;
                r_uimm_bank1_valid <= 1'b0;
                r_uimm_bank2_valid <= 1'b0;
            end else if (iw_opc == `OPC_LUIui) begin
                case (iw_instr[15:14])
                    2'b00: begin r_uimm_bank0 <= iw_imm12_val; r_uimm_bank0_valid <= 1'b1; end
                    2'b01: begin r_uimm_bank1 <= iw_imm12_val; r_uimm_bank1_valid <= 1'b1; end
                    2'b10: begin r_uimm_bank2 <= iw_imm12_val; r_uimm_bank2_valid <= 1'b1; end
                    default: begin r_uimm_bank0 <= iw_imm12_val; r_uimm_bank0_valid <= 1'b1; end // treat others as bank0
                endcase
            end
        end
    end

    always @* begin
        r_halt = 1'b0;
        if (!iw_stall) begin
            r_branch_taken = 1'b0;
            r_addr         = {`SIZE_ADDR{1'b0}};
            r_result       = {`SIZE_DATA{1'b0}};
            r_ar_result    = {`SIZE_ADDR{1'b0}};
            r_sr_result    = {`SIZE_ADDR{1'b0}};
            r_tgt_ar_we    = 1'b0;
            r_tgt_sr_we    = 1'b0;
            r_trap_lr_we   = 1'b0;
            r_trap_lr_value= {`SIZE_ADDR{1'b0}};
            r_trap_cause   = `PSTATE_CAUSE_NONE;
            r_trap_info    = 16'd0;
            r_trap_pending = 1'b0;
            r_kill_gp_we   = 1'b0;
            r_pstate_next  = iw_pstate_val;
            r_pstate_dirty = 1'b0;
            r_sr_aux_we    = 1'b0;
            r_sr_aux_addr  = {(`HBIT_TGT_SR+1){1'b0}};
            r_sr_aux_result= {`SIZE_ADDR{1'b0}};
            // Defaults for CR writebacks
            r_cr_write_addr = {(`HBIT_TGT_CR+1){1'b0}};
            r_cr_we_base  = 1'b0; r_cr_base  = {`SIZE_ADDR{1'b0}};
            r_cr_we_len   = 1'b0; r_cr_len   = {`SIZE_ADDR{1'b0}};
            r_cr_we_cur   = 1'b0; r_cr_cur   = {`SIZE_ADDR{1'b0}};
            r_cr_we_perms = 1'b0; r_cr_perms = {`SIZE_DATA{1'b0}};
            r_cr_we_attr  = 1'b0; r_cr_attr  = {`SIZE_DATA{1'b0}};
            r_cr_we_tag   = 1'b0; r_cr_tag   = 1'b0;
        end
        // By default, clear computed flags each cycle; set only when op defines them
        r_fl             = {`SIZE_FLAG{1'b0}};
        r_flags_we       = 1'b0;
        // Default 24-bit immediate: high 12 bits from bank0
        r_ir            = {r_uimm_bank0, iw_imm12_val};
        r_se_imm12_val  = {{12{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val};
        r_se_imm14_val  = {{10{iw_imm14_val[`HBIT_IMM14]}}, iw_imm14_val};
        r_se_imm10_val  = {{14{iw_imm10_val[`HBIT_IMM10]}}, iw_imm10_val};
        if ((iw_opc == `OPC_BCCsr  ||
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
`ifndef SYNTHESIS
        if (r_branch_taken) begin
            $display("[EX-BR] opc=%h pc=%0d -> %0d", iw_opc, iw_pc, r_branch_pc);
        end
`endif
        case (iw_opc)
            // CHERI: 24-bit loads/stores checked against CR
            `OPC_LDcso: begin
                reg [47:0] eff;
                reg [7:0]  cause;
                reg        fault;
                cause = `PSTATE_CAUSE_NONE;
                fault = 1'b0;
                eff = iw_cr_s_cur + {{38{iw_imm10_val[`HBIT_IMM10]}}, iw_imm10_val};
                if (!iw_cr_s_tag) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_TAG;
                end else if (iw_cr_s_attr[`CR_ATTR_SEALED_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_SEAL;
                end else if (!iw_cr_s_perms[`CR_PERM_R_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_PERM;
                end else if (!((eff >= iw_cr_s_base) && (eff < (iw_cr_s_base + iw_cr_s_len)))) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_OOB;
                end
                if (fault) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = cause;
                end else begin
                    r_addr = eff;
                end
            end
            `OPC_STcso: begin
                reg [47:0] eff;
                reg [7:0]  cause;
                reg        fault;
                cause = `PSTATE_CAUSE_NONE;
                fault = 1'b0;
                eff = iw_cr_t_cur + {{38{iw_imm10_val[`HBIT_IMM10]}}, iw_imm10_val};
                if (!iw_cr_t_tag) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_TAG;
                end else if (iw_cr_t_attr[`CR_ATTR_SEALED_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_SEAL;
                end else if (!iw_cr_t_perms[`CR_PERM_W_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_PERM;
                end else if (!((eff >= iw_cr_t_base) && (eff < (iw_cr_t_base + iw_cr_t_len)))) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_OOB;
                end
                if (fault) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = cause;
                end else begin
                    r_addr   = eff;
                    r_result = iw_src_gp_val;
                end
            end
            `OPC_CINC, `OPC_CINCv: begin
                // Update CRt.cursor via AR write/forwarding path
                reg signed [47:0] delta;
                reg [47:0] newc;
                reg fault;
                delta = {{24{iw_src_gp_val[23]}}, iw_src_gp_val};
                // Use forwarded AR view of CRt.cursor so back-to-back updates
                // chain correctly without waiting for WB commit.
                newc  = iw_tgt_ar_val + delta;
                fault = 1'b0;
                if (iw_opc == `OPC_CINCv) begin
                    if (!((newc >= iw_cr_t_base) && (newc < (iw_cr_t_base + iw_cr_t_len)))) fault = 1'b1;
                end
                if (fault) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_CAP_OOB;
                end else begin
                    // Drive both AR path and CR direct write to ensure commit
                    r_tgt_ar_we   = 1'b1;
                    r_ar_result   = newc;
                    r_cr_write_addr = iw_tgt_ar;
                    r_cr_we_cur     = 1'b1;
                    r_cr_cur        = newc;
`ifndef SYNTHESIS
                    $display("[EX] CINC%c (reg) set CR%0d.cur := %0d", (iw_opc==`OPC_CINCv)?"v":" ", iw_tgt_ar, newc);
`endif
                end
            end
            `OPC_CINCi, `OPC_CINCiv: begin
                reg signed [47:0] delta;
                reg [47:0] newc;
                reg fault;
                delta = {{34{iw_imm14_val[`HBIT_IMM14]}}, iw_imm14_val};
                // Use forwarded AR view of CRt.cursor for immediate form as well
                newc  = iw_tgt_ar_val + delta;
                fault = 1'b0;
`ifndef SYNTHESIS
                $display("[EX] CINC%sv imm=%0d cur=%0d -> newc=%0d",
                    (iw_opc==`OPC_CINCiv)?"iv":"i", $signed(iw_imm14_val), iw_cr_t_cur, newc);
`endif
                if (iw_opc == `OPC_CINCiv) begin
                    if (!((newc >= iw_cr_t_base) && (newc < (iw_cr_t_base + iw_cr_t_len)))) fault = 1'b1;
                end
                if (fault) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_CAP_OOB;
                end else begin
                    r_tgt_ar_we     = 1'b1;
                    r_ar_result     = newc;
                    r_cr_write_addr = iw_tgt_ar;
                    r_cr_we_cur     = 1'b1;
                    r_cr_cur        = newc;
`ifndef SYNTHESIS
                    $display("[EX] CINC%c (imm) set CR%0d.cur := %0d", (iw_opc==`OPC_CINCiv)?"v":" ", iw_tgt_ar, newc);
`endif
                end
            end
            `OPC_CMOV: begin
                // Copy full capability CRs -> CRt
                r_cr_write_addr = iw_tgt_ar;
                r_cr_we_base  = 1'b1; r_cr_base  = iw_cr_s_base;
                r_cr_we_len   = 1'b1; r_cr_len   = iw_cr_s_len;
                r_cr_we_cur   = 1'b1; r_cr_cur   = iw_cr_s_cur;
                r_cr_we_perms = 1'b1; r_cr_perms = iw_cr_s_perms;
                r_cr_we_attr  = 1'b1; r_cr_attr  = iw_cr_s_attr;
                r_cr_we_tag   = 1'b1; r_cr_tag   = iw_cr_s_tag;
`ifndef SYNTHESIS
                $display("[EX] CMOV CR%0d->CR%0d base=%0d len=%0d cur=%0d perms=%h tag=%0d",
                    iw_src_ar, iw_tgt_ar, iw_cr_s_base, iw_cr_s_len, iw_cr_s_cur, iw_cr_s_perms, iw_cr_s_tag);
`endif
            end
            `OPC_CSETB, `OPC_CSETBi, `OPC_CSETBv, `OPC_CSETBiv: begin
                // Set bounds: base := CRs.cursor, len := DRs or imm
                reg signed [47:0] newlen;
                reg [47:0] newbase;
                reg [7:0]  cause;
                reg        fault;
                // Use forwarded AR view for CRs.cursor for proper bypassing
                newbase = iw_src_ar_val;
                if ((iw_opc == `OPC_CSETBi) || (iw_opc == `OPC_CSETBiv))
                    newlen = {{34{iw_imm14_val[`HBIT_IMM14]}}, iw_imm14_val};
                else
                    newlen = {{24{iw_src_gp_val[23]}}, iw_src_gp_val};
                fault = 1'b0;
                cause = `PSTATE_CAUSE_NONE;
                // Require SB permission on target capability to change bounds
                if (!iw_cr_t_perms[`CR_PERM_SB_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_PERM;
                end
                // Checked variants: length must be > 0 and current cursor must fit
                if (!fault && ((iw_opc == `OPC_CSETBv) || (iw_opc == `OPC_CSETBiv))) begin
                    if (newlen <= 0) begin
                        fault = 1'b1;
                        cause = `PSTATE_CAUSE_CAP_CFG;
                    end else if (!((iw_cr_t_cur >= newbase) && (iw_cr_t_cur < (newbase + newlen[47:0])))) begin
                        fault = 1'b1;
                        cause = `PSTATE_CAUSE_CAP_OOB;
                    end
                end
                if (fault) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = cause;
                end else begin
                    r_cr_write_addr = iw_tgt_ar;
                    r_cr_we_base    = 1'b1; r_cr_base = newbase;
                    r_cr_we_len     = 1'b1; r_cr_len  = newlen[47:0];
                end
            end
            `OPC_CANDP: begin
                // AND permissions with mask in DRs
                r_cr_write_addr = iw_tgt_ar;
                r_cr_we_perms   = 1'b1;
                r_cr_perms      = (iw_cr_t_perms & iw_src_gp_val);
            end
            `OPC_CCLRT: begin
                // Clear capability tag (invalidate)
                r_cr_write_addr = iw_tgt_ar;
                r_cr_we_tag     = 1'b1;
                r_cr_tag        = 1'b0;
            end
            `OPC_CGETP: begin
                r_result = iw_cr_s_perms;
            end
            `OPC_CGETT: begin
                r_result = {23'b0, (iw_cr_s_tag ? 1'b1 : 1'b0)};
            end
            // Check-only ops for capability load/store sequences
            `OPC_CLDcso: begin
                // Validate capability load: require LC permission and in-bounds for 10 BAUs
                reg [47:0] eff;
                reg [47:0] last;
                reg [47:0] bound;
                reg [7:0]  cause;
                reg        fault;
                cause = `PSTATE_CAUSE_NONE;
                fault = 1'b0;
                eff   = iw_cr_s_cur + {{38{iw_imm10_val[`HBIT_IMM10]}}, iw_imm10_val};
                last  = eff + 48'd10; // exclusive upper bound (covers words [0..9])
                bound = iw_cr_s_base + iw_cr_s_len;
                if (!iw_cr_s_tag) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_TAG;
                end else if (iw_cr_s_attr[`CR_ATTR_SEALED_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_SEAL;
                end else if (!iw_cr_s_perms[`CR_PERM_LC_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_PERM;
                end else if (!((eff >= iw_cr_s_base) && (last <= bound))) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_OOB;
                end
                if (fault) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = cause;
                end
            end
            `OPC_CSTcso: begin
                // Validate capability store: require SC permission and in-bounds for 10 BAUs
                reg [47:0] eff;
                reg [47:0] last;
                reg [47:0] bound;
                reg [7:0]  cause;
                reg        fault;
                cause = `PSTATE_CAUSE_NONE;
                fault = 1'b0;
                eff   = iw_cr_t_cur + {{38{iw_imm10_val[`HBIT_IMM10]}}, iw_imm10_val};
                last  = eff + 48'd10;
                bound = iw_cr_t_base + iw_cr_t_len;
                if (!iw_cr_t_tag) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_TAG;
                end else if (iw_cr_t_attr[`CR_ATTR_SEALED_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_SEAL;
                end else if (!iw_cr_t_perms[`CR_PERM_SC_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_PERM;
                end else if (!((eff >= iw_cr_t_base) && (last <= bound))) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_OOB;
                end
                if (fault) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = cause;
                end
            end
            // Micro-ops: CR2SR and SR2CR
            `OPC_CR2SR: begin
                // field selector at [11:8]
                case (iw_instr[11:8])
                    `CR_FLD_BASE:  r_sr_result = iw_cr_s_base;
                    `CR_FLD_LEN:   r_sr_result = iw_cr_s_len;
                    `CR_FLD_CUR:   r_sr_result = iw_cr_s_cur;
                    `CR_FLD_PERMS: r_sr_result = {24'b0, iw_cr_s_perms};
                    `CR_FLD_ATTR:  r_sr_result = {24'b0, iw_cr_s_attr};
                    `CR_FLD_TAG:   r_sr_result = {47'b0, iw_cr_s_tag};
                    default:       r_sr_result = {`SIZE_ADDR{1'b0}};
                endcase
                r_result    = r_sr_result[23:0];
            end
            `OPC_SR2CR: begin
                r_cr_write_addr = iw_tgt_ar;
                case (iw_instr[11:8])
                    `CR_FLD_BASE:  begin r_cr_we_base  = 1'b1; r_cr_base  = iw_src_sr_val; end
                    `CR_FLD_LEN:   begin r_cr_we_len   = 1'b1; r_cr_len   = iw_src_sr_val; end
                    `CR_FLD_CUR:   begin r_cr_we_cur   = 1'b1; r_cr_cur   = iw_src_sr_val; end
                    `CR_FLD_PERMS: begin r_cr_we_perms = 1'b1; r_cr_perms = iw_src_sr_val[23:0]; end
                    `CR_FLD_ATTR:  begin r_cr_we_attr  = 1'b1; r_cr_attr  = iw_src_sr_val[23:0]; end
                    `CR_FLD_TAG:   begin r_cr_we_tag   = 1'b1; r_cr_tag   = iw_src_sr_val[0]; end
                endcase
            end
            
            `OPC_LUIui: begin
                // r_uimm_* banks and valid bits updated in sequential block
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
                if (amt_mod == 5'd0) begin
                    // No-op: result unchanged, flags unchanged
                    r_result = iw_tgt_gp_val;
                end else begin
                    r_result = (iw_tgt_gp_val << amt_mod) | (iw_tgt_gp_val >> (`SIZE_DATA - amt_mod));
                    // Last bit shifted out corresponds to bit SIZE-amt_mod
                    carry_idx = (`SIZE_DATA - amt_mod);
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
                if (amt_mod == 5'd0) begin
                    // No-op: result unchanged, flags unchanged
                    r_result = iw_tgt_gp_val;
                end else begin
                    r_result = (iw_tgt_gp_val >> amt_mod) | (iw_tgt_gp_val << (`SIZE_DATA - amt_mod));
                    // Last bit shifted out comes from bit amt_mod-1
                    carry_idx = (amt_mod-1);
                    r_fl[`FLAG_C] = (iw_tgt_gp_val >> carry_idx) & 1'b1;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end
            end
            
            // CSR read: r_result already muxed via amber to contain CSR value (in iw_src_sr_val[23:0])
            `OPC_CSRRD: begin
                r_result = iw_src_sr_val[23:0];
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                r_flags_we = 1'b1;
            end
            
            // CSR write: pass DRs value along result path for WB to write into CSR file
            `OPC_CSRWR: begin
                r_result = iw_src_gp_val;
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
                // Logical left shift by variable amount; trap on range per spec
                reg [4:0] n;
                reg [4:0] n_eff;
                n = iw_src_gp_val[4:0];
                if (n == 5'd0) begin
                    // No-op, flags unchanged
                    r_result = iw_tgt_gp_val;
                end else if (n >= `SIZE_DATA) begin
                    // Range trap: branch to handler base from uimm banks; save LR=PC+1
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_RANGE;
                end else begin
                    n_eff = n;
                    r_result = iw_tgt_gp_val << n_eff;
                    // Update flags (Z,C) only when amount is non-zero (true here)
                    r_fl[`FLAG_C] = ((iw_tgt_gp_val >> (`SIZE_DATA - n_eff)) & 1'b1);
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end
            end
            `OPC_SHRur: begin
                // Logical right shift by variable amount; trap on range per spec
                reg [4:0] n;
                reg [4:0] n_eff;
                n = iw_src_gp_val[4:0];
                if (n == 5'd0) begin
                    // No-op, flags unchanged
                    r_result = iw_tgt_gp_val;
                end else if (n >= `SIZE_DATA) begin
                    // Range trap
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_RANGE;
                end else begin
                    n_eff = n;
                    r_result = iw_tgt_gp_val >> n_eff;
                    // Update flags (Z,C) only when amount is non-zero (true here)
                    r_fl[`FLAG_C] = ((iw_tgt_gp_val >> (n_eff-1)) & 1'b1);
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
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
            
            `OPC_STui: begin
                // CHERI-checked store: 24-bit immediate to (CRt.cursor)
                reg [47:0] eff;
                reg [7:0]  cause;
                reg        fault;
                eff   = iw_cr_t_cur; // no offset
                cause = `PSTATE_CAUSE_NONE;
                fault = 1'b0;
                if (!iw_cr_t_tag) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_TAG;
                end else if (iw_cr_t_attr[`CR_ATTR_SEALED_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_SEAL;
                end else if (!iw_cr_t_perms[`CR_PERM_W_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_PERM;
                end else if (!((eff >= iw_cr_t_base) && (eff < (iw_cr_t_base + iw_cr_t_len)))) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_OOB;
                end
                if (fault) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = cause;
                end else begin
                    r_addr   = eff;
                    r_result = r_ir; // zero-extended 24-bit immediate
                end
            end
            `OPC_STsi: begin
                // CHERI-checked store: 24-bit sign-extended immediate to (CRt.cursor)
                reg [47:0] eff;
                reg [7:0]  cause;
                reg        fault;
                eff   = iw_cr_t_cur; // no offset
                cause = `PSTATE_CAUSE_NONE;
                fault = 1'b0;
                if (!iw_cr_t_tag) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_TAG;
                end else if (iw_cr_t_attr[`CR_ATTR_SEALED_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_SEAL;
                end else if (!iw_cr_t_perms[`CR_PERM_W_BIT]) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_PERM;
                end else if (!((eff >= iw_cr_t_base) && (eff < (iw_cr_t_base + iw_cr_t_len)))) begin
                    fault = 1'b1;
                    cause = `PSTATE_CAUSE_CAP_OOB;
                end
                if (fault) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = cause;
                end else begin
                    r_addr   = eff;
                    r_result = r_se_imm14_val;
                end
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
            // Trap-on-overflow variants (register)
            `OPC_ADDsv: begin
                r_result = $signed(iw_src_gp_val) + $signed(iw_tgt_gp_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                r_fl[`FLAG_N] = ($signed(r_result) < 0);
                r_fl[`FLAG_V] = ((~(iw_src_gp_val[`HBIT_DATA] ^ iw_tgt_gp_val[`HBIT_DATA])) &&
                                 (iw_src_gp_val[`HBIT_DATA] ^ r_result[`HBIT_DATA]));
                // if overflow, raise trap: branch to absolute base from uimm banks (low12=0), save LR=PC+1
                if (r_fl[`FLAG_V]) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0; // do not write FL when trapping
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_OVF;
                end else begin
                    r_flags_we = 1'b1;
                end
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
            `OPC_SUBsv: begin
                r_result = $signed(iw_tgt_gp_val) - $signed(iw_src_gp_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                r_fl[`FLAG_N] = ($signed(r_result) < 0);
                r_fl[`FLAG_V] = ((iw_src_gp_val[`HBIT_DATA] ^ iw_tgt_gp_val[`HBIT_DATA]) &&
                                 (iw_tgt_gp_val[`HBIT_DATA] ^ r_result[`HBIT_DATA]));
                if (r_fl[`FLAG_V]) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_OVF;
                end else begin
                    r_flags_we = 1'b1;
                end
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
            `OPC_NEGsv: begin
                r_result = $signed(24'd0) - $signed(iw_tgt_gp_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                r_fl[`FLAG_N] = ($signed(r_result) < 0);
                r_fl[`FLAG_V] = (iw_tgt_gp_val == 24'h800000);
                if (r_fl[`FLAG_V]) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_OVF;
                end else begin
                    r_flags_we = 1'b1;
                end
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
            `OPC_SHRsrv: begin
                // Arithmetic right shift by variable amount with range trap
                // Trap on n >= 24; otherwise identical behavior to SHRsr
                reg [4:0] n;
                reg [4:0] n_eff;
                n = iw_src_gp_val[4:0];
                if (n == 5'd0) begin
                    // No-op, flags unchanged
                    r_result = iw_tgt_gp_val;
                end else if (n >= `SIZE_DATA) begin
                    // Range trap: branch to handler base from uimm banks; save LR=PC+1, suppress GP write
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0; // do not update flags on trap
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_RANGE;
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
                    r_branch_pc = $signed(iw_pc) +
                                   $signed(extend_data_to_addr(iw_tgt_gp_val));
            end
            `OPC_MOVui: begin
                if (!r_uimm_bank0_valid) begin
                    // UIMM_STATE trap
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
                    r_result = r_ir;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                    r_flags_we = 1'b1;
                end
            end
            `OPC_ADDui: begin
                if (!r_uimm_bank0_valid) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
                    r_result = iw_tgt_gp_val + r_ir;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                    r_fl[`FLAG_C] = (r_result < iw_tgt_gp_val) ? 1'b1 : 1'b0;
                    r_flags_we = 1'b1;
                end
            end
            `OPC_SUBui: begin
                if (!r_uimm_bank0_valid) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
                    r_result = iw_tgt_gp_val - r_ir;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                    r_fl[`FLAG_C] = (iw_tgt_gp_val < r_ir) ? 1'b1 : 1'b0;
                    r_flags_we = 1'b1;
                end
            end
            `OPC_ANDui: begin
                if (!r_uimm_bank0_valid) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
                    r_result = iw_tgt_gp_val & r_ir;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                    r_flags_we = 1'b1;
                end
            end
            `OPC_ORui: begin
                if (!r_uimm_bank0_valid) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
                    r_result = iw_tgt_gp_val | r_ir;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                    r_flags_we = 1'b1;
                end
            end
            `OPC_XORui: begin
                if (!r_uimm_bank0_valid) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
                    r_result = iw_tgt_gp_val ^ r_ir;
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                    r_flags_we = 1'b1;
                end
            end
            `OPC_SHLui: begin
                if (!r_uimm_bank0_valid) begin
                    // UIMM_STATE trap
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
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
            end
            `OPC_SHLuiv: begin
                // Checked left shift: trap when imm5 >= 24 (ARITH_RANGE)
                reg [4:0] n;
                n = r_ir[4:0];
                if (n == 5'd0) begin
                    r_result = iw_tgt_gp_val;
                end else if (n >= `SIZE_DATA) begin
                    // Trap: branch to SWI vector from uimm banks; save LR=PC+1; cancel GP write/flags
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_RANGE;
                end else begin
                    r_result = iw_tgt_gp_val << n;
                    r_fl[`FLAG_C] = ((iw_tgt_gp_val >> (`SIZE_DATA - n)) & 1'b1);
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end
            end
            `OPC_ROLui: begin
                if (!r_uimm_bank0_valid) begin
                    // UIMM_STATE trap
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
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
            end
            `OPC_RORui: begin
                if (!r_uimm_bank0_valid) begin
                    // UIMM_STATE trap
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
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
            end
            `OPC_SHRui: begin
                if (!r_uimm_bank0_valid) begin
                    // UIMM_STATE trap
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
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
            end
            `OPC_SHRuiv: begin
                // Checked right shift: trap when imm5 >= 24 (ARITH_RANGE)
                reg [4:0] n;
                n = r_ir[4:0];
                if (n == 5'd0) begin
                    r_result = iw_tgt_gp_val;
                end else if (n >= `SIZE_DATA) begin
                    // Trap: branch to SWI vector from uimm banks; save LR=PC+1; cancel GP write/flags
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_RANGE;
                end else begin
                    r_result = iw_tgt_gp_val >> n;
                    r_fl[`FLAG_C] = ((iw_tgt_gp_val >> (n-1)) & 1'b1);
                    r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                    r_flags_we = 1'b1;
                end
            end
            `OPC_CMPui: begin
                if (!r_uimm_bank0_valid) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                end else begin
                    r_fl[`FLAG_Z] = (iw_tgt_gp_val == r_ir) ? 1'b1 : 1'b0;
                    r_fl[`FLAG_C] = (iw_tgt_gp_val < r_ir) ? 1'b1 : 1'b0;
                    r_flags_we = 1'b1;
                end
            end
            `OPC_JCCui: begin
                if (r_branch_taken) begin
                    // If uimm banks are not valid, raise UIMM_STATE trap instead of branching
                    if (!(r_uimm_bank0_valid & r_uimm_bank1_valid & r_uimm_bank2_valid)) begin
                        r_branch_taken = 1'b1;
                        r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                        r_trap_lr_we   = 1'b1;
                        r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                        r_kill_gp_we   = 1'b1;
                    end else begin
                        // Assemble 48-bit absolute from banks and imm12
                        r_branch_pc = {r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, iw_imm12_val};
                    end
                end
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
                    ((~(iw_tgt_gp_val[`HBIT_DATA] ^ r_se_imm12_val[`HBIT_DATA])) &&
                    (iw_tgt_gp_val[`HBIT_DATA] ^ r_result[`HBIT_DATA])) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_ADDsiv: begin
                r_result = $signed(iw_tgt_gp_val) + $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                r_fl[`FLAG_N] = ($signed(r_result) < 0);
                r_fl[`FLAG_V] = ((~(iw_tgt_gp_val[`HBIT_DATA] ^ r_se_imm12_val[`HBIT_DATA])) &&
                                 (iw_tgt_gp_val[`HBIT_DATA] ^ r_result[`HBIT_DATA]));
                if (r_fl[`FLAG_V]) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_OVF;
                end else begin
                    r_flags_we = 1'b1;
                end
            end
            `OPC_SUBsi: begin
                r_result = $signed(iw_tgt_gp_val) - $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((r_se_imm12_val[`HBIT_DATA] ^ iw_tgt_gp_val[`HBIT_DATA]) &&
                    (iw_tgt_gp_val[`HBIT_DATA] ^ r_result[`HBIT_DATA])) ? 1'b1 : 1'b0;
                r_flags_we = 1'b1;
            end
            `OPC_SUBsiv: begin
                r_result = $signed(iw_tgt_gp_val) - $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}});
                r_fl[`FLAG_N] = ($signed(r_result) < 0);
                r_fl[`FLAG_V] = ((r_se_imm12_val[`HBIT_DATA] ^ iw_tgt_gp_val[`HBIT_DATA]) &&
                                 (iw_tgt_gp_val[`HBIT_DATA] ^ r_result[`HBIT_DATA]));
                if (r_fl[`FLAG_V]) begin
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_OVF;
                end else begin
                    r_flags_we = 1'b1;
                end
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
            `OPC_SHRsiv: begin
                // Checked arithmetic right shift by immediate: trap when imm5 >= 24 (ARITH_RANGE)
                reg [4:0] n;
                n = iw_imm12_val[4:0];
                if (n == 5'd0) begin
                    // No-op, flags unchanged
                    r_result = iw_tgt_gp_val;
                end else if (n >= `SIZE_DATA) begin
                    // Trap: branch to SWI vector from uimm banks; save LR=PC+1; cancel GP write/flags
                    r_branch_taken = 1'b1;
                    r_branch_pc    = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we   = 1'b1;
                    r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                    r_kill_gp_we   = 1'b1;
                    r_flags_we     = 1'b0;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_ARITH_RANGE;
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
                r_fl[`FLAG_V] = ((iw_tgt_gp_val[`HBIT_DATA] ^ r_se_imm12_val[`HBIT_DATA]) &
                                 (iw_tgt_gp_val[`HBIT_DATA] ^ s_diff[`HBIT_DATA]));
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
                    r_branch_pc = $signed(iw_pc) +
                                   $signed(extend_imm12_to_addr(iw_imm12_val));
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
                    r_branch_pc = $signed(iw_tgt_sr_val) +
                                   $signed(extend_imm10_to_addr(iw_imm10_val));
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
            
            `OPC_BALso: begin
                // Unconditional PC-relative branch by signed imm16
                r_branch_taken = 1'b1;
                r_branch_pc    = $signed(iw_pc) +
                                  $signed(extend_imm16_to_addr(iw_imm16_val));
            end
            // Privileged/trap entry: SYSCALL/SWI
            `OPC_SYSCALL: begin
                // Save return PC (PC+1) into LR via SR write path
                r_trap_lr_value = iw_pc + `SIZE_ADDR'd1;
                r_trap_lr_we   = 1'b1;
                // Branch to absolute 48-bit target assembled from LUI banks + imm12
                r_branch_taken = 1'b1;
                if (!(r_uimm_bank0_valid & r_uimm_bank1_valid & r_uimm_bank2_valid)) begin
                    // UIMM_STATE trap
                    r_branch_pc  = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, 12'h000 };
                    r_trap_lr_we = 1'b1; // LR already set above
                    r_kill_gp_we = 1'b1;
                    r_trap_pending = 1'b1;
                    r_trap_cause   = `PSTATE_CAUSE_UIMM_STATE;
                end else begin
                    r_branch_pc  = { r_uimm_bank2, r_uimm_bank1, r_uimm_bank0, iw_imm12_val };
                end
            end
            // Kernel return: KRET/SRET — jump to LR (selected via ID stage)
            `OPC_KRET: begin
                r_branch_taken = 1'b1;
                r_branch_pc    = iw_tgt_sr_val;
            end
            `OPC_HLT: begin
                r_halt         = 1'b1;
                r_branch_taken = 1'b0;
            end
            default: begin
                r_result = `SIZE_DATA'b0;
                r_fl     = `SIZE_FLAG'b0;
            end
        endcase
        // After computing r_fl, apply flag updates to PSTATE
        if (r_flags_we) begin
            r_pstate_next[`PSTATE_BIT_Z] = r_fl[`FLAG_Z];
            r_pstate_next[`PSTATE_BIT_N] = r_fl[`FLAG_N];
            r_pstate_next[`PSTATE_BIT_C] = r_fl[`FLAG_C];
            r_pstate_next[`PSTATE_BIT_V] = r_fl[`FLAG_V];
            r_pstate_dirty = 1'b1;
        end
        // Ensure mode bit tracks current privilege when updating
        if (iw_mode_kernel != iw_pstate_val[`PSTATE_BIT_MODE]) begin
            r_pstate_next[`PSTATE_BIT_MODE] = iw_mode_kernel;
            r_pstate_dirty = 1'b1;
        end
        if (r_trap_pending) begin
            r_pstate_next[`PSTATE_BIT_TPE] = 1'b1;
            r_pstate_next[`PSTATE_BIT_MODE] = 1'b1; // enter kernel on trap
            r_pstate_next[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO] = r_trap_cause;
            r_pstate_next[`PSTATE_INFO_HI:`PSTATE_INFO_LO]  = r_trap_info;
            r_pstate_dirty = 1'b1;
        end
        if (r_trap_lr_we) begin
            r_sr_result = r_trap_lr_value;
        end
        if (r_pstate_dirty) begin
            r_sr_aux_we     = 1'b1;
            r_sr_aux_addr   = `SR_IDX_PSTATE;
            r_sr_aux_result = r_pstate_next;
        end
    end

    reg [`HBIT_ADDR:0]   r_pc_latch;
    reg [`HBIT_DATA:0]   r_instr_latch;
    reg [`HBIT_OPC:0]    r_opc_latch;
    reg [`HBIT_OPC:0]    r_root_opc_latch;
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
    reg                  r_trap_pending_latch;
    reg                  r_halt_latch;
    // SR aux writeback (PSTATE)
    reg                  r_sr_aux_we_latch;
    reg [`HBIT_TGT_SR:0] r_sr_aux_addr_latch;
    reg [`HBIT_ADDR:0]   r_sr_aux_result_latch;
    // CR writeback latches
    reg [`HBIT_TGT_CR:0] r_cr_write_addr_latch;
    reg                  r_cr_we_base_latch;
    reg [`HBIT_ADDR:0]   r_cr_base_latch;
    reg                  r_cr_we_len_latch;
    reg [`HBIT_ADDR:0]   r_cr_len_latch;
    reg                  r_cr_we_cur_latch;
    reg [`HBIT_ADDR:0]   r_cr_cur_latch;
    reg                  r_cr_we_perms_latch;
    reg [`HBIT_DATA:0]   r_cr_perms_latch;
    reg                  r_cr_we_attr_latch;
    reg [`HBIT_DATA:0]   r_cr_attr_latch;
    reg                  r_cr_we_tag_latch;
    reg                  r_cr_tag_latch;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_pc_latch           <= `SIZE_ADDR'b0;
            r_instr_latch        <= `SIZE_DATA'b0;
            r_opc_latch          <= `SIZE_OPC'b0;
            r_root_opc_latch     <= `SIZE_OPC'b0;
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
            r_trap_pending_latch <= 1'b0;
            r_trap_pending_latch <= 1'b0;
            r_halt_latch         <= 1'b0;
            r_sr_aux_we_latch    <= 1'b0;
            r_sr_aux_addr_latch  <= {(`HBIT_TGT_SR+1){1'b0}};
            r_sr_aux_result_latch<= {`SIZE_ADDR{1'b0}};
            // CR writeback latches
            r_cr_write_addr_latch<= {(`HBIT_TGT_CR+1){1'b0}};
            r_cr_we_base_latch   <= 1'b0;
            r_cr_base_latch      <= {`SIZE_ADDR{1'b0}};
            r_cr_we_len_latch    <= 1'b0;
            r_cr_len_latch       <= {`SIZE_ADDR{1'b0}};
            r_cr_we_cur_latch    <= 1'b0;
            r_cr_cur_latch       <= {`SIZE_ADDR{1'b0}};
            r_cr_we_perms_latch  <= 1'b0;
            r_cr_perms_latch     <= {`SIZE_DATA{1'b0}};
            r_cr_we_attr_latch   <= 1'b0;
            r_cr_attr_latch      <= {`SIZE_DATA{1'b0}};
            r_cr_we_tag_latch    <= 1'b0;
            r_cr_tag_latch       <= 1'b0;
        end else if (iw_flush) begin
            r_pc_latch           <= `SIZE_ADDR'b0;
            r_instr_latch        <= `SIZE_DATA'b0;
            r_opc_latch          <= `SIZE_OPC'b0;
            r_root_opc_latch     <= `SIZE_OPC'b0;
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
            r_trap_pending_latch <= 1'b0;
            r_halt_latch         <= 1'b0;
            r_sr_aux_we_latch    <= 1'b0;
            r_sr_aux_addr_latch  <= {(`HBIT_TGT_SR+1){1'b0}};
            r_sr_aux_result_latch<= {`SIZE_ADDR{1'b0}};
            r_cr_write_addr_latch<= {(`HBIT_TGT_CR+1){1'b0}};
            r_cr_we_base_latch   <= 1'b0;
            r_cr_base_latch      <= {`SIZE_ADDR{1'b0}};
            r_cr_we_len_latch    <= 1'b0;
            r_cr_len_latch       <= {`SIZE_ADDR{1'b0}};
            r_cr_we_cur_latch    <= 1'b0;
            r_cr_cur_latch       <= {`SIZE_ADDR{1'b0}};
            r_cr_we_perms_latch  <= 1'b0;
            r_cr_perms_latch     <= {`SIZE_DATA{1'b0}};
            r_cr_we_attr_latch   <= 1'b0;
            r_cr_attr_latch      <= {`SIZE_DATA{1'b0}};
            r_cr_we_tag_latch    <= 1'b0;
            r_cr_tag_latch       <= 1'b0;
        end else if (iw_stall) begin
            r_pc_latch           <= r_pc_latch;
            r_instr_latch        <= r_instr_latch;
            r_opc_latch          <= r_opc_latch;
            r_root_opc_latch     <= r_root_opc_latch;
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
            r_halt_latch         <= r_halt_latch;
            r_trap_pending_latch <= r_trap_pending_latch;
            r_sr_aux_we_latch    <= r_sr_aux_we_latch;
            r_sr_aux_addr_latch  <= r_sr_aux_addr_latch;
            r_sr_aux_result_latch<= r_sr_aux_result_latch;
            r_cr_write_addr_latch<= r_cr_write_addr_latch;
            r_cr_we_base_latch   <= r_cr_we_base_latch;
            r_cr_base_latch      <= r_cr_base_latch;
            r_cr_we_len_latch    <= r_cr_we_len_latch;
            r_cr_len_latch       <= r_cr_len_latch;
            r_cr_we_cur_latch    <= r_cr_we_cur_latch;
            r_cr_cur_latch       <= r_cr_cur_latch;
            r_cr_we_perms_latch  <= r_cr_we_perms_latch;
            r_cr_perms_latch     <= r_cr_perms_latch;
            r_cr_we_attr_latch   <= r_cr_we_attr_latch;
            r_cr_attr_latch      <= r_cr_attr_latch;
            r_cr_we_tag_latch    <= r_cr_we_tag_latch;
            r_cr_tag_latch       <= r_cr_tag_latch;
        end else begin
            r_pc_latch           <= iw_pc;
            r_instr_latch        <= iw_instr;
            r_opc_latch          <= iw_opc;
            r_root_opc_latch     <= iw_root_opc;
            r_tgt_gp_latch       <= iw_tgt_gp;
            // Kill GP writeback if a trap is taken in EX
            r_tgt_gp_we_latch    <= (iw_tgt_gp_we & ~r_kill_gp_we);
            // SR write target: prefer trap LR write, then FL (flags), else incoming
            r_tgt_sr_latch       <= (r_trap_lr_we ? `SR_IDX_LR : (r_tgt_sr_we ? `SR_IDX_FL : iw_tgt_sr));
            r_tgt_sr_we_latch    <= (iw_tgt_sr_we | r_tgt_sr_we | r_trap_lr_we);
            r_tgt_ar_latch       <= iw_tgt_ar;
            r_tgt_ar_we_latch    <= r_tgt_ar_we;
            r_addr_latch         <= r_addr;
            r_result_latch       <= r_result;
            r_ar_result_latch    <= r_ar_result;
            r_sr_result_latch    <= r_sr_result;
            r_branch_taken_latch <= r_branch_taken;
            r_branch_pc_latch    <= r_branch_pc;
            r_halt_latch         <= r_halt;
            r_trap_pending_latch <= r_trap_pending;
            r_sr_aux_we_latch    <= r_sr_aux_we;
            r_sr_aux_addr_latch  <= r_sr_aux_addr;
            r_sr_aux_result_latch<= r_sr_aux_result;
            r_cr_write_addr_latch<= r_cr_write_addr;
            r_cr_we_base_latch   <= r_cr_we_base;
            r_cr_base_latch      <= r_cr_base;
            r_cr_we_len_latch    <= r_cr_we_len;
            r_cr_len_latch       <= r_cr_len;
            r_cr_we_cur_latch    <= r_cr_we_cur;
            r_cr_cur_latch       <= r_cr_cur;
            r_cr_we_perms_latch  <= r_cr_we_perms;
            r_cr_perms_latch     <= r_cr_perms;
            r_cr_we_attr_latch   <= r_cr_we_attr;
            r_cr_attr_latch      <= r_cr_attr;
            r_cr_we_tag_latch    <= r_cr_we_tag;
            r_cr_tag_latch       <= r_cr_tag;
        end
    end
    assign ow_pc           = r_pc_latch;
    assign ow_instr        = r_instr_latch;
    assign ow_opc          = r_opc_latch;
    assign ow_root_opc     = r_root_opc_latch;
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
    assign ow_sr_aux_we    = r_sr_aux_we_latch;
    assign ow_sr_aux_addr  = r_sr_aux_addr_latch;
    assign ow_sr_aux_result= r_sr_aux_result_latch;
    assign ow_branch_taken = r_branch_taken_latch;
    assign ow_branch_pc    = r_branch_pc_latch;
    assign ow_trap_pending = r_trap_pending_latch;
    assign ow_halt         = r_halt_latch;
    // CR writeback
    assign ow_cr_write_addr = r_cr_write_addr_latch;
    assign ow_cr_we_base    = r_cr_we_base_latch;
    assign ow_cr_base       = r_cr_base_latch;
    assign ow_cr_we_len     = r_cr_we_len_latch;
    assign ow_cr_len        = r_cr_len_latch;
    assign ow_cr_we_cur     = r_cr_we_cur_latch;
    assign ow_cr_cur        = r_cr_cur_latch;
    assign ow_cr_we_perms   = r_cr_we_perms_latch;
    assign ow_cr_perms      = r_cr_perms_latch;
    assign ow_cr_we_attr    = r_cr_we_attr_latch;
    assign ow_cr_attr       = r_cr_attr_latch;
    assign ow_cr_we_tag     = r_cr_we_tag_latch;
    assign ow_cr_tag        = r_cr_tag_latch;
endmodule
