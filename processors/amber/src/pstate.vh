`ifndef PSTATE_VH
`define PSTATE_VH

// Bit positions within the 48-bit PSTATE register
`define PSTATE_BIT_Z         0
`define PSTATE_BIT_N         1
`define PSTATE_BIT_C         2
`define PSTATE_BIT_V         3
`define PSTATE_BIT_IE        4
`define PSTATE_BIT_TPE       5
`define PSTATE_BIT_MODE      8

// Trap cause field lives in bits [23:16]
`define PSTATE_CAUSE_LO     16
`define PSTATE_CAUSE_HI     23

// Trap info field lives in bits [39:24]
`define PSTATE_INFO_LO      24
`define PSTATE_INFO_HI      39

// Trap cause encodings
`define PSTATE_CAUSE_NONE        8'h00
`define PSTATE_CAUSE_ARITH_OVF   8'h01
`define PSTATE_CAUSE_ARITH_RANGE 8'h02
`define PSTATE_CAUSE_DIV_ZERO    8'h03
`define PSTATE_CAUSE_CAP_OOB     8'h10
`define PSTATE_CAUSE_CAP_TAG     8'h11
`define PSTATE_CAUSE_CAP_PERM    8'h12
`define PSTATE_CAUSE_CAP_SEAL    8'h13
`define PSTATE_CAUSE_CAP_ALIGN   8'h14
`define PSTATE_CAUSE_EXEC_PERM   8'h15
`define PSTATE_CAUSE_UIMM_STATE  8'h20
`define PSTATE_CAUSE_CAP_CFG     8'h30

`endif
