// henad.v
// Top-level Henad 5-stage RISC core
`include "src/iset.vh"
`include "src/opcodes.vh"
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
    wire [11:0] data_mem_data;
    wire [11:0] data_mem_addr;
    wire [11:0] data_mem_wdata;
    wire        data_mem_we;

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


    reg  [3:0] ifid_set_reg;
    wire [3:0] ifid_set;
    // Instruction set value at each pipeline stage
    wire [3:0] idex_set;
    wire [3:0] exma_set;
    wire [3:0] mamo_set;
    wire [3:0] mora_set;
    wire [3:0] raro_set;
    wire [3:0] final_set;

    // Simple control hazard handling
    // Detect branch instructions in the EX stage so that the
    // following instruction can be replaced with a NOP.  This avoids
    // the need for branch prediction.
    // Branch resolution occurs in the EX stage, but the result is latched and
    // visible at the MA stage.  Use the MA stage instruction information to
    // determine whether the previous instruction was a taken branch.
    wire ex_is_branch = (({exma_set, exma_instr[11:8]} == {`ISET_R,  `OPC_R_BCC})  ||
                         ({exma_set, exma_instr[11:8]} == {`ISET_I,  `OPC_I_BCCi}) ||
                         ({exma_set, exma_instr[11:8]} == {`ISET_IS, `OPC_IS_BCCis}) ||
                         ({exma_set, exma_instr[11:8]} == {`ISET_S,  `OPC_S_SRBCC})) &&
                        ex_branch_taken;

    reg branch_stall;
    // Latch the resolved branch target so the PC can be updated on the
    // following cycle when a branch is taken.
    reg [11:0] branch_pc;

    // Stall signal for read-after-write hazards
    wire hazard_stall;

    // Combined stall control used by the decode stage and PC logic
    wire stall_signal = branch_stall || hazard_stall;

    // Hold the stall for a single cycle after a branch reaches the
    // execute stage.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            branch_stall <= 1'b0;
            branch_pc    <= 12'b0;
        end else begin
            branch_stall <= ex_is_branch;
            if (ex_is_branch)
                branch_pc <= ex_result;
        end
    end

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
    wire [11:0] ex_result;
    wire [11:0] ex_store_data;
    wire [3:0]  ex_flags;
    wire        ex_branch_taken;
    wire [11:0] ma_result;
    wire [11:0] ma_store_data;
    wire [3:0]  ma_flags;
    wire [11:0] mo_result;
    wire [3:0]  mo_flags;
    wire [11:0] ra_result;
    wire [3:0]  ra_flags;
    wire [3:0]  ra_reg_waddr;
    wire [11:0] ro_result;
    wire [3:0]  ro_flags;
    wire [3:0]  reg_waddr;
    wire        reg_we;
    wire        flag_we;
    wire [11:0] lr_out;
    wire [11:0] lr_wdata;
    wire        lr_we;

    // Update ia_pc and enable signals
    always @(posedge clk or posedge rst) begin
        if (branch_stall) begin
            // Use the resolved branch address when stalling
            ia_pc <= branch_pc;
        end else if (stage1ia_en) begin
            // Default sequential increment
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
            stage1ia_en <= stall_signal ? 1'b0 : 1'b1;
            stage1if_en <= stall_signal ? 1'b0 : stage1if_en_w;
            stage2id_en <= stall_signal ? 1'b1 : stage2id_en_w;
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
    memdata u_memdata(
        .clk(clk),
        .we(data_mem_we),
        .addr(data_mem_addr),
        .wdata(data_mem_wdata),
        .rdata(data_mem_data)
    );

    // General purpose register file and flag register
    wire [11:0] reg_src_data;
    wire [11:0] reg_tgt_data;
    reggp u_reggp(
        .clk(clk),
        .rst(rst),
        .raddr1(id_src_gp),
        .raddr2(id_tgt_gp),
        .waddr(reg_waddr),
        .wdata(ro_result),
        .we(reg_we),
        .rdata1(reg_src_data),
        .rdata2(reg_tgt_data)
    );

    wire [3:0] current_flags;
    regflag u_regflag(
        .clk(clk),
        .rst(rst),
        .flag_in(ro_flags),
        .we(flag_we),
        .flag_out(current_flags)
    );

    // Link register
    reglr u_reglr(
        .clk(clk),
        .rst(rst),
        .lr_in(lr_wdata),
        .we(lr_we),
        .lr_out(lr_out)
    );


    // Instruction set tracking register.  The decode stage outputs the set
    // for the current instruction and this register feeds the next
    // instruction into the pipeline so that SW instructions take effect.
    assign ifid_set = ifid_set_reg;

    // Determine the instruction set for the next instruction.  A switch (SW)
    // instruction selects a new set; otherwise the current set is preserved.
    wire [3:0] next_ifid_set =
        (ifid_instr[11:8] == `OPC_SW) ? {1'b0, ifid_instr[2:0]} : ifid_set_reg;

    always @(posedge clk or posedge rst) begin
        if (rst)
            ifid_set_reg <= `ISET_R;
        else if (stage2id_en)
            ifid_set_reg <= next_ifid_set;
    end

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
        .sgn_en_out(id_sgn_en),
        .stall_in(stall_signal)
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
        .src_data_in(reg_src_data),
        .tgt_data_in(reg_tgt_data),
        .lr_in(lr_out),
        .flags_in(current_flags),
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
        .sgn_en_out(ex_sgn_en),
        .result_out(ex_result),
        .flags_out(ex_flags),
        .store_data_out(ex_store_data),
        .branch_taken_out(ex_branch_taken)
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
        .result_in(ex_result),
        .store_data_in(ex_store_data),
        .flags_in(ex_flags),
        .mem_addr(data_mem_addr),
        .pc_out(mamo_pc),
        .instr_out(mamo_instr),
        .instr_set_out(mamo_set),
        .result_out(ma_result),
        .flags_out(ma_flags),
        .store_data_out(ma_store_data)
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
        .result_in(ma_result),
        .store_data_in(ma_store_data),
        .flags_in(ma_flags),
        .mem_rdata(data_mem_data),
        .mem_wdata(data_mem_wdata),
        .mem_we(data_mem_we),
        .pc_out(mora_pc),
        .instr_out(mora_instr),
        .instr_set_out(mora_set),
        .result_out(mo_result),
        .flags_out(mo_flags)
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
        .result_in(mo_result),
        .flags_in(mo_flags),
        .pc_out(raro_pc),
        .instr_out(raro_instr),
        .instr_set_out(raro_set),
        .result_out(ra_result),
        .flags_out(ra_flags),
        .reg_waddr_out(ra_reg_waddr)
    );

    // Register operation stage
    stage5ro u_stage5ro(
        .clk(clk),
        .rst(rst),
        .enable_in(stage5ro_en),
        .pc_in(raro_pc),
        .instr_in(raro_instr),
        .instr_set_in(raro_set),
        .result_in(ra_result),
        .flags_in(ra_flags),
        .reg_waddr_in(ra_reg_waddr),
        .pc_out(final_pc),
        .instr_out(final_instr),
        .instr_set_out(final_set),
        .reg_waddr(reg_waddr),
        .reg_wdata(ro_result),
        .reg_we(reg_we),
        .lr_wdata(lr_wdata),
        .lr_we(lr_we),
        .flag_wdata(ro_flags),
        .flag_we(flag_we)
    );

    // Hazard detection unit
    hazardunit u_hazardunit(
        .id_src_gp(id_src_gp),
        .id_tgt_gp(id_tgt_gp),
        .idex_instr(idex_instr),
        .idex_set(idex_set),
        .exma_instr(exma_instr),
        .exma_set(exma_set),
        .mamo_instr(mamo_instr),
        .mamo_set(mamo_set),
        .stall(hazard_stall)
    );
endmodule
