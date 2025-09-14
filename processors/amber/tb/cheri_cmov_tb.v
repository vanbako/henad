`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"

module cheri_cmov_tb;
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
        // Initialize CR1 with distinct values
        u_amber.u_regcr.r_base[1]  = 48'd1000;
        u_amber.u_regcr.r_len[1]   = 48'd88;
        u_amber.u_regcr.r_cur[1]   = 48'd1010;
        u_amber.u_regcr.r_perms[1] = (24'd1 << `CR_PERM_R_BIT) |
                                      (24'd1 << `CR_PERM_W_BIT) |
                                      (24'd1 << `CR_PERM_SB_BIT);
        u_amber.u_regcr.r_attr[1]  = 24'h00A5_5A;
        u_amber.u_regcr.r_tag[1]   = 1'b1;

        // Initialize CR0 differently so CMOV effect is observable
        u_amber.u_regcr.r_base[0]  = 48'd10;
        u_amber.u_regcr.r_len[0]   = 48'd20;
        u_amber.u_regcr.r_cur[0]   = 48'd15;
        u_amber.u_regcr.r_perms[0] = 24'd0;
        u_amber.u_regcr.r_attr[0]  = 24'd0;
        u_amber.u_regcr.r_tag[0]   = 1'b0;

        // 0: NOP (pipeline warmup)
        u_amber.u_imem.r_mem[0] = { `OPC_NOP, 16'd0 };
        // 1: CMOV CR1, CR0 => copy all fields (including tag)
        // encoding: {opc, CRt=0, CRs=1, pad}
        u_amber.u_imem.r_mem[1] = { `OPC_CMOV, 2'b00, 2'b01, 12'd0 };
        // 2: HLT
        u_amber.u_imem.r_mem[2] = { `OPC_HLT, 16'd0 };

        // Allow enough cycles for full CR writeback to retire across pipeline
        repeat (100) @(posedge r_clk);

        if (u_amber.u_regcr.r_base[0]  !== 48'd1000) begin $display("FAIL: base"); $finish; end
        if (u_amber.u_regcr.r_len[0]   !== 48'd88)   begin $display("FAIL: len");  $finish; end
        if (u_amber.u_regcr.r_cur[0]   !== 48'd1010) begin $display("FAIL: cur");  $finish; end
        if (u_amber.u_regcr.r_perms[0] !== ((24'd1 << `CR_PERM_R_BIT) | (24'd1 << `CR_PERM_W_BIT) | (24'd1 << `CR_PERM_SB_BIT))) begin
            $display("FAIL: perms"); $finish;
        end
        if (u_amber.u_regcr.r_attr[0]  !== 24'h00A5_5A) begin $display("FAIL: attr"); $finish; end
        if (u_amber.u_regcr.r_tag[0]   !== 1'b1) begin $display("FAIL: tag"); $finish; end
        $display("CMOV test PASS");
        $finish;
    end
endmodule
