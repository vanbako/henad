// Clean, minimal AXI-Lite style single-ported RAM for iris GPU

module gw5ast_memory #(
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 16
)(
    input  wire                       clk,
    input  wire                       rst_n,

    // Write address (AW)
    input  wire                       axi_awvalid,
    output reg                        axi_awready,
    input  wire [ADDR_WIDTH-1:0]      axi_awaddr,

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

    // Read address (AR)
    input  wire                       axi_arvalid,
    output reg                        axi_arready,
    input  wire [ADDR_WIDTH-1:0]      axi_araddr,

    // Read data (R)
    output reg                        axi_rvalid,
    input  wire                       axi_rready,
    output reg [DATA_WIDTH-1:0]       axi_rdata,
    output reg [1:0]                  axi_rresp,
    output reg                        axi_rlast
);

    // ---------------------------------------------------------------
    // Simple single-ported memory array (word addressed)
    // ---------------------------------------------------------------
    localparam integer MEM_DEPTH = (1 << ADDR_WIDTH);
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Registered write transaction capture
    reg                        have_aw;
    reg                        have_w;
    reg [ADDR_WIDTH-1:0]      wr_addr;
    reg [DATA_WIDTH-1:0]      wr_data;
    reg [3:0]                 wr_strb;

    // Registered read address
    reg [ADDR_WIDTH-1:0]      rd_addr;

    // Default constants
    wire [1:0] RESP_OKAY = 2'b00;

    integer idx;

    // Write address/data handshake and storage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_awready <= 1'b0;
            axi_wready  <= 1'b0;
            axi_bvalid  <= 1'b0;
            axi_bresp   <= RESP_OKAY;
            have_aw     <= 1'b0;
            have_w      <= 1'b0;
            wr_addr     <= {ADDR_WIDTH{1'b0}};
            wr_data     <= {DATA_WIDTH{1'b0}};
            wr_strb     <= 4'b0000;
        end else begin
            // Ready when not issuing a response and slot not filled
            axi_awready <= (!axi_bvalid) && (!have_aw);
            axi_wready  <= (!axi_bvalid) && (!have_w);

            // Capture address
            if (axi_awvalid && axi_awready) begin
                have_aw <= 1'b1;
                wr_addr <= axi_awaddr;
            end

            // Capture data
            if (axi_wvalid && axi_wready) begin
                have_w  <= 1'b1;
                wr_data <= axi_wdata;
                wr_strb <= axi_wstrb;
            end

            // When both captured, perform write and issue response
            if (have_aw && have_w && !axi_bvalid) begin
                // Read-modify-write per strobe (for 24-bit data, ignore strobe[3])
                reg [DATA_WIDTH-1:0] cur;
                reg [DATA_WIDTH-1:0] neww;
                cur = mem[wr_addr];
                neww = cur;
                if (wr_strb[0]) neww[7:0]   = wr_data[7:0];
                if (wr_strb[1]) neww[15:8]  = wr_data[15:8];
                if (wr_strb[2]) neww[23:16] = wr_data[23:16];
                // wr_strb[3] ignored (no 4th byte in 24-bit word)
                mem[wr_addr] <= neww;

                axi_bvalid <= 1'b1;
                axi_bresp  <= RESP_OKAY;
                have_aw    <= 1'b0;
                have_w     <= 1'b0;
            end

            // Complete write response
            if (axi_bvalid && axi_bready) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // Read address handshake and data return
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= {DATA_WIDTH{1'b0}};
            axi_rresp   <= RESP_OKAY;
            axi_rlast   <= 1'b0;
            rd_addr     <= {ADDR_WIDTH{1'b0}};
        end else begin
            // Accept new read when not holding valid data
            axi_arready <= !axi_rvalid;
            if (axi_arvalid && axi_arready) begin
                rd_addr    <= axi_araddr;
                axi_rdata  <= mem[axi_araddr];
                axi_rresp  <= RESP_OKAY;
                axi_rlast  <= 1'b1; // single-beat
                axi_rvalid <= 1'b1;
            end

            if (axi_rvalid && axi_rready) begin
                axi_rvalid <= 1'b0;
                axi_rlast  <= 1'b0;
            end
        end
    end

endmodule
