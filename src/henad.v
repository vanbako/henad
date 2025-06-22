// henad.v
// Top-level Henad 5-stage RISC core
`include "src/iset.vh"
module henad(
    input wire clk,
    input wire rst
);
    reg [11:0] ia_pc; // instruction address stage PC

    // Enable registers for each pipeline (sub)stage
    reg stage1ia_en;
    reg stage1if_en;
    reg stage2id_en;
    reg stage3ex_en;
    reg stage4ma_en;
    reg stage4mo_en;
    reg stage5ra_en;
    reg stage5ro_en;

    wire stage1if_en_w;
    wire stage2id_en_w;
    wire stage3ex_en_w;
    wire stage4ma_en_w;
    wire stage4mo_en_w;
    wire stage5ra_en_w;
    wire stage5ro_en_w;

    wire [11:0] instr_mem_data;
    wire [11:0] instr_mem_addr;

    wire [11:0] iaif_pc;
    wire [11:0] ifid_pc;
    wire [11:0] idex_pc;
    wire [11:0] exma_pc;
    wire [11:0] mamo_pc;
    wire [11:0] mora_pc;
    wire [11:0] raro_pc;
    wire [11:0] final_pc;

    wire [11:0] ifid_instr;
    wire [11:0] idex_instr;
    wire [11:0] exma_instr;
    wire [11:0] mamo_instr;
    wire [11:0] mora_instr;
    wire [11:0] raro_instr;
    wire [11:0] final_instr;

    wire [3:0] ifid_set;
    // Instruction set value at each pipeline stage
    wire [3:0] idex_set;
    wire [3:0] exma_set;
    wire [3:0] mamo_set;
    wire [3:0] mora_set;
    wire [3:0] raro_set;
    wire [3:0] final_set;

    // Decoded instruction fields from ID stage
    wire [3:0] id_bcc;
    wire [3:0] id_tgt_gp;
    wire [3:0] id_tgt_sr;
    wire [3:0] id_src_gp;
    wire [3:0] id_src_sr;
    wire       id_imm_en;
    wire       id_imm_hilo;
    wire [5:0] id_imm_val;
    wire [5:0] id_off;
    wire       id_sgn_en;

    // Decoded instruction fields after the EX stage
    wire [3:0] ex_bcc;
    wire [3:0] ex_tgt_gp;
    wire [3:0] ex_tgt_sr;
    wire [3:0] ex_src_gp;
    wire [3:0] ex_src_sr;
    wire       ex_imm_en;
    wire       ex_imm_hilo;
    wire [5:0] ex_imm_val;
    wire [5:0] ex_off;
    wire       ex_sgn_en;

    // Update ia_pc and enable signals
    always @(posedge clk or posedge rst) begin
        if (stage1ia_en) begin
            ia_pc <= ia_pc + 12'd1;
        end
        if (rst) begin
            ia_pc       <= 12'b0;
            stage1ia_en <= 1'b0;
            stage1if_en <= 1'b0;
            stage2id_en <= 1'b0;
            stage3ex_en <= 1'b0;
            stage4ma_en <= 1'b0;
            stage4mo_en <= 1'b0;
            stage5ra_en <= 1'b0;
            stage5ro_en <= 1'b0;
        end else begin
            stage1ia_en <= 1'b1;
            stage1if_en <= stage1if_en_w;
            stage2id_en <= stage2id_en_w;
            stage3ex_en <= stage3ex_en_w;
            stage4ma_en <= stage4ma_en_w;
            stage4mo_en <= stage4mo_en_w;
            stage5ra_en <= stage5ra_en_w;
            stage5ro_en <= stage5ro_en_w;
        end
    end

    // Stage and control instantiations

    // IA stage
    stage1ia u_stage1ia(
        .clk(clk),
        .rst(rst),
        .enable_in(stage1ia_en),
        .enable_out(stage1if_en_w),
        .mem_addr(instr_mem_addr),
        .pc_in(ia_pc),
        .pc_out(iaif_pc)
    );

    // IF stage
    stage1if u_stage1if(
        .clk(clk),
        .rst(rst),
        .enable_in(stage1if_en),
        .enable_out(stage2id_en_w),
        .pc_in(iaif_pc),
        .pc_out(ifid_pc),
        .instr_out(ifid_instr),
        .instr_mem_data(instr_mem_data)
    );
    meminstr u_meminstr(
        .clk(clk),
        .addr(instr_mem_addr),
        .data(instr_mem_data)
    );

    // Initial instruction set for the pipeline
    assign ifid_set = `ISET_R;

    // ID stage
    stage2id u_stage2id(
        .clk(clk),
        .rst(rst),
        .enable_in(stage2id_en),
        .enable_out(stage3ex_en_w),
        .pc_in(ifid_pc),
        .instr_in(ifid_instr),
        .instr_set_in(ifid_set),
        .pc_out(idex_pc),
        .instr_out(idex_instr),
        .instr_set_out(idex_set),
        .bcc_out(id_bcc),
        .tgt_gp_out(id_tgt_gp),
        .tgt_sr_out(id_tgt_sr),
        .src_gp_out(id_src_gp),
        .src_sr_out(id_src_sr),
        .imm_en_out(id_imm_en),
        .imm_hilo_out(id_imm_hilo),
        .imm_val_out(id_imm_val),
        .off_out(id_off),
        .sgn_en_out(id_sgn_en)
    );

    // EX stage
    stage3ex u_stage3ex(
        .clk(clk),
        .rst(rst),
        .enable_in(stage3ex_en),
        .enable_out(stage4ma_en_w),
        .pc_in(idex_pc),
        .instr_in(idex_instr),
        .instr_set_in(idex_set),
        .bcc_in(id_bcc),
        .tgt_gp_in(id_tgt_gp),
        .tgt_sr_in(id_tgt_sr),
        .src_gp_in(id_src_gp),
        .src_sr_in(id_src_sr),
        .imm_en_in(id_imm_en),
        .imm_hilo_in(id_imm_hilo),
        .imm_val_in(id_imm_val),
        .off_in(id_off),
        .sgn_en_in(id_sgn_en),
        .pc_out(exma_pc),
        .instr_out(exma_instr),
        .instr_set_out(exma_set),
        .bcc_out(ex_bcc),
        .tgt_gp_out(ex_tgt_gp),
        .tgt_sr_out(ex_tgt_sr),
        .src_gp_out(ex_src_gp),
        .src_sr_out(ex_src_sr),
        .imm_en_out(ex_imm_en),
        .imm_hilo_out(ex_imm_hilo),
        .imm_val_out(ex_imm_val),
        .off_out(ex_off),
        .sgn_en_out(ex_sgn_en)
    );

    // Memory address stage
    stage4ma u_stage4ma(
        .clk(clk),
        .rst(rst),
        .enable_in(stage4ma_en),
        .enable_out(stage4mo_en_w),
        .pc_in(exma_pc),
        .instr_in(exma_instr),
        .instr_set_in(exma_set),
        .pc_out(mamo_pc),
        .instr_out(mamo_instr),
        .instr_set_out(mamo_set)
    );

    // Memory operation stage
    stage4mo u_stage4mo(
        .clk(clk),
        .rst(rst),
        .enable_in(stage4mo_en),
        .enable_out(stage5ra_en_w),
        .pc_in(mamo_pc),
        .instr_in(mamo_instr),
        .instr_set_in(mamo_set),
        .pc_out(mora_pc),
        .instr_out(mora_instr),
        .instr_set_out(mora_set)
    );

    // Register address stage
    stage5ra u_stage5ra(
        .clk(clk),
        .rst(rst),
        .enable_in(stage5ra_en),
        .enable_out(stage5ro_en_w),
        .pc_in(mora_pc),
        .instr_in(mora_instr),
        .instr_set_in(mora_set),
        .pc_out(raro_pc),
        .instr_out(raro_instr),
        .instr_set_out(raro_set)
    );

    // Register operation stage
    stage5ro u_stage5ro(
        .clk(clk),
        .rst(rst),
        .enable_in(stage5ro_en),
        .pc_in(raro_pc),
        .instr_in(raro_instr),
        .instr_set_in(raro_set),
        .pc_out(final_pc),
        .instr_out(final_instr),
        .instr_set_out(final_set)
    );
endmodule
