// latch1ifid.v
module latch1ifid(
    input wire clk,
    input wire rst,
    input wire enable,
    input wire [11:0] instr_in,
    input wire [11:0] pc_in,
    output reg [11:0] instr_out,
    output reg [11:0] pc_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            instr_out <= 12'b0;
            pc_out <= 12'b0;
        end else if (enable) begin
            instr_out <= instr_in;
            pc_out <= pc_in;
        end
    end
endmodule
