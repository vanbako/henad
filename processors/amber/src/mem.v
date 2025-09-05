`include "src/sizes.vh"

// Dual-port memory with 24-bit storage words and 24/48-bit access mode.
//
// Port [0] and [1] map to the alternating MA/MO usage controlled by
// r_mem_mp_latch in the MA stage:
// - r_mem_mp_latch toggles 0/1 every cycle (when not in reset).
// - In cycle N:     MA drives ow_mem_addr[~r_mem_mp_latch] to set the base
//                   address for the next cycle.
// - In the same cycle N: MO uses port [r_mem_mp_latch] to read/write using
//                   that base address set in the previous cycle.
//
// 48-bit accesses are handled inside this memory by splitting/combining two
// adjacent 24-bit words at {addr, addr+1} (little-endian: low at addr,
// high at addr+1). Only the selected port performs the 48-bit operation;
// the opposite port remains free for the MA stage to prepare the next base.
module mem #(
    parameter READ_MEM = 1
)(
    input wire                iw_clk,
    input wire                iw_we [0:1],
    input wire [`HBIT_ADDR:0] iw_addr [0:1],
    // 48-bit wide data buses for convenience; low 24 bits are stored at addr,
    // high 24 bits at addr+1 when 48-bit mode is selected.
    input wire [`HBIT_ADDR:0] iw_wdata [0:1],
    input wire                iw_is48  [0:1], // 0=24-bit, 1=48-bit per port
    output reg [`HBIT_ADDR:0] or_rdata [0:1]
);
    reg [`HBIT_DATA:0] r_mem [0:4095];
    // Optional plusarg file name for runtime program load: +HEX=<path>
    reg [1023:0] plusarg_hex_file;
    initial begin
        integer i;
        for (i = 0; i < 4096; i = i + 1)
            r_mem[i] = 24'b0;
`ifdef MEM_HEX_FILE
        if (READ_MEM)
            $readmemh(`MEM_HEX_FILE, r_mem);
`else
        // If no compile-time MEM_HEX_FILE was provided, allow runtime plusarg:
        // vvp ... +HEX=path/to/file.hex
        if (READ_MEM) begin
            if ($value$plusargs("HEX=%s", plusarg_hex_file)) begin
                $display("[mem] Loading program from +HEX=%0s", plusarg_hex_file);
                $readmemh(plusarg_hex_file, r_mem);
            end
        end
`endif
    end
    // Read path with cross-port forwarding (supports 24/48-bit).
    // Little-endian: {hi, lo} = {mem[addr+1], mem[addr]}
    reg [`HBIT_DATA:0] rd0_lo, rd0_hi, rd1_lo, rd1_hi;
    reg [`HBIT_ADDR:0] rdata0_mux, rdata1_mux;
    always @* begin
        // Base reads
        rd0_lo = r_mem[iw_addr[0]];
        rd0_hi = r_mem[iw_addr[0] + 1'b1];
        rd1_lo = r_mem[iw_addr[1]];
        rd1_hi = r_mem[iw_addr[1] + 1'b1];

        // Cross-port forwarding from port 1 -> port 0
        if (iw_we[1]) begin
            if (iw_is48[1]) begin
                if (iw_addr[0] == iw_addr[1])           rd0_lo = iw_wdata[1][23:0];
                if (iw_addr[0] == (iw_addr[1] + 1'b1))  rd0_lo = iw_wdata[1][47:24];
                if ((iw_addr[0] + 1'b1) == iw_addr[1])           rd0_hi = iw_wdata[1][23:0];
                if ((iw_addr[0] + 1'b1) == (iw_addr[1] + 1'b1))  rd0_hi = iw_wdata[1][47:24];
            end else begin
                if (iw_addr[0] == iw_addr[1])           rd0_lo = iw_wdata[1][23:0];
                if ((iw_addr[0] + 1'b1) == iw_addr[1])  rd0_hi = iw_wdata[1][23:0];
            end
        end
        // Cross-port forwarding from port 0 -> port 1
        if (iw_we[0]) begin
            if (iw_is48[0]) begin
                if (iw_addr[1] == iw_addr[0])           rd1_lo = iw_wdata[0][23:0];
                if (iw_addr[1] == (iw_addr[0] + 1'b1))  rd1_lo = iw_wdata[0][47:24];
                if ((iw_addr[1] + 1'b1) == iw_addr[0])           rd1_hi = iw_wdata[0][23:0];
                if ((iw_addr[1] + 1'b1) == (iw_addr[0] + 1'b1))  rd1_hi = iw_wdata[0][47:24];
            end else begin
                if (iw_addr[1] == iw_addr[0])           rd1_lo = iw_wdata[0][23:0];
                if ((iw_addr[1] + 1'b1) == iw_addr[0])  rd1_hi = iw_wdata[0][23:0];
            end
        end

        // Pack outputs according to access width requested for each port
        rdata0_mux = iw_is48[0] ? {rd0_hi, rd0_lo} : {24'b0, rd0_lo};
        rdata1_mux = iw_is48[1] ? {rd1_hi, rd1_lo} : {24'b0, rd1_lo};
    end
    always @(posedge iw_clk) begin
`ifdef DEBUG_MEM_TB
        if (iw_we[0]) $display("mem wr0 addr=%0d data=%h (is48=%0d)", iw_addr[0], iw_wdata[0], iw_is48[0]);
        if (iw_we[1]) $display("mem wr1 addr=%0d data=%h (is48=%0d)", iw_addr[1], iw_wdata[1], iw_is48[1]);
`endif
        // Registered read outputs with forwarding
        or_rdata[0] <= rdata0_mux;
        or_rdata[1] <= rdata1_mux;
        // Writes
        if (iw_we[0]) begin
            r_mem[iw_addr[0]] <= iw_wdata[0][23:0];
            if (iw_is48[0]) r_mem[iw_addr[0] + 1'b1] <= iw_wdata[0][47:24];
        end
        if (iw_we[1]) begin
            r_mem[iw_addr[1]] <= iw_wdata[1][23:0];
            if (iw_is48[1]) r_mem[iw_addr[1] + 1'b1] <= iw_wdata[1][47:24];
        end
    end
endmodule
