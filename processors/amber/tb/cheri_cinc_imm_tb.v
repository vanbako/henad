`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"
`include "src/sr.vh"

module cheri_cinc_imm_tb;
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
        // Init CR0: [base, base+len) = [100, 120), cur=105, tag=1
        u_amber.u_regcr.r_base[0]  = 48'd100;
        u_amber.u_regcr.r_len[0]   = 48'd20;
        u_amber.u_regcr.r_cur[0]   = 48'd105;
        u_amber.u_regcr.r_perms[0] = 24'd0; // perms not used by CINC*
        u_amber.u_regcr.r_attr[0]  = 24'd0;
        u_amber.u_regcr.r_tag[0]   = 1'b1;

        // Program:
        // 0: NOP (pipeline warmup)
        u_amber.u_imem.r_mem[0] = { `OPC_NOP, 16'd0 };
        // 1: CINCi #+7, CR0 => cur = 112
        u_amber.u_imem.r_mem[1] = { `OPC_CINCi, 2'b00, 14'd7 };
        // 2: CINCiv #-5, CR0 => cur = 107 (in-bounds, no trap)
        // encode -5 as 14-bit two's complement: 2^14 - 5 = 16379 = 14'h3FFB
        u_amber.u_imem.r_mem[2] = { `OPC_CINCiv, 2'b00, 14'h3FFB };
        // 3: HLT
        u_amber.u_imem.r_mem[3] = { `OPC_HLT, 16'd0 };

        // Run enough cycles for EX and WB to retire (include cache stalls)
        repeat (100) @(posedge r_clk);

        if (u_amber.u_regcr.r_cur[0] !== 48'd107) begin
            $display("FAIL: CR0.cur expected 107, got %0d", u_amber.u_regcr.r_cur[0]);
            $finish;
        end
        // Ensure no trap was taken (LR should be 0)
        if (u_amber.u_regsr.r_sr[`SR_IDX_LR] !== 48'd0) begin
            $display("FAIL: Unexpected trap during CINCiv in-bounds path (LR=%0d)", u_amber.u_regsr.r_sr[`SR_IDX_LR]);
            $finish;
        end
        $display("CINCi/CINCiv immediate test PASS");
        $finish;
    end
endmodule
