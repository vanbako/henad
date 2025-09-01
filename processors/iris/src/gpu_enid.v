// Iris GPU variant with enid endpoint bridge
// - Instantiates N cores
// - Arbitrates per-core AXI requests onto a single channel
// - Converts AXI-lite single-beat transactions to enid endpoint requests

`include "../../interfaces/enid/src/enid_defs.vh"

module gw5ast_8x24gpu_enid #(
    parameter integer N_CORES    = 8,
    parameter integer DATA_WIDTH = 24,
    parameter integer ADDR_WIDTH = 16,
    parameter integer ID_WIDTH   = 4,
    // Destination module/sub for remote VRAM service
    parameter [(`ENID_MODULE_ID_W-1):0] DEST_MOD = 4'd1,
    parameter [(`ENID_SUB_ID_W-1):0]    DEST_SUB = 2'd0
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
    output wire [DATA_WIDTH-1:0] core_result [N_CORES-1:0],

    // enid Endpoint transaction interface (exposed to parent)
    output wire                         ep_req_valid,
    input  wire                         ep_req_ready,
    output wire [1:0]                   ep_req_type,
    output wire [1:0]                   ep_req_mem_op,
    output wire [`ENID_MODULE_ID_W-1:0] ep_req_dest_mod,
    output wire [`ENID_SUB_ID_W-1:0]    ep_req_dest_sub,
    output wire [`ENID_ADDR_W-1:0]      ep_req_addr,
    output wire [`ENID_LEN_W-1:0]       ep_req_len,
    output wire                         ep_req_wvalid,
    input  wire                         ep_req_wready,
    output wire [31:0]                  ep_req_wdata,
    output wire                         ep_req_wlast,
    input  wire                         ep_rsp_valid,
    output wire                         ep_rsp_ready,
    input  wire [1:0]                   ep_rsp_status,
    input  wire [`ENID_LEN_W-1:0]       ep_rsp_len,
    input  wire                         ep_rsp_rvalid,
    output wire                         ep_rsp_rready,
    input  wire [31:0]                  ep_rsp_rdata,
    input  wire                         ep_rsp_rlast
);

// -----------------------------------------------------------------------------
// Per-core AXI-lite wires
// -----------------------------------------------------------------------------
wire                         mem_axi_awvalid   [0:N_CORES-1];
wire                         mem_axi_awready   [0:N_CORES-1];
wire [ADDR_WIDTH-1:0]        mem_axi_awaddr    [0:N_CORES-1];
wire [ID_WIDTH-1:0]          mem_axi_awid      [0:N_CORES-1];
wire [7:0]                   mem_axi_awlen     [0:N_CORES-1];
wire [2:0]                   mem_axi_awsize    [0:N_CORES-1];
wire [1:0]                   mem_axi_awburst   [0:N_CORES-1];

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

wire                         mem_axi_rvalid    [0:N_CORES-1];
wire                         mem_axi_rready    [0:N_CORES-1];
wire [DATA_WIDTH-1:0]        mem_axi_rdata     [0:N_CORES-1];
wire [1:0]                   mem_axi_rresp     [0:N_CORES-1];
wire                         mem_axi_rlast     [0:N_CORES-1];
wire [ID_WIDTH-1:0]          mem_axi_rid       [0:N_CORES-1];

// Flatten arrays for arbiter ports
function integer idx(input integer i, input integer w); idx = i*w; endfunction

// Concatenate signals for arbiter (1-bit vectors)
wire [N_CORES-1:0]             m_awvalid;
wire [N_CORES-1:0]             m_wvalid;
wire [N_CORES-1:0]             m_arvalid;
wire [N_CORES-1:0]             m_bready;
wire [N_CORES-1:0]             m_rready;

wire [N_CORES*ADDR_WIDTH-1:0]  m_awaddr;
wire [N_CORES*ID_WIDTH-1:0]    m_awid;
wire [N_CORES*8-1:0]           m_awlen;
wire [N_CORES*3-1:0]           m_awsize;
wire [N_CORES*2-1:0]           m_awburst;
wire [N_CORES*DATA_WIDTH-1:0]  m_wdata;
wire [N_CORES*4-1:0]           m_wstrb;
wire [N_CORES-1:0]             m_wlast;
wire [N_CORES*ADDR_WIDTH-1:0]  m_araddr;
wire [N_CORES*ID_WIDTH-1:0]    m_arid;
wire [N_CORES*8-1:0]           m_arlen;
wire [N_CORES*3-1:0]           m_arsize;
wire [N_CORES*2-1:0]           m_arburst;

