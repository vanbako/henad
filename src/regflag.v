// regflag.v
// Flag Register (Zero, Carry, Negative, Overflow)
module regflag(
    input wire clk,
    input wire rst,
    input wire [3:0] flag_in,
    input wire we,
    output reg [3:0] flag_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) flag_out <= 4'b0;
        else if (we) flag_out <= flag_in;
    end
endmodule
