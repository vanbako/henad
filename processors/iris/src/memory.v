// Clean, minimal AXI-Lite style single-ported RAM for iris GPU

module gw5ast_memory #(
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 16
)(
    input  wire                       clk,
    input  wire                       rst_n,

    // Write address (AW)
    input  wire                       axi_awvalid,
    output reg                        axi_awready,
    input  wire [ADDR_WIDTH-1:0]      axi_awaddr,

    // Write data (W)
    input  wire                       axi_wvalid,
    output reg                        axi_wready,
    input  wire [DATA_WIDTH-1:0]      axi_wdata,
    input  wire [3:0]                 axi_wstrb,
    input  wire                       axi_wlast,

    // Write response (B)
    output reg                        axi_bvalid,
    input  wire                       axi_bready,
    output reg [1:0]                  axi_bresp,

    // Read address (AR)
    input  wire                       axi_arvalid,
    output reg                        axi_arready,
    input  wire [ADDR_WIDTH-1:0]      axi_araddr,

    // Read data (R)
    output reg                        axi_rvalid,
    input  wire                       axi_rready,
    output reg [DATA_WIDTH-1:0]       axi_rdata,
    output reg [1:0]                  axi_rresp,
    output reg                        axi_rlast
);

    // ---------------------------------------------------------------
    // Simple single-ported memory array (word addressed)
    // ---------------------------------------------------------------
    localparam integer MEM_DEPTH = (1 << ADDR_WIDTH);
    reg [DATA_WIDTH-1:0] mem [0:MEM_DEPTH-1];

    // Default constants
    localparam [1:0] RESP_OKAY = 2'b00;

    // ----------------------------
    // Write channel with pipelining/backpressure
    // ----------------------------
    // Two-entry FIFOs for AW and W independently; writes are performed
    // in order when both FIFOs are non-empty and no B response is pending.
    reg [ADDR_WIDTH-1:0] aw_fifo_addr [0:1];
    reg [1:0]            aw_fifo_qcnt; // 0..2
    reg                  aw_fifo_rd_ptr;
    reg                  aw_fifo_wr_ptr;

    reg [DATA_WIDTH-1:0] w_fifo_data  [0:1];
    reg [3:0]            w_fifo_strb  [0:1];
    reg [1:0]            w_fifo_qcnt; // 0..2
    reg                  w_fifo_rd_ptr;
    reg                  w_fifo_wr_ptr;

    reg [DATA_WIDTH-1:0] wr_cur;
    reg [DATA_WIDTH-1:0] wr_new;

    wire aw_fifo_full  = (aw_fifo_qcnt == 2);
    wire aw_fifo_empty = (aw_fifo_qcnt == 0);
    wire w_fifo_full   = (w_fifo_qcnt  == 2);
    wire w_fifo_empty  = (w_fifo_qcnt  == 0);

    wire do_push_aw = axi_awvalid && axi_awready;
    wire do_push_w  = axi_wvalid  && axi_wready;
    wire do_pop_aw  = (!aw_fifo_empty) && (!axi_bvalid) && (!w_fifo_empty);
    wire do_pop_w   = (!w_fifo_empty)  && (!axi_bvalid) && (!aw_fifo_empty);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            aw_fifo_qcnt  <= 0;
            aw_fifo_rd_ptr<= 0;
            aw_fifo_wr_ptr<= 0;
            w_fifo_qcnt   <= 0;
            w_fifo_rd_ptr <= 0;
            w_fifo_wr_ptr <= 0;

            axi_awready   <= 1'b0;
            axi_wready    <= 1'b0;
            axi_bvalid    <= 1'b0;
            axi_bresp     <= RESP_OKAY;
        end else begin
            // Backpressure to masters based on FIFO space
            axi_awready <= !aw_fifo_full;
            axi_wready  <= !w_fifo_full;

            // AW FIFO push
            if (do_push_aw) begin
                aw_fifo_addr[aw_fifo_wr_ptr] <= axi_awaddr;
                aw_fifo_wr_ptr <= ~aw_fifo_wr_ptr;
                aw_fifo_qcnt   <= aw_fifo_qcnt + 1'b1;
            end
            // W FIFO push
            if (do_push_w) begin
                w_fifo_data[w_fifo_wr_ptr] <= axi_wdata;
                w_fifo_strb[w_fifo_wr_ptr] <= axi_wstrb;
                w_fifo_wr_ptr <= ~w_fifo_wr_ptr;
                w_fifo_qcnt   <= w_fifo_qcnt + 1'b1;
            end

            // Perform a write when possible and if no B is pending
            if (do_pop_aw && do_pop_w && !axi_bvalid) begin
                // Pop both FIFOs
                aw_fifo_rd_ptr <= ~aw_fifo_rd_ptr;
                w_fifo_rd_ptr  <= ~w_fifo_rd_ptr;
                aw_fifo_qcnt   <= aw_fifo_qcnt - 1'b1;
                w_fifo_qcnt    <= w_fifo_qcnt  - 1'b1;

                // Execute write (RMW per strobe) and raise BVALID
                wr_cur = mem[aw_fifo_addr[aw_fifo_rd_ptr]];
                wr_new = wr_cur;
                if (w_fifo_strb[w_fifo_rd_ptr][0]) wr_new[7:0]   = w_fifo_data[w_fifo_rd_ptr][7:0];
                if (w_fifo_strb[w_fifo_rd_ptr][1]) wr_new[15:8]  = w_fifo_data[w_fifo_rd_ptr][15:8];
                if (w_fifo_strb[w_fifo_rd_ptr][2]) wr_new[23:16] = w_fifo_data[w_fifo_rd_ptr][23:16];
                mem[aw_fifo_addr[aw_fifo_rd_ptr]] <= wr_new;

                axi_bvalid <= 1'b1;
                axi_bresp  <= RESP_OKAY;
            end

            // Write response handshake
            if (axi_bvalid && axi_bready) begin
                axi_bvalid <= 1'b0;
            end
        end
    end

    // ----------------------------
    // Read channel with pipelining/backpressure
    // ----------------------------
    // Two-entry FIFO for AR addresses; send R when not blocked.
    reg [ADDR_WIDTH-1:0] ar_fifo_addr [0:1];
    reg [1:0]            ar_fifo_qcnt; // 0..2
    reg                  ar_fifo_rd_ptr;
    reg                  ar_fifo_wr_ptr;

    wire ar_fifo_full  = (ar_fifo_qcnt == 2);
    wire ar_fifo_empty = (ar_fifo_qcnt == 0);
    wire do_push_ar    = axi_arvalid && axi_arready;
    wire can_issue_r   = (!axi_rvalid) && (!ar_fifo_empty);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ar_fifo_qcnt  <= 0;
            ar_fifo_rd_ptr<= 0;
            ar_fifo_wr_ptr<= 0;

            axi_arready   <= 1'b0;
            axi_rvalid    <= 1'b0;
            axi_rdata     <= {DATA_WIDTH{1'b0}};
            axi_rresp     <= RESP_OKAY;
            axi_rlast     <= 1'b0;
        end else begin
            // Backpressure to master based on FIFO space
            axi_arready <= !ar_fifo_full;

            // Push AR
            if (do_push_ar) begin
                ar_fifo_addr[ar_fifo_wr_ptr] <= axi_araddr;
                ar_fifo_wr_ptr <= ~ar_fifo_wr_ptr;
                ar_fifo_qcnt   <= ar_fifo_qcnt + 1'b1;
            end

            // Issue R when possible
            if (can_issue_r) begin
                // Pop AR
                axi_rdata      <= mem[ar_fifo_addr[ar_fifo_rd_ptr]];
                axi_rresp      <= RESP_OKAY;
                axi_rlast      <= 1'b1; // single-beat
                axi_rvalid     <= 1'b1;
                ar_fifo_rd_ptr <= ~ar_fifo_rd_ptr;
                ar_fifo_qcnt   <= ar_fifo_qcnt - 1'b1;
            end

            // R handshake
            if (axi_rvalid && axi_rready) begin
                axi_rvalid <= 1'b0;
                axi_rlast  <= 1'b0;
            end
        end
    end

endmodule
