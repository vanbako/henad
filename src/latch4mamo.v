// latch4mamo.v
// Latch between Memory Address (MA) and Memory Operation (MO) stages
`include "src/iset.vh"
module latch4mamo(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [11:0] instr_in,
    input  wire [3:0]  instr_set_in,
    input  wire [11:0] pc_in,
    output reg  [11:0] instr_out,
    output reg  [3:0]  instr_set_out,
    output reg  [11:0] pc_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            instr_out <= 12'b0;
            instr_set_out <= `ISET_BASE;
            pc_out    <= 12'b0;
        end else if (enable) begin
            instr_out <= instr_in;
            instr_set_out <= instr_set_in;
            pc_out    <= pc_in;
        end
    end
endmodule
