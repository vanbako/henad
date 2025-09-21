`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/csr.vh"

module mmu_tlb_tb;
    reg clk;
    reg rst;
    reg mode_kernel;

    // CSR interface
    reg                    csr_write_en;
    reg  [11:0]            csr_write_addr;
    reg  [23:0]            csr_write_data;
    reg                    csr_read_en;
    reg  [11:0]            csr_read_addr;
    wire [23:0]            csr_read_data;
    wire                   csr_read_valid;

    // Invalidation command wires
    reg                    tlbinv_all;
    reg                    tlbinv_asid_valid;
    reg  [15:0]            tlbinv_asid;
    reg                    tlbinv_page_valid;
    reg  [35:0]            tlbinv_page_vpn;
    reg                    tlbinv_page_global;

    // D-side request interface
    reg                    d_req_valid;
    reg  [47:0]            d_req_vaddr;
    reg                    d_req_is_store;
    wire                   d_stall;
    wire                   d_resp_valid;
    wire [47:0]            d_resp_paddr;
    wire [5:0]             d_resp_port;
    wire                   d_resp_linear;
    wire                   d_fault;
    wire [2:0]             d_fault_code;
    wire [47:0]            d_fault_vaddr;

    // ITLB interface not used in this unit test
    wire                   i_stall;
    wire                   i_resp_valid;
    wire [47:0]            i_resp_paddr;
    wire                   i_fault;
    wire [2:0]             i_fault_code;
    wire [47:0]            i_fault_vaddr;

    wire [3:0]             status_fault_bits;
    wire [47:0]            status_fault_va;
    wire                   status_busy;

    amber_mmu u_mmu(
        .iw_clk               (clk),
        .iw_rst               (rst),
        .iw_mode_kernel       (mode_kernel),
        .iw_flush             (1'b0),
        .iw_csr_read_en       (csr_read_en),
        .iw_csr_read_addr     (csr_read_addr),
        .ow_csr_read_data     (csr_read_data),
        .ow_csr_read_valid    (csr_read_valid),
        .iw_csr_write_en      (csr_write_en),
        .iw_csr_write_addr    (csr_write_addr),
        .iw_csr_write_data    (csr_write_data),
        .iw_tlbinv_all        (tlbinv_all),
        .iw_tlbinv_asid_valid (tlbinv_asid_valid),
        .iw_tlbinv_asid       (tlbinv_asid),
        .iw_tlbinv_page_valid (tlbinv_page_valid),
        .iw_tlbinv_page_vpn   (tlbinv_page_vpn),
        .iw_tlbinv_page_global(tlbinv_page_global),
        .iw_d_req_valid       (d_req_valid),
        .iw_d_req_vaddr       (d_req_vaddr),
        .iw_d_req_is_store    (d_req_is_store),
        .ow_d_stall           (d_stall),
        .ow_d_resp_valid      (d_resp_valid),
        .ow_d_resp_paddr      (d_resp_paddr),
        .ow_d_resp_port       (d_resp_port),
        .ow_d_resp_linear     (d_resp_linear),
        .ow_d_fault           (d_fault),
        .ow_d_fault_code      (d_fault_code),
        .ow_d_fault_vaddr     (d_fault_vaddr),
        .iw_i_req_valid       (1'b0),
        .iw_i_req_vaddr       (48'd0),
        .ow_i_stall           (i_stall),
        .ow_i_resp_valid      (i_resp_valid),
        .ow_i_resp_paddr      (i_resp_paddr),
        .ow_i_fault           (i_fault),
        .ow_i_fault_code      (i_fault_code),
        .ow_i_fault_vaddr     (i_fault_vaddr),
        .ow_status_fault_bits (status_fault_bits),
        .ow_status_fault_va   (status_fault_va),
        .ow_status_busy       (status_busy)
    );

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        mode_kernel = 1'b1;
        csr_write_en = 1'b0;
        csr_write_addr = 12'd0;
        csr_write_data = 24'd0;
        csr_read_en = 1'b0;
        csr_read_addr = 12'd0;
        tlbinv_all = 1'b0;
        tlbinv_asid_valid = 1'b0;
        tlbinv_asid = 16'd0;
        tlbinv_page_valid = 1'b0;
        tlbinv_page_vpn = 36'd0;
        tlbinv_page_global = 1'b0;
        d_req_valid = 1'b0;
        d_req_vaddr = 48'd0;
        d_req_is_store = 1'b0;
        repeat (4) @(posedge clk);
        rst = 1'b0;
    end

    // Utility tasks
    task csr_write;
        input [11:0] addr;
        input [23:0] data;
        begin
            @(negedge clk);
            csr_write_addr <= addr;
            csr_write_data <= data;
            csr_write_en   <= 1'b1;
            @(negedge clk);
            csr_write_en   <= 1'b0;
        end
    endtask

    task set_asid;
        input [15:0] asid;
        begin
            csr_write(`CSR_IDX_MMU_ASID, {asid, 8'd0});
        end
    endtask

    task enable_dtlb;
        begin
            csr_write(`CSR_IDX_MMU_CFG, 24'h000005); // EN | EN_DTLB
        end
    endtask

    task write_tlb_entry;
        input        is_dtlb;
        input [4:0]  idx;
        input [35:0] vpn;
        input [29:0] ppn;
        input [5:0]  perm;
        input [7:0]  asid_tag;
        input        is_global;
        begin
            csr_write(`CSR_IDX_MMU_TLBIDX, {18'd0, is_dtlb, idx});
            csr_write(`CSR_IDX_MMU_TLBVPN_LO, vpn[23:0]);
            csr_write(`CSR_IDX_MMU_TLBVPN_HI, {12'd0, vpn[35:24]});
            csr_write(`CSR_IDX_MMU_TLBDATA_LO, {ppn[11:0], 6'd0, perm});
            csr_write(`CSR_IDX_MMU_TLBDATA_HI, {6'd0, ppn[29:12]});
            csr_write(`CSR_IDX_MMU_TLBMETA, {8'd0, asid_tag, 2'b00, 1'b0, 1'b0, 1'b0, 1'b0, is_global, 1'b1});
        end
    endtask

    task tlbinv_all_pulse;
        begin
            @(negedge clk);
            tlbinv_all <= 1'b1;
            @(negedge clk);
            tlbinv_all <= 1'b0;
        end
    endtask

    task tlbinv_asid_pulse;
        input [15:0] asid;
        begin
            @(negedge clk);
            tlbinv_asid <= asid;
            tlbinv_asid_valid <= 1'b1;
            @(negedge clk);
            tlbinv_asid_valid <= 1'b0;
        end
    endtask

    task tlbinv_page_pulse;
        input [35:0] vpn;
        begin
            @(negedge clk);
            tlbinv_page_vpn <= vpn;
            tlbinv_page_global <= 1'b1;
            tlbinv_page_valid <= 1'b1;
            @(negedge clk);
            tlbinv_page_valid <= 1'b0;
            tlbinv_page_global <= 1'b0;
        end
    endtask

    task expect_translation;
        input [47:0] va;
        input [47:0] pa;
        begin
            @(negedge clk);
            d_req_vaddr    <= va;
            d_req_is_store <= 1'b0;
            d_req_valid    <= 1'b1;
            @(posedge clk);
            #1;
            if (!d_resp_valid || d_fault) begin
                $fatal(1, "Expected translation for VA %h, got fault=%0d code=%0d", va, d_fault, d_fault_code);
            end
            if (d_resp_paddr !== pa) begin
                $fatal(1, "Expected PA %h, got %h", pa, d_resp_paddr);
            end
            @(negedge clk);
            d_req_valid <= 1'b0;
        end
    endtask

    task expect_fault;
        input [47:0] va;
        input        is_store;
        input [2:0]  code;
        begin
            @(negedge clk);
            d_req_vaddr    <= va;
            d_req_is_store <= is_store;
            d_req_valid    <= 1'b1;
            @(posedge clk);
            #1;
            if (!d_fault) begin
                $fatal(1, "Expected fault code %0d for VA %h, but translation succeeded", code, va);
            end
            if (d_fault_code !== code) begin
                $fatal(1, "Expected fault code %0d, got %0d", code, d_fault_code);
            end
            @(negedge clk);
            d_req_valid    <= 1'b0;
            d_req_is_store <= 1'b0;
        end
    endtask

    localparam [47:0] VA0  = 48'h0000_0000_1000;
    localparam [35:0] VPN0 = VA0[47:12];
    localparam [29:0] PPN0 = 30'h00000002;
    localparam [47:0] PA0  = {6'd0, PPN0, 12'h000};

    localparam [47:0] VA1  = 48'h0000_0000_2000;
    localparam [35:0] VPN1 = VA1[47:12];
    localparam [29:0] PPN1 = 30'h00000003;
    localparam [47:0] PA1  = {6'd0, PPN1, 12'h000};

    initial begin
        @(negedge rst);
        enable_dtlb();
        set_asid(16'h0001);

        // Program entry 0 with R/W/X permissions (ASID=1)
        write_tlb_entry(1'b1, 5'd0, VPN0, PPN0, 6'b000111, 8'h01, 1'b0);
        expect_translation(VA0, PA0);

        // Disallow stores and expect PERM fault
        write_tlb_entry(1'b1, 5'd0, VPN0, PPN0, 6'b000101, 8'h01, 1'b0);
        expect_fault(VA0, 1'b1, 3'd1);

        // Restore write permission and verify again
        write_tlb_entry(1'b1, 5'd0, VPN0, PPN0, 6'b000111, 8'h01, 1'b0);
        expect_translation(VA0, PA0);

        // Page invalidation removes entry
        tlbinv_page_pulse(VPN0);
        expect_fault(VA0, 1'b0, 3'd0);

        // Reinstall entry and test TLBINV_ALL
        write_tlb_entry(1'b1, 5'd0, VPN0, PPN0, 6'b000111, 8'h01, 1'b0);
        expect_translation(VA0, PA0);
        tlbinv_all_pulse();
        expect_fault(VA0, 1'b0, 3'd0);

        // Install two entries with different ASIDs
        write_tlb_entry(1'b1, 5'd0, VPN0, PPN0, 6'b000111, 8'h02, 1'b0);
        write_tlb_entry(1'b1, 5'd1, VPN1, PPN1, 6'b000111, 8'h03, 1'b0);

        // With ASID=2 only VA0 should translate
        set_asid(16'h0002);
        expect_translation(VA0, PA0);
        expect_fault(VA1, 1'b0, 3'd0);

        // With ASID=3 only VA1 should translate
        set_asid(16'h0003);
        expect_translation(VA1, PA1);

        // Invalidate ASID=3 entries, expect miss
        tlbinv_asid_pulse(16'h0003);
        expect_fault(VA1, 1'b0, 3'd0);

        $display("mmu_tlb_tb: PASS");
        $finish;
    end
endmodule
