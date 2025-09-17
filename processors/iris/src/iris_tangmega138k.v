module iris_tangmega138k (
    input  wire        sys_clk,
    input  wire        sys_rst_n,

    // TMDS outputs (Dock connector 0)
    output wire [2:0]  tmds_d_p_0,
    output wire [2:0]  tmds_d_n_0,
    output wire        tmds_clk_p_0,
    output wire        tmds_clk_n_0,

    // DDR3 interface (note: current IP configured as 16-bit wide controller)
    output wire [2:0]  ddr_bank,
    output wire [13:0] ddr_addr,
    output wire        ddr_cs_n,
    output wire        ddr_ras_n,
    output wire        ddr_cas_n,
    output wire        ddr_we_n,
    output wire        ddr_ck_p,
    output wire        ddr_ck_n,
    output wire        ddr_cke,
    output wire        ddr_odt,
    output wire        ddr_reset_n,
    output wire [1:0]  ddr_dm,
    inout  wire [15:0] ddr_dq,
    inout  wire [1:0]  ddr_dqs,
    inout  wire [1:0]  ddr_dqs_n
);

    // ------------------------------------------------------------------
    // Clock generation
    // ------------------------------------------------------------------
    wire clk_tmds;
    wire clk_pix;
    wire hdmi_lock;

    hdmi_pll u_hdmi_pll (
        .clkin   (sys_clk),
        .init_clk(sys_clk),
        .clkout0 (clk_tmds),
        .clkout1 (clk_pix),
        .lock    (hdmi_lock)
    );

    wire ddr_mem_clk;
    wire ddr_pll_lock;

    ddr3_pll u_ddr_pll (
        .clkin   (sys_clk),
        .init_clk(sys_clk),
        .clkout0 (ddr_mem_clk),
        .lock    (ddr_pll_lock)
    );

    // Global reset combines external reset and PLL lock domains
    wire core_rst_n = sys_rst_n & hdmi_lock;
    wire ddr_rst_n  = sys_rst_n & ddr_pll_lock;

    // Pixel domain reset synchroniser
    reg [1:0] pix_rst_sync;
    always @(posedge clk_pix or negedge core_rst_n) begin
        if (!core_rst_n)
            pix_rst_sync <= 2'b00;
        else
            pix_rst_sync <= {pix_rst_sync[0], 1'b1};
    end
    wire pix_rst_n = pix_rst_sync[1];

    // ------------------------------------------------------------------
    // Iris core instance (single prototype core)
    // ------------------------------------------------------------------
    wire axi_awvalid;
    wire axi_awready;
    wire [47:0] axi_awaddr;
    wire [3:0]  axi_awid;
    wire [7:0]  axi_awlen;
    wire [2:0]  axi_awsize;
    wire [1:0]  axi_awburst;
    wire        axi_awlock;
    wire [3:0]  axi_awcache;
    wire [2:0]  axi_awprot;
    wire [3:0]  axi_awqos;

    wire        axi_wvalid;
    wire        axi_wready;
    wire [191:0] axi_wdata;
    wire [23:0]  axi_wstrb;
    wire         axi_wlast;

    wire        axi_bvalid;
    wire        axi_bready;
    wire [1:0]  axi_bresp;
    wire [3:0]  axi_bid;

    wire        axi_arvalid;
    wire        axi_arready;
    wire [47:0] axi_araddr;
    wire [3:0]  axi_arid;
    wire [7:0]  axi_arlen;
    wire [2:0]  axi_arsize;
    wire [1:0]  axi_arburst;
    wire        axi_arlock;
    wire [3:0]  axi_arcache;
    wire [2:0]  axi_arprot;
    wire [3:0]  axi_arqos;

    wire        axi_rvalid;
    wire        axi_rready;
    wire [191:0] axi_rdata;
    wire [1:0]   axi_rresp;
    wire         axi_rlast;
    wire [3:0]   axi_rid;

    wire [7:0] video_r;
    wire [7:0] video_g;
    wire [7:0] video_b;
    wire       video_de;
    wire       video_hsync;
    wire       video_vsync;
    wire       frame_done_irq;

    gw5ast_core u_core (
        .clk          (sys_clk),
        .rst_n        (core_rst_n),
        .pix_clk      (clk_pix),
        .pix_rst_n    (pix_rst_n),
        .axi_valid_in (1'b0),
        .axi_ready_out(),
        .cmd_write_in (1'b0),
        .cmd_addr_in  ({16{1'b0}}),
        .cmd_wdata_in ({24{1'b0}}),
        .axi_data_out (),

        .axi_awvalid  (axi_awvalid),
        .axi_awready  (axi_awready),
        .axi_awaddr   (axi_awaddr),
        .axi_awid     (axi_awid),
        .axi_awlen    (axi_awlen),
        .axi_awsize   (axi_awsize),
        .axi_awburst  (axi_awburst),
        .axi_awlock   (axi_awlock),
        .axi_awcache  (axi_awcache),
        .axi_awprot   (axi_awprot),
        .axi_awqos    (axi_awqos),

        .axi_wvalid   (axi_wvalid),
        .axi_wready   (axi_wready),
        .axi_wdata    (axi_wdata),
        .axi_wstrb    (axi_wstrb),
        .axi_wlast    (axi_wlast),

        .axi_bvalid   (axi_bvalid),
        .axi_bready   (axi_bready),
        .axi_bresp    (axi_bresp),
        .axi_bid      (axi_bid),

        .axi_arvalid  (axi_arvalid),
        .axi_arready  (axi_arready),
        .axi_araddr   (axi_araddr),
        .axi_arid     (axi_arid),
        .axi_arlen    (axi_arlen),
        .axi_arsize   (axi_arsize),
        .axi_arburst  (axi_arburst),
        .axi_arlock   (axi_arlock),
        .axi_arcache  (axi_arcache),
        .axi_arprot   (axi_arprot),
        .axi_arqos    (axi_arqos),

        .axi_rvalid   (axi_rvalid),
        .axi_rready   (axi_rready),
        .axi_rdata    (axi_rdata),
        .axi_rresp    (axi_rresp),
        .axi_rlast    (axi_rlast),
        .axi_rid      (axi_rid),

        .video_r      (video_r),
        .video_g      (video_g),
        .video_b      (video_b),
        .video_de     (video_de),
        .video_hsync  (video_hsync),
        .video_vsync  (video_vsync),
        .frame_done_irq(frame_done_irq)
    );

    // Placeholder AXI target providing zero data while DDR integration is completed
    iris_axi_zero_mem #(
        .ADDR_WIDTH(48),
        .DATA_WIDTH(192),
        .ID_WIDTH  (4)
    ) u_axi_stub (
        .clk         (sys_clk),
        .rst_n       (core_rst_n),
        .axi_awvalid (axi_awvalid),
        .axi_awready (axi_awready),
        .axi_awaddr  (axi_awaddr),
        .axi_awid    (axi_awid),
        .axi_awlen   (axi_awlen),
        .axi_awsize  (axi_awsize),
        .axi_awburst (axi_awburst),
        .axi_awlock  (axi_awlock),
        .axi_awcache (axi_awcache),
        .axi_awprot  (axi_awprot),
        .axi_awqos   (axi_awqos),
        .axi_wvalid  (axi_wvalid),
        .axi_wready  (axi_wready),
        .axi_wdata   (axi_wdata),
        .axi_wstrb   (axi_wstrb),
        .axi_wlast   (axi_wlast),
        .axi_bvalid  (axi_bvalid),
        .axi_bready  (axi_bready),
        .axi_bresp   (axi_bresp),
        .axi_bid     (axi_bid),
        .axi_arvalid (axi_arvalid),
        .axi_arready (axi_arready),
        .axi_araddr  (axi_araddr),
        .axi_arid    (axi_arid),
        .axi_arlen   (axi_arlen),
        .axi_arsize  (axi_arsize),
        .axi_arburst (axi_arburst),
        .axi_arlock  (axi_arlock),
        .axi_arcache (axi_arcache),
        .axi_arprot  (axi_arprot),
        .axi_arqos   (axi_arqos),
        .axi_rvalid  (axi_rvalid),
        .axi_rready  (axi_rready),
        .axi_rdata   (axi_rdata),
        .axi_rresp   (axi_rresp),
        .axi_rlast   (axi_rlast),
        .axi_rid     (axi_rid)
    );

    // ------------------------------------------------------------------
    // DVI transmitter
    // ------------------------------------------------------------------
    dvi_tx u_dvi_tx (
        .I_rst_n    (pix_rst_n),
        .I_serial_clk(clk_tmds),
        .I_rgb_clk  (clk_pix),
        .I_rgb_vs   (video_vsync),
        .I_rgb_hs   (video_hsync),
        .I_rgb_de   (video_de),
        .I_rgb_r    (video_r),
        .I_rgb_g    (video_g),
        .I_rgb_b    (video_b),
        .O_tmds_clk_p(tmds_clk_p_0),
        .O_tmds_clk_n(tmds_clk_n_0),
        .O_tmds_data_p(tmds_d_p_0),
        .O_tmds_data_n(tmds_d_n_0)
    );

    // ------------------------------------------------------------------
    // DDR3 IP block (currently idle, kept for pinout/timing integration)
    // ------------------------------------------------------------------
    wire ddr_pll_stop;
    wire ddr_clk_out;
    wire ddr_internal_rst;
    wire ddr_init_done;
    wire ddr_cmd_ready;
    wire ddr_wr_data_rdy;
    wire [255:0] ddr_rd_data;
    wire         ddr_rd_valid;
    wire         ddr_rd_end;
    wire         ddr_sr_ack;
    wire         ddr_ref_ack;

    ddr3 u_ddr3 (
        .clk                 (sys_clk),
        .memory_clk          (ddr_mem_clk),
        .pll_lock            (ddr_pll_lock),
        .rst_n               (ddr_rst_n),
        .clk_out             (ddr_clk_out),
        .ddr_rst             (ddr_internal_rst),
        .init_calib_complete (ddr_init_done),
        .cmd_ready           (ddr_cmd_ready),
        .cmd                 (3'b000),
        .cmd_en              (1'b0),
        .addr                (28'd0),
        .wr_data_rdy         (ddr_wr_data_rdy),
        .wr_data             (256'd0),
        .wr_data_en          (1'b0),
        .wr_data_end         (1'b0),
        .wr_data_mask        (32'hFFFF_FFFF),
        .rd_data             (ddr_rd_data),
        .rd_data_valid       (ddr_rd_valid),
        .rd_data_end         (ddr_rd_end),
        .sr_req              (1'b0),
        .ref_req             (1'b0),
        .sr_ack              (ddr_sr_ack),
        .ref_ack             (ddr_ref_ack),
        .burst               (1'b0),
        .pll_stop            (ddr_pll_stop),
        .O_ddr_addr          (ddr_addr),
        .O_ddr_ba            (ddr_bank),
        .O_ddr_cs_n          (ddr_cs_n),
        .O_ddr_ras_n         (ddr_ras_n),
        .O_ddr_cas_n         (ddr_cas_n),
        .O_ddr_we_n          (ddr_we_n),
        .O_ddr_clk           (ddr_ck_p),
        .O_ddr_clk_n         (ddr_ck_n),
        .O_ddr_cke           (ddr_cke),
        .O_ddr_odt           (ddr_odt),
        .O_ddr_reset_n       (ddr_reset_n),
        .O_ddr_dqm           (ddr_dm),
        .IO_ddr_dq           (ddr_dq),
        .IO_ddr_dqs          (ddr_dqs),
        .IO_ddr_dqs_n        (ddr_dqs_n)
    );

endmodule
