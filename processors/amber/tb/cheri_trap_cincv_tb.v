`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"
`include "src/sr.vh"

module cheri_trap_cincv_tb;
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
        // Init CR0 so that CINCv goes out of bounds: [base, base+len) = [100,105)
        u_amber.u_regcr.r_base[0]  = 48'd100;
        u_amber.u_regcr.r_len[0]   = 48'd5;
        u_amber.u_regcr.r_cur[0]   = 48'd104;
        u_amber.u_regcr.r_perms[0] = (24'd1 << `CR_PERM_R_BIT) |
                                      (24'd1 << `CR_PERM_W_BIT) |
                                      (24'd1 << `CR_PERM_SB_BIT);
        u_amber.u_regcr.r_attr[0]  = 24'd0;
        u_amber.u_regcr.r_tag[0]   = 1'b1;

        // Program:
        // 0: MOVsi #5, DR1
        u_amber.u_imem.r_mem[0] = { `OPC_MOVsi, 4'd1, 12'd5 };
        // 1: CINCv DR1, CR0 -> trap to base from LUI banks (default 0)
        u_amber.u_imem.r_mem[1] = { `OPC_CINCv, 2'b00, 4'd1, 10'd0 };
        // 2: HLT (never reached if trap fires)
        u_amber.u_imem.r_mem[2] = { `OPC_HLT, 16'd0 };

        // Run enough cycles to retire the trap in EX and reflect LR write in WB
        repeat (50) @(posedge r_clk);
        if (u_amber.u_regsr.r_sr[`SR_IDX_LR] == 48'd0) begin
            $display("FAIL: LR not written on CINCv trap");
            $fatal;
        end
        $display("CINCv trap test PASS");
        $finish;
    end
endmodule

