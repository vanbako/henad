// alu.v
// Simple ALU for Henad core implementing a subset of operations
`include "src/opcodes.vh"
`include "src/flags.vh"
module alu(
    input  wire [3:0] opcode,
    input  wire [11:0] src,
    input  wire [11:0] tgt,
    input  wire [11:0] imm,
    input  wire        imm_en,
    input  wire        sgn_en,
    output reg  [11:0] result,
    output reg  [3:0]  flags
);
    // internal wires for arithmetic operations
    reg [12:0] calc;
    reg        carry;
    reg        overflow;
    reg [11:0] operand;
    reg [11:0] tgt_op;
    reg [11:0] src_val;
    
    always @* begin
        operand = imm_en ? imm : src;
        tgt_op  = tgt;
        result  = 12'b0;
        carry   = 1'b0;
        overflow = 1'b0;
        src_val = operand;
        case (opcode)
            `OPC_R_MOV, `OPC_I_MOVi, `OPC_IS_MOVis: begin
                result = operand;
            end
            `OPC_R_ADD, `OPC_I_ADDi, `OPC_RS_ADDs, `OPC_IS_ADDis: begin
                calc = tgt_op + operand;
                result = calc[11:0];
                carry = calc[12];
                overflow = (~(tgt_op[11] ^ operand[11]) & (result[11] ^ tgt_op[11]));
            end
            `OPC_R_SUB, `OPC_I_SUBi, `OPC_RS_SUBs, `OPC_IS_SUBis,
            `OPC_R_CMP, `OPC_I_CMPi, `OPC_RS_CMPs, `OPC_IS_CMPis: begin
                calc = tgt_op + (~operand + 12'd1);
                result = calc[11:0];
                carry = calc[12];
                overflow = ((tgt_op[11] ^ operand[11]) & (result[11] ^ tgt_op[11]));
            end
            `OPC_R_NOT: begin
                result = ~tgt_op;
            end
            `OPC_R_AND, `OPC_I_ANDi: begin
                result = tgt_op & operand;
            end
            `OPC_R_OR, `OPC_I_ORi: begin
                result = tgt_op | operand;
            end
            `OPC_R_XOR, `OPC_I_XORi: begin
                result = tgt_op ^ operand;
            end
            `OPC_R_SL, `OPC_I_SLi: begin
                result = tgt_op << operand[3:0];
            end
            `OPC_R_SR, `OPC_I_SRi, `OPC_RS_SRs, `OPC_IS_SRis: begin
                if (sgn_en)
                    result = $signed(tgt_op) >>> operand[3:0];
                else
                    result = tgt_op >> operand[3:0];
            end
            default: begin
                result = 12'b0;
            end
        endcase
        flags[`FLAG_Z] = (result == 12'b0);
        flags[`FLAG_C] = carry;
        flags[`FLAG_N] = result[11];
        flags[`FLAG_V] = overflow;
    end
endmodule
