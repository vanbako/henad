`include "src/sizes.vh"
`include "src/csr.vh"

// Amber MMU (TLB + CSR window). This implementation currently provides
// fully-associative ITLB/DTLBs with manual CSR population. A hardware
// page-table walker will plug into the existing hooks in a follow-up.
module amber_mmu #(
    parameter ITLB_ENTRIES = 32,
    parameter DTLB_ENTRIES = 32
)(
    input  wire                   iw_clk,
    input  wire                   iw_rst,
    input  wire                   iw_mode_kernel,
    input  wire                   iw_flush,
    // CSR access from WB stage (writes) / EX stage (reads)
    input  wire                   iw_csr_read_en,
    input  wire [`HBIT_TGT_CSR:0] iw_csr_read_addr,
    output reg  [`HBIT_DATA:0]    ow_csr_read_data,
    output reg                    ow_csr_read_valid,
    input  wire                   iw_csr_write_en,
    input  wire [`HBIT_TGT_CSR:0] iw_csr_write_addr,
    input  wire [`HBIT_DATA:0]    iw_csr_write_data,
    // TLB invalidation commands (pulses)
    input  wire                   iw_tlbinv_all,
    input  wire                   iw_tlbinv_asid_valid,
    input  wire [15:0]            iw_tlbinv_asid,
    input  wire                   iw_tlbinv_page_valid,
    input  wire [35:0]            iw_tlbinv_page_vpn,
    input  wire                   iw_tlbinv_page_global,
    // D-side translation request
    input  wire                   iw_d_req_valid,
    input  wire [47:0]            iw_d_req_vaddr,
    input  wire                   iw_d_req_is_store,
    output wire                   ow_d_stall,
    output reg                    ow_d_resp_valid,
    output reg  [47:0]            ow_d_resp_paddr,
    output reg  [5:0]             ow_d_resp_port,
    output reg                    ow_d_resp_linear,
    output reg                    ow_d_fault,
    output reg  [2:0]             ow_d_fault_code,
    output reg  [47:0]            ow_d_fault_vaddr,
    // I-side translation request (optional; disabled when EN_ITLB=0)
    input  wire                   iw_i_req_valid,
    input  wire [47:0]            iw_i_req_vaddr,
    output wire                   ow_i_stall,
    output reg                    ow_i_resp_valid,
    output reg  [47:0]            ow_i_resp_paddr,
    output reg                    ow_i_fault,
    output reg  [2:0]             ow_i_fault_code,
    output reg  [47:0]            ow_i_fault_vaddr,
    // Status mirror for top-level trap wiring
    output reg  [3:0]             ow_status_fault_bits,
    output reg  [47:0]            ow_status_fault_va,
    output reg                    ow_status_busy
);

    localparam VPN_BITS = 36; // virtual page number bits (48-12)
    localparam PPN_BITS = 30; // physical page number bits (48-12-6)
    localparam TLB_ADDR_BITS = 6; // supports up to 64 entries

    // ---------------------------------------------------------------------
    // CSR registers
    // ---------------------------------------------------------------------
    reg [23:0] r_cfg;       // MMU_CFG
    reg [23:0] r_status;    // MMU_STATUS
    reg [47:0] r_root;      // MMU_ROOT
    reg [23:0] r_asid_reg;  // MMU_ASID (bits[23:8]=ASID, bit1 shared, bit0 mode mirror)
    reg [47:0] r_walk_base; // MMU_WALK_BASE
    reg [47:0] r_walk_len;  // MMU_WALK_LEN
    reg [63:0] r_portmask;  // MMU_PORTMASK (only bits[63:0] used)
    reg [47:0] r_fault_va;  // MMU_FAULT_VA
    reg [5:0]  r_tlbidx;    // [4:0]=entry, [5]=TLB select (0=ITLB,1=DTLB)
    reg [VPN_BITS-1:0] r_csr_tlbvpn; // helper for manual fills
    reg [PPN_BITS-1:0] r_csr_tlbppn;
    reg [5:0]          r_csr_tlbport;
    reg [5:0]          r_csr_tlbperm;
    reg [15:0]         r_csr_tlbasid;
    reg                r_csr_tlbvalid;
    reg                r_csr_tlbglobal;
    reg                r_csr_tlb_nu;
    reg                r_csr_tlb_ns;
    reg                r_csr_tlb_nl;
    reg                r_csr_tlb_accessed;
    reg                r_csr_tlb_dirty;

    wire w_cfg_en      = r_cfg[0];
    wire w_cfg_en_itlb = r_cfg[1];
    wire w_cfg_en_dtlb = r_cfg[2];

    wire [15:0] w_current_asid = r_asid_reg[23:8];

    // Update status mirror outputs
    always @(*) begin
        ow_status_fault_bits = r_status[3:0];
        ow_status_fault_va   = r_fault_va;
        ow_status_busy       = r_status[4];
    end

    // ---------------------------------------------------------------------
    // ITLB/DTLB storage
    // ---------------------------------------------------------------------
    reg                 r_itlb_valid   [0:ITLB_ENTRIES-1];
    reg                 r_itlb_global  [0:ITLB_ENTRIES-1];
    reg [15:0]          r_itlb_asid    [0:ITLB_ENTRIES-1];
    reg [VPN_BITS-1:0]  r_itlb_vpn     [0:ITLB_ENTRIES-1];
    reg [PPN_BITS-1:0]  r_itlb_ppn     [0:ITLB_ENTRIES-1];
    reg [5:0]           r_itlb_port    [0:ITLB_ENTRIES-1];
    reg [5:0]           r_itlb_perm    [0:ITLB_ENTRIES-1]; // [0]=R, [1]=W, [2]=X, [3]=NU, [4]=NS, [5]=NL
    reg                 r_itlb_accessed[0:ITLB_ENTRIES-1];

    reg                 r_dtlb_valid   [0:DTLB_ENTRIES-1];
    reg                 r_dtlb_global  [0:DTLB_ENTRIES-1];
    reg [15:0]          r_dtlb_asid    [0:DTLB_ENTRIES-1];
    reg [VPN_BITS-1:0]  r_dtlb_vpn     [0:DTLB_ENTRIES-1];
    reg [PPN_BITS-1:0]  r_dtlb_ppn     [0:DTLB_ENTRIES-1];
    reg [5:0]           r_dtlb_port    [0:DTLB_ENTRIES-1];
    reg [5:0]           r_dtlb_perm    [0:DTLB_ENTRIES-1];
    reg                 r_dtlb_accessed[0:DTLB_ENTRIES-1];
    reg                 r_dtlb_dirty   [0:DTLB_ENTRIES-1];

    integer i;

    // Reset / CSR writes / invalidations / access tracking
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_cfg       <= 24'd0;
            r_status    <= 24'd0;
            r_root      <= 48'd0;
            r_asid_reg  <= 24'd0;
            r_walk_base <= 48'd0;
            r_walk_len  <= 48'd0;
            r_portmask  <= 64'hFFFF_FFFF_FFFF_FFFF;
            r_fault_va  <= 48'd0;
            r_tlbidx    <= 6'd0;
            r_csr_tlbvpn    <= {VPN_BITS{1'b0}};
            r_csr_tlbppn    <= {PPN_BITS{1'b0}};
            r_csr_tlbport   <= 6'd0;
            r_csr_tlbperm   <= 6'd0;
            r_csr_tlbasid   <= 16'd0;
            r_csr_tlbvalid  <= 1'b0;
            r_csr_tlbglobal <= 1'b0;
            r_csr_tlb_nu    <= 1'b0;
            r_csr_tlb_ns    <= 1'b0;
            r_csr_tlb_nl    <= 1'b0;
            r_csr_tlb_accessed <= 1'b0;
            r_csr_tlb_dirty <= 1'b0;
            for (i = 0; i < ITLB_ENTRIES; i = i + 1) begin
                r_itlb_valid[i]    <= 1'b0;
                r_itlb_global[i]   <= 1'b0;
                r_itlb_asid[i]     <= 16'd0;
                r_itlb_vpn[i]      <= {VPN_BITS{1'b0}};
                r_itlb_ppn[i]      <= {PPN_BITS{1'b0}};
                r_itlb_port[i]     <= 6'd0;
                r_itlb_perm[i]     <= 6'd0;
                r_itlb_accessed[i] <= 1'b0;
            end
            for (i = 0; i < DTLB_ENTRIES; i = i + 1) begin
                r_dtlb_valid[i]    <= 1'b0;
                r_dtlb_global[i]   <= 1'b0;
                r_dtlb_asid[i]     <= 16'd0;
                r_dtlb_vpn[i]      <= {VPN_BITS{1'b0}};
                r_dtlb_ppn[i]      <= {PPN_BITS{1'b0}};
                r_dtlb_port[i]     <= 6'd0;
                r_dtlb_perm[i]     <= 6'd0;
                r_dtlb_accessed[i] <= 1'b0;
                r_dtlb_dirty[i]    <= 1'b0;
            end
        end else begin
            // Mirror current privilege mode in ASID register bit0 so CSRRD observes it
            r_asid_reg[0] <= iw_mode_kernel ? 1'b1 : 1'b0;
            // CSR writes (kernel-only)
            if (iw_csr_write_en && iw_mode_kernel) begin
                case (iw_csr_write_addr)
                    `CSR_IDX_MMU_CFG:          r_cfg       <= iw_csr_write_data;
                    `CSR_IDX_MMU_STATUS:       r_status    <= r_status & ~iw_csr_write_data; // write-1-to-clear
                    `CSR_IDX_MMU_ROOT_LO:      r_root[23:0]   <= iw_csr_write_data;
                    `CSR_IDX_MMU_ROOT_HI:      r_root[47:24]  <= iw_csr_write_data;
                    `CSR_IDX_MMU_ASID: begin
                        r_asid_reg[23:1] <= iw_csr_write_data[23:1];
                        // bit0 handled outside to mirror mode
                    end
                    `CSR_IDX_MMU_WALK_BASE_LO: r_walk_base[23:0]  <= iw_csr_write_data;
                    `CSR_IDX_MMU_WALK_BASE_HI: r_walk_base[47:24] <= iw_csr_write_data;
                    `CSR_IDX_MMU_WALK_LEN_LO:  r_walk_len[23:0]   <= iw_csr_write_data;
                    `CSR_IDX_MMU_WALK_LEN_HI:  r_walk_len[47:24]  <= iw_csr_write_data;
                    `CSR_IDX_MMU_PORTMASK0:    r_portmask[23:0]   <= iw_csr_write_data;
                    `CSR_IDX_MMU_PORTMASK1:    r_portmask[47:24]  <= iw_csr_write_data;
                    `CSR_IDX_MMU_PORTMASK2:    r_portmask[63:48]  <= iw_csr_write_data[15:0];
                    `CSR_IDX_MMU_FAULT_VA_LO:  r_fault_va[23:0]   <= iw_csr_write_data;
                    `CSR_IDX_MMU_FAULT_VA_HI:  r_fault_va[47:24]  <= iw_csr_write_data;
                    `CSR_IDX_MMU_TLBIDX:       r_tlbidx          <= iw_csr_write_data[5:0];
                    `CSR_IDX_MMU_TLBVPN_LO:    r_csr_tlbvpn[23:0] <= iw_csr_write_data;
                    `CSR_IDX_MMU_TLBVPN_HI:    r_csr_tlbvpn[VPN_BITS-1:24] <= iw_csr_write_data[11:0];
                    `CSR_IDX_MMU_TLBDATA_LO: begin
                        r_csr_tlbperm <= iw_csr_write_data[5:0];
                        r_csr_tlbport <= iw_csr_write_data[11:6];
                        r_csr_tlbppn[11:0] <= iw_csr_write_data[23:12];
                        r_csr_tlb_nl  <= iw_csr_write_data[5];
                    end
                    `CSR_IDX_MMU_TLBDATA_HI: begin
                        r_csr_tlbppn[PPN_BITS-1:12] <= iw_csr_write_data[PPN_BITS-12-1:0];
                    end
                    `CSR_IDX_MMU_TLBMETA: begin
                        r_csr_tlbvalid   <= iw_csr_write_data[0];
                        r_csr_tlbglobal  <= iw_csr_write_data[1];
                        r_csr_tlb_nu     <= iw_csr_write_data[2];
                        r_csr_tlb_ns     <= iw_csr_write_data[3];
                        r_csr_tlb_accessed <= iw_csr_write_data[4];
                        r_csr_tlb_dirty  <= iw_csr_write_data[5];
                        r_csr_tlbasid    <= iw_csr_write_data[15:8];
                        // Commit entry on META write
                        if (!r_tlbidx[5]) begin
                            if (r_tlbidx[4:0] < ITLB_ENTRIES) begin
                                r_itlb_valid[r_tlbidx[4:0]]    <= iw_csr_write_data[0];
                                r_itlb_global[r_tlbidx[4:0]]   <= iw_csr_write_data[1];
                                r_itlb_asid[r_tlbidx[4:0]]     <= {8'd0, iw_csr_write_data[15:8]};
                                r_itlb_vpn[r_tlbidx[4:0]]      <= r_csr_tlbvpn;
                                r_itlb_ppn[r_tlbidx[4:0]]      <= r_csr_tlbppn;
                                r_itlb_port[r_tlbidx[4:0]]     <= r_csr_tlbport;
                                r_itlb_perm[r_tlbidx[4:0]]     <= r_csr_tlbperm;
                                r_itlb_accessed[r_tlbidx[4:0]] <= iw_csr_write_data[4];
                            end
                        end else begin
                            if (r_tlbidx[4:0] < DTLB_ENTRIES) begin
                                r_dtlb_valid[r_tlbidx[4:0]]    <= iw_csr_write_data[0];
                                r_dtlb_global[r_tlbidx[4:0]]   <= iw_csr_write_data[1];
                                r_dtlb_asid[r_tlbidx[4:0]]     <= {8'd0, iw_csr_write_data[15:8]};
                                r_dtlb_vpn[r_tlbidx[4:0]]      <= r_csr_tlbvpn;
                                r_dtlb_ppn[r_tlbidx[4:0]]      <= r_csr_tlbppn;
                                r_dtlb_port[r_tlbidx[4:0]]     <= r_csr_tlbport;
                                r_dtlb_perm[r_tlbidx[4:0]]     <= r_csr_tlbperm;
                                r_dtlb_accessed[r_tlbidx[4:0]] <= iw_csr_write_data[4];
                                r_dtlb_dirty[r_tlbidx[4:0]]    <= iw_csr_write_data[5];
                            end
                        end
                    end
                endcase
            end

            // TLB invalidations
            if (iw_tlbinv_all) begin
                for (i = 0; i < ITLB_ENTRIES; i = i + 1)
                    r_itlb_valid[i] <= 1'b0;
                for (i = 0; i < DTLB_ENTRIES; i = i + 1)
                    r_dtlb_valid[i] <= 1'b0;
            end else if (iw_tlbinv_asid_valid) begin
                for (i = 0; i < ITLB_ENTRIES; i = i + 1) begin
                    if (r_itlb_valid[i] && !r_itlb_global[i] && (r_itlb_asid[i] == iw_tlbinv_asid))
                        r_itlb_valid[i] <= 1'b0;
                end
                for (i = 0; i < DTLB_ENTRIES; i = i + 1) begin
                    if (r_dtlb_valid[i] && !r_dtlb_global[i] && (r_dtlb_asid[i] == iw_tlbinv_asid))
                        r_dtlb_valid[i] <= 1'b0;
                end
            end else if (iw_tlbinv_page_valid) begin
                for (i = 0; i < ITLB_ENTRIES; i = i + 1) begin
                    if (r_itlb_valid[i] && (r_itlb_vpn[i] == iw_tlbinv_page_vpn)) begin
                        if (iw_tlbinv_page_global || !r_itlb_global[i])
                            r_itlb_valid[i] <= 1'b0;
                    end
                end
                for (i = 0; i < DTLB_ENTRIES; i = i + 1) begin
                    if (r_dtlb_valid[i] && (r_dtlb_vpn[i] == iw_tlbinv_page_vpn)) begin
                        if (iw_tlbinv_page_global || !r_dtlb_global[i])
                            r_dtlb_valid[i] <= 1'b0;
                    end
                end
            end

            // Accessed / dirty tracking (D path)
            if (w_cfg_en && w_cfg_en_dtlb && iw_d_req_valid && w_d_hit && (w_d_fault_kind == 2'd0)) begin
                if (w_d_hit_idx < DTLB_ENTRIES) begin
                    r_dtlb_accessed[w_d_hit_idx] <= 1'b1;
                    if (iw_d_req_is_store)
                        r_dtlb_dirty[w_d_hit_idx] <= 1'b1;
                end
            end
        end
    end

    // ---------------------------------------------------------------------
    // CSR read mux
    // ---------------------------------------------------------------------
    always @(*) begin
        ow_csr_read_valid = 1'b0;
        ow_csr_read_data  = {(`HBIT_DATA+1){1'b0}};
        if (iw_csr_read_en) begin
            case (iw_csr_read_addr)
                `CSR_IDX_MMU_CFG: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = iw_mode_kernel ? r_cfg : {23'd0, r_cfg[0]};
                end
                `CSR_IDX_MMU_STATUS: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = iw_mode_kernel ? r_status : 24'd0;
                end
                `CSR_IDX_MMU_ROOT_LO: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_root[23:0];
                end
                `CSR_IDX_MMU_ROOT_HI: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_root[47:24];
                end
                `CSR_IDX_MMU_ASID: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_asid_reg;
                end
                `CSR_IDX_MMU_WALK_BASE_LO: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_walk_base[23:0];
                end
                `CSR_IDX_MMU_WALK_BASE_HI: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_walk_base[47:24];
                end
                `CSR_IDX_MMU_WALK_LEN_LO: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_walk_len[23:0];
                end
                `CSR_IDX_MMU_WALK_LEN_HI: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_walk_len[47:24];
                end
                `CSR_IDX_MMU_PORTMASK0: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_portmask[23:0];
                end
                `CSR_IDX_MMU_PORTMASK1: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_portmask[47:24];
                end
                `CSR_IDX_MMU_PORTMASK2: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = {8'd0, r_portmask[63:48]};
                end
                `CSR_IDX_MMU_FAULT_VA_LO: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_fault_va[23:0];
                end
                `CSR_IDX_MMU_FAULT_VA_HI: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_fault_va[47:24];
                end
                `CSR_IDX_MMU_TLBIDX: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = {18'd0, r_tlbidx};
                end
                `CSR_IDX_MMU_TLBVPN_LO: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = r_csr_tlbvpn[23:0];
                end
                `CSR_IDX_MMU_TLBVPN_HI: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = {12'd0, r_csr_tlbvpn[VPN_BITS-1:24]};
                end
                `CSR_IDX_MMU_TLBDATA_LO: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = {r_csr_tlbppn[11:0], r_csr_tlbport, r_csr_tlbperm};
                end
                `CSR_IDX_MMU_TLBDATA_HI: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = {{(24-(PPN_BITS-12)){1'b0}}, r_csr_tlbppn[PPN_BITS-1:12]};
                end
                `CSR_IDX_MMU_TLBMETA: begin
                    ow_csr_read_valid = 1'b1;
                    ow_csr_read_data  = {8'd0, r_csr_tlbasid, r_csr_tlb_dirty, r_csr_tlb_accessed, r_csr_tlb_ns, r_csr_tlb_nu, r_csr_tlbglobal, r_csr_tlbvalid};
                end
                default: begin
                    ow_csr_read_valid = 1'b0;
                    ow_csr_read_data  = {(`HBIT_DATA+1){1'b0}};
                end
            endcase
        end
    end

    // Refresh CSR shadow registers on IDX change to show current TLB entry
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            // already reset above
        end else begin
            // When index changes, latch selected entry for CSR reads
            if (iw_csr_write_en && iw_csr_write_addr == `CSR_IDX_MMU_TLBIDX) begin
                if (!iw_csr_write_data[5]) begin
                    if (iw_csr_write_data[4:0] < ITLB_ENTRIES) begin
                        r_csr_tlbvpn       <= r_itlb_vpn[iw_csr_write_data[4:0]];
                        r_csr_tlbppn       <= r_itlb_ppn[iw_csr_write_data[4:0]];
                        r_csr_tlbport      <= r_itlb_port[iw_csr_write_data[4:0]];
                        r_csr_tlbperm      <= r_itlb_perm[iw_csr_write_data[4:0]];
                        r_csr_tlbasid      <= r_itlb_asid[iw_csr_write_data[4:0]];
                        r_csr_tlbvalid     <= r_itlb_valid[iw_csr_write_data[4:0]];
                        r_csr_tlbglobal    <= r_itlb_global[iw_csr_write_data[4:0]];
                        r_csr_tlb_accessed <= r_itlb_accessed[iw_csr_write_data[4:0]];
                        r_csr_tlb_dirty    <= 1'b0;
                        r_csr_tlb_nu       <= r_itlb_perm[iw_csr_write_data[4:0]][3];
                        r_csr_tlb_ns       <= r_itlb_perm[iw_csr_write_data[4:0]][4];
                        r_csr_tlb_nl       <= r_itlb_perm[iw_csr_write_data[4:0]][5];
                    end
                end else begin
                    if (iw_csr_write_data[4:0] < DTLB_ENTRIES) begin
                        r_csr_tlbvpn       <= r_dtlb_vpn[iw_csr_write_data[4:0]];
                        r_csr_tlbppn       <= r_dtlb_ppn[iw_csr_write_data[4:0]];
                        r_csr_tlbport      <= r_dtlb_port[iw_csr_write_data[4:0]];
                        r_csr_tlbperm      <= r_dtlb_perm[iw_csr_write_data[4:0]];
                        r_csr_tlbasid      <= r_dtlb_asid[iw_csr_write_data[4:0]];
                        r_csr_tlbvalid     <= r_dtlb_valid[iw_csr_write_data[4:0]];
                        r_csr_tlbglobal    <= r_dtlb_global[iw_csr_write_data[4:0]];
                        r_csr_tlb_accessed <= r_dtlb_accessed[iw_csr_write_data[4:0]];
                        r_csr_tlb_dirty    <= r_dtlb_dirty[iw_csr_write_data[4:0]];
                        r_csr_tlb_nu       <= r_dtlb_perm[iw_csr_write_data[4:0]][3];
                        r_csr_tlb_ns       <= r_dtlb_perm[iw_csr_write_data[4:0]][4];
                        r_csr_tlb_nl       <= r_dtlb_perm[iw_csr_write_data[4:0]][5];
                    end
                end
            end
        end
    end

    // ---------------------------------------------------------------------
    // Translation helpers
    // ---------------------------------------------------------------------
    function automatic [2:0] map_fault_code(input [1:0] kind);
        case (kind)
            2'd1: map_fault_code = 3'd1; // PERM
            2'd2: map_fault_code = 3'd2; // PORT
            2'd3: map_fault_code = 3'd3; // PTAB (unused)
            default: map_fault_code = 3'd0; // VINV
        endcase
    endfunction

    // DTLB lookup
    reg        w_d_hit;
    reg [4:0] w_d_hit_idx;
    reg [PPN_BITS-1:0] w_d_hit_ppn;
    reg [5:0]  w_d_hit_port;
    reg [5:0]  w_d_hit_perm;
    reg [15:0] w_d_hit_asid;
    reg        w_d_hit_global;
    reg [1:0]  w_d_fault_kind;
    always @(*) begin
        w_d_hit        = 1'b0;
        w_d_hit_idx    = 5'd0;
        w_d_hit_ppn    = {PPN_BITS{1'b0}};
        w_d_hit_port   = 6'd0;
        w_d_hit_perm   = 6'd0;
        w_d_hit_asid   = 16'd0;
        w_d_hit_global = 1'b0;
        w_d_fault_kind = 2'd0;
        if (w_cfg_en && w_cfg_en_dtlb && iw_d_req_valid) begin
            for (i = 0; i < DTLB_ENTRIES; i = i + 1) begin
                if (!w_d_hit && r_dtlb_valid[i]) begin
                    if (r_dtlb_vpn[i] == iw_d_req_vaddr[47:12]) begin
                        if (r_dtlb_global[i] || (r_dtlb_asid[i] == w_current_asid)) begin
                            w_d_hit        = 1'b1;
                            w_d_hit_idx    = i[4:0];
                            w_d_hit_ppn    = r_dtlb_ppn[i];
                            w_d_hit_port   = r_dtlb_port[i];
                            w_d_hit_perm   = r_dtlb_perm[i];
                            w_d_hit_asid   = r_dtlb_asid[i];
                            w_d_hit_global = r_dtlb_global[i];
                        end
                    end
                end
            end
        if (!w_d_hit) begin
            w_d_fault_kind = 2'd0; // VINV
        end else begin
            // Permission checks
            if ((!iw_mode_kernel && w_d_hit_perm[3]) || (!iw_mode_kernel && w_d_hit_perm[4])) begin
                    w_d_fault_kind = 2'd1;
                end else if (iw_d_req_is_store && !w_d_hit_perm[1]) begin
                    w_d_fault_kind = 2'd1;
                end else if (!iw_d_req_is_store && !w_d_hit_perm[0]) begin
                    w_d_fault_kind = 2'd1;
                end else if (!r_portmask[w_d_hit_port]) begin
                    w_d_fault_kind = 2'd2;
                end else begin
                    w_d_fault_kind = 2'd0;
                end
            end
        end
    end

    assign ow_d_stall = 1'b0; // no walker yet

    always @(*) begin
        ow_d_resp_valid  = 1'b0;
        ow_d_resp_paddr  = 48'd0;
        ow_d_resp_port   = 6'd0;
        ow_d_resp_linear = 1'b0;
        ow_d_fault       = 1'b0;
        ow_d_fault_code  = 3'd0;
        ow_d_fault_vaddr = 48'd0;
        if (!w_cfg_en || !w_cfg_en_dtlb) begin
            if (iw_d_req_valid) begin
                ow_d_resp_valid = 1'b1;
                ow_d_resp_paddr = iw_d_req_vaddr;
                ow_d_resp_port  = 6'd0;
                ow_d_resp_linear= 1'b0;
            end
        end else if (iw_d_req_valid) begin
            if (!w_d_hit || (w_d_fault_kind != 2'd0)) begin
                ow_d_fault       = 1'b1;
                ow_d_fault_code  = map_fault_code(w_d_fault_kind);
                ow_d_fault_vaddr = iw_d_req_vaddr;
            end else begin
                ow_d_resp_valid  = 1'b1;
                ow_d_resp_port   = w_d_hit_port;
                ow_d_resp_linear = w_d_hit_perm[5];
                ow_d_resp_paddr  = {w_d_hit_port, w_d_hit_ppn, iw_d_req_vaddr[11:0]};
            end
        end
    end

    // ITLB lookup (optional)
    reg        w_i_hit;
    reg [4:0]  w_i_hit_idx;
    reg [PPN_BITS-1:0] w_i_hit_ppn;
    reg [5:0]  w_i_hit_port;
    reg [5:0]  w_i_hit_perm;
    reg [1:0]  w_i_fault_kind;
    always @(*) begin
        w_i_hit       = 1'b0;
        w_i_hit_idx   = 5'd0;
        w_i_hit_ppn   = {PPN_BITS{1'b0}};
        w_i_hit_port  = 6'd0;
        w_i_hit_perm  = 6'd0;
        w_i_fault_kind= 2'd0;
        if (w_cfg_en && w_cfg_en_itlb && iw_i_req_valid) begin
            for (i = 0; i < ITLB_ENTRIES; i = i + 1) begin
                if (!w_i_hit && r_itlb_valid[i]) begin
                    if (r_itlb_vpn[i] == iw_i_req_vaddr[47:12]) begin
                        if (r_itlb_global[i] || (r_itlb_asid[i] == w_current_asid)) begin
                            w_i_hit      = 1'b1;
                            w_i_hit_idx  = i[4:0];
                            w_i_hit_ppn  = r_itlb_ppn[i];
                            w_i_hit_port = r_itlb_port[i];
                            w_i_hit_perm = r_itlb_perm[i];
                        end
                    end
                end
            end
            if (!w_i_hit) begin
                w_i_fault_kind = 2'd0;
            end else if (!w_i_hit_perm[2]) begin
                w_i_fault_kind = 2'd1;
            end else if (!r_portmask[w_i_hit_port]) begin
                w_i_fault_kind = 2'd2;
            end
        end
    end

    assign ow_i_stall = 1'b0;

    always @(*) begin
        ow_i_resp_valid  = 1'b0;
        ow_i_resp_paddr  = 48'd0;
        ow_i_fault       = 1'b0;
        ow_i_fault_code  = 3'd0;
        ow_i_fault_vaddr = 48'd0;
        if (!w_cfg_en || !w_cfg_en_itlb) begin
            if (iw_i_req_valid) begin
                ow_i_resp_valid = 1'b1;
                ow_i_resp_paddr = iw_i_req_vaddr;
            end
        end else if (iw_i_req_valid) begin
            if (!w_i_hit || (w_i_fault_kind != 2'd0)) begin
                ow_i_fault       = 1'b1;
                ow_i_fault_code  = map_fault_code(w_i_fault_kind);
                ow_i_fault_vaddr = iw_i_req_vaddr;
            end else begin
                ow_i_resp_valid = 1'b1;
                ow_i_resp_paddr = {w_i_hit_port, w_i_hit_ppn, iw_i_req_vaddr[11:0]};
            end
        end
    end

    // Update MMU_STATUS on faults (sticky until cleared)
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            // already reset above
        end else begin
            if (ow_d_fault) begin
                r_fault_va <= ow_d_fault_vaddr;
                case (ow_d_fault_code)
                    3'd0: r_status[0] <= 1'b1; // VINV
                    3'd1: r_status[1] <= 1'b1; // PERM
                    3'd2: r_status[2] <= 1'b1; // PORT
                    3'd3: r_status[3] <= 1'b1; // PTAB
                endcase
                r_status[23:8] <= {16{1'b0}} | w_current_asid;
            end else if (ow_i_fault) begin
                r_fault_va <= ow_i_fault_vaddr;
                case (ow_i_fault_code)
                    3'd0: r_status[0] <= 1'b1;
                    3'd1: r_status[1] <= 1'b1;
                    3'd2: r_status[2] <= 1'b1;
                    3'd3: r_status[3] <= 1'b1;
                endcase
                r_status[23:8] <= {16{1'b0}} | w_current_asid;
            end
            if (iw_flush) begin
                r_status[4] <= 1'b0;
            end
        end
    end

endmodule
