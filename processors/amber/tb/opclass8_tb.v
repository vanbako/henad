`timescale 1ns/1ps

module opclass8_tb;
    reg clk;
    reg rst;

    amber dut(
        .iw_clk(clk),
        .iw_rst(rst)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        // Preload program into instruction memory before releasing reset
        dut.u_imem.r_mem[0] = 24'h111ACE; // MOVui #0x0ACE, DR1
        dut.u_imem.r_mem[1] = 24'h811321; // CSRWR DR1, #0x321
        dut.u_imem.r_mem[2] = 24'h311000; // MOVsi #0, DR1 (clear)
        dut.u_imem.r_mem[3] = 24'h802321; // CSRRD #0x321, DR2
        dut.u_imem.r_mem[4] = 24'h803000; // CSRRD STATUS, DR3
        dut.u_imem.r_mem[5] = 24'h900000; // HLT

        // Allow a couple of cycles in reset for pipeline state to clear
        repeat (3) @(posedge clk);
        rst = 1'b0;

        // Run long enough for the short program to retire
        repeat (40) @(posedge clk);

        // Validate CSR write/read via DR2
        if (dut.u_reggp.r_gp[2] !== 24'h00ACE) begin
            $display("opclass8_tb FAIL: DR2=%h (expected 00ACE)", dut.u_reggp.r_gp[2]);
            $fatal;
        end
        if (dut.u_regcsr.r_csr[12'h321] !== 24'h00ACE) begin
            $display("opclass8_tb FAIL: CSR[0x321]=%h (expected 00ACE)", dut.u_regcsr.r_csr[12'h321]);
            $fatal;
        end
        // STATUS read should reflect kernel mode bit set
        if (dut.u_reggp.r_gp[3] !== 24'h000001) begin
            $display("opclass8_tb FAIL: STATUS read unexpected value %h", dut.u_reggp.r_gp[3]);
            $fatal;
        end

        $display("opclass8_tb PASS");
        $finish;
    end
endmodule
