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

    // IA stage control
    control1ia u_control1ia(
        .clk(clk),
        .rst(rst),
        .enable_in(stage1ia_en),
        .enable_out(stage1if_en_w),
        .mem_addr(instr_mem_addr),
        .pc_in(ia_pc),
        .pc_out(iaif_pc)
    );

    // IF stage control
    control1if u_control1if(
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
    assign ifid_set = `ISET_BASE;

    // ID stage control
    control2id u_control2id(
        .clk(clk),
        .rst(rst),
        .enable_in(stage2id_en),
        .enable_out(stage3ex_en_w),
        .pc_in(ifid_pc),
        .instr_in(ifid_instr),
        .instr_set_in(ifid_set),
        .pc_out(idex_pc),
        .instr_out(idex_instr),
        .instr_set_out(idex_set)
    );

    // EX stage control
    control3ex u_control3ex(
        .clk(clk),
        .rst(rst),
        .enable_in(stage3ex_en),
        .enable_out(stage4ma_en_w),
        .pc_in(idex_pc),
        .instr_in(idex_instr),
        .instr_set_in(idex_set),
        .pc_out(exma_pc),
        .instr_out(exma_instr),
        .instr_set_out(exma_set)
    );

    // Memory address stage control
    control4ma u_control4ma(
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

    // Memory operation stage control
    control4mo u_control4mo(
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

    // Register address stage control
    control5ra u_control5ra(
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

    // Register operation stage control
    control5ro u_control5ro(
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