genvar gi;
generate
    for (gi = 0; gi < N_CORES; gi = gi + 1) begin : pack
        assign m_awvalid[gi] = mem_axi_awvalid[gi];
        assign m_wvalid [gi] = mem_axi_wvalid [gi];
        assign m_arvalid[gi] = mem_axi_arvalid[gi];
        assign m_bready [gi] = mem_axi_bready [gi];
        assign m_rready [gi] = mem_axi_rready [gi];
        assign m_awaddr [gi*ADDR_WIDTH +: ADDR_WIDTH] = mem_axi_awaddr[gi];
        assign m_awid   [gi*ID_WIDTH   +: ID_WIDTH]   = mem_axi_awid[gi];
        assign m_awlen  [gi*8          +: 8]          = mem_axi_awlen[gi];
        assign m_awsize [gi*3          +: 3]          = mem_axi_awsize[gi];
        assign m_awburst[gi*2          +: 2]          = mem_axi_awburst[gi];
        assign m_wdata  [gi*DATA_WIDTH +: DATA_WIDTH] = mem_axi_wdata[gi];
        assign m_wstrb  [gi*4          +: 4]          = mem_axi_wstrb[gi];
        assign m_wlast  [gi]                           = mem_axi_wlast[gi];
        assign m_araddr [gi*ADDR_WIDTH +: ADDR_WIDTH] = mem_axi_araddr[gi];
        assign m_arid   [gi*ID_WIDTH   +: ID_WIDTH]   = mem_axi_arid[gi];
        assign m_arlen  [gi*8          +: 8]          = mem_axi_arlen[gi];
        assign m_arsize [gi*3          +: 3]          = mem_axi_arsize[gi];
        assign m_arburst[gi*2          +: 2]          = mem_axi_arburst[gi];
    end
endgenerate

// Arbiter outputs (single slave view)
wire                        s_awvalid;
wire                        s_awready;
wire [ADDR_WIDTH-1:0]       s_awaddr;
wire [ID_WIDTH-1:0]         s_awid;
wire [7:0]                  s_awlen;
wire [2:0]                  s_awsize;
wire [1:0]                  s_awburst;
wire                        s_wvalid;
wire                        s_wready;
wire [DATA_WIDTH-1:0]       s_wdata;
wire [3:0]                  s_wstrb;
wire                        s_wlast;
wire                        s_bvalid;
wire                        s_bready;
wire [1:0]                  s_bresp;
wire [ID_WIDTH-1:0]         s_bid;
wire                        s_arvalid;
wire                        s_arready;
wire [ADDR_WIDTH-1:0]       s_araddr;
wire [ID_WIDTH-1:0]         s_arid;
wire [7:0]                  s_arlen;
wire [2:0]                  s_arsize;
wire [1:0]                  s_arburst;
wire                        s_rvalid;
wire                        s_rready;
wire [DATA_WIDTH-1:0]       s_rdata;
wire [1:0]                  s_rresp;
wire                        s_rlast;
wire [ID_WIDTH-1:0]         s_rid;

// Arbiter instance
axi_rr_arb #(
    .N(N_CORES), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH)
) u_arb (
    .clk(clk), .rst_n(rst_n),
    .m_awvalid(m_awvalid), .m_awready(m_awready_vec), .m_awaddr(m_awaddr), .m_awid(m_awid), .m_awlen(m_awlen), .m_awsize(m_awsize), .m_awburst(m_awburst),
    .m_wvalid(m_wvalid), .m_wready(m_wready_vec), .m_wdata(m_wdata), .m_wstrb(m_wstrb), .m_wlast(m_wlast),
    .m_bvalid(m_bvalid_vec), .m_bready(m_bready), .m_bresp(m_bresp_vec), .m_bid(m_bid_vec),
    .m_arvalid(m_arvalid), .m_arready(m_arready_vec), .m_araddr(m_araddr), .m_arid(m_arid), .m_arlen(m_arlen), .m_arsize(m_arsize), .m_arburst(m_arburst),
    .m_rvalid(m_rvalid_vec), .m_rready(m_rready), .m_rdata(m_rdata_vec), .m_rresp(m_rresp_vec), .m_rlast(m_rlast_vec), .m_rid(m_rid_vec),
    .s_awvalid(s_awvalid), .s_awready(s_awready), .s_awaddr(s_awaddr), .s_awid(s_awid), .s_awlen(s_awlen), .s_awsize(s_awsize), .s_awburst(s_awburst),
    .s_wvalid(s_wvalid), .s_wready(s_wready), .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wlast(s_wlast),
    .s_bvalid(s_bvalid), .s_bready(s_bready), .s_bresp(s_bresp), .s_bid(s_bid),
    .s_arvalid(s_arvalid), .s_arready(s_arready), .s_araddr(s_araddr), .s_arid(s_arid), .s_arlen(s_arlen), .s_arsize(s_arsize), .s_arburst(s_arburst),
    .s_rvalid(s_rvalid), .s_rready(s_rready), .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rlast(s_rlast), .s_rid(s_rid)
);

// Unpack arbiter outputs back to per-core arrays
wire [N_CORES-1:0]            m_awready_vec;
wire [N_CORES-1:0]            m_wready_vec;
wire [N_CORES-1:0]            m_bvalid_vec;
wire [N_CORES*2-1:0]          m_bresp_vec;
wire [N_CORES*ID_WIDTH-1:0]   m_bid_vec;
wire [N_CORES-1:0]            m_arready_vec;
wire [N_CORES-1:0]            m_rvalid_vec;
wire [N_CORES*DATA_WIDTH-1:0] m_rdata_vec;
wire [N_CORES*2-1:0]          m_rresp_vec;
wire [N_CORES-1:0]            m_rlast_vec;
wire [N_CORES*ID_WIDTH-1:0]   m_rid_vec;

