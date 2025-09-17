`timescale 1ns/1ps

module gw5ast_core #(
    parameter integer CMD_ADDR_WIDTH = 16,
    parameter integer CMD_DATA_WIDTH = 24,
    parameter integer AXI_ADDR_WIDTH = 48,
    parameter integer AXI_DATA_WIDTH = 192,
    parameter integer AXI_ID_WIDTH   = 4
)(
    input  wire                       clk,
    input  wire                       rst_n,
    input  wire                       pix_clk,
    input  wire                       pix_rst_n,

    // Host command ring (valid/ready micro protocol)
    input  wire                       axi_valid_in,
    output wire                       axi_ready_out,
    input  wire                       cmd_write_in,
    input  wire [CMD_ADDR_WIDTH-1:0]  cmd_addr_in,
    input  wire [CMD_DATA_WIDTH-1:0]  cmd_wdata_in,
    output reg  [CMD_DATA_WIDTH-1:0]  axi_data_out,

    // AXI4 master towards external memory (DDR)
    output reg                        axi_awvalid,
    input  wire                       axi_awready,
    output reg [AXI_ADDR_WIDTH-1:0]   axi_awaddr,
    output reg [AXI_ID_WIDTH-1:0]     axi_awid,
    output reg [7:0]                  axi_awlen,
    output reg [2:0]                  axi_awsize,
    output reg [1:0]                  axi_awburst,
    output reg                        axi_awlock,
    output reg [3:0]                  axi_awcache,
    output reg [2:0]                  axi_awprot,
    output reg [3:0]                  axi_awqos,

    output reg                        axi_wvalid,
    input  wire                       axi_wready,
    output reg [AXI_DATA_WIDTH-1:0]   axi_wdata,
    output reg [(AXI_DATA_WIDTH/8)-1:0] axi_wstrb,
    output reg                        axi_wlast,

    input  wire                       axi_bvalid,
    output reg                        axi_bready,
    input  wire [1:0]                 axi_bresp,
    input  wire [AXI_ID_WIDTH-1:0]    axi_bid,

    output reg                        axi_arvalid,
    input  wire                       axi_arready,
    output reg [AXI_ADDR_WIDTH-1:0]   axi_araddr,
    output reg [AXI_ID_WIDTH-1:0]     axi_arid,
    output reg [7:0]                  axi_arlen,
    output reg [2:0]                  axi_arsize,
    output reg [1:0]                  axi_arburst,
    output reg                        axi_arlock,
    output reg [3:0]                  axi_arcache,
    output reg [2:0]                  axi_arprot,
    output reg [3:0]                  axi_arqos,

    input  wire                       axi_rvalid,
    output reg                        axi_rready,
    input  wire [AXI_DATA_WIDTH-1:0]  axi_rdata,
    input  wire [1:0]                 axi_rresp,
    input  wire                       axi_rlast,
    input  wire [AXI_ID_WIDTH-1:0]    axi_rid,

    // HDMI-style pixel outputs (RGB888 + syncs)
    output reg  [7:0]                 video_r,
    output reg  [7:0]                 video_g,
    output reg  [7:0]                 video_b,
    output reg                        video_de,
    output reg                        video_hsync,
    output reg                        video_vsync,
    output reg                        frame_done_irq
);

    // ------------------------------------------------------------------
    // Render & output configuration constants
    // ------------------------------------------------------------------
    localparam integer RENDER_WIDTH        = 768;
    localparam integer RENDER_HEIGHT       = 576;
    localparam integer OUTPUT_WIDTH        = 1280;
    localparam integer OUTPUT_HEIGHT       = 720;
    localparam integer OUTPUT_H_FP         = 110;
    localparam integer OUTPUT_H_SYNC       = 40;
    localparam integer OUTPUT_H_BP         = 220;
    localparam integer OUTPUT_V_FP         = 5;
    localparam integer OUTPUT_V_SYNC       = 5;
    localparam integer OUTPUT_V_BP         = 20;
    localparam integer OUTPUT_TOTAL_WIDTH  = OUTPUT_WIDTH + OUTPUT_H_FP + OUTPUT_H_SYNC + OUTPUT_H_BP;
    localparam integer OUTPUT_TOTAL_HEIGHT = OUTPUT_HEIGHT + OUTPUT_V_FP + OUTPUT_V_SYNC + OUTPUT_V_BP;
    localparam integer LETTERBOX_X_OFF     = (OUTPUT_WIDTH  - RENDER_WIDTH ) / 2; // 256
    localparam integer LETTERBOX_Y_OFF     = (OUTPUT_HEIGHT - RENDER_HEIGHT) / 2; // 72
    localparam integer TILE_SIZE           = 16;
    localparam integer TILE_PIXELS         = TILE_SIZE * TILE_SIZE;              // 256
    localparam integer RENDER_TILE_COLS    = RENDER_WIDTH  / TILE_SIZE;          // 48
    localparam integer RENDER_TILE_ROWS    = RENDER_HEIGHT / TILE_SIZE;          // 36
    localparam integer COLOR12_MAX         = 12'd4095;
    localparam integer COLOR6_MAX          = 6'd63;
    localparam integer AXI_BURST_BYTES     = AXI_DATA_WIDTH / 8;                 // 24 bytes @ 192-bit
    localparam integer LINE_STRIDE_BYTES   = RENDER_WIDTH * 3;                   // 2304
    localparam integer LINE_BURSTS         = LINE_STRIDE_BYTES / AXI_BURST_BYTES;   // 96 bursts per line
    localparam integer USE_ORDERED_DITHER  = 1;                                  // enable 4x4 matrix
    localparam integer PIXELS_PER_BURST    = AXI_BURST_BYTES / 3;                // 8 pixels @ 24 B
    localparam integer TILE_BURSTS         = TILE_PIXELS / PIXELS_PER_BURST;     // 32 bursts

    // ------------------------------------------------------------------
    // Helper functions
    // ------------------------------------------------------------------
    function automatic [5:0] q12_to_q6;
        input [11:0] val;
        reg   [12:0] tmp;
    begin
        tmp = {1'b0, val} + 13'd32;       // round-to-nearest
        tmp = tmp >> 6;                   // convert to 6-bit
        if (tmp[6])
            q12_to_q6 = COLOR6_MAX;       // clamp if overflow
        else
            q12_to_q6 = tmp[5:0];
    end
    endfunction

    function automatic [7:0] expand6_to_8;
        input [5:0] val6;
    begin
        expand6_to_8 = {val6, 2'b00} | (val6 >> 4); // replicate bits for approx x255/63
    end
    endfunction

    function automatic [23:0] pack_rgba6;
        input [5:0] r6;
        input [5:0] g6;
        input [5:0] b6;
        input [5:0] a6;
    begin
        pack_rgba6 = {r6, g6, b6, a6};
    end
    endfunction

    function automatic [3:0] bayer4_threshold;
        input [1:0] x;
        input [1:0] y;
    begin
        case ({y, x})
            4'b0000: bayer4_threshold = 4'd0;
            4'b0001: bayer4_threshold = 4'd8;
            4'b0010: bayer4_threshold = 4'd2;
            4'b0011: bayer4_threshold = 4'd10;
            4'b0100: bayer4_threshold = 4'd12;
            4'b0101: bayer4_threshold = 4'd4;
            4'b0110: bayer4_threshold = 4'd14;
            4'b0111: bayer4_threshold = 4'd6;
            4'b1000: bayer4_threshold = 4'd3;
            4'b1001: bayer4_threshold = 4'd11;
            4'b1010: bayer4_threshold = 4'd1;
            4'b1011: bayer4_threshold = 4'd9;
            4'b1100: bayer4_threshold = 4'd15;
            4'b1101: bayer4_threshold = 4'd7;
            4'b1110: bayer4_threshold = 4'd13;
            default: bayer4_threshold = 4'd5; // 4'b1111
        endcase
    end
    endfunction

    function automatic [11:0] apply_dither4x4;
        input [11:0] value12;
        input [1:0]  x;
        input [1:0]  y;
        reg   [3:0]  thresh;
        reg   [12:0] sum;
    begin
        thresh = bayer4_threshold(x, y);
        sum    = {1'b0, value12} + {1'b0, (thresh << 8)}; // scale to U0.12 domain
        if (sum[12])
            apply_dither4x4 = COLOR12_MAX;
        else
            apply_dither4x4 = sum[11:0];
    end
    endfunction

    function automatic [11:0] maybe_dither12;
        input [11:0] value12;
        input [1:0]  x;
        input [1:0]  y;
    begin
        if (USE_ORDERED_DITHER)
            maybe_dither12 = apply_dither4x4(value12, x, y);
        else
            maybe_dither12 = value12;
    end
    endfunction

    function automatic [23:0] quantize_rgba12_to_rgba6;
        input [11:0] r12;
        input [11:0] g12;
        input [11:0] b12;
        input [11:0] a12;
        input [1:0]  x;
        input [1:0]  y;
        reg   [11:0] r_q;
        reg   [11:0] g_q;
        reg   [11:0] b_q;
        reg   [11:0] a_q;
    begin
        r_q = maybe_dither12(r12, x, y);
        g_q = maybe_dither12(g12, x, y);
        b_q = maybe_dither12(b12, x, y);
        a_q = a12; // alpha not dithered
        quantize_rgba12_to_rgba6 = {q12_to_q6(r_q), q12_to_q6(g_q), q12_to_q6(b_q), q12_to_q6(a_q)};
    end
    endfunction

    function automatic [AXI_ADDR_WIDTH-1:0] tile_color_addr;
        input [AXI_ADDR_WIDTH-1:0] base;
        input [5:0] tile_col;
        input [5:0] tile_row;
        reg   [47:0] offset_row;
        reg   [47:0] offset_col;
    begin
        offset_row = tile_row;
        offset_row = offset_row * TILE_SIZE;
        offset_row = offset_row * LINE_STRIDE_BYTES;

        offset_col = tile_col;
        offset_col = offset_col * TILE_SIZE * 3;

        tile_color_addr = base + offset_row + offset_col;
    end
    endfunction

    function automatic [AXI_ADDR_WIDTH-1:0] tile_depth_addr;
        input [AXI_ADDR_WIDTH-1:0] base;
        input [5:0] tile_col;
        input [5:0] tile_row;
        reg   [47:0] offset_row;
        reg   [47:0] offset_col;
    begin
        offset_row = tile_row;
        offset_row = offset_row * TILE_SIZE;
        offset_row = offset_row * LINE_STRIDE_BYTES;

        offset_col = tile_col;
        offset_col = offset_col * TILE_SIZE * 3;

        tile_depth_addr = base + offset_row + offset_col;
    end
    endfunction

    function automatic [AXI_DATA_WIDTH-1:0] gather_tile_burst;
        input        use_depth;
        input        bank_sel;
        input [5:0]  burst_idx;
        integer      i;
        reg [AXI_DATA_WIDTH-1:0] packed;
        reg [8:0]  base_index;
    begin
        packed     = {AXI_DATA_WIDTH{1'b0}};
        base_index = burst_idx * PIXELS_PER_BURST;
        for (i = 0; i < PIXELS_PER_BURST; i = i + 1) begin
            if (use_depth)
                packed[(i*24) +: 24] = tile_depth[bank_sel][base_index + i];
            else
                packed[(i*24) +: 24] = tile_color[bank_sel][base_index + i];
        end
        gather_tile_burst = packed;
    end
    endfunction

    // ------------------------------------------------------------------
    // Tile-local storage (double buffered color + depth)
    // ------------------------------------------------------------------
    reg [23:0] tile_color   [0:1][0:TILE_PIXELS-1]; // RGBA6 packed
    reg [23:0] tile_depth   [0:1][0:TILE_PIXELS-1]; // U0.24 depth per pixel
    reg        tile_sel_wr;
    reg        tile_sel_rd;

    reg [8:0]  tile_write_cursor;

    reg [23:0] scanout_line_buffer [0:1][0:RENDER_WIDTH-1];

    // ------------------------------------------------------------------
    // Host-visible registers
    // ------------------------------------------------------------------
    localparam [CMD_ADDR_WIDTH-1:0] REG_RT_BASE_LO   = 16'h0000;
    localparam [CMD_ADDR_WIDTH-1:0] REG_RT_BASE_HI   = 16'h0001;
    localparam [CMD_ADDR_WIDTH-1:0] REG_DS_BASE_LO   = 16'h0002;
    localparam [CMD_ADDR_WIDTH-1:0] REG_DS_BASE_HI   = 16'h0003;
    localparam [CMD_ADDR_WIDTH-1:0] REG_RT_PITCH     = 16'h0004;
    localparam [CMD_ADDR_WIDTH-1:0] REG_CONTROL      = 16'h0005;
    localparam [CMD_ADDR_WIDTH-1:0] REG_STATUS       = 16'h0006;
    localparam [CMD_ADDR_WIDTH-1:0] REG_IRQ_MASK     = 16'h0007;
    localparam [CMD_ADDR_WIDTH-1:0] REG_IRQ_STATUS   = 16'h0008;
    localparam [CMD_ADDR_WIDTH-1:0] REG_CLEAR_COLOR  = 16'h0009;
    localparam [CMD_ADDR_WIDTH-1:0] REG_CLEAR_DEPTH  = 16'h000A;
    localparam [CMD_ADDR_WIDTH-1:0] REG_FENCE_LO     = 16'h000B;
    localparam [CMD_ADDR_WIDTH-1:0] REG_FENCE_HI     = 16'h000C;
    localparam [CMD_ADDR_WIDTH-1:0] REG_VERSION      = 16'h000D;

    localparam [CMD_DATA_WIDTH-1:0] VERSION_VALUE    = 24'h495249; // "IRI"

    reg [47:0] rt_base;
    reg [47:0] ds_base;
    reg [23:0] rt_pitch_reg;
    reg [23:0] clear_color_rgba6;
    reg [23:0] clear_depth24;
    reg [47:0] fence_addr;
    reg [CMD_DATA_WIDTH-1:0] control_reg;
    reg [CMD_DATA_WIDTH-1:0] status_reg;
    reg [CMD_DATA_WIDTH-1:0] irq_mask_reg;
    reg [CMD_DATA_WIDTH-1:0] irq_status_reg;

    reg kick_request;
    reg clear_enable;
    reg scanout_enable;

    wire tile_fsm_busy;
    reg  kick_consume_pulse;
    reg  frame_done_pulse;

    assign axi_ready_out = 1'b1; // single-cycle acceptance

    // ------------------------------------------------------------------
    // Command register interface
    // ------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_data_out      <= {CMD_DATA_WIDTH{1'b0}};
            rt_base           <= {AXI_ADDR_WIDTH{1'b0}};
            ds_base           <= {AXI_ADDR_WIDTH{1'b0}};
            rt_pitch_reg      <= LINE_STRIDE_BYTES[23:0];
            clear_color_rgba6 <= 24'h000000;
            clear_depth24     <= 24'hFFFFFF;
            fence_addr        <= {AXI_ADDR_WIDTH{1'b0}};
            control_reg       <= {CMD_DATA_WIDTH{1'b0}};
            status_reg        <= {CMD_DATA_WIDTH{1'b0}};
            irq_mask_reg      <= {CMD_DATA_WIDTH{1'b0}};
            irq_status_reg    <= {CMD_DATA_WIDTH{1'b0}};
            kick_request      <= 1'b0;
            clear_enable      <= 1'b1;
            scanout_enable    <= 1'b1;
        end else begin
            if (axi_valid_in) begin
                if (cmd_write_in) begin
                    case (cmd_addr_in)
                        REG_RT_BASE_LO:   rt_base[23:0]  <= cmd_wdata_in;
                        REG_RT_BASE_HI:   rt_base[47:24] <= cmd_wdata_in[23:0];
                        REG_DS_BASE_LO:   ds_base[23:0]  <= cmd_wdata_in;
                        REG_DS_BASE_HI:   ds_base[47:24] <= cmd_wdata_in[23:0];
                        REG_RT_PITCH:     rt_pitch_reg   <= cmd_wdata_in;
                        REG_CLEAR_COLOR:  clear_color_rgba6 <= cmd_wdata_in;
                        REG_CLEAR_DEPTH:  clear_depth24     <= cmd_wdata_in;
                        REG_FENCE_LO:     fence_addr[23:0]  <= cmd_wdata_in;
                        REG_FENCE_HI:     fence_addr[47:24] <= cmd_wdata_in[23:0];
                        REG_IRQ_MASK:     irq_mask_reg      <= cmd_wdata_in;
                        REG_IRQ_STATUS:   irq_status_reg    <= irq_status_reg & ~cmd_wdata_in; // W1C
                        REG_CONTROL: begin
                            control_reg    <= cmd_wdata_in;
                            clear_enable   <= cmd_wdata_in[1];
                            scanout_enable <= cmd_wdata_in[2];
                            if (cmd_wdata_in[0])
                                kick_request <= 1'b1; // latch kick until consumed
                        end
                        default: ;
                    endcase
                end else begin
                    case (cmd_addr_in)
                        REG_RT_BASE_LO:   axi_data_out <= rt_base[23:0];
                        REG_RT_BASE_HI:   axi_data_out <= rt_base[47:24];
                        REG_DS_BASE_LO:   axi_data_out <= ds_base[23:0];
                        REG_DS_BASE_HI:   axi_data_out <= ds_base[47:24];
                        REG_RT_PITCH:     axi_data_out <= rt_pitch_reg;
                        REG_CONTROL:      axi_data_out <= control_reg;
                        REG_STATUS:       axi_data_out <= status_reg;
                        REG_IRQ_MASK:     axi_data_out <= irq_mask_reg;
                        REG_IRQ_STATUS:   axi_data_out <= irq_status_reg;
                        REG_CLEAR_COLOR:  axi_data_out <= clear_color_rgba6;
                        REG_CLEAR_DEPTH:  axi_data_out <= clear_depth24;
                        REG_FENCE_LO:     axi_data_out <= fence_addr[23:0];
                        REG_FENCE_HI:     axi_data_out <= fence_addr[47:24];
                        REG_VERSION:      axi_data_out <= VERSION_VALUE;
                        default:          axi_data_out <= {CMD_DATA_WIDTH{1'b0}};
                    endcase
                end
            end

            if (kick_consume_pulse)
                kick_request <= 1'b0;

            if (frame_done_pulse)
                irq_status_reg[0] <= 1'b1;

            status_reg[0] <= kick_request;
            status_reg[1] <= tile_fsm_busy;
            status_reg[2] <= scanout_enable;
        end
    end

    // ------------------------------------------------------------------
    // Tile walker state machine
    // ------------------------------------------------------------------
    localparam [2:0] TW_IDLE        = 3'd0;
    localparam [2:0] TW_CLEAR_TILE  = 3'd1;
    localparam [2:0] TW_QUEUE_FLUSH = 3'd2;
    localparam [2:0] TW_WAIT_FLUSH  = 3'd3;
    localparam [2:0] TW_ADVANCE     = 3'd4;
    localparam [2:0] TW_DONE        = 3'd5;

    reg [2:0] tile_state;
    reg [5:0] tile_col;
    reg [5:0] tile_row;

    reg       tile_flush_valid;
    wire      tile_flush_ready;
    reg [AXI_ADDR_WIDTH-1:0] tile_flush_color_addr;
    reg [AXI_ADDR_WIDTH-1:0] tile_flush_depth_addr;
    reg [5:0] tile_flush_col;
    reg [5:0] tile_flush_row;
    reg       tile_flush_bank;
    reg       tile_flush_is_last;
    reg       tile_processed_any;

    assign tile_fsm_busy = (tile_state != TW_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tile_state            <= TW_IDLE;
            tile_col              <= 6'd0;
            tile_row              <= 6'd0;
            tile_sel_wr           <= 1'b0;
            tile_sel_rd           <= 1'b1;
            tile_write_cursor     <= 9'd0;
            tile_flush_valid      <= 1'b0;
            tile_flush_color_addr <= {AXI_ADDR_WIDTH{1'b0}};
            tile_flush_depth_addr <= {AXI_ADDR_WIDTH{1'b0}};
            tile_flush_col        <= 6'd0;
            tile_flush_row        <= 6'd0;
            tile_flush_bank       <= 1'b0;
            tile_flush_is_last    <= 1'b0;
            tile_processed_any    <= 1'b0;
            frame_done_irq        <= 1'b0;
            kick_consume_pulse    <= 1'b0;
            frame_done_pulse      <= 1'b0;
        end else begin
            frame_done_irq     <= 1'b0;
            kick_consume_pulse <= 1'b0;
            frame_done_pulse   <= 1'b0;

            case (tile_state)
                TW_IDLE: begin
                    if (kick_request) begin
                        tile_state        <= clear_enable ? TW_CLEAR_TILE : TW_QUEUE_FLUSH;
                        tile_col          <= 6'd0;
                        tile_row          <= 6'd0;
                        tile_write_cursor <= 9'd0;
                        tile_sel_wr       <= 1'b0;
                        tile_sel_rd       <= 1'b1;
                        tile_processed_any<= 1'b0;
                        tile_flush_valid  <= 1'b0;
                        kick_consume_pulse<= 1'b1;
                    end
                end

                TW_CLEAR_TILE: begin
                    tile_color[tile_sel_wr][tile_write_cursor] <= clear_color_rgba6;
                    tile_depth[tile_sel_wr][tile_write_cursor] <= clear_depth24;

                    if (tile_write_cursor == TILE_PIXELS-1) begin
                        tile_write_cursor <= 9'd0;
                        tile_flush_bank   <= tile_sel_wr;
                        tile_sel_wr       <= ~tile_sel_wr;
                        tile_state        <= TW_QUEUE_FLUSH;
                    end else begin
                        tile_write_cursor <= tile_write_cursor + 9'd1;
                    end
                end

                TW_QUEUE_FLUSH: begin
                    if (!tile_flush_valid) begin
                        tile_flush_color_addr <= tile_color_addr(rt_base, tile_col, tile_row);
                        tile_flush_depth_addr <= tile_depth_addr(ds_base, tile_col, tile_row);
                        tile_flush_col        <= tile_col;
                        tile_flush_row        <= tile_row;
                        tile_flush_is_last    <= (tile_col == RENDER_TILE_COLS-1) && (tile_row == RENDER_TILE_ROWS-1);
                        tile_flush_valid      <= 1'b1;
                        tile_processed_any    <= 1'b1;
                        tile_sel_rd           <= tile_flush_bank;
                        tile_state            <= TW_WAIT_FLUSH;
                    end
                end

                TW_WAIT_FLUSH: begin
                    if (tile_flush_valid && tile_flush_ready) begin
                        tile_flush_valid <= 1'b0;
                        tile_state       <= TW_ADVANCE;
                    end
                end

                TW_ADVANCE: begin
                    if (tile_col == RENDER_TILE_COLS-1) begin
                        tile_col <= 6'd0;
                        if (tile_row == RENDER_TILE_ROWS-1) begin
                            tile_state <= TW_DONE;
                        end else begin
                            tile_row   <= tile_row + 6'd1;
                            tile_state <= clear_enable ? TW_CLEAR_TILE : TW_QUEUE_FLUSH;
                        end
                    end else begin
                        tile_col   <= tile_col + 6'd1;
                        tile_state <= clear_enable ? TW_CLEAR_TILE : TW_QUEUE_FLUSH;
                    end
                end

                TW_DONE: begin
                    frame_done_irq   <= 1'b1;
                    frame_done_pulse <= 1'b1;
                    tile_state       <= TW_IDLE;
                end

                default: tile_state <= TW_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Tile flush DMA (color + depth writes)
    // ------------------------------------------------------------------
    localparam [2:0] DMA_IDLE         = 3'd0;
    localparam [2:0] DMA_AW_COLOR     = 3'd1;
    localparam [2:0] DMA_W_COLOR      = 3'd2;
    localparam [2:0] DMA_B_COLOR      = 3'd3;
    localparam [2:0] DMA_AW_DEPTH     = 3'd4;
    localparam [2:0] DMA_W_DEPTH      = 3'd5;
    localparam [2:0] DMA_B_DEPTH      = 3'd6;

    reg [2:0]  dma_state;
    reg [5:0]  dma_burst_idx;
    reg        dma_bank_sel;
    reg [AXI_ADDR_WIDTH-1:0] dma_color_addr;
    reg [AXI_ADDR_WIDTH-1:0] dma_depth_addr;
    reg        dma_do_depth;

    wire depth_enabled = |ds_base;

    assign tile_flush_ready = (dma_state == DMA_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_state       <= DMA_IDLE;
            dma_burst_idx   <= 6'd0;
            dma_bank_sel    <= 1'b0;
            dma_color_addr  <= {AXI_ADDR_WIDTH{1'b0}};
            dma_depth_addr  <= {AXI_ADDR_WIDTH{1'b0}};
            dma_do_depth    <= 1'b0;

            axi_awvalid     <= 1'b0;
            axi_awaddr      <= {AXI_ADDR_WIDTH{1'b0}};
            axi_awid        <= {AXI_ID_WIDTH{1'b0}};
            axi_awlen       <= 8'd0;
            axi_awsize      <= 3'd0;
            axi_awburst     <= 2'b01;
            axi_awlock      <= 1'b0;
            axi_awcache     <= 4'd0;
            axi_awprot      <= 3'd0;
            axi_awqos       <= 4'd0;

            axi_wvalid      <= 1'b0;
            axi_wdata       <= {AXI_DATA_WIDTH{1'b0}};
            axi_wstrb       <= {(AXI_DATA_WIDTH/8){1'b1}};
            axi_wlast       <= 1'b0;

            axi_bready      <= 1'b0;

        end else begin
            case (dma_state)
                DMA_IDLE: begin
                    axi_wstrb  <= {(AXI_DATA_WIDTH/8){1'b1}};
                    axi_bready <= 1'b0;
                    if (tile_flush_valid) begin
                        dma_bank_sel   <= tile_flush_bank;
                        dma_color_addr <= tile_flush_color_addr;
                        dma_depth_addr <= tile_flush_depth_addr;
                        dma_do_depth   <= depth_enabled;
                        dma_burst_idx  <= 6'd0;

                        axi_awaddr     <= tile_flush_color_addr;
                        axi_awlen      <= TILE_BURSTS[7:0] - 8'd1;
                        axi_awvalid    <= 1'b1;
                        axi_wlast      <= 1'b0;
                        axi_awsize     <= 3'd0; // unused by downstream
                        dma_state      <= DMA_AW_COLOR;
                    end
                end

                DMA_AW_COLOR: begin
                    if (axi_awvalid && axi_awready) begin
                        axi_awvalid <= 1'b0;
                        axi_wvalid  <= 1'b1;
                        axi_wdata   <= gather_tile_burst(1'b0, dma_bank_sel, dma_burst_idx);
                        axi_wlast   <= (TILE_BURSTS == 1);
                        axi_bready  <= 1'b1;
                        dma_state   <= DMA_W_COLOR;
                    end
                end

                DMA_W_COLOR: begin
                    if (axi_wvalid && axi_wready) begin
                        if (dma_burst_idx == TILE_BURSTS-1) begin
                            axi_wvalid <= 1'b0;
                            axi_wlast  <= 1'b0;
                            dma_state  <= DMA_B_COLOR;
                        end else begin
                            dma_burst_idx <= dma_burst_idx + 6'd1;
                            axi_wdata     <= gather_tile_burst(1'b0, dma_bank_sel, dma_burst_idx + 6'd1);
                            axi_wlast     <= (dma_burst_idx + 6'd2 == TILE_BURSTS);
                        end
                    end
                end

                DMA_B_COLOR: begin
                    if (axi_bvalid && axi_bready) begin
                        axi_bready <= 1'b0;
                        if (dma_do_depth) begin
                            dma_burst_idx <= 6'd0;
                            axi_awaddr    <= dma_depth_addr;
                            axi_awlen     <= TILE_BURSTS[7:0] - 8'd1;
                            axi_awvalid   <= 1'b1;
                            dma_state     <= DMA_AW_DEPTH;
                        end else begin
                            dma_state <= DMA_IDLE;
                        end
                    end
                end

                DMA_AW_DEPTH: begin
                    if (axi_awvalid && axi_awready) begin
                        axi_awvalid <= 1'b0;
                        axi_wvalid  <= 1'b1;
                        axi_wdata   <= gather_tile_burst(1'b1, dma_bank_sel, dma_burst_idx);
                        axi_wlast   <= (TILE_BURSTS == 1);
                        axi_bready  <= 1'b1;
                        dma_state   <= DMA_W_DEPTH;
                    end
                end

                DMA_W_DEPTH: begin
                    if (axi_wvalid && axi_wready) begin
                        if (dma_burst_idx == TILE_BURSTS-1) begin
                            axi_wvalid <= 1'b0;
                            axi_wlast  <= 1'b0;
                            dma_state  <= DMA_B_DEPTH;
                        end else begin
                            dma_burst_idx <= dma_burst_idx + 6'd1;
                            axi_wdata     <= gather_tile_burst(1'b1, dma_bank_sel, dma_burst_idx + 6'd1);
                            axi_wlast     <= (dma_burst_idx + 6'd2 == TILE_BURSTS);
                        end
                    end
                end

                DMA_B_DEPTH: begin
                    if (axi_bvalid && axi_bready) begin
                        axi_bready <= 1'b0;
                        dma_state   <= DMA_IDLE;
                    end
                end

                default: dma_state <= DMA_IDLE;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Scanout request/stream plumbing (720p read path)
    // ------------------------------------------------------------------
    reg        scanout_line_req_valid;
    reg [9:0]  scanout_line_req_index;
    reg        scanout_req_toggle_pix;
    reg [9:0]  scanout_req_line_index_pix;
    reg        scanout_req_bank_pix;

    reg        scanout_ack_toggle_pix_sync1;
    reg        scanout_ack_toggle_pix_sync2;
    reg        scanout_ack_toggle_pix_prev;
    reg        scanout_ack_bank_pix_sync1;
    reg        scanout_ack_bank_pix_sync2;

    reg        scanout_line_active_bank;
    reg        scanout_line_ready_bank;
    reg        scanout_line_ready_pending;
    reg        scanout_line_data_valid;
    reg [9:0]  scanout_line_read_idx;

    wire       scanout_line_req_ready;
    wire [23:0] scanout_pixel_current;
    wire        scanout_pixel_valid;

    assign scanout_line_req_ready = (scanout_req_toggle_pix == scanout_ack_toggle_pix_sync2);
    assign scanout_pixel_current  = scanout_line_buffer[scanout_line_active_bank][scanout_line_read_idx];
    assign scanout_pixel_valid    = scanout_line_data_valid && video_de && pixel_in_render && (scanout_line_read_idx < RENDER_WIDTH);

    reg        scanout_req_toggle_clk_sync1;
    reg        scanout_req_toggle_clk_sync2;
    reg        scanout_req_toggle_clk_seen;
    reg [9:0]  scanout_req_line_index_clk;
    reg        scanout_req_bank_clk;
    reg        scanout_req_pending;

    reg        scanout_ack_toggle_clk;
    reg        scanout_ack_bank_clk;

    localparam [2:0] SD_IDLE   = 3'd0;
    localparam [2:0] SD_AR     = 3'd1;
    localparam [2:0] SD_STREAM = 3'd2;
    localparam [2:0] SD_DONE   = 3'd3;

    reg [2:0]  scanout_dma_state;
    reg [6:0]  scanout_dma_burst_idx;
    reg [9:0]  scanout_dma_pixel_ptr;

    integer px;

    reg [10:0] h_ctr;
    reg [9:0]  v_ctr;
    wire       h_active;
    wire       v_active;
    wire       pixel_in_render;
    wire       line_in_render;

    assign h_active       = (h_ctr < OUTPUT_WIDTH);
    assign v_active       = (v_ctr < OUTPUT_HEIGHT);
    assign line_in_render = (v_ctr >= LETTERBOX_Y_OFF) && (v_ctr < LETTERBOX_Y_OFF + RENDER_HEIGHT);
    assign pixel_in_render = line_in_render && (h_ctr >= LETTERBOX_X_OFF) && (h_ctr < LETTERBOX_X_OFF + RENDER_WIDTH);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scanout_req_toggle_clk_sync1 <= 1'b0;
            scanout_req_toggle_clk_sync2 <= 1'b0;
            scanout_req_toggle_clk_seen  <= 1'b0;
            scanout_req_line_index_clk   <= 10'd0;
            scanout_req_bank_clk         <= 1'b0;
            scanout_req_pending          <= 1'b0;
            scanout_ack_toggle_clk       <= 1'b0;
            scanout_ack_bank_clk         <= 1'b0;
            scanout_dma_state            <= SD_IDLE;
            scanout_dma_burst_idx        <= 7'd0;
            scanout_dma_pixel_ptr        <= 10'd0;

            axi_arvalid <= 1'b0;
            axi_araddr  <= {AXI_ADDR_WIDTH{1'b0}};
            axi_arid    <= {AXI_ID_WIDTH{1'b0}};
            axi_arlen   <= 8'd0;
            axi_arsize  <= 3'd0;
            axi_arburst <= 2'b01;
            axi_arlock  <= 1'b0;
            axi_arcache <= 4'd0;
            axi_arprot  <= 3'd0;
            axi_arqos   <= 4'd0;

            axi_rready  <= 1'b0;
        end else begin
            scanout_req_toggle_clk_sync1 <= scanout_req_toggle_pix;
            scanout_req_toggle_clk_sync2 <= scanout_req_toggle_clk_sync1;

            if (scanout_req_toggle_clk_sync2 != scanout_req_toggle_clk_seen) begin
                scanout_req_toggle_clk_seen <= scanout_req_toggle_clk_sync2;
                scanout_req_line_index_clk  <= scanout_req_line_index_pix;
                scanout_req_bank_clk        <= scanout_req_bank_pix;
                scanout_req_pending         <= 1'b1;
            end

            case (scanout_dma_state)
                SD_IDLE: begin
                    axi_rready <= 1'b0;
                    if (scanout_req_pending) begin
                        axi_araddr  <= rt_base + (scanout_req_line_index_clk * rt_pitch_reg);
                        axi_arid    <= {AXI_ID_WIDTH{1'b0}};
                        axi_arlen   <= LINE_BURSTS[7:0] - 8'd1;
                        axi_arsize  <= 3'd0;
                        axi_arburst <= 2'b01;
                        axi_arlock  <= 1'b0;
                        axi_arcache <= 4'd0;
                        axi_arprot  <= 3'd0;
                        axi_arqos   <= 4'd0;
                        axi_arvalid <= 1'b1;
                        axi_rready  <= 1'b1;

                        scanout_dma_state     <= SD_AR;
                        scanout_dma_burst_idx <= 7'd0;
                        scanout_dma_pixel_ptr <= 10'd0;
                    end
                end

                SD_AR: begin
                    if (axi_arvalid && axi_arready) begin
                        axi_arvalid <= 1'b0;
                        scanout_dma_state <= SD_STREAM;
                    end
                end

                SD_STREAM: begin
                    if (axi_rvalid && axi_rready) begin
                        for (px = 0; px < PIXELS_PER_BURST; px = px + 1) begin
                            scanout_line_buffer[scanout_req_bank_clk][scanout_dma_pixel_ptr + px] <= axi_rdata[(px*24) +: 24];
                        end

                        scanout_dma_pixel_ptr <= scanout_dma_pixel_ptr + PIXELS_PER_BURST;
                        scanout_dma_burst_idx <= scanout_dma_burst_idx + 7'd1;

                        if (axi_rlast) begin
                            axi_rready        <= 1'b0;
                            scanout_req_pending <= 1'b0;
                            scanout_dma_state <= SD_DONE;
                        end
                    end
                end

                SD_DONE: begin
                    scanout_ack_bank_clk   <= scanout_req_bank_clk;
                    scanout_ack_toggle_clk <= ~scanout_ack_toggle_clk;
                    scanout_dma_state      <= SD_IDLE;
                end

                default: scanout_dma_state <= SD_IDLE;
            endcase
        end
    end

    always @(posedge pix_clk or negedge pix_rst_n) begin
        if (!pix_rst_n) begin
            h_ctr <= 11'd0;
            v_ctr <= 10'd0;
        end else begin
            if (h_ctr == OUTPUT_TOTAL_WIDTH-1) begin
                h_ctr <= 11'd0;
                if (v_ctr == OUTPUT_TOTAL_HEIGHT-1)
                    v_ctr <= 10'd0;
                else
                    v_ctr <= v_ctr + 10'd1;
            end else begin
                h_ctr <= h_ctr + 11'd1;
            end
        end
    end

    always @(posedge pix_clk or negedge pix_rst_n) begin
        if (!pix_rst_n) begin
            video_de    <= 1'b0;
            video_hsync <= 1'b0;
            video_vsync <= 1'b0;
            video_r     <= 8'd0;
            video_g     <= 8'd0;
            video_b     <= 8'd0;
            scanout_line_req_valid     <= 1'b0;
            scanout_line_req_index     <= 10'd0;
            scanout_req_toggle_pix     <= 1'b0;
            scanout_req_line_index_pix <= 10'd0;
            scanout_req_bank_pix       <= 1'b0;
            scanout_ack_toggle_pix_sync1 <= 1'b0;
            scanout_ack_toggle_pix_sync2 <= 1'b0;
            scanout_ack_toggle_pix_prev  <= 1'b0;
            scanout_ack_bank_pix_sync1   <= 1'b0;
            scanout_ack_bank_pix_sync2   <= 1'b0;
            scanout_line_active_bank     <= 1'b0;
            scanout_line_ready_bank      <= 1'b0;
            scanout_line_ready_pending   <= 1'b0;
            scanout_line_data_valid      <= 1'b0;
            scanout_line_read_idx        <= 10'd0;
        end else begin
            scanout_ack_toggle_pix_sync1 <= scanout_ack_toggle_clk;
            scanout_ack_toggle_pix_sync2 <= scanout_ack_toggle_pix_sync1;
            scanout_ack_bank_pix_sync1   <= scanout_ack_bank_clk;
            scanout_ack_bank_pix_sync2   <= scanout_ack_bank_pix_sync1;

            video_de    <= scanout_enable && h_active && v_active;
            video_hsync <= (h_ctr >= OUTPUT_WIDTH + OUTPUT_H_FP) && (h_ctr < OUTPUT_WIDTH + OUTPUT_H_FP + OUTPUT_H_SYNC);
            video_vsync <= (v_ctr >= OUTPUT_HEIGHT + OUTPUT_V_FP) && (v_ctr < OUTPUT_HEIGHT + OUTPUT_V_FP + OUTPUT_V_SYNC);

            if (!scanout_enable) begin
                scanout_line_req_valid   <= 1'b0;
                scanout_line_ready_pending <= 1'b0;
                scanout_line_data_valid  <= 1'b0;
            end

            if (scanout_enable && (h_ctr == 11'd0)) begin
                if (line_in_render) begin
                    scanout_line_req_index <= v_ctr - LETTERBOX_Y_OFF;
                    scanout_req_bank_pix   <= ~scanout_line_active_bank;
                    scanout_line_req_valid <= 1'b1;
                end else begin
                    scanout_line_req_valid <= 1'b0;
                end
            end

            if (scanout_line_req_valid && scanout_line_req_ready) begin
                scanout_line_req_valid     <= 1'b0;
                scanout_req_line_index_pix <= scanout_line_req_index;
                scanout_req_toggle_pix     <= ~scanout_req_toggle_pix;
            end

            if (scanout_ack_toggle_pix_sync2 != scanout_ack_toggle_pix_prev) begin
                scanout_ack_toggle_pix_prev <= scanout_ack_toggle_pix_sync2;
                scanout_line_ready_bank     <= scanout_ack_bank_pix_sync2;
                scanout_line_ready_pending  <= 1'b1;
            end

            if (!scanout_line_data_valid && scanout_line_ready_pending) begin
                scanout_line_active_bank   <= scanout_line_ready_bank;
                scanout_line_data_valid    <= 1'b1;
                scanout_line_ready_pending <= 1'b0;
                scanout_line_read_idx      <= 10'd0;
            end

            if (scanout_pixel_valid) begin
                if (scanout_line_read_idx == RENDER_WIDTH-1) begin
                    scanout_line_data_valid <= 1'b0;
                    scanout_line_read_idx   <= 10'd0;
                end else begin
                    scanout_line_read_idx <= scanout_line_read_idx + 10'd1;
                end
            end

            if (scanout_enable && video_de && pixel_in_render && scanout_line_data_valid) begin
                video_r <= expand6_to_8(scanout_pixel_current[23:18]);
                video_g <= expand6_to_8(scanout_pixel_current[17:12]);
                video_b <= expand6_to_8(scanout_pixel_current[11:6]);
            end else begin
                video_r <= 8'd0;
                video_g <= 8'd0;
                video_b <= 8'd0;
            end
        end
    end

    // ------------------------------------------------------------------
    // Placeholder: Remaining pipeline (DMA engines, FIFOs, etc.)
    // ------------------------------------------------------------------

endmodule
