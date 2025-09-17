// Simple AXI4 slave that acknowledges transactions and returns zero data.
// Used as a placeholder memory target while integrating external DDR.

module iris_axi_zero_mem #(
    parameter integer ADDR_WIDTH = 48,
    parameter integer DATA_WIDTH = 192,
    parameter integer ID_WIDTH   = 4
)(
    input  wire                       clk,
    input  wire                       rst_n,

    // Write address channel
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

    // Write data channel
    input  wire                       axi_wvalid,
    output reg                        axi_wready,
    input  wire [DATA_WIDTH-1:0]      axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0]  axi_wstrb,
    input  wire                       axi_wlast,

    // Write response channel
    output reg                        axi_bvalid,
    input  wire                       axi_bready,
    output reg [1:0]                  axi_bresp,
    output reg [ID_WIDTH-1:0]         axi_bid,

    // Read address channel
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

    // Read data channel
    output reg                        axi_rvalid,
    input  wire                       axi_rready,
    output reg [DATA_WIDTH-1:0]       axi_rdata,
    output reg [1:0]                  axi_rresp,
    output reg                        axi_rlast,
    output reg [ID_WIDTH-1:0]         axi_rid
);

    localparam [1:0] RESP_OKAY = 2'b00;

    // ------------------------------------------------------------------
    // Write channel: accept address/data immediately, respond zero-latency
    // ------------------------------------------------------------------
    reg [ID_WIDTH-1:0] wr_id_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_awready <= 1'b1;
            axi_wready  <= 1'b1;
            axi_bvalid  <= 1'b0;
            axi_bresp   <= RESP_OKAY;
            axi_bid     <= {ID_WIDTH{1'b0}};
            wr_id_q     <= {ID_WIDTH{1'b0}};
        end else begin
            // Always ready to accept address/data beats
            axi_awready <= !axi_bvalid; // provide minimal backpressure during response
            axi_wready  <= !axi_bvalid;

            if (axi_awvalid && axi_awready)
                wr_id_q <= axi_awid;

            if (axi_wvalid && axi_wready && axi_wlast && !axi_bvalid) begin
                axi_bvalid <= 1'b1;
                axi_bresp  <= RESP_OKAY;
                axi_bid    <= wr_id_q;
            end

            if (axi_bvalid && axi_bready)
                axi_bvalid <= 1'b0;
        end
    end

    // ------------------------------------------------------------------
    // Read channel: return zero data for requested burst length
    // ------------------------------------------------------------------
    reg                        rd_active;
    reg [7:0]                  rd_count;
    reg [ID_WIDTH-1:0]         rd_id_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_arready <= 1'b1;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= {DATA_WIDTH{1'b0}};
            axi_rresp   <= RESP_OKAY;
            axi_rlast   <= 1'b0;
            axi_rid     <= {ID_WIDTH{1'b0}};
            rd_active   <= 1'b0;
            rd_count    <= 8'd0;
            rd_id_q     <= {ID_WIDTH{1'b0}};
        end else begin
            if (!rd_active)
                axi_arready <= 1'b1;

            if (axi_arvalid && axi_arready) begin
                rd_active <= 1'b1;
                rd_id_q   <= axi_arid;
                rd_count  <= axi_arlen;
                axi_arready <= 1'b0;
            end

            if (rd_active) begin
                if (!axi_rvalid || (axi_rvalid && axi_rready)) begin
                    axi_rvalid <= 1'b1;
                    axi_rid    <= rd_id_q;
                    axi_rdata  <= {DATA_WIDTH{1'b0}};
                    axi_rresp  <= RESP_OKAY;
                    axi_rlast  <= (rd_count == 8'd0);

                    if (rd_count == 8'd0) begin
                        rd_active <= 1'b0;
                        axi_arready <= !axi_bvalid; // resume accepting AR once response clear
                    end else begin
                        rd_count <= rd_count - 8'd1;
                    end
                end
            end

            if (axi_rvalid && axi_rready && axi_rlast)
                axi_rvalid <= 1'b0;
        end
    end

endmodule
