`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"

module opclass4_tb;
    reg r_clk;
    reg r_rst;

    amber u_amber (
        .iw_clk(r_clk),
        .iw_rst(r_rst)
    );

    initial r_clk = 1'b0;
    always #5 r_clk = ~r_clk;

    task run_cycles(input integer n);
        integer i; begin for (i = 0; i < n; i = i + 1) @(posedge r_clk); end endtask

    initial begin
        r_rst = 1'b1;
        #20;
        r_rst = 1'b0;
    end

    initial begin
        integer base;
        @(negedge r_rst);

        // Init CR0 for basic LDcso/STcso: region [100, 100+32), cursor=105, perms R|W|LC|SC
        u_amber.u_regcr.r_base[0]  = 48'd100;
        u_amber.u_regcr.r_len[0]   = 48'd32;
        u_amber.u_regcr.r_cur[0]   = 48'd105;
        u_amber.u_regcr.r_perms[0] = (24'd1 << `CR_PERM_R_BIT) |
                                      (24'd1 << `CR_PERM_W_BIT) |
                                      (24'd1 << `CR_PERM_LC_BIT) |
                                      (24'd1 << `CR_PERM_SC_BIT);
        u_amber.u_regcr.r_attr[0]  = 24'd0;
        u_amber.u_regcr.r_tag[0]   = 1'b1;

        // Init CR1 for STui/STsi: region [200, 200+16), cursor=204, perms W
        u_amber.u_regcr.r_base[1]  = 48'd200;
        u_amber.u_regcr.r_len[1]   = 48'd16;
        u_amber.u_regcr.r_cur[1]   = 48'd204;
        u_amber.u_regcr.r_perms[1] = (24'd1 << `CR_PERM_W_BIT);
        u_amber.u_regcr.r_attr[1]  = 24'd0;
        u_amber.u_regcr.r_tag[1]   = 1'b1;

        // Init CR2 as CLD source window: region [300, 300+64), cursor=300
        u_amber.u_regcr.r_base[2]  = 48'd300;
        u_amber.u_regcr.r_len[2]   = 48'd64;
        u_amber.u_regcr.r_cur[2]   = 48'd300;
        u_amber.u_regcr.r_perms[2] = (24'd1 << `CR_PERM_R_BIT) |
                                      (24'd1 << `CR_PERM_LC_BIT);
        u_amber.u_regcr.r_attr[2]  = 24'd0;
        u_amber.u_regcr.r_tag[2]   = 1'b1;

        // Init CR3 as CST source value (some capability fields)
        u_amber.u_regcr.r_base[3]  = 48'd4000;
        u_amber.u_regcr.r_len[3]   = 48'd123;
        u_amber.u_regcr.r_cur[3]   = 48'd4010;
        u_amber.u_regcr.r_perms[3] = 24'h00A5A5;
        u_amber.u_regcr.r_attr[3]  = 24'h0055AA;
        u_amber.u_regcr.r_tag[3]   = 1'b1;

        // Prepare D-mem for LD/ST and CLD layout
        // For LDcso: place word at 105 + imm10(=0)
        u_amber.u_dmem.r_mem[105] = 24'h00C0DE;

        // For CLD: at CR2.cur (300) populate capability record (10 words)
        base = 300;
        // BASE= [0],[1]
        u_amber.u_dmem.r_mem[base+0] = 24'd1234;     // BASE_LO24
        u_amber.u_dmem.r_mem[base+1] = 24'd5678;     // BASE_HI24
        // LEN= [2],[3]
        u_amber.u_dmem.r_mem[base+2] = 24'd50;       // LEN_LO24
        u_amber.u_dmem.r_mem[base+3] = 24'd0;        // LEN_HI24
        // CUR= [4],[5]
        u_amber.u_dmem.r_mem[base+4] = 24'd1240;     // CUR_LO24
        u_amber.u_dmem.r_mem[base+5] = 24'd5678;     // CUR_HI24
        // PERMS, ATTR, TAG, RSV
        u_amber.u_dmem.r_mem[base+6] = 24'h0000F0;   // PERMS
        u_amber.u_dmem.r_mem[base+7] = 24'h00000F;   // ATTR
        u_amber.u_dmem.r_mem[base+8] = 24'h000001;   // TAG (bit0=1)
        u_amber.u_dmem.r_mem[base+9] = 24'h000000;   // RESERVED

        // Program:
        // 0: LUIui bank0, #0x00C ; upper 12 for 0x00C0DE
        u_amber.u_imem.r_mem[0] = { `OPC_LUIui, 2'b00, 12'h00C };
        // 1: MOVui #0x0DE, DR1   ; DR1 = 0x00C0DE
        u_amber.u_imem.r_mem[1] = { `OPC_MOVui, 4'd1, 12'h0DE };
        // 2: STcso DR1, #1(CR0)  => mem[106] = DR1
        u_amber.u_imem.r_mem[2] = { `OPC_STcso, 2'b00, 4'd1, 10'd1 };
        // 3: LUIui bank0, #0xABC ; upper 12 for immediate
        u_amber.u_imem.r_mem[3] = { `OPC_LUIui, 2'b00, 12'hABC };
        // 4: STui #0x123, (CR1)  => mem[204] = 0xABC123
        u_amber.u_imem.r_mem[4] = { `OPC_STui, 2'b01, 2'b00, 12'h123 };
        // 5: STsi #-8, (CR1)     => mem[204] overwritten with sign-extended -8 (0xFFFFF8)
        u_amber.u_imem.r_mem[5] = { `OPC_STsi, 2'b01, 14'h3FF8 };
        // 6: CLDcso #0(CR2), CR1 => load capability at 300 into CR1
        u_amber.u_imem.r_mem[6] = ({ `OPC_CLDcso, 16'd0 }) | (24'd1 << 14) | (24'd2 << 12) | 24'd0;
        // 7: CSTcso CR3, #2(CR0) => store capability CR3 at 105+2 = 107
        u_amber.u_imem.r_mem[7] = { `OPC_CSTcso, 2'b00, 2'b11, 12'd2 };
        // 8: HLT
        u_amber.u_imem.r_mem[8] = { `OPC_HLT, 16'd0 };

        // Run
        run_cycles(200);

        // Checks
        // STcso stored at 106
        if (u_amber.u_dmem.r_mem[106] !== 24'h00C0DE) begin $display("FAIL: STcso mem[106]=%h", u_amber.u_dmem.r_mem[106]); $fatal; end
        // STsi wrote sign-extended -8
        if (u_amber.u_dmem.r_mem[204] !== 24'hFFFFF8) begin $display("FAIL: STsi mem[204]=%h", u_amber.u_dmem.r_mem[204]); $fatal; end
        // CLD moved BASE into CR1.base and tag
        if (u_amber.u_regcr.r_base[1] !== {24'd5678,24'd1234}) begin $display("FAIL: CLD base %h", u_amber.u_regcr.r_base[1]); $fatal; end
        if (u_amber.u_regcr.r_tag[1] !== 1'b1) begin $display("FAIL: CLD tag %b", u_amber.u_regcr.r_tag[1]); $fatal; end
        // CST wrote PERMS+ATTR+TAG words at 107.. (check a couple of fields)
        if (u_amber.u_dmem.r_mem[107+6] !== 24'h00A5A5) begin $display("FAIL: CST perms %h", u_amber.u_dmem.r_mem[113]); $fatal; end
        if (u_amber.u_dmem.r_mem[107+8][0] !== 1'b1) begin $display("FAIL: CST tag word bit0 %b", u_amber.u_dmem.r_mem[115][0]); $fatal; end

        $display("opclass4_tb PASS");
        $finish;
    end
endmodule
