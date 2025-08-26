`include "src/sizes.vh"
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
    // localparam int MAX_SEQ = 4;

    wire [`HBIT_OPC:0]     w_opc       = iw_instr[`HBIT_INSTR_OPC:`LBIT_INSTR_OPC];
    wire [`HBIT_OPCLASS:0] w_opclass   = iw_instr[`HBIT_INSTR_OPCLASS:`LBIT_INSTR_OPCLASS];
    wire [`HBIT_SUBOP:0]   w_subop     = iw_instr[`HBIT_INSTR_SUBOP:`LBIT_INSTR_SUBOP];
    wire [`HBIT_IMM14:0]   w_imm14_val = iw_instr[`HBIT_INSTR_IMM14:0];
    wire [`HBIT_IMM12:0]   w_imm12_val = iw_instr[`HBIT_INSTR_IMM12:0];
    wire [`HBIT_IMM10:0]   w_imm10_val = iw_instr[`HBIT_INSTR_IMM10:0];
    wire [`HBIT_IMM8:0]    w_imm8_val  = iw_instr[`HBIT_INSTR_IMM8:0];
    // wire [`HBIT_CC:0]      w_cc        = iw_instr[`HBIT_INSTR_CC:`LBIT_INSTR_CC];
    // wire [`HBIT_TGT_GP:0]  w_tgt_gp    = iw_instr[`HBIT_INSTR_TGT_GP:`LBIT_INSTR_TGT_GP];
    // wire [`HBIT_TGT_SR:0]  w_tgt_sr    = iw_instr[`HBIT_INSTR_TGT_SR:`LBIT_INSTR_TGT_SR];
    // wire [`HBIT_SRC_GP:0]  w_src_gp    = iw_instr[`HBIT_INSTR_SRC_GP:`LBIT_INSTR_SRC_GP];
    // wire [`HBIT_SRC_SR:0]  w_src_sr    = iw_instr[`HBIT_INSTR_SRC_SR:`LBIT_INSTR_SRC_SR];
    // wire                   w_is_isa    = (w_opclass == `OPCLASS_ISA);

    // reg [3:0]          r_n_cnt;
    // reg [`HBIT_DATA:0] r_n_instr_list [0:MAX_SEQ-1];
    reg [`HBIT_ADDR:0] r_pc;
    reg [`HBIT_DATA:0] r_instr;
    always @(*) begin
        case (w_opclass)
            `OPCLASS_0, `OPCLASS_1, `OPCLASS_2, `OPCLASS_3, `OPCLASS_4, `OPCLASS_5, `OPCLASS_6, `OPCLASS_A: begin
                r_pc    = iw_pc;
                r_instr = iw_instr;
            end
            `OPCLASS_7, `OPCLASS_8: begin
                r_pc    = iw_pc;
                r_instr = iw_instr;
                // case (w_subop)
                    // `SUBOP_ISA_PUSH: begin
                    //     r_n_cnt = 2;
                    //     r_n_instr_list[0] = pack_instr_imm12(`OPC_IS_SUBis, w_tgt_gp, 12'd1);
                    //     r_n_instr_list[1] = pack_instr_src(`OPC_RU_STu, w_tgt_gp, w_src_gp);
                    // end
                    // `SUBOP_ISA_POP: begin
                    //     r_n_cnt = 2;
                    //     r_n_instr_list[0] = pack_instr_tgt(`OPC_RU_LDu, w_tgt_gp, w_src_gp);
                    //     r_n_instr_list[1] = pack_instr_imm12(`OPC_IS_ADDis, w_src_gp, 12'd1);
                    // end
                    // `SUBOP_ISA_PUSH: r_instr = `SIZE_DATA'b0;
                    // `SUBOP_ISA_POP:  r_instr = `SIZE_DATA'b0;
                    // `SUBOP_ISA_JSR:  r_instr = `SIZE_DATA'b0;
                    // `SUBOP_ISA_JSRi: r_instr = `SIZE_DATA'b0;
                    // `SUBOP_ISA_BSR:  r_instr = `SIZE_DATA'b0;
                    // `SUBOP_ISA_BSRi: r_instr = `SIZE_DATA'b0;
                    // `SUBOP_ISA_RET:  r_instr = `SIZE_DATA'b0;
                    // `SUBOP_ISA_RET:  begin
                    //     r_n_cnt = 1;
                    //     r_n_instr_list[0] = pack_instr_tgt(`OPC_RU_LDu, w_tgt_gp, w_src_gp);
                    // end
                    // default:         r_instr = `SIZE_DATA'b0;
                // endcase
            end
            `OPCLASS_A: begin
                r_pc    = iw_pc;
                r_instr = iw_instr;
            end
            `OPCLASS_F: begin
                r_pc    = iw_pc;
                // r_instr = `SIZE_DATA'b0;
                r_instr = iw_instr;
            end
            default: begin
                r_pc    = iw_pc;
                r_instr = `SIZE_DATA'b0;
            end
        endcase
    end

    // reg                r_busy;
    // reg [3:0]          r_idx;
    // reg [3:0]          r_cnt;
    // reg [`HBIT_DATA:0] r_instr_list [0:MAX_SEQ-1];
    // reg [`HBIT_ADDR:0] r_pc_hold;

    reg [`HBIT_ADDR:0] r_pc_latch;
    reg [`HBIT_DATA:0] r_instr_latch;

    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_flush) begin
            r_pc_latch    <= `SIZE_ADDR'b0;
            r_instr_latch <= `SIZE_DATA'b0;
        end else if (iw_stall) begin
            r_pc_latch    <= r_pc_latch;
            r_instr_latch <= r_instr_latch;
        end else begin
            r_pc_latch    <= r_pc;
            r_instr_latch <= r_instr;
        end
    end
    assign ow_pc    = r_pc_latch;
    assign ow_instr = r_instr_latch;
endmodule