`include "src/sizes.vh"
`include "src/sr.vh"

module regsr(
    input wire                   iw_clk,
    input wire                   iw_rst,
    input wire  [`HBIT_TGT_SR:0] iw_read_addr1,
    input wire  [`HBIT_TGT_SR:0] iw_read_addr2,
    input wire  [`HBIT_TGT_SR:0] iw_write_addr,
    input wire  [`HBIT_ADDR:0]   iw_write_data,
    input wire                   iw_write_enable,
    input wire                   iw_w2_enable,
    input wire  [`HBIT_TGT_SR:0] iw_w2_addr,
    input wire  [`HBIT_ADDR:0]   iw_w2_data,
    output wire [`HBIT_ADDR:0]   ow_read_data1,
    output wire [`HBIT_ADDR:0]   ow_read_data2,
    output wire [`HBIT_ADDR:0]   ow_pstate
);
    reg [`HBIT_ADDR:0] r_sr [0:`HBIT_SR];
    integer i;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            for (i = 0; i <= `HBIT_SR; i = i + 1) begin
                if (i == `SR_IDX_SSP)
                    r_sr[i] <= `SIZE_ADDR'h000000000FFF;
                else
                    r_sr[i] <= {(`HBIT_ADDR+1){1'b0}};
            end
        end else begin
            if (iw_write_enable)
                r_sr[iw_write_addr] <= iw_write_data;
            if (iw_w2_enable)
                r_sr[iw_w2_addr]   <= iw_w2_data;
        end
    end
    assign ow_read_data1 = r_sr[iw_read_addr1];
    assign ow_read_data2 = r_sr[iw_read_addr2];
    assign ow_pstate     = r_sr[`SR_IDX_PSTATE];
endmodule
