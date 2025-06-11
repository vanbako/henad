// memdata.v
// Data Memory (4096x12, read-write)
module memdata(
    input wire clk,
    input wire we,
    input wire [11:0] addr,
    input wire [11:0] wdata,
    output reg [11:0] rdata
);
    reg [11:0] mem [0:4095];
    always @(posedge clk) begin
        if (we) mem[addr] <= wdata;
        rdata <= mem[addr];
    end
endmodule
