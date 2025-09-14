`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"

module cheri_cld_tb;
    reg r_clk;
    reg r_rst;

    amber u_amber (
        .iw_clk(r_clk),
        .iw_rst(r_rst)
    );

    initial r_clk = 1'b0;
    always #5 r_clk = ~r_clk;

    initial begin
        r_rst = 1'b1;
        #10;
        r_rst = 1'b0;
    end

    initial begin
        @(negedge r_rst);
        // Init CR0 as source of address
        u_amber.u_regcr.r_base[0]  = 48'd0;
        u_amber.u_regcr.r_len[0]   = 48'd1000;
        u_amber.u_regcr.r_cur[0]   = 48'd500; // eff base
        u_amber.u_regcr.r_perms[0] = (24'd1 << `CR_PERM_LC_BIT); // allow load cap
        u_amber.u_regcr.r_attr[0]  = 24'd0;
        u_amber.u_regcr.r_tag[0]   = 1'b1;

        // Preload memory with a capability at 500
        u_amber.u_dmem.r_mem[500]  = 24'd42;        // base lo
        u_amber.u_dmem.r_mem[501]  = 24'd7;         // base hi
        u_amber.u_dmem.r_mem[502]  = 24'd88;        // len lo
        u_amber.u_dmem.r_mem[503]  = 24'd9;         // len hi
        u_amber.u_dmem.r_mem[504]  = 24'd123;       // cur lo
        u_amber.u_dmem.r_mem[505]  = 24'd3;         // cur hi
        u_amber.u_dmem.r_mem[506]  = 24'h0000EE;    // perms
        u_amber.u_dmem.r_mem[507]  = 24'd0;         // perms hi
        u_amber.u_dmem.r_mem[508]  = 24'h0000AA;    // attr
        u_amber.u_dmem.r_mem[509]  = 24'd0;         // attr hi
        u_amber.u_dmem.r_mem[510]  = 24'h000001;    // tag bit
        u_amber.u_dmem.r_mem[511]  = 24'd0;         // tag hi

        // Program: CLDcso #0(CR0), CR1; HLT
        u_amber.u_imem.r_mem[0] = { `OPC_CLDcso, 2'b01, 2'b00, 10'd0 };
        u_amber.u_imem.r_mem[1] = { `OPC_HLT, 16'd0 };

        repeat (400) @(posedge r_clk);

        if (u_amber.u_regcr.r_base[1] !== {24'd7, 24'd42}) begin $display("FAIL: CLD base mismatch: %h", u_amber.u_regcr.r_base[1]); $finish; end
        if (u_amber.u_regcr.r_len[1]  !== {24'd9, 24'd88}) begin $display("FAIL: CLD len mismatch: %h", u_amber.u_regcr.r_len[1]); $finish; end
        if (u_amber.u_regcr.r_cur[1]  !== {24'd3, 24'd123}) begin $display("FAIL: CLD cur mismatch: %h", u_amber.u_regcr.r_cur[1]); $finish; end
        if (u_amber.u_regcr.r_perms[1] !== 24'h0000EE)      begin $display("FAIL: CLD perms mismatch: %h", u_amber.u_regcr.r_perms[1]); $finish; end
        if (u_amber.u_regcr.r_attr[1]  !== 24'h0000AA)      begin $display("FAIL: CLD attr mismatch: %h", u_amber.u_regcr.r_attr[1]); $finish; end
        if (u_amber.u_regcr.r_tag[1]   !== 1'b1)            begin $display("FAIL: CLD tag mismatch"); $finish; end

        $display("CLDcso test PASS");
        $finish;
    end
endmodule
