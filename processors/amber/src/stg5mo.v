`include "src/sizes.vh"
`include "src/opcodes.vh"

module stg_mo(
    input wire                   iw_clk,
    input wire                   iw_rst,
    input wire  [`HBIT_ADDR:0]   iw_pc,
    output wire [`HBIT_ADDR:0]   ow_pc,
    input wire  [`HBIT_DATA:0]   iw_instr,
    output wire [`HBIT_DATA:0]   ow_instr,
    input wire  [`HBIT_OPC:0]    iw_opc,
    output wire [`HBIT_OPC:0]    ow_opc,
    input wire  [`HBIT_TGT_GP:0] iw_tgt_gp,
    input wire                   iw_tgt_gp_we,
    output wire [`HBIT_TGT_GP:0] ow_tgt_gp,
    output wire                  ow_tgt_gp_we,
    input wire  [`HBIT_TGT_SR:0] iw_tgt_sr,
    input wire                   iw_tgt_sr_we,
    output wire [`HBIT_TGT_SR:0] ow_tgt_sr,
    output wire                  ow_tgt_sr_we,
    input wire  [`HBIT_TGT_AR:0] iw_tgt_ar,
    input wire                   iw_tgt_ar_we,
    output wire [`HBIT_TGT_AR:0] ow_tgt_ar,
    output wire                  ow_tgt_ar_we,
    input wire                   iw_mem_mp,
    output reg                   ow_mem_we [0:1],
    output reg  [`HBIT_DATA:0]   ow_mem_wdata [0:1],
    input wire  [`HBIT_DATA:0]   iw_mem_rdata [0:1],
    input wire  [`HBIT_DATA:0]   iw_result,
    output wire [`HBIT_DATA:0]   ow_result,
    input wire  [`HBIT_ADDR:0]   iw_ar_result,
    output wire [`HBIT_ADDR:0]   ow_ar_result
);
    reg [`HBIT_DATA:0] r_result;
    always @(*) begin
        ow_mem_we[0] = 1'b0;
        ow_mem_we[1] = 1'b0;
        ow_mem_wdata[0] = `SIZE_DATA'b0;
        ow_mem_wdata[1] = `SIZE_DATA'b0;
        r_result = iw_result;
        case (iw_opc)
            `OPC_LDur, `OPC_LDso, `OPC_SRLDso: begin
                r_result = iw_mem_rdata[iw_mem_mp];
            end
            `OPC_STur, `OPC_STso, `OPC_STui, `OPC_STsi, `OPC_SRSTso: begin
                ow_mem_we[iw_mem_mp] = 1'b1;
                ow_mem_wdata[iw_mem_mp] = iw_result;
            end
        endcase
    end
    reg [`HBIT_ADDR:0]   r_pc_latch;
    reg [`HBIT_DATA:0]   r_instr_latch;
    reg [`HBIT_OPC:0]    r_opc_latch;
    reg [`HBIT_TGT_GP:0] r_tgt_gp_latch;
    reg                  r_tgt_gp_we_latch;
    reg [`HBIT_TGT_SR:0] r_tgt_sr_latch;
    reg                  r_tgt_sr_we_latch;
    reg [`HBIT_TGT_AR:0] r_tgt_ar_latch;
    reg                  r_tgt_ar_we_latch;
    reg [`HBIT_DATA:0]   r_result_latch;
    reg [`HBIT_ADDR:0]   r_ar_result_latch;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_pc_latch        <= `SIZE_ADDR'b0;
            r_instr_latch     <= `SIZE_DATA'b0;
            r_opc_latch       <= `SIZE_OPC'b0;
            r_tgt_gp_latch    <= `SIZE_TGT_GP'b0;
            r_tgt_gp_we_latch <= 1'b0;
            r_tgt_sr_latch    <= `SIZE_TGT_SR'b0;
            r_tgt_sr_we_latch <= 1'b0;
            r_tgt_ar_latch    <= `SIZE_TGT_AR'b0;
            r_tgt_ar_we_latch <= 1'b0;
            r_result_latch    <= `SIZE_DATA'b0;
            r_ar_result_latch <= `SIZE_ADDR'b0;
        end
        else begin
            r_pc_latch        <= iw_pc;
            r_instr_latch     <= iw_instr;
            r_opc_latch       <= iw_opc;
            r_tgt_gp_latch    <= iw_tgt_gp;
            r_tgt_gp_we_latch <= iw_tgt_gp_we;
            r_tgt_sr_latch    <= iw_tgt_sr;
            r_tgt_sr_we_latch <= iw_tgt_sr_we;
            r_tgt_ar_latch    <= iw_tgt_ar;
            r_tgt_ar_we_latch <= iw_tgt_ar_we;
            r_result_latch    <= r_result;
            r_ar_result_latch <= iw_ar_result;
        end
    end
    assign ow_pc        = r_pc_latch;
    assign ow_instr     = r_instr_latch;
    assign ow_opc       = r_opc_latch;
    assign ow_tgt_gp    = r_tgt_gp_latch;
    assign ow_tgt_gp_we = r_tgt_gp_we_latch;
    assign ow_tgt_sr    = r_tgt_sr_latch;
    assign ow_tgt_sr_we = r_tgt_sr_we_latch;
    assign ow_tgt_ar    = r_tgt_ar_latch;
    assign ow_tgt_ar_we = r_tgt_ar_we_latch;
    assign ow_result    = r_result_latch;
    assign ow_ar_result = r_ar_result_latch;
endmodule
