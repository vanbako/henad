`ifndef SIZES_VH
`define SIZES_VH

`define SIZE_ADDR 48
`define SIZE_DATA 24
`define SIZE_FLAG  4

`define SIZE_OPCLASS 4
`define SIZE_SUBOP   4
`define SIZE_OPC     8
`define SIZE_CC      4
`define SIZE_IMM14  14
`define SIZE_IMM12  12
`define SIZE_IMM10  10
`define SIZE_IMM8    8
`define SIZE_IMM16  16
`define SIZE_TGT_GP  4
`define SIZE_TGT_AR  2
`define SIZE_TGT_SR  2
`define SIZE_TGT_CR  2
`define SIZE_SRC_GP  4
`define SIZE_SRC_AR  2
`define SIZE_SRC_SR  2

`define HBIT_GP   15
`define HBIT_AR   3
`define HBIT_SR   3
`define HBIT_CR   1
`define HBIT_ADDR 47
`define HBIT_DATA 23
`define HBIT_FLAG  3

`define HBIT_INSTR_OPCLASS 23
`define LBIT_INSTR_OPCLASS 20
`define HBIT_INSTR_SUBOP   19
`define LBIT_INSTR_SUBOP   16
`define HBIT_INSTR_OPC     23
`define LBIT_INSTR_OPC     16
`define HBIT_INSTR_IMM14   13
`define HBIT_INSTR_IMM12   11
`define HBIT_INSTR_IMM10    9
`define HBIT_INSTR_IMM8     7
`define LBIT_INSTR_IMM      0

`define HBIT_OPCLASS  3
`define HBIT_SUBOP    3
`define HBIT_OPC      7
`define HBIT_IMM16   15
`define HBIT_IMM14   13
`define HBIT_IMM12   11
`define HBIT_IMM10    9
`define HBIT_IMM8     7
`define HBIT_CC       3
`define HBIT_ADDR_GP  3
`define HBIT_ADDR_AR  1
`define HBIT_ADDR_SR  1
`define HBIT_ADDR_CR  1

// Aliases for address bit widths per operand kind
`define HBIT_TGT_GP  `HBIT_ADDR_GP
`define HBIT_SRC_GP  `HBIT_ADDR_GP
`define HBIT_TGT_AR  `HBIT_ADDR_AR
`define HBIT_SRC_AR  `HBIT_ADDR_AR
`define HBIT_TGT_SR  `HBIT_ADDR_SR
`define HBIT_TGT_CR  `HBIT_ADDR_CR
`define HBIT_SRC_SR  `HBIT_ADDR_SR

// CSR file: 24-bit data, 12-bit index (up to 4096 CSRs)
`define SIZE_TGT_CSR  12
`define HBIT_TGT_CSR  11

`endif
