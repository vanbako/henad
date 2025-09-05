`timescale 1ns/1ps
`include "src/sizes.vh"
`include "src/csr.vh"

module math24_async_tb;
    reg clk = 0;
    reg rst = 1;
    always #5 clk = ~clk; // 100MHz

    // regcsr <-> math wiring
    reg  [`HBIT_TGT_CSR:0] cpu_waddr;
    reg  [`HBIT_DATA:0]    cpu_wdata;
    reg                    cpu_wen;
    wire [`HBIT_TGT_CSR:0] raddr1;
    wire [`HBIT_TGT_CSR:0] raddr2;
    reg  [`HBIT_TGT_CSR:0] cpu_raddr1;
    reg  [`HBIT_TGT_CSR:0] cpu_raddr2;
    wire [`HBIT_DATA:0]    csr_rdata1;
    wire [`HBIT_DATA:0]    csr_rdata2;

    wire                    w2_en;
    wire [`HBIT_TGT_CSR:0] w2_addr;
    wire [`HBIT_DATA:0]    w2_data;

    wire [`HBIT_DATA:0] math_ctrl;
    wire [`HBIT_DATA:0] math_opa;
    wire [`HBIT_DATA:0] math_opb;
    wire [`HBIT_DATA:0] math_opc;

    // regcsr under test
    regcsr u_regcsr(
        .iw_clk(clk), .iw_rst(rst),
        .iw_read_addr1(cpu_raddr1), .iw_read_addr2(cpu_raddr2),
        .iw_write_addr(cpu_waddr), .iw_write_data(cpu_wdata), .iw_write_enable(cpu_wen),
        .iw_w2_enable(w2_en), .iw_w2_addr(w2_addr), .iw_w2_data(w2_data),
        .ow_read_data1(csr_rdata1), .ow_read_data2(csr_rdata2),
        .ow_math_ctrl(math_ctrl), .ow_math_opa(math_opa), .ow_math_opb(math_opb), .ow_math_opc(math_opc)
    );

    // math engine
    math24_async u_math(
        .iw_clk(clk), .iw_rst(rst),
        .iw_math_ctrl(math_ctrl), .iw_math_opa(math_opa), .iw_math_opb(math_opb), .iw_math_opc(math_opc),
        .ow_csr_wen(w2_en), .ow_csr_waddr(w2_addr), .ow_csr_wdata(w2_data)
    );

    // Helpers
    task csr_write(input [7:0] idx, input [23:0] data);
        begin
            @(negedge clk);
            cpu_waddr <= idx; cpu_wdata <= data; cpu_wen <= 1'b1;
            @(negedge clk);
            cpu_wen <= 1'b0;
        end
    endtask

    task csr_read_t(input [7:0] idx, output [23:0] data);
        begin
            @(negedge clk);
            cpu_raddr1 <= idx;
            @(negedge clk);
            data = csr_rdata1;
        end
    endtask

    task start_op(input [3:0] op);
        begin
            csr_write(`CSR_IDX_MATH_CTRL, {19'd0, op, 1'b1});
        end
    endtask

    task wait_ready;
        reg [23:0] st;
        begin
            repeat (40) begin
                csr_read_t(`CSR_IDX_MATH_STATUS, st);
                if (st[0]) disable wait_ready;
            end
        end
    endtask

    // signed helpers
    function integer s24_to_int(input [23:0] v);
        begin
            s24_to_int = (v[23] ? -((~v + 1) & 24'hFFFFFF) : v);
        end
    endfunction

    function [23:0] int_to_s24(input integer x);
        integer y;
        begin
            y = x;
            if (y < 0) int_to_s24 = (~((-y) & 24'hFFFFFF) + 1) & 24'hFFFFFF;
            else       int_to_s24 = y & 24'hFFFFFF;
        end
    endfunction

    integer errors;
    initial begin
        cpu_waddr = 0; cpu_wdata = 0; cpu_wen = 0; cpu_raddr1 = 0; cpu_raddr2 = 0;
        errors = 0;
        #1; rst = 1; repeat (2) @(negedge clk); rst = 0; @(negedge clk);

        // MULU: 0x00FF00 * 0x10 = 0x0FF000
        csr_write(`CSR_IDX_MATH_OPA, 24'h00FF00);
        csr_write(`CSR_IDX_MATH_OPB, 24'h000010);
        start_op(4'h0);
        wait_ready;
        begin reg [23:0] rd;
            csr_read_t(`CSR_IDX_MATH_RES0, rd); if (rd !== 24'h0FF000) begin errors = errors + 1; $display("FAIL: MULU RES0"); end
            csr_read_t(`CSR_IDX_MATH_RES1, rd); if (rd !== 24'h000000) begin errors = errors + 1; $display("FAIL: MULU RES1"); end
        end

        // DIVU: 100 / 7 -> q=14 r=2
        csr_write(`CSR_IDX_MATH_OPA, 24'd100);
        csr_write(`CSR_IDX_MATH_OPB, 24'd7);
        start_op(4'h1);
        wait_ready;
        begin reg [23:0] rd;
            csr_read_t(`CSR_IDX_MATH_RES0, rd); if (rd !== 24'd14) begin errors = errors + 1; $display("FAIL: DIVU q"); end
            csr_read_t(`CSR_IDX_MATH_RES1, rd); if (rd !== 24'd2)  begin errors = errors + 1; $display("FAIL: DIVU r"); end
        end

        // DIVS: (-100) / 7 -> q=-14 r=-2 (C semantics)
        csr_write(`CSR_IDX_MATH_OPA, int_to_s24(-100));
        csr_write(`CSR_IDX_MATH_OPB, 24'd7);
        start_op(4'h5);
        wait_ready;
        begin reg [23:0] rdq, rdr;
            csr_read_t(`CSR_IDX_MATH_RES0, rdq); if (s24_to_int(rdq) !== -14) begin errors = errors + 1; $display("FAIL: DIVS q"); end
            csr_read_t(`CSR_IDX_MATH_RES1, rdr); if (s24_to_int(rdr) !== -2)  begin errors = errors + 1; $display("FAIL: DIVS r"); end
        end

        // MIN_U: min(5,9)=5
        csr_write(`CSR_IDX_MATH_OPA, 24'd5);
        csr_write(`CSR_IDX_MATH_OPB, 24'd9);
        start_op(4'h8);
        wait_ready;
        begin reg [23:0] rd;
            csr_read_t(`CSR_IDX_MATH_RES0, rd); if (rd !== 24'd5) begin errors = errors + 1; $display("FAIL: MIN_U"); end
        end

        // MAX_S: max(-5, 3)=3
        csr_write(`CSR_IDX_MATH_OPA, int_to_s24(-5));
        csr_write(`CSR_IDX_MATH_OPB, 24'd3);
        start_op(4'hB);
        wait_ready;
        begin reg [23:0] rd;
            csr_read_t(`CSR_IDX_MATH_RES0, rd); if (s24_to_int(rd) !== 3) begin errors = errors + 1; $display("FAIL: MAX_S"); end
        end

        // ABS_S: |-7| = 7
        csr_write(`CSR_IDX_MATH_OPA, int_to_s24(-7));
        start_op(4'h7);
        wait_ready;
        begin reg [23:0] rd;
            csr_read_t(`CSR_IDX_MATH_RES0, rd); if (rd !== 24'd7) begin errors = errors + 1; $display("FAIL: ABS_S"); end
        end

        // CLAMP_U: clamp(30, [10,20]) => 20
        csr_write(`CSR_IDX_MATH_OPA, 24'd30);
        csr_write(`CSR_IDX_MATH_OPB, 24'd20); // max
        csr_write(`CSR_IDX_MATH_OPC, 24'd10); // min
        start_op(4'hC);
        wait_ready;
        begin reg [23:0] rd;
            csr_read_t(`CSR_IDX_MATH_RES0, rd); if (rd !== 24'd20) begin errors = errors + 1; $display("FAIL: CLAMP_U"); end
        end

        // CLAMP_S: clamp(-10, [-5,15]) => -5
        csr_write(`CSR_IDX_MATH_OPA, int_to_s24(-10));
        csr_write(`CSR_IDX_MATH_OPB, 24'd15); // max
        csr_write(`CSR_IDX_MATH_OPC, int_to_s24(-5)); // min
        start_op(4'hD);
        wait_ready;
        begin reg [23:0] rd;
            csr_read_t(`CSR_IDX_MATH_RES0, rd); if (s24_to_int(rd) !== -5) begin errors = errors + 1; $display("FAIL: CLAMP_S"); end
        end

        // SQRTU: sqrt(144^2)=144
        csr_write(`CSR_IDX_MATH_OPA, 24'd20736);
        start_op(4'h3);
        wait_ready;
        begin reg [23:0] rd;
            csr_read_t(`CSR_IDX_MATH_RES0, rd); if (rd !== 24'd144) begin errors = errors + 1; $display("FAIL: SQRTU"); end
        end

        // DIVU div0 check
        csr_write(`CSR_IDX_MATH_OPA, 24'd123);
        csr_write(`CSR_IDX_MATH_OPB, 24'd0);
        start_op(4'h1);
        wait_ready;
        begin reg [23:0] st_div0; reg [23:0] r0, r1;
            csr_read_t(`CSR_IDX_MATH_STATUS, st_div0);
            csr_read_t(`CSR_IDX_MATH_RES0, r0);
            csr_read_t(`CSR_IDX_MATH_RES1, r1);
            if (st_div0[2] !== 1'b1) begin errors = errors + 1; $display("FAIL: DIV0 flag, STATUS=%h RES0=%h RES1=%h", st_div0, r0, r1); end
        end

        if (errors == 0) $display("math24_async_tb: PASS");
        else $display("math24_async_tb: FAIL (%0d errors)", errors);
        $finish;
    end
endmodule
