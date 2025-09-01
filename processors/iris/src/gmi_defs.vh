// Simple GPU Memory Interface (GMI) definitions for iris
`ifndef GMI_DEFS_VH
`define GMI_DEFS_VH

// Default widths (override via params inside modules)
`define GMI_ADDR_W   16
`define GMI_DATA_W   24

// Response status
`define GMI_OK       2'b00
`define GMI_ERR      2'b10

`endif // GMI_DEFS_VH

