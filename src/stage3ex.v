// stage3ex.v
`include "src/iset.vh"
`include "src/opcodes.vh"
`include "src/flags.vh"
`include "src/bcc.vh"
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
    // Current value of the link register
    input  wire [11:0] lr_in,
    // Current flag register value for conditional branches
    input  wire [3:0]  flags_in,
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
    output wire [3:0]  flags_out,
    // Data value for store instructions
    output wire [11:0] store_data_out,
    // Asserted when a branch condition is met
    output wire        branch_taken_out
);
    // Propagate the enable signal to the next stage.  For the special
    // halt instruction the pipeline is stalled by clearing the enable
    // line.
    assign enable_out = (instr_in[11:8] == `OPC_S_HLT) ? 1'b0 : enable_in;

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

    // Execution logic (formerly in a separate ALU module)
    reg [11:0] alu_result;
    reg [3:0]  alu_flags;
    reg [12:0] calc;
    reg        carry;
    reg        overflow;
    reg [11:0] operand;
    reg [11:0] tgt_op;
    reg [11:0] store_data;
    reg        branch_taken;
    // Immediate register used by immediate instructions
    reg [11:0] ir_comb;
    reg [11:0] ir_reg;

    always @* begin
        operand       = stage_imm_en ? ir_reg : src_data_in;
        tgt_op        = tgt_data_in;
        alu_result    = 12'b0;
        carry         = 1'b0;
        overflow      = 1'b0;
        store_data    = 12'b0;
        branch_taken  = 1'b0;

        // Combine instruction set and opcode so that opcodes that share the same
        // value across different sets can be uniquely identified.
        // This avoids executing a special set instruction as a register set
        // instruction when the opcode values overlap.
        case ({instr_set_in, instr_in[11:8]})
            {`ISET_R,  `OPC_R_MOV},
            {`ISET_I,  `OPC_I_MOVi},
            {`ISET_IS, `OPC_IS_MOVis}: begin
                alu_result = operand;
            end
            {`ISET_R,  `OPC_R_ADD},
            {`ISET_I,  `OPC_I_ADDi},
            {`ISET_RS, `OPC_RS_ADDs},
            {`ISET_IS, `OPC_IS_ADDis}: begin
                calc       = tgt_op + operand;
                alu_result = calc[11:0];
                carry      = calc[12];
                overflow   = (~(tgt_op[11] ^ operand[11]) & (alu_result[11] ^ tgt_op[11]));
            end
            {`ISET_R,  `OPC_R_SUB},
            {`ISET_I,  `OPC_I_SUBi},
            {`ISET_RS, `OPC_RS_SUBs},
            {`ISET_IS, `OPC_IS_SUBis},
            {`ISET_R,  `OPC_R_CMP},
            {`ISET_I,  `OPC_I_CMPi},
            {`ISET_RS, `OPC_RS_CMPs},
            {`ISET_IS, `OPC_IS_CMPis}: begin
                calc       = tgt_op + (~operand + 12'd1);
                alu_result = calc[11:0];
                carry      = calc[12];
                overflow   = ((tgt_op[11] ^ operand[11]) & (alu_result[11] ^ tgt_op[11]));
            end
            {`ISET_R, `OPC_R_NOT}: begin
                alu_result = ~tgt_op;
            end
            {`ISET_R, `OPC_R_AND},
            {`ISET_I, `OPC_I_ANDi}: begin
                alu_result = tgt_op & operand;
            end
            {`ISET_R, `OPC_R_OR},
            {`ISET_I, `OPC_I_ORi}: begin
                alu_result = tgt_op | operand;
            end
            {`ISET_R, `OPC_R_XOR},
            {`ISET_I, `OPC_I_XORi}: begin
                alu_result = tgt_op ^ operand;
            end
            {`ISET_R, `OPC_R_SL},
            {`ISET_I, `OPC_I_SLi}: begin
                alu_result = tgt_op << operand[3:0];
            end
            {`ISET_R,  `OPC_R_SR},
            {`ISET_I,  `OPC_I_SRi},
            {`ISET_RS, `OPC_RS_SRs},
            {`ISET_IS, `OPC_IS_SRis}: begin
                if (stage_sgn_en)
                    alu_result = $signed(tgt_op) >>> operand[3:0];
                else
                    alu_result = tgt_op >> operand[3:0];
            end
            {`ISET_R,  `OPC_R_BCC}: begin
                // Branch to absolute address in the target register
                case (stage_bcc)
                    `BCC_RA: branch_taken = 1'b1;
                    `BCC_EQ: branch_taken =  flags_in[`FLAG_Z];
                    `BCC_NE: branch_taken = ~flags_in[`FLAG_Z];
                    `BCC_LT: branch_taken =  flags_in[`FLAG_N] ^ flags_in[`FLAG_V];
                    `BCC_GT: branch_taken = (~flags_in[`FLAG_Z]) &&
                                     ~(flags_in[`FLAG_N] ^ flags_in[`FLAG_V]);
                    `BCC_LE: branch_taken =  flags_in[`FLAG_Z] ||
                                     (flags_in[`FLAG_N] ^ flags_in[`FLAG_V]);
                    `BCC_GE: branch_taken = ~(flags_in[`FLAG_N] ^ flags_in[`FLAG_V]);
                    default: branch_taken = 1'b0;
                endcase
                alu_result = branch_taken ? tgt_op : pc_in;
            end
            {`ISET_I,  `OPC_I_BCCi},
            {`ISET_IS, `OPC_IS_BCCis}: begin
                // Branch relative to PC using the signed lower 6 bits of
                // the immediate register
                case (stage_bcc)
                    `BCC_RA: branch_taken = 1'b1;
                    `BCC_EQ: branch_taken =  flags_in[`FLAG_Z];
                    `BCC_NE: branch_taken = ~flags_in[`FLAG_Z];
                    `BCC_LT: branch_taken =  flags_in[`FLAG_N] ^ flags_in[`FLAG_V];
                    `BCC_GT: branch_taken = (~flags_in[`FLAG_Z]) &&
                                     ~(flags_in[`FLAG_N] ^ flags_in[`FLAG_V]);
                    `BCC_LE: branch_taken =  flags_in[`FLAG_Z] ||
                                     (flags_in[`FLAG_N] ^ flags_in[`FLAG_V]);
                    `BCC_GE: branch_taken = ~(flags_in[`FLAG_N] ^ flags_in[`FLAG_V]);
                    default: branch_taken = 1'b0;
                endcase
                if (branch_taken)
                    alu_result = pc_in + {{6{ir_reg[5]}}, ir_reg[5:0]};
                else
                    alu_result = pc_in;
            end
            {`ISET_R, `OPC_R_LD}: begin
                alu_result = src_data_in; // Placeholder load behaviour
            end
            {`ISET_I, `OPC_I_LDi}: begin
                alu_result = src_data_in; // Placeholder immediate load behaviour
            end
            {`ISET_R, `OPC_R_ST}: begin
                alu_result = tgt_op; // Address held in target register
                store_data = src_data_in; // Data to store
            end
            {`ISET_I, `OPC_I_STi}: begin
                alu_result = tgt_op; // Address held in target register
                store_data = ir_reg; // Immediate data
            end
            {`ISET_I,  `OPC_I_Li}: begin
                ir_comb = stage_imm_hilo ? {stage_imm_val, ir_reg[5:0]} : {ir_reg[11:6], stage_imm_val};
            end
            {`ISET_IS, `OPC_IS_Lis}: begin
                ir_comb = {{6{stage_imm_val[5]}}, stage_imm_val};
            end
            {`ISET_S, `OPC_S_SRMOV}: begin
                // Move program counter to a special register (e.g. LR)
                alu_result = pc_in;
            end
            {`ISET_S, `OPC_S_SRBCC}: begin
                case (stage_bcc)
                    `BCC_RA: branch_taken = 1'b1;
                    `BCC_EQ: branch_taken =  flags_in[`FLAG_Z];
                    `BCC_NE: branch_taken = ~flags_in[`FLAG_Z];
                    `BCC_LT: branch_taken =  flags_in[`FLAG_N] ^ flags_in[`FLAG_V];
                    `BCC_GT: branch_taken = (~flags_in[`FLAG_Z]) &&
                                     ~(flags_in[`FLAG_N] ^ flags_in[`FLAG_V]);
                    `BCC_LE: branch_taken =  flags_in[`FLAG_Z] ||
                                     (flags_in[`FLAG_N] ^ flags_in[`FLAG_V]);
                    `BCC_GE: branch_taken = ~(flags_in[`FLAG_N] ^ flags_in[`FLAG_V]);
                    default: branch_taken = 1'b0;
                endcase
                if (branch_taken)
                    alu_result = lr_in + {{6{stage_off[5]}}, stage_off};
                else
                    alu_result = pc_in;
            end
            {`ISET_S, `OPC_S_HLT}: begin
                alu_result = 12'b0;
            end
            default: begin
                alu_result = 12'b0;
            end
        endcase

        alu_flags[`FLAG_Z] = (alu_result == 12'b0);
        alu_flags[`FLAG_C] = carry;
        alu_flags[`FLAG_N] = alu_result[11];
        alu_flags[`FLAG_V] = overflow;
    end

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
    reg [11:0] store_data_latch;
    reg        branch_taken_latch;

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
            store_data_latch <= 12'b0;
            branch_taken_latch <= 1'b0;
            ir_reg <= 12'b0;
            ir_comb <= 12'b0;
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
            store_data_latch <= store_data;
            branch_taken_latch <= branch_taken;
            ir_reg <= ir_comb;
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
    assign store_data_out = store_data_latch;
    assign branch_taken_out = branch_taken_latch;
endmodule
