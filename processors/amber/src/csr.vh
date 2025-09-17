`ifndef CSR_VH
`define CSR_VH

// Named CSR indices (12-bit). Extend as needed.
`define CSR_IDX_STATUS   12'h000
`define CSR_IDX_CAUSE    12'h001
`define CSR_IDX_EPC_LO   12'h002  // low 24 bits of EPC
`define CSR_IDX_EPC_HI   12'h003  // high 24 bits of EPC
`define CSR_IDX_CYCLE_L  12'h004
`define CSR_IDX_CYCLE_H  12'h005
`define CSR_IDX_INSTRET_L 12'h006
`define CSR_IDX_INSTRET_H 12'h007

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
`define CSR_IDX_MATH_CTRL   12'h010
`define CSR_IDX_MATH_STATUS 12'h011
`define CSR_IDX_MATH_OPA    12'h012
`define CSR_IDX_MATH_OPB    12'h013
`define CSR_IDX_MATH_RES0   12'h014 // MUL: product[23:0]; DIV: quotient; MOD/SQRT: result
`define CSR_IDX_MATH_RES1   12'h015 // MUL: product[47:24]; DIV: remainder; otherwise 0
`define CSR_IDX_MATH_OPC    12'h016 // Optional third operand (e.g., clamp min)

// CSR[STATUS] bit assignments (low 24-bit data field)
// [0] MODE: 1=kernel, 0=user
`define CSR_STATUS_MODE_BIT 0

`endif
// Default Capability Windows (addresses per design/csr.md)
// DDC window: 0x020–0x028
`define CSR_IDX_DDC_BASE_LO 12'h020
`define CSR_IDX_DDC_BASE_HI 12'h021
`define CSR_IDX_DDC_LEN_LO  12'h022
`define CSR_IDX_DDC_LEN_HI  12'h023
`define CSR_IDX_DDC_CUR_LO  12'h024
`define CSR_IDX_DDC_CUR_HI  12'h025
`define CSR_IDX_DDC_PERMS   12'h026
`define CSR_IDX_DDC_ATTR    12'h027
`define CSR_IDX_DDC_TAG     12'h028

// PCC window: 0x030–0x038
`define CSR_IDX_PCC_BASE_LO 12'h030
`define CSR_IDX_PCC_BASE_HI 12'h031
`define CSR_IDX_PCC_LEN_LO  12'h032
`define CSR_IDX_PCC_LEN_HI  12'h033
`define CSR_IDX_PCC_CUR_LO  12'h034
`define CSR_IDX_PCC_CUR_HI  12'h035
`define CSR_IDX_PCC_PERMS   12'h036
`define CSR_IDX_PCC_ATTR    12'h037
`define CSR_IDX_PCC_TAG     12'h038

// SCC window: 0x040–0x048
`define CSR_IDX_SCC_BASE_LO 12'h040
`define CSR_IDX_SCC_BASE_HI 12'h041
`define CSR_IDX_SCC_LEN_LO  12'h042
`define CSR_IDX_SCC_LEN_HI  12'h043
`define CSR_IDX_SCC_CUR_LO  12'h044
`define CSR_IDX_SCC_CUR_HI  12'h045
`define CSR_IDX_SCC_PERMS   12'h046
`define CSR_IDX_SCC_ATTR    12'h047
`define CSR_IDX_SCC_TAG     12'h048
