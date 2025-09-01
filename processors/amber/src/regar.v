`include "src/sizes.vh"

module regar(
    input wire                   iw_clk,
    input wire                   iw_rst,
    input wire  [`HBIT_TGT_GP:0] iw_read_addr1,
    input wire  [`HBIT_TGT_GP:0] iw_read_addr2,
    input wire  [`HBIT_TGT_GP:0] iw_write_addr,
    input wire  [`HBIT_ADDR:0]   iw_write_data,
    input wire                   iw_write_enable,
    output wire [`HBIT_ADDR:0]   ow_read_data1,
    output wire [`HBIT_ADDR:0]   ow_read_data2
);
    reg [`HBIT_ADDR:0] r_ar [0:`HBIT_AR];
    integer i;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            for (i = 0; i <= `HBIT_AR; i = i + 1) begin
                r_ar[i] <= `SIZE_ADDR'b0;
            end
        end else if (iw_write_enable) begin
            r_ar[iw_write_addr] <= iw_write_data;
        end
    end
    assign ow_read_data1 = r_ar[iw_read_addr1];
    assign ow_read_data2 = r_ar[iw_read_addr2];
endmodule