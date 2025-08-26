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
    input wire  [`HBIT_IMM12:0]  iw_imm12_val,
    input wire  [`HBIT_IMM8:0]   iw_imm8_val,
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
    input wire  [`HBIT_SRC_SR:0] iw_src_sr,
    output wire [`HBIT_ADDR:0]   ow_addr,
    output wire [`HBIT_DATA:0]   ow_result,
    output wire                  ow_branch_taken,
    output wire [`HBIT_ADDR:0]   ow_branch_pc,
    input wire  [`HBIT_DATA:0]   iw_src_gp_val,
    input wire  [`HBIT_DATA:0]   iw_tgt_gp_val,
    input wire  [`HBIT_DATA:0]   iw_src_sr_val,
    input wire  [`HBIT_DATA:0]   iw_tgt_sr_val,
    input wire                   iw_flush,
    input wire                   iw_stall
);
    reg [`HBIT_IMM12:0] r_ui;
    reg [`HBIT_DATA:0]  r_ir;
    reg [`HBIT_DATA:0]  r_se_imm12_val;
    reg [`HBIT_DATA:0]  r_se_imm8_val;
    reg [`HBIT_ADDR:0]  r_addr;
    reg [`HBIT_DATA:0]  r_result;
    reg [`HBIT_FLAG:0]  r_fl;
    reg                 r_branch_taken;
    reg [`HBIT_ADDR:0]  r_branch_pc;

    always @* begin
        if (!iw_stall) begin
            r_branch_taken = 1'b0;
            r_addr         = {`SIZE_ADDR{1'b0}};
            r_result       = {`SIZE_DATA{1'b0}};
        end
        r_ir           = {r_ui, iw_imm12_val};
        r_se_imm12_val = {{12{iw_imm12_val[`HBIT_IMM12]}}, iw_imm12_val};
        r_se_imm8_val  = {{16{iw_imm8_val[`HBIT_IMM8]}}, iw_imm8_val};
        if ((iw_opc == `OPC_RU_JCCu  || iw_opc == `OPC_RS_BCCs  ||
             iw_opc == `OPC_IU_JCCiu || iw_opc == `OPC_IS_BCCis ||
             iw_opc == `OPC_SR_SRJCCu)) begin
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
            `OPC_RU_LUI: begin
                r_ui = iw_imm12_val;
            end
            `OPC_RU_MOVu: begin
                r_result = iw_src_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_RU_ADDu: begin
                r_result = iw_src_gp_val + iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (r_result < iw_src_gp_val) ? 1'b1 : 1'b0;
            end
            `OPC_RU_SUBu: begin
                r_result = iw_tgt_gp_val - iw_src_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_tgt_gp_val < iw_src_gp_val) ? 1'b1 : 1'b0;
            end
            `OPC_RU_NOTu: begin
                r_result = ~iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_RU_ANDu: begin
                r_result = iw_src_gp_val & iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_RU_ORu: begin
                r_result = iw_src_gp_val | iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_RU_XORu: begin
                r_result = iw_src_gp_val ^ iw_tgt_gp_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_RU_SHLu: begin
                if (iw_src_gp_val >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_V] = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val << iw_src_gp_val[4:0];
                    r_fl[`FLAG_V] = 1'b0;
                end
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_RU_SHRu: begin
                if (iw_src_gp_val >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_V] = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val >> iw_src_gp_val[4:0];
                    r_fl[`FLAG_V] = 1'b0;
                end
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_RU_CMPu: begin
                r_fl[`FLAG_Z] = (iw_src_gp_val == iw_tgt_gp_val) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_src_gp_val < iw_tgt_gp_val) ? 1'b1 : 1'b0;
            end
            `OPC_RU_JCCu: begin
                if (r_branch_taken)
                    r_branch_pc = iw_pc + iw_src_gp_val;
            end
            `OPC_RU_LDu: begin
                r_addr = iw_src_gp_val;
            end
            `OPC_RU_STu: begin
                r_addr = iw_tgt_gp_val;
                r_result = iw_src_gp_val;
            end
            `OPC_RS_ADDs: begin
                r_result = $signed(iw_src_gp_val) + $signed(iw_tgt_gp_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((~(iw_src_gp_val[`HBIT_DATA-1] ^ iw_tgt_gp_val[`HBIT_DATA-1])) &&
                    (iw_src_gp_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
            end
            `OPC_RS_SUBs: begin
                r_result = $signed(iw_tgt_gp_val) - $signed(iw_src_gp_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((iw_src_gp_val[`HBIT_DATA-1] ^ iw_tgt_gp_val[`HBIT_DATA-1]) &&
                    (iw_tgt_gp_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
            end
            `OPC_RS_SHRs: begin
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
            `OPC_RS_CMPs: begin
                reg signed [`HBIT_DATA:0] s_diff;
                s_diff = $signed(iw_tgt_gp_val) - $signed(iw_src_gp_val);
                r_fl[`FLAG_Z] = (iw_src_gp_val == iw_tgt_gp_val) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = (s_diff < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((iw_src_gp_val[`HBIT_DATA] ^ iw_tgt_gp_val[`HBIT_DATA]) &
                    (iw_src_gp_val[`HBIT_DATA] ^ s_diff[`HBIT_DATA]));
            end
            `OPC_RS_BCCs: begin
                if (r_branch_taken)
                    r_branch_pc = iw_pc + $signed(iw_src_gp_val);
            end
            `OPC_IU_MOViu: begin
                r_result = r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_IU_ADDiu: begin
                r_result = iw_tgt_gp_val + r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (r_result < iw_tgt_gp_val) ? 1'b1 : 1'b0;
            end
            `OPC_IU_SUBiu: begin
                r_result = iw_tgt_gp_val - r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_tgt_gp_val < r_ir) ? 1'b1 : 1'b0;
            end
            `OPC_IU_ANDiu: begin
                r_result = iw_tgt_gp_val & r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_IU_ORiu: begin
                r_result = iw_tgt_gp_val | r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_IU_XORiu: begin
                r_result = iw_tgt_gp_val ^ r_ir;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_IU_SHLiu: begin
                if (r_ir >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_V] = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val << r_ir[4:0];
                    r_fl[`FLAG_V] = 1'b0;
                end
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_IU_SHRiu: begin
                if (r_ir >= `SIZE_DATA) begin
                    r_result = {`SIZE_DATA{1'b0}};
                    r_fl[`FLAG_V] = 1'b1;
                end else begin
                    r_result = iw_tgt_gp_val >> r_ir[4:0];
                    r_fl[`FLAG_V] = 1'b0;
                end
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_IU_CMPiu: begin
                r_fl[`FLAG_Z] = (iw_tgt_gp_val == r_ir) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_tgt_gp_val < r_ir) ? 1'b1 : 1'b0;
            end
            `OPC_IU_JCCiu: begin
                if (r_branch_taken)
                    r_branch_pc = r_ir;
            end
            `OPC_IU_STiu: begin
                r_addr = iw_tgt_gp_val;
                r_result = r_ir;
            end
            `OPC_IS_MOVis: begin
                r_result = r_se_imm12_val;
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
            end
            `OPC_IS_ADDis: begin
                r_result = $signed(iw_tgt_gp_val) + $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((~(iw_tgt_gp_val[`HBIT_DATA-1] ^ r_se_imm12_val[`HBIT_DATA-1])) &&
                    (iw_tgt_gp_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
            end
            `OPC_IS_SUBis: begin
                r_result = $signed(iw_tgt_gp_val) - $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((r_se_imm12_val[`HBIT_DATA-1] ^ iw_tgt_gp_val[`HBIT_DATA-1]) &&
                    (iw_tgt_gp_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
            end
            `OPC_IS_SHRis: begin
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
            `OPC_IS_CMPis: begin
                reg signed [`HBIT_DATA:0] s_diff;
                s_diff = $signed(iw_tgt_gp_val) - $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (iw_tgt_gp_val == r_se_imm12_val) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = (s_diff < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] = ((iw_tgt_gp_val[`HBIT_DATA] ^ r_se_imm12_val[`HBIT_DATA]) &
                                 (iw_tgt_gp_val[`HBIT_DATA] ^ s_diff[`HBIT_DATA]));
            end
            `OPC_IS_BCCis: begin
                if (r_branch_taken)
                    r_branch_pc = iw_pc + $signed(r_se_imm12_val);
            end
            `OPC_IS_STis: begin
                r_addr = iw_tgt_gp_val;
                r_result = r_se_imm12_val;
            end
            `OPC_SR_SRMOVu: begin
                r_result = (iw_src_sr == `INDEX_PC) ? iw_pc : iw_src_sr_val;
            end
            `OPC_SR_SRADDis: begin
                r_result = $signed(iw_tgt_sr_val) + $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((~(iw_tgt_sr_val[`HBIT_DATA-1] ^ r_se_imm12_val[`HBIT_DATA-1])) &&
                    (iw_tgt_sr_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
            end
            `OPC_SR_SRSUBis: begin
                r_result = $signed(iw_tgt_sr_val) - $signed(r_se_imm12_val);
                r_fl[`FLAG_Z] = (r_result == {`SIZE_DATA{1'b0}}) ? 1'b1 : 1'b0;
                r_fl[`FLAG_N] = ($signed(r_result) < 0) ? 1'b1 : 1'b0;
                r_fl[`FLAG_V] =
                    ((r_se_imm12_val[`HBIT_DATA-1] ^ iw_tgt_sr_val[`HBIT_DATA-1]) &&
                    (iw_tgt_sr_val[`HBIT_DATA-1] ^ r_result[`HBIT_DATA-1])) ? 1'b1 : 1'b0;
            end
            `OPC_SR_SRCMPu: begin
                r_fl[`FLAG_Z] = (iw_src_sr_val == iw_tgt_sr_val) ? 1'b1 : 1'b0;
                r_fl[`FLAG_C] = (iw_src_sr_val < iw_tgt_sr_val) ? 1'b1 : 1'b0;
            end
            `OPC_SR_SRJCCu: begin
                if (r_branch_taken) begin
                    r_branch_pc = iw_src_sr_val + r_se_imm8_val;
                    // $display("SRJCCu: branch_pc=%h", r_branch_pc);
                end
                // $display("SRJCCu: branch_pc=%h", r_branch_pc);
            end
            `OPC_SR_SRLDu: begin
                r_addr = iw_src_sr_val;
                // $display("SRLDu: addr=%h", r_addr);
            end
            `OPC_SR_SRSTu: begin
                r_addr = iw_tgt_sr_val;
                r_result = iw_src_sr_val;
                // $display("SRSTu: addr=%h result=%h", r_addr, r_result);
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
    reg [`HBIT_ADDR:0]   r_addr_latch;
    reg [`HBIT_DATA:0]   r_result_latch;
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
            r_addr_latch         <= `SIZE_ADDR'b0;
            r_result_latch       <= `SIZE_DATA'b0;
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
            r_addr_latch         <= `SIZE_ADDR'b0;
            r_result_latch       <= `SIZE_DATA'b0;
            r_branch_taken_latch <= 1'b0;
            r_branch_pc_latch    <= `SIZE_ADDR'b0;
        end else if (iw_stall) begin
            r_pc_latch           <= `SIZE_ADDR'b0;
            r_instr_latch        <= `SIZE_DATA'b0;
            r_opc_latch          <= `SIZE_OPC'b0;
            r_tgt_gp_latch       <= `SIZE_TGT_GP'b0;
            r_tgt_gp_we_latch    <= 1'b0;
            r_tgt_sr_latch       <= `SIZE_TGT_SR'b0;
            r_tgt_sr_we_latch    <= 1'b0;
            r_addr_latch         <= `SIZE_ADDR'b0;
            r_result_latch       <= `SIZE_DATA'b0;
            r_branch_taken_latch <= 1'b0;
            r_branch_pc_latch    <= `SIZE_ADDR'b0;
        end else begin
            r_pc_latch           <= iw_pc;
            r_instr_latch        <= iw_instr;
            r_opc_latch          <= iw_opc;
            r_tgt_gp_latch       <= iw_tgt_gp;
            r_tgt_gp_we_latch    <= iw_tgt_gp_we;
            r_tgt_sr_latch       <= iw_tgt_sr;
            r_tgt_sr_we_latch    <= iw_tgt_sr_we;
            r_addr_latch         <= r_addr;
            r_result_latch       <= r_result;
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
    assign ow_addr         = r_addr_latch;
    assign ow_result       = r_result_latch;
    assign ow_branch_taken = r_branch_taken_latch;
    assign ow_branch_pc    = r_branch_pc_latch;
endmodule