generate
    for (gi = 0; gi < N_CORES; gi = gi + 1) begin : unpack
        assign mem_axi_awready[gi] = m_awready_vec[gi];
        assign mem_axi_wready [gi] = m_wready_vec[gi];
        assign mem_axi_bvalid [gi] = m_bvalid_vec[gi];
        assign mem_axi_bresp  [gi] = m_bresp_vec[gi*2 +: 2];
        assign mem_axi_bid    [gi] = m_bid_vec[gi*ID_WIDTH +: ID_WIDTH];
        assign mem_axi_arready[gi] = m_arready_vec[gi];
        assign mem_axi_rvalid [gi] = m_rvalid_vec[gi];
        assign mem_axi_rdata  [gi] = m_rdata_vec[gi*DATA_WIDTH +: DATA_WIDTH];
        assign mem_axi_rresp  [gi] = m_rresp_vec[gi*2 +: 2];
        assign mem_axi_rlast  [gi] = m_rlast_vec[gi];
        assign mem_axi_rid    [gi] = m_rid_vec[gi*ID_WIDTH +: ID_WIDTH];
    end
endgenerate

// AXI -> enid EP bridge (acts as memory slave)
axi2enid #(
    .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .ID_WIDTH(ID_WIDTH), .DEST_MOD(DEST_MOD), .DEST_SUB(DEST_SUB), .EP_DATA_W(32)
) u_axi2ep (
    .clk(clk), .rst_n(rst_n),
    .s_awvalid(s_awvalid), .s_awready(s_awready), .s_awaddr(s_awaddr), .s_awid(s_awid), .s_awlen(s_awlen), .s_awsize(s_awsize), .s_awburst(s_awburst),
    .s_wvalid(s_wvalid), .s_wready(s_wready), .s_wdata(s_wdata), .s_wstrb(s_wstrb), .s_wlast(s_wlast),
    .s_bvalid(s_bvalid), .s_bready(s_bready), .s_bresp(s_bresp), .s_bid(s_bid),
    .s_arvalid(s_arvalid), .s_arready(s_arready), .s_araddr(s_araddr), .s_arid(s_arid), .s_arlen(s_arlen), .s_arsize(s_arsize), .s_arburst(s_arburst),
    .s_rvalid(s_rvalid), .s_rready(s_rready), .s_rdata(s_rdata), .s_rresp(s_rresp), .s_rlast(s_rlast), .s_rid(s_rid),
    .req_valid(ep_req_valid), .req_ready(ep_req_ready), .req_type(ep_req_type), .req_mem_op(ep_req_mem_op), .req_dest_mod(ep_req_dest_mod), .req_dest_sub(ep_req_dest_sub), .req_addr(ep_req_addr), .req_len(ep_req_len),
    .req_wvalid(ep_req_wvalid), .req_wready(ep_req_wready), .req_wdata(ep_req_wdata), .req_wlast(ep_req_wlast),
    .rsp_valid(ep_rsp_valid), .rsp_ready(ep_rsp_ready), .rsp_status(ep_rsp_status), .rsp_len(ep_rsp_len),
    .rsp_rvalid(ep_rsp_rvalid), .rsp_rready(ep_rsp_rready), .rsp_rdata(ep_rsp_rdata), .rsp_rlast(ep_rsp_rlast)
);

// -----------------------------------------------------------------------------
// Instantiate compute cores
// -----------------------------------------------------------------------------
genvar i;
generate
    for (i = 0; i < N_CORES; i = i + 1) begin : gen_cores
        gw5ast_core #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH),
            .ID_WIDTH  (ID_WIDTH)
        ) u_core (
            .clk(clk), .rst_n(rst_n),
            .axi_valid_in(axi_valid_in[i]),
            .axi_ready_out(axi_ready_out[i]),
            .cmd_write_in(cmd_write_in[i]),
            .cmd_addr_in (cmd_addr_in[i]),
            .cmd_wdata_in(cmd_wdata_in[i]),
            .axi_data_out(axi_data_out[i]),

            // AXI4 master to memory (now routed to arbiter -> enid)
            .axi_awvalid (mem_axi_awvalid[i]),
            .axi_awready (mem_axi_awready[i]),
            .axi_awaddr  (mem_axi_awaddr[i]),
            .axi_awid    (mem_axi_awid[i]),
            .axi_awlen   (mem_axi_awlen[i]),
            .axi_awsize  (mem_axi_awsize[i]),
            .axi_awburst (mem_axi_awburst[i]),

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

            .axi_rvalid  (mem_axi_rvalid[i]),
            .axi_rready  (mem_axi_rready[i]),
            .axi_rdata   (mem_axi_rdata[i]),
            .axi_rresp   (mem_axi_rresp[i]),
            .axi_rlast   (mem_axi_rlast[i]),
            .axi_rid     (mem_axi_rid[i]),

            .result      (core_result[i])
        );
    end
endgenerate

endmodule
