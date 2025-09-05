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

// Async 24-bit math engine CSRs
// Control: [0] START, [4:1] OP
// OP encodings:
//   0x0 MULU, 0x1 DIVU, 0x2 MODU, 0x3 SQRTU,
//   0x4 MULS, 0x5 DIVS, 0x6 MODS,
//   0x7 ABS_S,
//   0x8 MIN_U, 0x9 MAX_U, 0xA MIN_S, 0xB MAX_S,
//   0xC CLAMP_U, 0xD CLAMP_S
// Status:  [0] READY, [1] BUSY, [2] DIV0, other bits reserved
// Operands/Results are 24-bit wide
`define CSR_IDX_MATH_CTRL   8'h10
`define CSR_IDX_MATH_STATUS 8'h11
`define CSR_IDX_MATH_OPA    8'h12
`define CSR_IDX_MATH_OPB    8'h13
`define CSR_IDX_MATH_RES0   8'h14 // MUL: product[23:0]; DIV: quotient; MOD/SQRT: result
`define CSR_IDX_MATH_RES1   8'h15 // MUL: product[47:24]; DIV: remainder; otherwise 0
`define CSR_IDX_MATH_OPC    8'h16 // Optional third operand (e.g., clamp min)

// CSR[STATUS] bit assignments (low 24-bit data field)
// [0] MODE: 1=kernel, 0=user
`define CSR_STATUS_MODE_BIT 0

`endif
