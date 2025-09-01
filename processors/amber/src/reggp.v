`include "src/sizes.vh"

module reggp(
    input wire                   iw_clk,
    input wire                   iw_rst,
    input wire  [`HBIT_TGT_GP:0] iw_read_addr1,
    input wire  [`HBIT_TGT_GP:0] iw_read_addr2,
    input wire  [`HBIT_TGT_GP:0] iw_write_addr,
    input wire  [`HBIT_DATA:0]   iw_write_data,
    input wire                   iw_write_enable,
    output wire [`HBIT_DATA:0]   ow_read_data1,
    output wire [`HBIT_DATA:0]   ow_read_data2
);
    reg [`HBIT_DATA:0] r_gp [0:`HBIT_GP];
    integer i;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            for (i = 0; i <= `HBIT_GP; i = i + 1)
                r_gp[i] <= `SIZE_DATA'b0;
        end else if (iw_write_enable) begin
            r_gp[iw_write_addr] <= iw_write_data;
        end
    end
    assign ow_read_data1 = r_gp[iw_read_addr1];
    assign ow_read_data2 = r_gp[iw_read_addr2];
endmodule