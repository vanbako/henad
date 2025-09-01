// enid common definitions (proto-1)
`ifndef ENID_DEFS_VH
`define ENID_DEFS_VH

// Address map widths
`define ENID_MODULE_ID_W 4
`define ENID_SUB_ID_W    2
`define ENID_ADDR_W      36
`define ENID_LEN_W       16
`define ENID_SEQ_W        8
`define ENID_VC_W         2
`define ENID_HDRCRC_W    16
`define ENID_PAYCRC_W    32

// Default link/credit widths (override via params where applicable)
`define ENID_LINK_W      16
`define ENID_DATA_W      32
`define ENID_CR_W         5

// Packet types
`define ENID_PT_MEM       4'd0
`define ENID_PT_MSG       4'd1
`define ENID_PT_ACK       4'd2
`define ENID_PT_NACK      4'd3

// Memory ops
`define ENID_MEM_RD       2'd0
`define ENID_MEM_WR       2'd1

`endif // ENID_DEFS_VH

