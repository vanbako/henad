// bcc.vh
// Branch Condition Code definitions for Henad
`ifndef BCC_VH
`define BCC_VH

// [7:4] BCC field
`define BCC_RA 4'h0 // always
`define BCC_EQ 4'h1 // equal
`define BCC_NE 4'h2 // not equal
`define BCC_LT 4'h3 // less than
`define BCC_GT 4'h4 // greater than
`define BCC_LE 4'h5 // less or equal
`define BCC_GE 4'h6 // greater or equal

`endif // BCC_VH
