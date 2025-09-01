// Clean, minimal AXI4-style single-ported RAM for iris GPU

module gw5ast_memory #(
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 16,
    parameter ID_WIDTH   = 4
)(
    input  wire                       clk,
    input  wire                       rst_n,

    // Write address (AW)
    input  wire                       axi_awvalid,
    output reg                        axi_awready,
    input  wire [ADDR_WIDTH-1:0]      axi_awaddr,
    input  wire [ID_WIDTH-1:0]        axi_awid,
    input  wire [7:0]                 axi_awlen,
    input  wire [2:0]                 axi_awsize,
    input  wire [1:0]                 axi_awburst,
    input  wire                       axi_awlock,
    input  wire [3:0]                 axi_awcache,
    input  wire [2:0]                 axi_awprot,
    input  wire [3:0]                 axi_awqos,

    // Write data (W)
    input  wire                       axi_wvalid,
    output reg                        axi_wready,
    input  wire [DATA_WIDTH-1:0]      axi_wdata,
    input  wire [3:0]                 axi_wstrb,
    input  wire                       axi_wlast,

    // Write response (B)
    output reg                        axi_bvalid,
    input  wire                       axi_bready,
    output reg [1:0]                  axi_bresp,
    output reg [ID_WIDTH-1:0]         axi_bid,

    // Read address (AR)
    input  wire                       axi_arvalid,
    output reg                        axi_arready,
    input  wire [ADDR_WIDTH-1:0]      axi_araddr,
    input  wire [ID_WIDTH-1:0]        axi_arid,
    input  wire [7:0]                 axi_arlen,
    input  wire [2:0]                 axi_arsize,
    input  wire [1:0]                 axi_arburst,
    input  wire                       axi_arlock,
    input  wire [3:0]                 axi_arcache,
    input  wire [2:0]                 axi_arprot,
    input  wire [3:0]                 axi_arqos,

    // Read data (R)
    output reg                        axi_rvalid,
    input  wire                       axi_rready,
    output reg [DATA_WIDTH-1:0]       axi_rdata,
    output reg [1:0]                  axi_rresp,
    output reg                        axi_rlast,
    output reg [ID_WIDTH-1:0]         axi_rid
);

    // ---------------------------------------------------------------
    // Simple single-ported memory array (word addressed)
    // ---------------------------------------------------------------
    localparam integer MEM_DEPTH = (1 << ADDR_WIDTH);
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Default constants
    localparam [1:0] RESP_OKAY = 2'b00;

    // ----------------------------
    // Write channel: one outstanding transaction, supports bursts
    // ----------------------------
    reg                       wr_active;
    reg [ADDR_WIDTH-1:0]      wr_addr;
    reg [7:0]                 wr_beats_left; // remaining beats in current burst
    reg [ID_WIDTH-1:0]        wr_id;
    reg [DATA_WIDTH-1:0]      wr_cur;
    reg [DATA_WIDTH-1:0]      wr_new;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_active     <= 1'b0;
            wr_addr       <= {ADDR_WIDTH{1'b0}};
            wr_beats_left <= 8'd0;
            wr_id         <= {ID_WIDTH{1'b0}};

            axi_awready   <= 1'b0;
            axi_wready    <= 1'b0;
            axi_bvalid    <= 1'b0;
            axi_bresp     <= RESP_OKAY;
            axi_bid       <= {ID_WIDTH{1'b0}};
        end else begin
            // Default backpressure
            axi_awready <= (!wr_active) && (!axi_bvalid);
            axi_wready  <= wr_active && (!axi_bvalid);

            // Accept AW only if not in a transaction
            if (axi_awvalid && axi_awready) begin
                wr_active     <= 1'b1;
                wr_addr       <= axi_awaddr;
                wr_beats_left <= axi_awlen + 8'd1; // beats = len+1
                wr_id         <= axi_awid;
            end

            // Consume W beats when active
            if (wr_active && axi_wvalid && axi_wready) begin
                wr_cur = mem[wr_addr];
                wr_new = wr_cur;
                if (axi_wstrb[0]) wr_new[7:0]   = axi_wdata[7:0];
                if (axi_wstrb[1]) wr_new[15:8]  = axi_wdata[15:8];
                if (axi_wstrb[2]) wr_new[23:16] = axi_wdata[23:16];
                mem[wr_addr] <= wr_new;

                // Advance address and beat counter
                wr_addr       <= wr_addr + 1'b1; // word addressing
                if (wr_beats_left != 0)
                    wr_beats_left <= wr_beats_left - 8'd1;

                // When last beat observed, produce B response
                if (axi_wlast || (wr_beats_left == 8'd1)) begin
                    wr_active  <= 1'b0;
                    axi_bvalid <= 1'b1;
                    axi_bresp  <= RESP_OKAY;
                    axi_bid    <= wr_id;
                end
            end

            // Write response handshake
            if (axi_bvalid && axi_bready) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // ----------------------------
    // Read channel: one outstanding transaction, supports bursts
    // ----------------------------
    reg                       rd_active;
    reg [ADDR_WIDTH-1:0]      rd_addr;
    reg [7:0]                 rd_beats_left;
    reg [ID_WIDTH-1:0]        rd_id;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_active     <= 1'b0;
            rd_addr       <= {ADDR_WIDTH{1'b0}};
            rd_beats_left <= 8'd0;
            rd_id         <= {ID_WIDTH{1'b0}};

            axi_arready   <= 1'b0;
            axi_rvalid    <= 1'b0;
            axi_rdata     <= {DATA_WIDTH{1'b0}};
            axi_rresp     <= RESP_OKAY;
            axi_rlast     <= 1'b0;
            axi_rid       <= {ID_WIDTH{1'b0}};
        end else begin
            // Accept AR only if no active read burst and not currently driving R
            axi_arready <= (!rd_active);
            if (axi_arvalid && axi_arready) begin
                rd_active     <= 1'b1;
                rd_addr       <= axi_araddr;
                rd_beats_left <= axi_arlen + 8'd1;
                rd_id         <= axi_arid;
            end

            // Drive R when active and either not valid yet or accepted
            if (rd_active && (!axi_rvalid || (axi_rvalid && axi_rready))) begin
                axi_rdata <= mem[rd_addr];
                axi_rresp <= RESP_OKAY;
                axi_rid   <= rd_id;

                // Determine if this is the last beat
                axi_rlast <= (rd_beats_left == 8'd1);
                axi_rvalid<= 1'b1;

                // Advance for next beat
                rd_addr       <= rd_addr + 1'b1; // word addressing
                if (rd_beats_left != 0)
                    rd_beats_left <= rd_beats_left - 8'd1;

                // If this was the last beat, clear active after handshake
                if (rd_beats_left == 8'd1 && axi_rready) begin
                    rd_active <= 1'b0;
                end
            end

            // After last beat accepted, drop RVALID and RLAST
            if (axi_rvalid && axi_rready) begin
                if (axi_rlast) begin
                    axi_rvalid <= 1'b0;
                    axi_rlast  <= 1'b0;
                end else begin
                    // Keep valid asserted for next beat (handled above)
                end
            end
        end
    end

endmodule
