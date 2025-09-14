`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"

module cheri_ops_tb;
    reg r_clk;
    reg r_rst;

    amber u_amber (
        .iw_clk(r_clk),
        .iw_rst(r_rst)
    );

    initial r_clk = 1'b0;
    always #5 r_clk = ~r_clk;

    // Simple CHERI program:
    //  0: MOVsi #5, DR1          ; delta = +5
    //  1: CINC DR1, CR0          ; CR0.cur += 5
    //  2: CSETBi CR0,#20, CR0    ; CR0.base := CR0.cur; CR0.len := 20
    //  3: MOVsi #1, DR2          ; perms mask R-only
    //  4: CANDP DR2, CR0         ; perms &= 1
    //  5: CGETP CR0, DR3         ; DR3 = perms
    //  6: CCLRT CR0              ; tag := 0
    //  7: CGETT CR0, DR4         ; DR4 = tag
    //  8: HLT
    initial begin
        r_rst = 1'b1;
        #10;
        r_rst = 1'b0;
    end

    initial begin
        // Program load after reset deassertion
        @(negedge r_rst);
        // Init CR0: base=100, len=50, cur=100, perms=R|W|SB, tag=1
        u_amber.u_regcr.r_base[0]  = 48'd100;
        u_amber.u_regcr.r_len[0]   = 48'd50;
        u_amber.u_regcr.r_cur[0]   = 48'd100;
        u_amber.u_regcr.r_perms[0] = (24'd1 << `CR_PERM_R_BIT) |
                                      (24'd1 << `CR_PERM_W_BIT) |
                                      (24'd1 << `CR_PERM_SB_BIT);
        u_amber.u_regcr.r_attr[0]  = 24'd0;
        u_amber.u_regcr.r_tag[0]   = 1'b1;

        // Load instructions into I-mem
        // 0: MOVsi #5, DR1
        u_amber.u_imem.r_mem[0] = { `OPC_MOVsi, 4'd1, 12'd5 };
        // 1: CINC DR1, CR0 => {opc, CRt[1:0]=0, DRs[3:0]=1, 10'b0}
        u_amber.u_imem.r_mem[1] = { `OPC_CINC, 2'b00, 4'd1, 10'd0 };
        // 2: CSETBi CRs=CR0 (encoded in imm14[11:10]==2'b00), imm14=20, CRt=CR0
        //    Pack as {opc, CRt, imm14}; choose imm14 with bits[11:10]=00.
        u_amber.u_imem.r_mem[2] = { `OPC_CSETBi, 2'b00, 14'd20 };
        // 3: MOVsi #1, DR2 (R-only mask)
        u_amber.u_imem.r_mem[3] = { `OPC_MOVsi, 4'd2, 12'd1 };
        // 4: CANDP DR2, CR0 => {opc, CRt=0, DRs=2, pad}
        u_amber.u_imem.r_mem[4] = { `OPC_CANDP, 2'b00, 4'd2, 10'd0 };
        // 5..8: NOPs (allow CR write to retire)
        u_amber.u_imem.r_mem[5] = { `OPC_NOP, 16'd0 };
        u_amber.u_imem.r_mem[6] = { `OPC_NOP, 16'd0 };
        u_amber.u_imem.r_mem[7] = { `OPC_NOP, 16'd0 };
        u_amber.u_imem.r_mem[8] = { `OPC_NOP, 16'd0 };
        // 9: CGETP CR0 -> DR3 => {opc, DRt=3, CRs=0, pad}
        u_amber.u_imem.r_mem[9] = { `OPC_CGETP, 4'd3, 2'b00, 10'd0 };
        // 10: CCLRT CR0 => {opc, CRt=0, pad}
        u_amber.u_imem.r_mem[10] = { `OPC_CCLRT, 2'b00, 14'd0 };
        // 11..12: NOPs
        u_amber.u_imem.r_mem[11] = { `OPC_NOP, 16'd0 };
        u_amber.u_imem.r_mem[12] = { `OPC_NOP, 16'd0 };
        // 13: CGETT CR0 -> DR4 => {opc, DRt=4, CRs=0, pad}
        u_amber.u_imem.r_mem[13] = { `OPC_CGETT, 4'd4, 2'b00, 10'd0 };
        // 14: HLT
        u_amber.u_imem.r_mem[14] = { `OPC_HLT, 16'd0 };

        // Run for enough cycles
        repeat (80) @(posedge r_clk);

        // Checks
        if (u_amber.u_regcr.r_cur[0] !== 48'd105) begin
            $display("FAIL: CR0.cur expected 105, got %0d", u_amber.u_regcr.r_cur[0]);
            $fatal;
        end
        if (u_amber.u_regcr.r_base[0] !== 48'd105) begin
            $display("FAIL: CR0.base expected 105, got %0d", u_amber.u_regcr.r_base[0]);
            $fatal;
        end
        if (u_amber.u_regcr.r_len[0] !== 48'd20) begin
            $display("FAIL: CR0.len expected 20, got %0d", u_amber.u_regcr.r_len[0]);
            $fatal;
        end
        if (u_amber.u_regcr.r_perms[0] !== 24'd1) begin
            $display("FAIL: CR0.perms expected 0x000001, got %h", u_amber.u_regcr.r_perms[0]);
            $fatal;
        end
        if (u_amber.u_regcr.r_tag[0] !== 1'b0) begin
            $display("FAIL: CR0.tag expected 0, got %b", u_amber.u_regcr.r_tag[0]);
            $fatal;
        end
        if (u_amber.u_reggp.r_gp[3] !== 24'd1) begin
            $display("FAIL: DR3 (perms) expected 1, got %0d", u_amber.u_reggp.r_gp[3]);
            $fatal;
        end
        if (u_amber.u_reggp.r_gp[4] !== 24'd0) begin
            $display("FAIL: DR4 (tag) expected 0, got %0d", u_amber.u_reggp.r_gp[4]);
            $fatal;
        end
        $display("CHERI ops test PASS");
        $finish;
    end
endmodule
