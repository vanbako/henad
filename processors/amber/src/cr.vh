`ifndef CR_VH
`define CR_VH

`include "src/sizes.vh"

// Capability register file sizing (CR0..CR3)
`define SIZE_TGT_CR  2
`define HBIT_TGT_CR  1

// Capability permission bits layout in a 24-bit perms word
// [0] R, [1] W, [2] X, [3] LC (load cap), [4] SC (store cap), [5] SB (set bounds)
`define CR_PERM_R_BIT   0
`define CR_PERM_W_BIT   1
`define CR_PERM_X_BIT   2
`define CR_PERM_LC_BIT  3
`define CR_PERM_SC_BIT  4
`define CR_PERM_SB_BIT  5

// Attribute register (24-bit): [0] SEALED, [23:8] OTYPE (up to 16 bits), others reserved
`define CR_ATTR_SEALED_BIT 0

// CR field selector encodings for CR2SR/SR2CR micro-ops
`define CR_FLD_BASE   4'd0
`define CR_FLD_LEN    4'd1
`define CR_FLD_CUR    4'd2
`define CR_FLD_PERMS  4'd3
`define CR_FLD_ATTR   4'd4
`define CR_FLD_TAG    4'd5

`endif
