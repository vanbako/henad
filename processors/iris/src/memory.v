// Parameter definitions
parameter DATA_WIDTH = 24;
parameter ADDR_WIDTH = 16; // Typically this would be wider

module gw5ast_memory #(
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,

    // AXI-Lite interface for memory transactions
    input  wire axi_awvalid,
    output reg  axi_awready;
    input  wire [ADDR_WIDTH-1:0] axi_awaddr;
    input  wire [2:0] axi_awcache; // Not used here, but required by standard
    input  wire [3:0] axi_awprot;  // Not used here, but required by standard
    input  wire [3:0] axi_awregion; // Not used here, but required by standard
    input  wire [7:0] axi_awlen;   // Not used here, but required by standard
    input  wire [2:0] axi_awsize;  // Not used here, but required by standard
    input  wire [1:0] axi_awburst; // Not used here, but required by standard
    input  wire axi_awlock;
    input  wire [3:0] axi_awqos;   // Not used here, but required by standard
    input  wire [4:0] axi_awuser;  // Not used here, but required by standard

    input  wire axi_wvalid,
    output reg  axi_wready;
    input  wire [DATA_WIDTH-1:0] axi_wdata;
    input  wire [3:0] axi_wstrb;
    input  wire axi_wlast;

    output reg [DATA_WIDTH-1:0] axi_rdata;
    output reg axi_rvalid;
    input  wire axi_rready;
    output reg [1:0] axi_rresp;
    output reg axi_rlast;

    output reg [DATA_WIDTH-1:0] axi_bresp;
    output reg axi_bvalid;
    input  wire axi_bready,

    // Memory interface
    output reg [ADDR_WIDTH-1:0] mem_addr,
    output reg [DATA_WIDTH-1:0] mem_wdata,
    input  wire [DATA_WIDTH-1:0] mem_rdata,
    output reg mem_we,
    output reg [3:0] mem_be,
    output reg mem_ce
);

// AXI states (simplified version; actual implementation may differ)
reg [3:0] state;
parameter IDLE = 4'd0, AWSTATE = 4'd1, WSTATE = 4'd2, BRESP = 4'd3, RSTATE = 4'd4;

// Internal signals
reg [ADDR_WIDTH-1:0] awaddr;
reg wdata;
wire [DATA_WIDTH/8-1:0] wstrb_one_hot;
wire [DATA_WIDTH-1:0] mem_data_out;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        state <= IDLE;
        axi_awready <= 1'b0;
        axi_wready <= 1'b0;
        axi_rvalid <= 1'b0;
        axi_bvalid <= 1'b0;
        mem_addr <= 16'd0;
        mem_wdata <= 24'd0;
        mem_we <= 1'b0;
        mem_be <= 4'd15;
        mem_ce <= 1'b0;
    end else begin
        case (state)
            IDLE:
                if (axi_awvalid) begin
                    state <= AWSTATE;
                    awaddr <= axi_awaddr;
                    axi_awready <= 1'b1;
                end

            AWSTATE:
                if (axi_wvalid && !axi_wlast) begin
                    state <= WSTATE;
                    wdata <= axi_wdata;
                    mem_addr <= awaddr;
                    mem_wdata <= axi_wdata;
                    mem_we <= 1'b0;
                    mem_be <= axi_wstrb;
                    mem_ce <= 1'b1;
                    axi_awready <= 1'b0;
                end else if (axi_wvalid && axi_wlast) begin
                    state <= WSTATE;
                    wdata <= axi_wdata;
                    mem_addr <= awaddr;
                    mem_wdata <= axi_wdata;
                    mem_we <= 1'b0;
                    mem_be <= axi_wstrb;
                    mem_ce <= 1'b1;
                    axi_awready <= 1'b0;
                end

            WSTATE:
                if (axi_wvalid && axi_wlast) begin
                    state <= BRESP;
                    axi_bvalid <= 1'b1;
                    axi_bresp <= 2'd0;
                    mem_ce <= 1'b0; // Deassert memory control
                end else if (axi_wvalid) begin
                    state <= WSTATE;
                    wdata <= axi_wdata;
                    mem_addr <= awaddr;
                    mem_wdata <= axi_wdata;
                    mem_we <= 1'b0;
                    mem_be <= axi_wstrb;
                    mem_ce <= 1'b1;
                end

            BRESP:
                if (axi_bready) begin
                    state <= IDLE;
                    axi_bvalid <= 1'b0;
                    mem_ce <= 1'b0; // Deassert memory control
                end

            RSTATE:
                if (axi_rready && !mem_rdata_valid) begin
                    state <= RSTATE;
                    mem_addr <= axi_awaddr;
                    mem_we <= 1'b0;
                    mem_be <= 4'd15;
                    mem_ce <= 1'b1; // Assert memory control for read
                end else if (axi_rready && mem_rdata_valid) begin
                    state <= RSTATE;
                    axi_rvalid <= 1'b1;
                    axi_rdata <= mem_data_out;
                    axi_rresp <= 2'd0;
                    axi_rlast <= 1'b1;
                    mem_ce <= 1'b0; // Deassert memory control
                end

        endcase

    end
end

// Memory interface signals
assign mem_addr = awaddr;
assign mem_wdata = wdata;
assign mem_we = axi_awvalid & (axi_awburst == 2'd0); // Only single writes supported here
assign mem_be = {4{1'b1}};
assign mem_ce = state != IDLE;

// Memory interface outputs
wire mem_rdata_valid;
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        mem_rdata <= 24'd0;
        mem_rdata_valid <= 1'b0;
    end else begin
        // Simplified model: always output last write data on read
        if (axi_awvalid && axi_wlast) begin
            mem_rdata <= wdata;
            mem_rdata_valid <= 1'b1;
        end else begin
            mem_rdata <= mem_data_out;
            mem_rdata_valid <= mem_we || mem_ce;
        end
    end
end

assign axi_rdata = mem_rdata;

// AXI memory interface
assign axi_wready = state != WSTATE;
assign axi_bresp = 2'd0; // OKAY response on write complete
assign axi_bresp = 2'd2; // EXOKAY on read (not implemented)

endmodule
