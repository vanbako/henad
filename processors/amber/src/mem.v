`include "src/sizes.vh"

module mem #(
    parameter READ_MEM = 1
)(
    input wire                iw_clk,
    input wire                iw_we [0:1],
    input wire [`HBIT_ADDR:0] iw_addr [0:1],
    input wire [`HBIT_DATA:0] iw_wdata [0:1],
    output reg [`HBIT_DATA:0] or_rdata [0:1]
);
    reg [`HBIT_DATA:0] r_mem [0:4095];
    initial begin
        integer i;
        for (i = 0; i < 4096; i = i + 1)
            r_mem[i] = 24'b0;
        if (READ_MEM)
            $readmemh(`MEM_HEX_FILE, r_mem);
    end
    always @(posedge iw_clk) begin
`ifdef DEBUG_MEM_TB
        if (iw_we[0]) $display("mem wr0 addr=%0d data=%h", iw_addr[0], iw_wdata[0]);
        if (iw_we[1]) $display("mem wr1 addr=%0d data=%h", iw_addr[1], iw_wdata[1]);
`endif
        if (iw_we[0]) begin
            r_mem[iw_addr[0]] <= iw_wdata[0];
            if (iw_addr[0] == iw_addr[1])
                or_rdata[1] <= iw_wdata[0];
            else
                or_rdata[1] <= r_mem[iw_addr[1]];
        end else
            or_rdata[1] <= r_mem[iw_addr[1]];
        if (iw_we[1]) begin
            r_mem[iw_addr[1]] <= iw_wdata[1];
            if (iw_addr[1] == iw_addr[0])
                or_rdata[0] <= iw_wdata[1];
            else
                or_rdata[0] <= r_mem[iw_addr[0]];
        end else
            or_rdata[0] <= r_mem[iw_addr[0]];
    end
endmodule
