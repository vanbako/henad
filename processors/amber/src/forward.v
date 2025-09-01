`include "src/sizes.vh"

module forward(
    input wire  [`HBIT_TGT_GP:0] iw_tgt_gp,
    input wire                   iw_tgt_gp_we,
    input wire  [`HBIT_TGT_GP:0] iw_tgt_exma_gp,
    input wire                   iw_tgt_exma_gp_we,
    input wire  [`HBIT_TGT_GP:0] iw_tgt_mamo_gp,
    input wire                   iw_tgt_mamo_gp_we,
    input wire  [`HBIT_TGT_GP:0] iw_tgt_mowb_gp,
    input wire                   iw_tgt_mowb_gp_we,
    input wire  [`HBIT_TGT_SR:0] iw_tgt_sr,
    input wire                   iw_tgt_sr_we,
    input wire  [`HBIT_TGT_SR:0] iw_tgt_exma_sr,
    input wire                   iw_tgt_exma_sr_we,
    input wire  [`HBIT_TGT_SR:0] iw_tgt_mamo_sr,
    input wire                   iw_tgt_mamo_sr_we,
    input wire  [`HBIT_TGT_SR:0] iw_tgt_mowb_sr,
    input wire                   iw_tgt_mowb_sr_we,
    input wire  [`HBIT_SRC_GP:0] iw_src_gp,
    input wire  [`HBIT_SRC_SR:0] iw_src_sr,
    input wire  [`HBIT_DATA:0]   iw_gp_read_data1,
    input wire  [`HBIT_DATA:0]   iw_gp_read_data2,
    input wire  [`HBIT_DATA:0]   iw_sr_read_data1,
    input wire  [`HBIT_DATA:0]   iw_sr_read_data2,
    input wire  [`HBIT_DATA:0]   iw_exma_result,
    input wire  [`HBIT_DATA:0]   iw_mamo_result,
    input wire  [`HBIT_DATA:0]   iw_mowb_result,
    output reg  [`HBIT_DATA:0]   or_src_gp_val,
    output reg  [`HBIT_DATA:0]   or_tgt_gp_val,
    output reg  [`HBIT_DATA:0]   or_src_sr_val,
    output reg  [`HBIT_DATA:0]   or_tgt_sr_val
);
    always @* begin
        if (iw_tgt_exma_gp_we && (iw_tgt_exma_gp == iw_src_gp))
            or_src_gp_val = iw_exma_result;
        else if (iw_tgt_mamo_gp_we && (iw_tgt_mamo_gp == iw_src_gp))
            or_src_gp_val = iw_mamo_result;
        else if (iw_tgt_mowb_gp_we && (iw_tgt_mowb_gp == iw_src_gp))
            or_src_gp_val = iw_mowb_result;
        else
            or_src_gp_val = iw_gp_read_data1;
        if (iw_tgt_exma_gp_we && (iw_tgt_exma_gp == iw_tgt_gp))
            or_tgt_gp_val = iw_exma_result;
        else if (iw_tgt_mamo_gp_we && (iw_tgt_mamo_gp == iw_tgt_gp))
            or_tgt_gp_val = iw_mamo_result;
        else if (iw_tgt_mowb_gp_we && (iw_tgt_mowb_gp == iw_tgt_gp))
            or_tgt_gp_val = iw_mowb_result;
        else
            or_tgt_gp_val = iw_gp_read_data2;
        if (iw_tgt_exma_sr_we && (iw_tgt_exma_sr == iw_src_sr)) begin
            or_src_sr_val = iw_exma_result;
            // $display("EXMA: src_sr=%h result=%h", iw_src_sr, iw_exma_result);
        end
        else if (iw_tgt_mamo_sr_we && (iw_tgt_mamo_sr == iw_src_sr)) begin
            or_src_sr_val = iw_mamo_result;
            // $display("MAMO: src_sr=%h result=%h", iw_src_sr, iw_mamo_result);
        end
        else if (iw_tgt_mowb_sr_we && (iw_tgt_mowb_sr == iw_src_sr)) begin
            or_src_sr_val = iw_mowb_result;
            // $display("MOWB: src_sr=%h result=%h", iw_src_sr, iw_mowb_result);
        end
        else
            or_src_sr_val = iw_sr_read_data1;
        if (iw_tgt_exma_sr_we && (iw_tgt_exma_sr == iw_tgt_sr)) begin
            or_tgt_sr_val = iw_exma_result;
            // $display("EXMA: tgt_sr=%h result=%h", iw_tgt_sr, iw_exma_result);
        end
        else if (iw_tgt_mamo_sr_we && (iw_tgt_mamo_sr == iw_tgt_sr)) begin
            or_tgt_sr_val = iw_mamo_result;
            // $display("MAMO: tgt_sr=%h result=%h", iw_tgt_sr, iw_mamo_result);
        end
        else if (iw_tgt_mowb_sr_we && (iw_tgt_mowb_sr == iw_tgt_sr)) begin
            or_tgt_sr_val = iw_mowb_result;
            // $display("MOWB: tgt_sr=%h result=%h", iw_tgt_sr, iw_mowb_result);
        end
        else
            or_tgt_sr_val = iw_sr_read_data2;
    end
endmodule
