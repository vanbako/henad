module gw5ast_8x24gpu #(
    parameter integer N_CORES    = 8,
    parameter integer DATA_WIDTH = 24,
    parameter integer ADDR_WIDTH = 16,
    parameter integer ID_WIDTH   = 4
)(
    input  wire clk,
    input  wire rst_n,

    // Command interface per core (valid/ready)
    input  wire                  axi_valid_in [N_CORES-1:0],
    output wire                  axi_ready_out[N_CORES-1:0],
    input  wire                  cmd_write_in [N_CORES-1:0],
    input  wire [ADDR_WIDTH-1:0] cmd_addr_in  [N_CORES-1:0],
    input  wire [DATA_WIDTH-1:0] cmd_wdata_in [N_CORES-1:0],

    // Read data response (from reads)
    output wire [DATA_WIDTH-1:0] axi_data_out [N_CORES-1:0],

    // Core results (for observation)
    output wire [DATA_WIDTH-1:0] core_result [N_CORES-1:0]
);

// -----------------------------------------------------------------------------
// Per-core AXI-Lite arrays (core <-> memory)
// -----------------------------------------------------------------------------
wire                         mem_axi_awvalid   [0:N_CORES-1];
wire                         mem_axi_awready   [0:N_CORES-1];
wire [ADDR_WIDTH-1:0]        mem_axi_awaddr    [0:N_CORES-1];
wire [ID_WIDTH-1:0]          mem_axi_awid      [0:N_CORES-1];
wire [7:0]                   mem_axi_awlen     [0:N_CORES-1];
wire [2:0]                   mem_axi_awsize    [0:N_CORES-1];
wire [1:0]                   mem_axi_awburst   [0:N_CORES-1];
wire                         mem_axi_awlock    [0:N_CORES-1];
wire [3:0]                   mem_axi_awcache   [0:N_CORES-1];
wire [2:0]                   mem_axi_awprot    [0:N_CORES-1];
wire [3:0]                   mem_axi_awqos     [0:N_CORES-1];

wire                         mem_axi_wvalid    [0:N_CORES-1];
wire                         mem_axi_wready    [0:N_CORES-1];
wire [DATA_WIDTH-1:0]        mem_axi_wdata     [0:N_CORES-1];
wire [3:0]                   mem_axi_wstrb     [0:N_CORES-1];
wire                         mem_axi_wlast     [0:N_CORES-1];

wire                         mem_axi_bvalid    [0:N_CORES-1];
wire                         mem_axi_bready    [0:N_CORES-1];
wire [1:0]                   mem_axi_bresp     [0:N_CORES-1];
wire [ID_WIDTH-1:0]          mem_axi_bid       [0:N_CORES-1];

wire                         mem_axi_arvalid   [0:N_CORES-1];
wire                         mem_axi_arready   [0:N_CORES-1];
wire [ADDR_WIDTH-1:0]        mem_axi_araddr    [0:N_CORES-1];
wire [ID_WIDTH-1:0]          mem_axi_arid      [0:N_CORES-1];
wire [7:0]                   mem_axi_arlen     [0:N_CORES-1];
wire [2:0]                   mem_axi_arsize    [0:N_CORES-1];
wire [1:0]                   mem_axi_arburst   [0:N_CORES-1];
wire                         mem_axi_arlock    [0:N_CORES-1];
wire [3:0]                   mem_axi_arcache   [0:N_CORES-1];
wire [2:0]                   mem_axi_arprot    [0:N_CORES-1];
wire [3:0]                   mem_axi_arqos     [0:N_CORES-1];

wire                         mem_axi_rvalid    [0:N_CORES-1];
wire                         mem_axi_rready    [0:N_CORES-1];
wire [DATA_WIDTH-1:0]        mem_axi_rdata     [0:N_CORES-1];
wire [1:0]                   mem_axi_rresp     [0:N_CORES-1];
wire                         mem_axi_rlast     [0:N_CORES-1];
wire [ID_WIDTH-1:0]          mem_axi_rid       [0:N_CORES-1];

