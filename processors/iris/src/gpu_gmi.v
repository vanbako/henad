// Iris 8x24 GPU using custom GMI + enid endpoint
`include "../../interfaces/enid/src/enid_defs.vh"
`include "gmi_defs.vh"

module gw5ast_8x24gpu_gmi #(
    parameter integer N_CORES    = 8,
    parameter integer DATA_WIDTH = `GMI_DATA_W,
    parameter integer ADDR_WIDTH = `GMI_ADDR_W,
    parameter [(`ENID_MODULE_ID_W-1):0] DEST_MOD = 4'd1,
    parameter [(`ENID_SUB_ID_W-1):0]    DEST_SUB = 2'd0
)(
    input  wire clk,
    input  wire rst_n,

    // Command interface per core (valid/ready)
    input  wire                  cmd_valid_in [N_CORES-1:0],
    output wire                  cmd_ready_out[N_CORES-1:0],
    input  wire                  cmd_write_in [N_CORES-1:0],
    input  wire [ADDR_WIDTH-1:0] cmd_addr_in  [N_CORES-1:0],
    input  wire [DATA_WIDTH-1:0] cmd_wdata_in [N_CORES-1:0],

    // Read data response
    output wire [DATA_WIDTH-1:0] data_out     [N_CORES-1:0],

    // Core results (for observation)
    output wire [DATA_WIDTH-1:0] core_result  [N_CORES-1:0],

    // enid Endpoint transaction interface (to parent)
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
// Per-core GMI signals
// -----------------------------------------------------------------------------
wire                         gmi_req_valid   [0:N_CORES-1];
wire                         gmi_req_ready   [0:N_CORES-1];
wire                         gmi_req_write   [0:N_CORES-1];
wire [ADDR_WIDTH-1:0]        gmi_req_addr    [0:N_CORES-1];
wire [DATA_WIDTH-1:0]        gmi_req_wdata   [0:N_CORES-1];

wire                         gmi_rsp_valid   [0:N_CORES-1];
wire [1:0]                   gmi_rsp_status  [0:N_CORES-1];
wire [DATA_WIDTH-1:0]        gmi_rsp_rdata   [0:N_CORES-1];
wire                         gmi_rsp_ready   [0:N_CORES-1];

// -----------------------------------------------------------------------------
// Instantiate compute cores (GMI)
// -----------------------------------------------------------------------------
genvar i;
generate
    for (i = 0; i < N_CORES; i = i + 1) begin : gen_cores
        gw5ast_core_gmi #(
            .DATA_WIDTH(DATA_WIDTH),
            .ADDR_WIDTH(ADDR_WIDTH)
        ) u_core (
            .clk(clk), .rst_n(rst_n),
            .cmd_valid(cmd_valid_in[i]),
            .cmd_ready(cmd_ready_out[i]),
            .cmd_write(cmd_write_in[i]),
            .cmd_addr (cmd_addr_in[i]),
            .cmd_wdata(cmd_wdata_in[i]),
            .cmd_rdata(data_out[i]),
            .gmi_req_valid(gmi_req_valid[i]),
            .gmi_req_ready(gmi_req_ready[i]),
            .gmi_req_write(gmi_req_write[i]),
            .gmi_req_addr (gmi_req_addr[i]),
            .gmi_req_wdata(gmi_req_wdata[i]),
            .gmi_rsp_valid(gmi_rsp_valid[i]),
            .gmi_rsp_status(gmi_rsp_status[i]),
            .gmi_rsp_rdata (gmi_rsp_rdata[i]),
            .gmi_rsp_ready (gmi_rsp_ready[i]),
            .result(core_result[i])
        );
    end
endgenerate

// -----------------------------------------------------------------------------
// Flatten to arbiter
// -----------------------------------------------------------------------------
wire [N_CORES-1:0]             m_req_valid;
wire [N_CORES-1:0]             m_req_ready;
wire [N_CORES-1:0]             m_req_write;
wire [N_CORES*ADDR_WIDTH-1:0]  m_req_addr;
wire [N_CORES*DATA_WIDTH-1:0]  m_req_wdata;
wire [N_CORES-1:0]             m_rsp_valid;
wire [N_CORES-1:0]             m_rsp_ready;
wire [N_CORES*2-1:0]           m_rsp_status;
wire [N_CORES*DATA_WIDTH-1:0]  m_rsp_rdata;

