// Minimal AXI-like read refill bridge (24-bit data) for Amber caches.
//
// Purpose: Convert per-beat cache refill requests (one 24-bit word at a time)
// into AXI read transactions toward an external DDR (e.g., Tang Mega 60K DDR3).
// This version issues single-beat reads (ARLEN=0), simplifying integration.
// A future enhancement can coalesce 16 requests into a burst.

module amber_refill_axi24 (
    input  wire         clk,
    input  wire         rst,

    // I-cache beat request
    input  wire         ic_req,
    input  wire [47:0]  ic_addr,   // word address (24-bit word indexing)
    output reg          ic_valid,
    output reg  [47:0]  ic_rdata,  // {24'b0, data24}

    // D-cache beat request
    input  wire         dc_req,
    input  wire [47:0]  dc_addr,
    output reg          dc_valid,
    output reg  [47:0]  dc_rdata,

    // AXI-like read address channel (word-addressed, 24-bit data)
    output reg          axi_arvalid,
    input  wire         axi_arready,
    output reg  [31:0]  axi_araddr,
    output reg  [7:0]   axi_arlen,
    output reg  [2:0]   axi_arsize,
    output reg  [1:0]   axi_arburst,
    output reg  [3:0]   axi_arcache,
    output reg  [2:0]   axi_arprot,
    output reg  [3:0]   axi_arqos,
    output reg  [3:0]   axi_arid,

    // AXI-like read data channel
    input  wire         axi_rvalid,
    output reg          axi_rready,
    input  wire [23:0]  axi_rdata,
    input  wire         axi_rlast,
    input  wire [1:0]   axi_rresp,
    input  wire [3:0]   axi_rid
);
    // Simple two-source arbiter: prefer I-cache, then D-cache
    localparam CH_IC = 1'b0;
    localparam CH_DC = 1'b1;
    reg cur_ch;       // channel being serviced
    reg busy;         // outstanding read in flight
    reg [47:0] lat_addr;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            axi_arvalid <= 1'b0;
            axi_araddr  <= 32'd0;
            axi_arlen   <= 8'd0;       // single-beat
            axi_arsize  <= 3'd0;       // ignored by gw5ast_memory
            axi_arburst <= 2'b01;      // INCR
            axi_arcache <= 4'd0;
            axi_arprot  <= 3'd0;
            axi_arqos   <= 4'd0;
            axi_arid    <= 4'd0;

            axi_rready  <= 1'b1;       // always ready to accept data

            ic_valid    <= 1'b0;
            ic_rdata    <= 48'd0;
            dc_valid    <= 1'b0;
            dc_rdata    <= 48'd0;

            busy        <= 1'b0;
            cur_ch      <= CH_IC;
            lat_addr    <= 48'd0;
        end else begin
            // Defaults
            ic_valid   <= 1'b0;
            dc_valid   <= 1'b0;

            // Launch a new read when not busy
            if (!busy) begin
                if (ic_req) begin
                    cur_ch      <= CH_IC;
                    lat_addr    <= ic_addr;
                    axi_araddr  <= ic_addr[31:0];
                    axi_arvalid <= 1'b1;
                    busy        <= axi_arready; // if accepted immediately
                end else if (dc_req) begin
                    cur_ch      <= CH_DC;
                    lat_addr    <= dc_addr;
                    axi_araddr  <= dc_addr[31:0];
                    axi_arvalid <= 1'b1;
                    busy        <= axi_arready;
                end
            end else begin
                // Wait for AR handshake completion
                if (axi_arvalid && axi_arready) begin
                    axi_arvalid <= 1'b0;
                end
            end

            // Read data handling
            if (axi_rvalid) begin
                if (cur_ch == CH_IC) begin
                    ic_rdata <= {24'b0, axi_rdata};
                    ic_valid <= 1'b1;
                end else begin
                    dc_rdata <= {24'b0, axi_rdata};
                    dc_valid <= 1'b1;
                end
                // Single-beat read completes on first RVALID
                busy <= 1'b0;
            end
        end
    end
endmodule

