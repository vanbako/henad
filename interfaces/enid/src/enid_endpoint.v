// enid endpoint skeleton (proto-1)
// Bridges a simple transaction interface to the enid link layer.

`include "enid_defs.vh"

module enid_endpoint #(
    parameter integer LINK_W   = `ENID_LINK_W,
    parameter integer DATA_W   = `ENID_DATA_W
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // Local transaction request in
    input  wire                         req_valid,
    output wire                         req_ready,
    input  wire [1:0]                   req_type,      // 0=mem,1=msg
    input  wire [1:0]                   req_mem_op,    // 0=RD,1=WR
    input  wire [`ENID_MODULE_ID_W-1:0] req_dest_mod,
    input  wire [`ENID_SUB_ID_W-1:0]    req_dest_sub,
    input  wire [`ENID_ADDR_W-1:0]      req_addr,
    input  wire [`ENID_LEN_W-1:0]       req_len,

    // Write data stream for WR
    input  wire                         req_wvalid,
    output wire                         req_wready,
    input  wire [DATA_W-1:0]            req_wdata,
    input  wire                         req_wlast,

    // Response out
    output wire                         rsp_valid,
    input  wire                         rsp_ready,
    output wire [1:0]                   rsp_status,    // 0=OK,1=ERR,2=RETRY
    output wire [`ENID_LEN_W-1:0]       rsp_len,

    // Read data stream for RD or MSG
    output wire                         rsp_rvalid,
    input  wire                         rsp_rready,
    output wire [DATA_W-1:0]            rsp_rdata,
    output wire                         rsp_rlast,

    // Link TX (to PHY/LINK layer)
    output wire                         ltx_valid,
    input  wire                         ltx_ready,
    output wire [LINK_W-1:0]            ltx_flit,
    output wire                         ltx_sof,
    output wire                         ltx_eof,
    output wire [`ENID_VC_W-1:0]        ltx_vc,
    input  wire [`ENID_CR_W-1:0]        ltx_credit,

    // Link RX (from PHY/LINK layer)
    input  wire                         lrx_valid,
    output wire                         lrx_ready,
    input  wire [LINK_W-1:0]            lrx_flit,
    input  wire                         lrx_sof,
    input  wire                         lrx_eof,
    input  wire [`ENID_VC_W-1:0]        lrx_vc
);

    // NOTE: This is a skeleton with only handshakes tied off for now.
    // Implement packetization, header emit/parse, CRC, and data streaming here.

    assign req_ready  = 1'b0;
    assign req_wready = 1'b0;

    assign rsp_valid  = 1'b0;
    assign rsp_status = 2'd0;
    assign rsp_len    = {`ENID_LEN_W{1'b0}};
    assign rsp_rvalid = 1'b0;
    assign rsp_rdata  = {DATA_W{1'b0}};
    assign rsp_rlast  = 1'b0;

    assign ltx_valid  = 1'b0;
    assign ltx_flit   = {LINK_W{1'b0}};
    assign ltx_sof    = 1'b0;
    assign ltx_eof    = 1'b0;
    assign ltx_vc     = {`ENID_VC_W{1'b0}};

    assign lrx_ready  = 1'b1; // Always ready (until FIFOs are added)

endmodule

