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
// Control: [0] START, [5:1] OP
// OP encodings:
//   0x00 MULU, 0x01 DIVU, 0x02 MODU, 0x03 SQRTU,
//   0x04 MULS, 0x05 DIVS, 0x06 MODS,
//   0x07 ABS_S,
//   0x08 MIN_U, 0x09 MAX_U, 0x0A MIN_S, 0x0B MAX_S,
//   0x0C CLAMP_U, 0x0D CLAMP_S,
//   0x0E ADD24, 0x0F SUB24, 0x10 NEG24,
//   0x11 ADD12 (lane-wise), 0x12 SUB12 (lane-wise), 0x13 NEG12 (lane-wise)
//   0x14 MUL12  (lane-wise, unsigned)
//   0x15 DIV12  (lane-wise, unsigned) -> RES0:quot, RES1:rem
//   0x16 MOD12  (lane-wise, unsigned) -> RES0:rem
//   0x17 SQRT12 (lane-wise, unsigned)
//   0x18 ABS12  (lane-wise, signed)
//   0x19 MIN12_U, 0x1A MAX12_U, 0x1B MIN12_S, 0x1C MAX12_S
//   0x1D CLAMP12_U, 0x1E CLAMP12_S (lane-wise; OPA clamped to [OPC(min), OPB(max)])
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
