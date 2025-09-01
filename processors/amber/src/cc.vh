`ifndef CC_VH
`define CC_VH

`include "src/sizes.vh"

`define CC_AL 4'b0000 // branch always
`define CC_EQ 4'b0001 // branch if equal
`define CC_NE 4'b0010 // branch if not equal
`define CC_LT 4'b0011 // branch if less than (signed)
`define CC_GT 4'b0100 // branch if greater than (signed)
`define CC_LE 4'b0101 // branch if less than or equal (signed)
`define CC_GE 4'b0110 // branch if greater than or equal (signed)
`define CC_BT 4'b0111 // branch if below than (unsigned)
`define CC_AT 4'b1000 // branch if above than (unsigned)
`define CC_BE 4'b1001 // branch if below than or equal (unsigned)
`define CC_AE 4'b1010 // branch if above than or equal (unsigned)

// Backward-compatible alias used in some modules
`define CC_RA `CC_AL

function automatic [79:0] cc2str;
    input [`HBIT_CC:0] cc;
    begin
        case (cc)
            `CC_RA:  cc2str = "RA";
            `CC_EQ:  cc2str = "EQ";
            `CC_NE:  cc2str = "NE";
            `CC_LT:  cc2str = "LT";
            `CC_GT:  cc2str = "GT";
            `CC_LE:  cc2str = "LE";
            `CC_GE:  cc2str = "GE";
            `CC_BT:  cc2str = "BT";
            `CC_AT:  cc2str = "AT";
            `CC_BE:  cc2str = "BE";
            `CC_AE:  cc2str = "AE";
            default: cc2str = "UN";
        endcase
    end
endfunction

`endif
