`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"
`include "src/sr.vh"

module cheri_trap_csetbiv_tb;
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
        // Init CR0: any values; tag set
        u_amber.u_regcr.r_base[0]  = 48'd100;
        u_amber.u_regcr.r_len[0]   = 48'd50;
        u_amber.u_regcr.r_cur[0]   = 48'd110;
        u_amber.u_regcr.r_perms[0] = (24'd1 << `CR_PERM_SB_BIT); // allow setbounds
        u_amber.u_regcr.r_attr[0]  = 24'd0;
        u_amber.u_regcr.r_tag[0]   = 1'b1;

        // 0: CSETBiv CRs=CR0 (encoded via imm14[11:10]==00), imm14=0 -> invalid length 0 -> trap
        u_amber.u_imem.r_mem[0] = { `OPC_CSETBiv, 2'b00, 14'd0 };
        // 1: HLT (never reached if trap fires)
        u_amber.u_imem.r_mem[1] = { `OPC_HLT, 16'd0 };

        repeat (50) @(posedge r_clk);
        if (u_amber.u_regsr.r_sr[`SR_IDX_LR] == 48'd0) begin
            $display("FAIL: LR not written on CSETBiv trap");
            $fatal;
        end
        $display("CSETBiv trap test PASS");
        $finish;
    end
endmodule

