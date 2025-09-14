`include "src/sizes.vh"
`include "src/cr.vh"

// Capability register file: CR0..CR3
// Stores architectural view as separate fields (not compressed):
// - base  (48-bit BAU address)
// - len   (48-bit BAU length)
// - cur   (48-bit BAU cursor)
// - perms (24-bit)
// - attr  (24-bit; bit0=sealed, [23:8]=otype)
// - tag   (1-bit)
module regcr(
    input  wire                   iw_clk,
    input  wire                   iw_rst,
    // Two combinational read ports
    input  wire [`HBIT_TGT_CR:0]  iw_read_addr1,
    input  wire [`HBIT_TGT_CR:0]  iw_read_addr2,
    output wire [`HBIT_ADDR:0]    ow_read_base1,
    output wire [`HBIT_ADDR:0]    ow_read_len1,
    output wire [`HBIT_ADDR:0]    ow_read_cur1,
    output wire [`HBIT_DATA:0]    ow_read_perms1,
    output wire [`HBIT_DATA:0]    ow_read_attr1,
    output wire                   ow_read_tag1,
    output wire [`HBIT_ADDR:0]    ow_read_base2,
    output wire [`HBIT_ADDR:0]    ow_read_len2,
    output wire [`HBIT_ADDR:0]    ow_read_cur2,
    output wire [`HBIT_DATA:0]    ow_read_perms2,
    output wire [`HBIT_DATA:0]    ow_read_attr2,
    output wire                   ow_read_tag2,
    // Single synchronous write port (for future capability ops)
    input  wire [`HBIT_TGT_CR:0]  iw_write_addr,
    input  wire                   iw_write_en_base,
    input  wire [`HBIT_ADDR:0]    iw_write_base,
    input  wire                   iw_write_en_len,
    input  wire [`HBIT_ADDR:0]    iw_write_len,
    input  wire                   iw_write_en_cur,
    input  wire [`HBIT_ADDR:0]    iw_write_cur,
    input  wire                   iw_write_en_perms,
    input  wire [`HBIT_DATA:0]    iw_write_perms,
    input  wire                   iw_write_en_attr,
    input  wire [`HBIT_DATA:0]    iw_write_attr,
    input  wire                   iw_write_en_tag,
    input  wire                   iw_write_tag
);
    reg [`HBIT_ADDR:0] r_base [0:(1<<(`HBIT_TGT_CR+1))-1];
    reg [`HBIT_ADDR:0] r_len  [0:(1<<(`HBIT_TGT_CR+1))-1];
    reg [`HBIT_ADDR:0] r_cur  [0:(1<<(`HBIT_TGT_CR+1))-1];
    reg [`HBIT_DATA:0] r_perms[0:(1<<(`HBIT_TGT_CR+1))-1];
    reg [`HBIT_DATA:0] r_attr [0:(1<<(`HBIT_TGT_CR+1))-1];
    reg                 r_tag [0:(1<<(`HBIT_TGT_CR+1))-1];

    integer i;
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            for (i = 0; i < (1<<(`HBIT_TGT_CR+1)); i = i + 1) begin
                r_base[i]  <= {(`HBIT_ADDR+1){1'b0}};
                r_len[i]   <= {(`HBIT_ADDR+1){1'b0}};
                r_cur[i]   <= {(`HBIT_ADDR+1){1'b0}};
                r_perms[i] <= {(`HBIT_DATA+1){1'b0}};
                r_attr[i]  <= {(`HBIT_DATA+1){1'b0}};
                r_tag[i]   <= 1'b0;
            end
        end else begin
            if (iw_write_en_base)  r_base[iw_write_addr]  <= iw_write_base;
            if (iw_write_en_len)   r_len[iw_write_addr]   <= iw_write_len;
            if (iw_write_en_cur) begin
                r_cur[iw_write_addr] <= iw_write_cur;
`ifndef SYNTHESIS
                $display("[CR] write CUR CR%0d := %0d", iw_write_addr, iw_write_cur);
`endif
            end
            if (iw_write_en_perms) r_perms[iw_write_addr] <= iw_write_perms;
            if (iw_write_en_attr)  r_attr[iw_write_addr]  <= iw_write_attr;
            if (iw_write_en_tag)   r_tag[iw_write_addr]   <= iw_write_tag;
        end
    end

    assign ow_read_base1  = r_base[iw_read_addr1];
    assign ow_read_len1   = r_len[iw_read_addr1];
    assign ow_read_cur1   = r_cur[iw_read_addr1];
    assign ow_read_perms1 = r_perms[iw_read_addr1];
    assign ow_read_attr1  = r_attr[iw_read_addr1];
    assign ow_read_tag1   = r_tag[iw_read_addr1];

    assign ow_read_base2  = r_base[iw_read_addr2];
    assign ow_read_len2   = r_len[iw_read_addr2];
    assign ow_read_cur2   = r_cur[iw_read_addr2];
    assign ow_read_perms2 = r_perms[iw_read_addr2];
    assign ow_read_attr2  = r_attr[iw_read_addr2];
    assign ow_read_tag2   = r_tag[iw_read_addr2];
endmodule

