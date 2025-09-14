`include "src/sizes.vh"
`include "src/opcodes.vh"

module hazard(
    input wire                  iw_clk,
    input wire                  iw_rst,
    input wire [`HBIT_OPC:0]    iw_idex_opc,
    output wire                 ow_stall
);
    reg [2:0] r_cnt;
    // Stall on all memory operations that interact with data memory.
    // Policy: no memory-result forwarding; hold the front of the pipeline
    // for a fixed number of cycles regardless of following instructions.
    wire hazard = (
        // Loads
        (iw_idex_opc == `OPC_SRLDso) || (iw_idex_opc == `OPC_LDcso) ||
        // Stores
        (iw_idex_opc == `OPC_STui)   || (iw_idex_opc == `OPC_STsi)  ||
        (iw_idex_opc == `OPC_STcso)  || (iw_idex_opc == `OPC_SRSTso)
    );
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_cnt <= 3'b000;
        end else if (r_cnt != 3'b000) begin
            r_cnt <= r_cnt - 3'b001;
        end else if (hazard) begin
            // $display("HAZARD: Hazard detected, stalling for 3 cycles");
            r_cnt <= 3'b011;
        end
    end
    assign ow_stall = (r_cnt != 3'b000);
endmodule
