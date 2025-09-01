`include "src/sizes.vh"

module stg_if(
    input wire                 iw_clk,
    input wire                 iw_rst,
    input wire  [`HBIT_DATA:0] iw_mem_data [0:1],
    input wire                 iw_ia_valid,
    input wire  [`HBIT_ADDR:0] iw_pc,
    output wire [`HBIT_ADDR:0] ow_pc,
    output wire [`HBIT_DATA:0] ow_instr,
    input wire                 iw_flush,
    input wire                 iw_stall
);
    reg [`HBIT_ADDR:0] r_pc_latch;
    reg [`HBIT_DATA:0] r_instr_latch;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_flush) begin
            r_pc_latch    <= `SIZE_ADDR'b0;
            r_instr_latch <= `SIZE_DATA'b0;
        end else if (iw_stall) begin
            r_pc_latch    <= r_pc_latch;
            r_instr_latch <= r_instr_latch;
        end else if (iw_ia_valid) begin
            r_pc_latch    <= iw_pc;
            r_instr_latch <= iw_mem_data[0];
        end else begin
            r_pc_latch    <= `SIZE_ADDR'b0;
            r_instr_latch <= `SIZE_DATA'b0;
        end
    end
    assign ow_pc    = r_pc_latch;
    assign ow_instr = r_instr_latch;
endmodule
