// stage3ex.v
`include "src/iset.vh"
`include "src/opcodes.vh"
`include "src/flags.vh"
module stage3ex(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable_in,
    output wire        enable_out,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    input  wire [3:0]  instr_set_in,
    input  wire [3:0]  bcc_in,
    input  wire [3:0]  tgt_gp_in,
    input  wire [3:0]  tgt_sr_in,
    input  wire [3:0]  src_gp_in,
    input  wire [3:0]  src_sr_in,
    input  wire        imm_en_in,
    input  wire        imm_hilo_in,
    input  wire [5:0]  imm_val_in,
    input  wire [5:0]  off_in,
    input  wire        sgn_en_in,
    input  wire [11:0] src_data_in,
    input  wire [11:0] tgt_data_in,
    output wire [11:0] pc_out,
    output wire [11:0] instr_out,
    output wire [3:0]  instr_set_out,
    output wire [3:0]  bcc_out,
    output wire [3:0]  tgt_gp_out,
    output wire [3:0]  tgt_sr_out,
    output wire [3:0]  src_gp_out,
    output wire [3:0]  src_sr_out,
    output wire        imm_en_out,
    output wire        imm_hilo_out,
    output wire [5:0]  imm_val_out,
    output wire [5:0]  off_out,
    output wire        sgn_en_out,
    output wire [11:0] result_out,
    output wire [3:0]  flags_out
);
    // The execute stage currently performs no operations.  The program
    // counter is simply forwarded to the next pipeline stage while the
    // enable signal propagates unchanged.
    assign enable_out = enable_in;

    // Stage output prior to latching.  This is kept as a separate wire so
    // that future execute logic can easily be inserted here.
    wire [11:0] stage_pc   = pc_in;
    wire [3:0]  stage_bcc  = bcc_in;
    wire [3:0]  stage_tgt_gp = tgt_gp_in;
    wire [3:0]  stage_tgt_sr = tgt_sr_in;
    wire [3:0]  stage_src_gp = src_gp_in;
    wire [3:0]  stage_src_sr = src_sr_in;
    wire        stage_imm_en   = imm_en_in;
    wire        stage_imm_hilo = imm_hilo_in;
    wire [5:0]  stage_imm_val  = imm_val_in;
    wire [5:0]  stage_off      = off_in;
    wire        stage_sgn_en   = sgn_en_in;

    // Immediate value expansion
    wire [11:0] imm_ext_tmp  = stage_sgn_en ? {{6{stage_imm_val[5]}}, stage_imm_val}
                                            : {6'b0, stage_imm_val};
    wire [11:0] imm_ext      = stage_imm_hilo ? (imm_ext_tmp << 6) : imm_ext_tmp;

    // ALU instantiation
    wire [11:0] alu_result;
    wire [3:0]  alu_flags;
    alu u_alu(
        .opcode(instr_in[11:8]),
        .src(src_data_in),
        .tgt(tgt_data_in),
        .imm(imm_ext),
        .imm_en(stage_imm_en),
        .sgn_en(stage_sgn_en),
        .result(alu_result),
        .flags(alu_flags)
    );

    // Latch registers between EX and MA stages
    reg [11:0] pc_latch;
    reg [11:0] instr_latch;
    reg [3:0]  set_latch;
    reg [3:0]  bcc_latch;
    reg [3:0]  tgt_gp_latch;
    reg [3:0]  tgt_sr_latch;
    reg [3:0]  src_gp_latch;
    reg [3:0]  src_sr_latch;
    reg        imm_en_latch;
    reg        imm_hilo_latch;
    reg [5:0]  imm_val_latch;
    reg [5:0]  off_latch;
    reg        sgn_en_latch;
    reg [11:0] result_latch;
    reg [3:0]  flags_latch;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_latch       <= 12'b0;
            instr_latch    <= 12'b0;
            set_latch      <= `ISET_R;
            bcc_latch      <= 4'b0;
            tgt_gp_latch   <= 4'b0;
            tgt_sr_latch   <= 4'b0;
            src_gp_latch   <= 4'b0;
            src_sr_latch   <= 4'b0;
            imm_en_latch   <= 1'b0;
            imm_hilo_latch <= 1'b0;
            imm_val_latch  <= 6'b0;
            off_latch      <= 6'b0;
            sgn_en_latch   <= 1'b0;
            result_latch   <= 12'b0;
            flags_latch    <= 4'b0;
        end else if (enable_in) begin
            pc_latch       <= stage_pc;
            instr_latch    <= instr_in;
            set_latch      <= instr_set_in;
            bcc_latch      <= stage_bcc;
            tgt_gp_latch   <= stage_tgt_gp;
            tgt_sr_latch   <= stage_tgt_sr;
            src_gp_latch   <= stage_src_gp;
            src_sr_latch   <= stage_src_sr;
            imm_en_latch   <= stage_imm_en;
            imm_hilo_latch <= stage_imm_hilo;
            imm_val_latch  <= stage_imm_val;
            off_latch      <= stage_off;
            sgn_en_latch   <= stage_sgn_en;
            result_latch   <= alu_result;
            flags_latch    <= alu_flags;
        end
    end

    assign pc_out        = pc_latch;
    assign instr_out     = instr_latch;
    assign instr_set_out = set_latch;
    assign bcc_out       = bcc_latch;
    assign tgt_gp_out    = tgt_gp_latch;
    assign tgt_sr_out    = tgt_sr_latch;
    assign src_gp_out    = src_gp_latch;
    assign src_sr_out    = src_sr_latch;
    assign imm_en_out    = imm_en_latch;
    assign imm_hilo_out  = imm_hilo_latch;
    assign imm_val_out   = imm_val_latch;
    assign off_out       = off_latch;
    assign sgn_en_out    = sgn_en_latch;
    assign result_out    = result_latch;
    assign flags_out     = flags_latch;
endmodule
