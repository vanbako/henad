`ifndef CSR_VH
`define CSR_VH

// Named CSR indices (8-bit). Extend as needed.
`define CSR_IDX_STATUS   8'h00
`define CSR_IDX_CAUSE    8'h01
`define CSR_IDX_EPC_LO   8'h02  // low 24 bits of EPC
`define CSR_IDX_EPC_HI   8'h03  // high 24 bits of EPC
`define CSR_IDX_CYCLE_L  8'h04
`define CSR_IDX_CYCLE_H  8'h05
`define CSR_IDX_INSTRET_L 8'h06
`define CSR_IDX_INSTRET_H 8'h07

// CSR[STATUS] bit assignments (low 24-bit data field)
// [0] MODE: 1=kernel, 0=user
`define CSR_STATUS_MODE_BIT 0

`endif
