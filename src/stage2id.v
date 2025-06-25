// stage2id.v
`include "src/opcodes.vh"
`define DEFINE_REG_SRC_READ_FN
`define DEFINE_REG_TGT_READ_FN
`include "src/iset.vh"
`undef DEFINE_REG_TGT_READ_FN
`undef DEFINE_REG_SRC_READ_FN
module stage2id(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable_in,
    output wire        enable_out,
    input  wire [11:0] pc_in,
    input  wire [11:0] instr_in,
    input  wire [3:0]  instr_set_in,
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
    // Stall signal from the hazard unit. When asserted, a NOP is
    // inserted instead of the decoded instruction.
    input  wire        stall_in
);
    // Propagate enable to the next stage
    assign enable_out = enable_in;

    // Decode stage: update instruction set when a SW instruction is seen
    wire [3:0] opcode = instr_in[11:8];
    wire [3:0] stage_set = (opcode == `OPC_SW) ? {1'b0, instr_in[2:0]}
                                              : instr_set_in;

    // Replace handled instructions with NOPs
    wire [11:0] forwarded_instr =
        (opcode == `OPC_NOP || opcode == `OPC_SW) ? 12'b0 : instr_in;

    // Decode immediate, register and branch fields
    wire [3:0] bcc_w       = forwarded_instr[7:4];
    wire [3:0] fwd_opcode  = forwarded_instr[11:8];
    wire       use_src     = reg_src_read_fn(stage_set, fwd_opcode);
    wire       use_tgt     = reg_tgt_read_fn(stage_set, fwd_opcode);
    wire [3:0] tgt_gp_w    = (stage_set == `ISET_S || !use_tgt) ? 4'b0 : forwarded_instr[7:4];
    wire [3:0] tgt_sr_w    = (stage_set == `ISET_S) ? forwarded_instr[7:4] : 4'b0;
    wire [3:0] src_gp_w    = (stage_set == `ISET_S || !use_src) ? 4'b0 : forwarded_instr[3:0];
    wire [3:0] src_sr_w    = (stage_set == `ISET_S) ? forwarded_instr[3:0] : 4'b0;
    wire       imm_hilo_w  = forwarded_instr[7];
    wire [5:0] imm_val_w   = forwarded_instr[5:0];
    wire [5:0] off_w       = forwarded_instr[5:0];
    wire       instr_li  = ({stage_set, fwd_opcode} == {`ISET_I,  `OPC_I_Li});
    wire       instr_lis = ({stage_set, fwd_opcode} == {`ISET_IS, `OPC_IS_Lis});
    wire       sgn_en_w  = (stage_set == `ISET_RS) || (stage_set == `ISET_IS);
    wire       imm_en_w  = ((stage_set == `ISET_I) || (stage_set == `ISET_IS)) &&
                           !(instr_li || instr_lis);

    // Latch outputs for the next pipeline stage
    reg [11:0]  pc_latch;
    reg [11:0]  instr_latch;
    reg [3:0]   set_latch;
    reg [3:0]   bcc_latch;
    reg [3:0]   tgt_gp_latch;
    reg [3:0]   tgt_sr_latch;
    reg [3:0]   src_gp_latch;
    reg [3:0]   src_sr_latch;
    reg         imm_en_latch;
    reg         imm_hilo_latch;
    reg [5:0]   imm_val_latch;
    reg [5:0]   off_latch;
    reg         sgn_en_latch;
    

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_latch   <= 12'b0;
            instr_latch <= 12'b0;
            set_latch  <= `ISET_R;
            bcc_latch       <= 4'b0;
            tgt_gp_latch    <= 4'b0;
            tgt_sr_latch    <= 4'b0;
            src_gp_latch    <= 4'b0;
            src_sr_latch    <= 4'b0;
            imm_en_latch    <= 1'b0;
            imm_hilo_latch  <= 1'b0;
            imm_val_latch   <= 6'b0;
            off_latch       <= 6'b0;
            sgn_en_latch    <= 1'b0;
        end else if (enable_in) begin
            if (stall_in) begin
                // Insert a bubble when stalling
                pc_latch       <= pc_in;
                instr_latch    <= 12'b0;
                set_latch      <= stage_set;
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
            end else begin
                pc_latch   <= pc_in;
                instr_latch <= forwarded_instr;
                set_latch  <= stage_set;
                bcc_latch       <= bcc_w;
                tgt_gp_latch    <= tgt_gp_w;
                tgt_sr_latch    <= tgt_sr_w;
                src_gp_latch    <= src_gp_w;
                src_sr_latch    <= src_sr_w;
                imm_en_latch    <= imm_en_w;
                imm_hilo_latch  <= imm_hilo_w;
                imm_val_latch   <= imm_val_w;
                off_latch       <= off_w;
                sgn_en_latch    <= sgn_en_w;
            end
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
endmodule
