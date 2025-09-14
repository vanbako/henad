`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"

module cheri_cst_tb;
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
        // Init CR0 (source), CR1 (target pointer)
        u_amber.u_regcr.r_base[0]  = 48'd1234;
        u_amber.u_regcr.r_len[0]   = 48'd5678;
        u_amber.u_regcr.r_cur[0]   = 48'd91011;
        u_amber.u_regcr.r_perms[0] = 24'h00ABCD;
        u_amber.u_regcr.r_attr[0]  = 24'h001122;
        u_amber.u_regcr.r_tag[0]   = 1'b1;

        u_amber.u_regcr.r_base[1]  = 48'd200;
        u_amber.u_regcr.r_len[1]   = 48'd100;
        u_amber.u_regcr.r_cur[1]   = 48'd300; // eff base
        u_amber.u_regcr.r_perms[1] = (24'd1 << `CR_PERM_SC_BIT); // allow store cap
        u_amber.u_regcr.r_attr[1]  = 24'd0;
        u_amber.u_regcr.r_tag[1]   = 1'b1;

        // Program: CSTcso CR0, #0(CR1); HLT
        // encoding: {opc, CRt[1:0]=CR1, CRs[3:0]=CR0, imm10=0}
        u_amber.u_imem.r_mem[0] = { `OPC_CSTcso, 2'b01, 4'b0000, 10'd0 };
        u_amber.u_imem.r_mem[1] = { `OPC_HLT, 16'd0 };

        // Run
        repeat (200) @(posedge r_clk);

        // Show LR
        $display("LR=%0d", u_amber.u_regsr.r_sr[`SR_IDX_LR]);
        // Check memory at eff=300
        $display("mem[0..11]   = %h %h %h %h %h %h %h %h %h %h %h %h",
            u_amber.u_dmem.r_mem[0], u_amber.u_dmem.r_mem[1], u_amber.u_dmem.r_mem[2], u_amber.u_dmem.r_mem[3],
            u_amber.u_dmem.r_mem[4], u_amber.u_dmem.r_mem[5], u_amber.u_dmem.r_mem[6], u_amber.u_dmem.r_mem[7],
            u_amber.u_dmem.r_mem[8], u_amber.u_dmem.r_mem[9], u_amber.u_dmem.r_mem[10], u_amber.u_dmem.r_mem[11]);
        $display("mem[300..311] = %h %h %h %h %h %h %h %h %h %h %h %h",
            u_amber.u_dmem.r_mem[300], u_amber.u_dmem.r_mem[301], u_amber.u_dmem.r_mem[302], u_amber.u_dmem.r_mem[303],
            u_amber.u_dmem.r_mem[304], u_amber.u_dmem.r_mem[305], u_amber.u_dmem.r_mem[306], u_amber.u_dmem.r_mem[307],
            u_amber.u_dmem.r_mem[308], u_amber.u_dmem.r_mem[309], u_amber.u_dmem.r_mem[310], u_amber.u_dmem.r_mem[311]);
        if (u_amber.u_dmem.r_mem[300]   !== 24'd1234) begin $display("FAIL: CST base lo mismatch"); $finish; end
        if (u_amber.u_dmem.r_mem[301]   !== (48'd1234 >> 24)) begin $display("FAIL: CST base hi mismatch"); $finish; end
        if (u_amber.u_dmem.r_mem[302]   !== 24'd5678) begin $display("FAIL: CST len lo mismatch"); $finish; end
        if (u_amber.u_dmem.r_mem[303]   !== (48'd5678 >> 24)) begin $display("FAIL: CST len hi mismatch"); $finish; end
        if (u_amber.u_dmem.r_mem[304]   !== 24'd91011) begin $display("FAIL: CST cur lo mismatch"); $finish; end
        if (u_amber.u_dmem.r_mem[305]   !== (48'd91011 >> 24)) begin $display("FAIL: CST cur hi mismatch"); $finish; end
        if (u_amber.u_dmem.r_mem[306]   !== 24'h00ABCD) begin $display("FAIL: CST perms mismatch"); $finish; end
        if (u_amber.u_dmem.r_mem[307]   !== 24'd0) begin $display("FAIL: CST perms hi should be 0"); $finish; end
        if (u_amber.u_dmem.r_mem[308]   !== 24'h001122) begin $display("FAIL: CST attr mismatch"); $finish; end
        if (u_amber.u_dmem.r_mem[309]   !== 24'd0) begin $display("FAIL: CST attr hi should be 0"); $finish; end
        if (u_amber.u_dmem.r_mem[310][0] !== 1'b1) begin $display("FAIL: CST tag bit mismatch"); $finish; end
        if (u_amber.u_dmem.r_mem[311]   !== 24'd0) begin $display("FAIL: CST tag hi should be 0"); $finish; end

        $display("CSTcso test PASS");
        $finish;
    end
endmodule
