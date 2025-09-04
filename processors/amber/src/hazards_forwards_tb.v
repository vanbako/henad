`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cc.vh"

module hazards_forwards_tb;
    reg clk;
    reg rst;

    amber u_amber (
        .iw_clk(clk),
        .iw_rst(rst)
    );

    // Clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Program:
    //  0: MOVsi  #7  -> DR0           ; DR0=7
    //  1: MOVsi  #1  -> DR2           ; DR2=1
    //  2: MOVsi  #5  -> DR1           ; DR1=5
    //  3: ADDur  DR0 + DR1 -> DR1     ; exma forward on tgt, DR1=12
    //  4: ADDur  DR1 + DR2 -> DR2     ; exma forward on src, DR2=13
    //  5: MOVsi  #9  -> DR3
    //  6: NOP
    //  7: ADDur  DR0 + DR3 -> DR3     ; mamo forward on tgt, DR3=16
    //  8: MOVsi  #2  -> DR4
    //  9: NOP
    // 10: NOP
    // 11: ADDur  DR0 + DR4 -> DR4     ; mowb forward on tgt, DR4=9
    // 12: ADDAsi AR0 += #20            ; AR0=20
    // 13: STui   (AR0) <= #0x055       ; memory hazard (3-cycle stall)
    // 14: NOP
    // 15: NOP
    // 16: MOVsi  #0  -> DR5           ; sets Z=1 (flags forward source for next)
    // 17: JCCui  EQ, #19              ; branch over next MOV if Z==1
    // 18: MOVsi  #9  -> DR6           ; should be skipped
    // 19: MOVsi  #7  -> DR6           ; taken path, DR6=7
    // 20: ADDAsi AR0 += #1             ; AR0=21
    // 21: ADDAsi AR0 += #2             ; AR0=23 (tgt AR forward)
    // 22: MOVDur L(AR0) -> DR7         ; src AR forward, DR7=23
    // 23: SRHLT
    initial begin
        // small delay to ensure memories exist
        #1;
        // MOVsi enc: 0x30 | DRt | imm12
        u_amber.u_imem.r_mem[ 0] = 24'h300007; // DR0 <- 7
        u_amber.u_imem.r_mem[ 1] = 24'h302001; // DR2 <- 1
        u_amber.u_imem.r_mem[ 2] = 24'h301005; // DR1 <- 5
        // ADDur enc: 0x03 | DRt | DRs << 8
        u_amber.u_imem.r_mem[ 3] = 24'h031000; // DR1 <- DR1 + DR0 = 12 (forward tgt from EXMA)
        u_amber.u_imem.r_mem[ 4] = 24'h032100; // DR2 <- DR2 + DR1 = 13 (forward src from EXMA)
        u_amber.u_imem.r_mem[ 5] = 24'h303009; // DR3 <- 9
        u_amber.u_imem.r_mem[ 6] = 24'h000000; // NOP
        u_amber.u_imem.r_mem[ 7] = 24'h033000; // DR3 <- DR3 + DR0 = 16 (forward from MAMO)
        u_amber.u_imem.r_mem[ 8] = 24'h304002; // DR4 <- 2
        u_amber.u_imem.r_mem[ 9] = 24'h000000; // NOP
        u_amber.u_imem.r_mem[10] = 24'h000000; // NOP
        u_amber.u_imem.r_mem[11] = 24'h034000; // DR4 <- DR4 + DR0 = 9 (forward from MOWB)
        // ADDAsi enc: 0x67 | ARt | imm12 (signed)
        u_amber.u_imem.r_mem[12] = 24'h670014; // AR0 += 20  => 20
        // STui enc: 0x42 | ARt | imm12 (zero-extended)
        u_amber.u_imem.r_mem[13] = 24'h420055; // *(AR0)=0x000055 (triggers hazard)
        u_amber.u_imem.r_mem[14] = 24'h000000; // NOP
        u_amber.u_imem.r_mem[15] = 24'h000000; // NOP
        u_amber.u_imem.r_mem[16] = 24'h305000; // DR5 <- 0 (Z=1)
        // JCCui enc: 0x72 | CC<<12 | imm12 (absolute PC)
        u_amber.u_imem.r_mem[17] = 24'h721013; // if EQ -> PC=19
        u_amber.u_imem.r_mem[18] = 24'h306009; // DR6 <- 9 (should be skipped)
        u_amber.u_imem.r_mem[19] = 24'h306007; // DR6 <- 7
        u_amber.u_imem.r_mem[20] = 24'h670001; // AR0 += 1  => 21
        u_amber.u_imem.r_mem[21] = 24'h670002; // AR0 += 2  => 23 (tgt AR forward)
        // MOVDur enc: 0x62 | DRt | ARs<<10 | Hbit<<9
        u_amber.u_imem.r_mem[22] = 24'h627000; // DR7 <- L(AR0) = 23 (src AR forward)
        u_amber.u_imem.r_mem[23] = 24'hA00000; // SRHLT
    end

    // Reset + run
    integer tick;
    initial begin
        rst = 1'b1; tick = 0;
        repeat (2) @(posedge clk);
        rst = 1'b0;
        // Run long enough for program to complete
        repeat (300) @(posedge clk);
        $display("Timeout waiting for SRHLT");
        $fatal;
    end

    // Track stalls and assert policy: exactly 3 cycles, PC holds constant
    reg prev_stall;
    integer stall_len;
    reg [47:0] stall_pc;
    initial begin prev_stall = 1'b0; stall_len = 0; stall_pc = 0; end
    always @(posedge clk) begin
        if (rst) begin
            prev_stall <= 1'b0; stall_len <= 0; stall_pc <= 0;
        end else begin
            if (u_amber.w_stall) begin
                if (!prev_stall) begin
                    stall_len <= 0;
                    stall_pc  <= u_amber.r_ia_pc;
                end else begin
                    if (u_amber.r_ia_pc !== stall_pc) begin
                        $display("ERROR: PC changed during stall: %h -> %h", stall_pc, u_amber.r_ia_pc);
                        $fatal;
                    end
                end
                stall_len <= stall_len + 1;
            end else if (prev_stall) begin
                if (stall_len !== 3) begin
                    $display("ERROR: Stall length %0d (expected 3)", stall_len);
                    $fatal;
                end else begin
                    $display("Stall observed: length=3, PC=%h held", stall_pc);
                end
            end
            prev_stall <= u_amber.w_stall;
        end
    end

    // Detect SRHLT at WB and then validate architectural state
    always @(posedge clk) begin
        if (!rst) begin
            // SRHLT flows to WB with OPC_A.SUBOP_SRHLT
            if (u_amber.w_wb_opc == `OPC_SRHLT) begin
                // Forwarding results
                if (u_amber.u_reggp.r_gp[1] !== 24'd12) begin
                    $display("FORWARD GP tgt (EXMA) FAIL: DR1=%0d exp=12", u_amber.u_reggp.r_gp[1]);
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[2] !== 24'd13) begin
                    $display("FORWARD GP src (EXMA) FAIL: DR2=%0d exp=13", u_amber.u_reggp.r_gp[2]);
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[3] !== 24'd16) begin
                    $display("FORWARD GP tgt (MAMO) FAIL: DR3=%0d exp=16", u_amber.u_reggp.r_gp[3]);
                    $fatal;
                end
                if (u_amber.u_reggp.r_gp[4] !== 24'd9) begin
                    $display("FORWARD GP tgt (MOWB) FAIL: DR4=%0d exp=9", u_amber.u_reggp.r_gp[4]);
                    $fatal;
                end
                // Branch with forwarded flags (Z from MOVsi DR5,#0)
                if (u_amber.u_reggp.r_gp[6] !== 24'd7) begin
                    $display("FORWARD SR flags to branch FAIL: DR6=%0d exp=7", u_amber.u_reggp.r_gp[6]);
                    $fatal;
                end
                // AR forwarding and AR->DR move
                if (u_amber.u_reggp.r_gp[7] !== 24'd23) begin
                    $display("FORWARD AR src/tgt FAIL: DR7=%0d exp=23", u_amber.u_reggp.r_gp[7]);
                    $fatal;
                end
                // Store landed at memory[AR0] (word address 20)
                if (u_amber.u_dmem.r_mem[20] !== 24'h000055) begin
                    $display("STORE verify FAIL: mem[20]=%h exp=000055", u_amber.u_dmem.r_mem[20]);
                    $fatal;
                end
                $display("All hazard+forward checks PASSED");
                #5; $finish;
            end
        end
    end

    // Simple progress counter (optional)
    always @(posedge clk) if (!rst) tick <= tick + 1;
endmodule

