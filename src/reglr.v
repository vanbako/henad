// reglr.v
// Link Register (12-bit)
module reglr(
    input wire clk,
    input wire rst,
    input wire [11:0] lr_in,
    input wire we,
    output reg [11:0] lr_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) lr_out <= 12'b0;
        else if (we) lr_out <= lr_in;
    end
endmodule
