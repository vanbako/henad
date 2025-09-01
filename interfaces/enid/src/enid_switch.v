// enid N-port cut-through switch skeleton (proto-1)

`include "enid_defs.vh"

module enid_switch #(
    parameter integer N_PORTS = 8,
    parameter integer LINK_W  = `ENID_LINK_W
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // Per-port link RX (ingress into switch core)
    input  wire [N_PORTS-1:0]           lrx_valid,
    output wire [N_PORTS-1:0]           lrx_ready,
    input  wire [N_PORTS*LINK_W-1:0]    lrx_flit,
    input  wire [N_PORTS-1:0]           lrx_sof,
    input  wire [N_PORTS-1:0]           lrx_eof,
    input  wire [N_PORTS*`ENID_VC_W-1:0] lrx_vc,

    // Per-port link TX (egress from switch core)
    output wire [N_PORTS-1:0]           ltx_valid,
    input  wire [N_PORTS-1:0]           ltx_ready,
    output wire [N_PORTS*LINK_W-1:0]    ltx_flit,
    output wire [N_PORTS-1:0]           ltx_sof,
    output wire [N_PORTS-1:0]           ltx_eof,
    output wire [N_PORTS*`ENID_VC_W-1:0] ltx_vc
);

    // NOTE: Skeleton only. Intended micro-architecture:
    // - Per-port small ingress FIFOs per VC
    // - Header parser to extract dest_mod/sub and route ID
    // - Per-output round-robin arbiter
    // - Cut-through forwarding of flits after header is accepted by arbiter
    // - Optional: backpressure with credits via ready signals mapping

    assign lrx_ready = {N_PORTS{1'b0}};
    assign ltx_valid = {N_PORTS{1'b0}};
    assign ltx_flit  = {N_PORTS*LINK_W{1'b0}};
    assign ltx_sof   = {N_PORTS{1'b0}};
    assign ltx_eof   = {N_PORTS{1'b0}};
    assign ltx_vc    = {N_PORTS*`ENID_VC_W{1'b0}};

endmodule

