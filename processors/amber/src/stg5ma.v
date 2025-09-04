`include "src/sizes.vh"
`include "src/opcodes.vh"

module stg_ma(
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
    output wire                  ow_mem_mp,
    output reg  [`HBIT_ADDR:0]   ow_mem_addr [0:1],
    input wire  [`HBIT_ADDR:0]   iw_addr,
    input wire  [`HBIT_DATA:0]   iw_result,
    output wire [`HBIT_DATA:0]   ow_result,
    input wire  [`HBIT_ADDR:0]   iw_sr_result,
    output wire [`HBIT_ADDR:0]   ow_sr_result,
    input wire  [`HBIT_ADDR:0]   iw_ar_result,
    output wire [`HBIT_ADDR:0]   ow_ar_result
);
    reg [`HBIT_ADDR:0]   r_pc_latch;
    reg [`HBIT_DATA:0]   r_instr_latch;
    reg [`HBIT_OPC:0]    r_opc_latch;
    reg [`HBIT_TGT_GP:0] r_tgt_gp_latch;
    reg                  r_tgt_gp_we_latch;
    reg [`HBIT_TGT_SR:0] r_tgt_sr_latch;
    reg                  r_tgt_sr_we_latch;
    reg [`HBIT_TGT_AR:0] r_tgt_ar_latch;
    reg                  r_tgt_ar_we_latch;
    // r_mem_mp_latch: Memory port multiplexer bit
    //
    // This bit toggles every cycle (when not in reset). MA uses the opposite
    // port index (~r_mem_mp_latch) to present the address for the next cycle,
    // while MO uses r_mem_mp_latch in the current cycle. This way MO always
    // reads/writes the address set by MA in the previous cycle.
    reg                  r_mem_mp_latch;
    reg [`HBIT_DATA:0]   r_result_latch;
    reg [`HBIT_ADDR:0]   r_sr_result_latch;
    reg [`HBIT_ADDR:0]   r_ar_result_latch;
    always @(*) begin
        // Address driving policy for the dual-port memory
        // MA always drives only the port opposite to MO so the address is
        // held for MO in the next cycle, regardless of 24/48-bit width.
        if (r_mem_mp_latch)
            ow_mem_addr[0] = iw_addr;
        else
            ow_mem_addr[1] = iw_addr;
    end
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
            r_mem_mp_latch    <= 1'b0; // start with MA driving [1], MO uses [0]
            r_result_latch    <= `SIZE_DATA'b0;
            r_sr_result_latch <= `SIZE_ADDR'b0;
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
            // Toggle each cycle so MA/MO alternate [0]/[1]
            r_mem_mp_latch    <= ~r_mem_mp_latch;
            r_result_latch    <= iw_result;
            r_sr_result_latch <= iw_sr_result;
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
    // MO uses r_mem_mp_latch to select its port; MA uses ~r_mem_mp_latch.
    assign ow_mem_mp    = r_mem_mp_latch;
    assign ow_result    = r_result_latch;
    assign ow_sr_result = r_sr_result_latch;
    assign ow_ar_result = r_ar_result_latch;
endmodule
