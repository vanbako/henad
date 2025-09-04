`include "src/sizes.vh"

module regcsr(
    input  wire                   iw_clk,
    input  wire                   iw_rst,
    // Two combinational read ports for convenience (match forward module style)
    input  wire [`HBIT_TGT_CSR:0] iw_read_addr1,
    input  wire [`HBIT_TGT_CSR:0] iw_read_addr2,
    // Single write port (synchronous)
    input  wire [`HBIT_TGT_CSR:0] iw_write_addr,
    input  wire [`HBIT_DATA:0]    iw_write_data,
    input  wire                   iw_write_enable,
    output wire [`HBIT_DATA:0]    ow_read_data1,
    output wire [`HBIT_DATA:0]    ow_read_data2
);
    // 256 x 24-bit CSRs
    reg [`HBIT_DATA:0] r_csr [0:(1<<(`HBIT_TGT_CSR+1))-1];
    integer i;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            for (i = 0; i < (1<<(`HBIT_TGT_CSR+1)); i = i + 1)
                r_csr[i] <= {(`HBIT_DATA+1){1'b0}};
        end else if (iw_write_enable) begin
            r_csr[iw_write_addr] <= iw_write_data;
        end
    end
    assign ow_read_data1 = r_csr[iw_read_addr1];
    assign ow_read_data2 = r_csr[iw_read_addr2];
endmodule