// -----------------------------------------------------------------------------
// Instantiate compute cores (one per lane)
// -----------------------------------------------------------------------------
genvar i;
generate
    for (i = 0; i < N_CORES; i = i + 1) begin : gen_cores
        gw5ast_core #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .ID_WIDTH  (ID_WIDTH)
        ) u_core (
            .clk(clk),
            .rst_n(rst_n),

            .axi_valid_in(axi_valid_in[i]),
            .axi_ready_out(axi_ready_out[i]),
            .cmd_write_in(cmd_write_in[i]),
            .cmd_addr_in (cmd_addr_in[i]),
            .cmd_wdata_in(cmd_wdata_in[i]),
            .axi_data_out(axi_data_out[i]),

            // AXI4 master to memory
            .axi_awvalid (mem_axi_awvalid[i]),
            .axi_awready (mem_axi_awready[i]),
            .axi_awaddr  (mem_axi_awaddr[i]),
            .axi_awid    (mem_axi_awid[i]),
            .axi_awlen   (mem_axi_awlen[i]),
            .axi_awsize  (mem_axi_awsize[i]),
            .axi_awburst (mem_axi_awburst[i]),
            .axi_awlock  (mem_axi_awlock[i]),
            .axi_awcache (mem_axi_awcache[i]),
            .axi_awprot  (mem_axi_awprot[i]),
            .axi_awqos   (mem_axi_awqos[i]),

            .axi_wvalid  (mem_axi_wvalid[i]),
            .axi_wready  (mem_axi_wready[i]),
            .axi_wdata   (mem_axi_wdata[i]),
            .axi_wstrb   (mem_axi_wstrb[i]),
            .axi_wlast   (mem_axi_wlast[i]),

            .axi_bvalid  (mem_axi_bvalid[i]),
            .axi_bready  (mem_axi_bready[i]),
            .axi_bresp   (mem_axi_bresp[i]),
            .axi_bid     (mem_axi_bid[i]),

            .axi_arvalid (mem_axi_arvalid[i]),
            .axi_arready (mem_axi_arready[i]),
            .axi_araddr  (mem_axi_araddr[i]),
            .axi_arid    (mem_axi_arid[i]),
            .axi_arlen   (mem_axi_arlen[i]),
            .axi_arsize  (mem_axi_arsize[i]),
            .axi_arburst (mem_axi_arburst[i]),
            .axi_arlock  (mem_axi_arlock[i]),
            .axi_arcache (mem_axi_arcache[i]),
            .axi_arprot  (mem_axi_arprot[i]),
            .axi_arqos   (mem_axi_arqos[i]),

            .axi_rvalid  (mem_axi_rvalid[i]),
            .axi_rready  (mem_axi_rready[i]),
            .axi_rdata   (mem_axi_rdata[i]),
            .axi_rresp   (mem_axi_rresp[i]),
            .axi_rlast   (mem_axi_rlast[i]),
            .axi_rid     (mem_axi_rid[i]),

            .result      (core_result[i])
        );

        // Per-core memory instance
        gw5ast_memory #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .ID_WIDTH  (ID_WIDTH)
        ) u_mem (
            .clk(clk),
            .rst_n(rst_n),

            .axi_awvalid(mem_axi_awvalid[i]),
            .axi_awready(mem_axi_awready[i]),
            .axi_awaddr (mem_axi_awaddr[i]),
            .axi_awid   (mem_axi_awid[i]),
            .axi_awlen  (mem_axi_awlen[i]),
            .axi_awsize (mem_axi_awsize[i]),
            .axi_awburst(mem_axi_awburst[i]),
            .axi_awlock (mem_axi_awlock[i]),
            .axi_awcache(mem_axi_awcache[i]),
            .axi_awprot (mem_axi_awprot[i]),
            .axi_awqos  (mem_axi_awqos[i]),

            .axi_wvalid (mem_axi_wvalid[i]),
            .axi_wready (mem_axi_wready[i]),
            .axi_wdata  (mem_axi_wdata[i]),
            .axi_wstrb  (mem_axi_wstrb[i]),
            .axi_wlast  (mem_axi_wlast[i]),

            .axi_bvalid (mem_axi_bvalid[i]),
            .axi_bready (mem_axi_bready[i]),
            .axi_bresp  (mem_axi_bresp[i]),
            .axi_bid    (mem_axi_bid[i]),

            .axi_arvalid(mem_axi_arvalid[i]),
            .axi_arready(mem_axi_arready[i]),
            .axi_araddr (mem_axi_araddr[i]),
            .axi_arid   (mem_axi_arid[i]),
            .axi_arlen  (mem_axi_arlen[i]),
            .axi_arsize (mem_axi_arsize[i]),
            .axi_arburst(mem_axi_arburst[i]),
            .axi_arlock (mem_axi_arlock[i]),
            .axi_arcache(mem_axi_arcache[i]),
            .axi_arprot (mem_axi_arprot[i]),
            .axi_arqos  (mem_axi_arqos[i]),

            .axi_rvalid (mem_axi_rvalid[i]),
            .axi_rready (mem_axi_rready[i]),
            .axi_rdata  (mem_axi_rdata[i]),
            .axi_rresp  (mem_axi_rresp[i]),
            .axi_rlast  (mem_axi_rlast[i]),
            .axi_rid    (mem_axi_rid[i])
        );
    end
endgenerate

endmodule
