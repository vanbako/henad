// regir.v
// Immediate Register (12-bit)
module regir(
    input wire clk,
    input wire rst,
    input wire [11:0] ir_in,
    input wire we,
    output reg [11:0] ir_out
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            ir_out <= 12'b0;
        else if (we)
            ir_out <= ir_in;
    end
endmodule
