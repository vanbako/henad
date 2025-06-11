// reggp.v
// General Purpose Register File (16x12)
module reggp(
    input wire clk,
    input wire rst,
    input wire [3:0] raddr1, raddr2, waddr,
    input wire [11:0] wdata,
    input wire we,
    output wire [11:0] rdata1, rdata2
);
    reg [11:0] regs[15:0];
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 16; i = i + 1) regs[i] <= 12'b0;
        end else if (we) begin
            regs[waddr] <= wdata;
        end
    end
    assign rdata1 = regs[raddr1];
    assign rdata2 = regs[raddr2];
endmodule