genvar gi;
generate
    for (gi = 0; gi < N_CORES; gi = gi + 1) begin : pack
        assign m_req_valid[gi] = gmi_req_valid[gi];
        assign gmi_req_ready[gi] = m_req_ready[gi];
        assign m_req_write[gi] = gmi_req_write[gi];
        assign m_req_addr [gi*ADDR_WIDTH +: ADDR_WIDTH] = gmi_req_addr[gi];
        assign m_req_wdata[gi*DATA_WIDTH +: DATA_WIDTH] = gmi_req_wdata[gi];
        assign gmi_rsp_valid[gi] = m_rsp_valid[gi];
        assign gmi_rsp_status[gi] = m_rsp_status[gi*2 +: 2];
        assign gmi_rsp_rdata [gi] = m_rsp_rdata[gi*DATA_WIDTH +: DATA_WIDTH];
        assign m_rsp_ready[gi] = gmi_rsp_ready[gi];
    end
endgenerate

// Arbiter outputs
wire                        s_req_valid;
wire                        s_req_ready;
wire                        s_req_write;
wire [ADDR_WIDTH-1:0]       s_req_addr;
wire [DATA_WIDTH-1:0]       s_req_wdata;
wire                        s_rsp_valid;
wire                        s_rsp_ready;
wire [1:0]                  s_rsp_status;
wire [DATA_WIDTH-1:0]       s_rsp_rdata;

gmi_rr_arb #(
    .N(N_CORES), .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)
) u_gmi_arb (
    .clk(clk), .rst_n(rst_n),
    .m_req_valid(m_req_valid), .m_req_ready(m_req_ready), .m_req_write(m_req_write), .m_req_addr(m_req_addr), .m_req_wdata(m_req_wdata),
    .m_rsp_valid(m_rsp_valid), .m_rsp_ready(m_rsp_ready), .m_rsp_status(m_rsp_status), .m_rsp_rdata(m_rsp_rdata),
    .s_req_valid(s_req_valid), .s_req_ready(s_req_ready), .s_req_write(s_req_write), .s_req_addr(s_req_addr), .s_req_wdata(s_req_wdata),
    .s_rsp_valid(s_rsp_valid), .s_rsp_ready(s_rsp_ready), .s_rsp_status(s_rsp_status), .s_rsp_rdata(s_rsp_rdata)
);

// Bridge to enid endpoint
gmi_enid_bridge #(
    .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH), .DEST_MOD(DEST_MOD), .DEST_SUB(DEST_SUB), .EP_DATA_W(32)
) u_gmi2ep (
    .clk(clk), .rst_n(rst_n),
    .s_req_valid(s_req_valid), .s_req_ready(s_req_ready), .s_req_write(s_req_write), .s_req_addr(s_req_addr), .s_req_wdata(s_req_wdata),
    .s_rsp_valid(s_rsp_valid), .s_rsp_ready(s_rsp_ready), .s_rsp_status(s_rsp_status), .s_rsp_rdata(s_rsp_rdata),
    .req_valid(ep_req_valid), .req_ready(ep_req_ready), .req_type(ep_req_type), .req_mem_op(ep_req_mem_op), .req_dest_mod(ep_req_dest_mod), .req_dest_sub(ep_req_dest_sub), .req_addr(ep_req_addr), .req_len(ep_req_len),
    .req_wvalid(ep_req_wvalid), .req_wready(ep_req_wready), .req_wdata(ep_req_wdata), .req_wlast(ep_req_wlast),
    .rsp_valid(ep_rsp_valid), .rsp_ready(ep_rsp_ready), .rsp_status(ep_rsp_status), .rsp_len(ep_rsp_len),
    .rsp_rvalid(ep_rsp_rvalid), .rsp_rready(ep_rsp_rready), .rsp_rdata(ep_rsp_rdata), .rsp_rlast(ep_rsp_rlast)
);

endmodule

