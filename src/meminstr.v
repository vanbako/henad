// meminstr.v
// Instruction Memory (4096x12, read-only)
module meminstr(
    input wire clk,
    input wire [11:0] addr,
    output reg [11:0] data
);
    reg [11:0] mem [0:4095];
    always @(posedge clk) begin
        data <= mem[addr];
    end
    // Memory initialization can be added here
endmodule
