`include "src/sizes.vh"

// Simple direct-mapped caches for Amber with 16 lines x 16 words (24-bit words).
// - Line size: 16 words (offset bits = 4)
// - Number of lines: 16 (index bits = 4)
// - Tag bits: 48 - 4 - 4 = 40
//
// Read latency: 1 cycle on hit (registered output like mem.v).
// On miss: cache stalls the core via ow_stall and refills the line from the
// provided backing memory ports (simple BRAM-like interface compatible with mem.v).
//
// Notes:
// - I-cache is read-only and only uses front port [0].
// - D-cache supports the Amber MA/MO dual-port protocol and 24/48-bit ops.
// - Refills and write-throughs use the dedicated backing memory instances that
//   are not visible to the pipeline. The refill path is implemented as a
//   sequential 16-beat read (one word per cycle) per line.

module icache_16x16_24(
    input  wire                 clk,
    input  wire                 rst,
    // Front side (to pipeline IF): matches mem.v read interface for [0]
    input  wire [`HBIT_ADDR:0]  f_addr,
    input  wire                 f_is48,       // ignored (instructions are 24-bit)
    output reg  [`HBIT_ADDR:0]  f_rdata,      // lower 24-bit used by IF
    output wire                 ow_stall,
    // Backing memory side (private, BRAM-like or AXI-adapted)
    output reg  [`HBIT_ADDR:0]  b_addr,
    output reg                  b_req,
    input  wire                 b_valid,
    input  wire [`HBIT_ADDR:0]  b_rdata
);
    localparam OFF_BITS = 4;   // 16 words per line
    localparam IDX_BITS = 4;   // 16 lines
    localparam TAG_BITS = 48 - OFF_BITS - IDX_BITS;

    // Data and metadata arrays
    reg [23:0]                data [0:(1<< (IDX_BITS+OFF_BITS)) - 1]; // 256 words
    reg [TAG_BITS-1:0]        tag  [0:(1<<IDX_BITS) - 1];
    reg                       valid[0:(1<<IDX_BITS) - 1];

    // Address decode
    wire [OFF_BITS-1:0] off = f_addr[OFF_BITS-1:0];
    wire [IDX_BITS-1:0] idx = f_addr[OFF_BITS+IDX_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0] atag= f_addr[`HBIT_ADDR:OFF_BITS+IDX_BITS];

    // Hit/miss detection
    wire hit = valid[idx] && (tag[idx] == atag);
    wire line_ready = valid[idx] && (tag[idx] == atag);

    // Miss handling
    reg                miss_active;
    reg                miss_issue;   // request for current beat issued
    reg [IDX_BITS-1:0] miss_idx;
    reg [TAG_BITS-1:0] miss_tag;
    reg [OFF_BITS-1:0] miss_cnt;     // current beat index
    reg [47:0]         base_addr;    // aligned to line start

    assign ow_stall = miss_active & ~line_ready; // allow pre-seeded lines to run without stalling

    // Backing address generator
    always @(*) begin
        // Default no access
        b_addr = 48'b0;
        b_req  = 1'b0;
        if (miss_active) begin
            b_addr = base_addr + {44'b0, miss_cnt};
            b_req  = ~miss_issue; // assert request when not yet issued
        end
    end

    // Front read output (registered, 1-cycle latency like mem.v)
    reg [23:0] rd_word;
    always @(*) begin
        rd_word = 24'b0;
        if (hit) begin
            rd_word = data[{idx, off}];
        end else if (miss_active && (idx == miss_idx)) begin
            // When refilling the same line, expose the words already present (e.g.,
            // preseeded by testbenches) instead of forcing zeros. This avoids the
            // frontend observing bogus NOPs while the line is still marked in-flight.
            rd_word = data[{idx, off}];
        end else begin
            // Otherwise (miss on a different line) provide zero until refill.
            rd_word = 24'b0;
        end
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            f_rdata <= 48'b0;
        end else if (!miss_active) begin
            // Hold output stable during refills to avoid transient values in IF
            f_rdata <= {24'b0, rd_word};
        end else begin
            f_rdata <= f_rdata;
        end
    end

    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            miss_active <= 1'b0;
            miss_idx    <= {IDX_BITS{1'b0}};
            miss_tag    <= {TAG_BITS{1'b0}};
            miss_cnt    <= {OFF_BITS{1'b0}};
            miss_issue  <= 1'b0;
            base_addr   <= 48'b0;
            for (i = 0; i < (1<<IDX_BITS); i = i + 1) begin
                valid[i] <= 1'b0;
                tag[i]   <= {TAG_BITS{1'b0}};
            end
        end else begin
            if (!miss_active) begin
                // Check for miss on current access
                if (!hit) begin
                    miss_active <= 1'b1;
                    miss_idx    <= idx;
                    miss_tag    <= atag;
                    miss_cnt    <= {OFF_BITS{1'b0}};
                    miss_issue  <= 1'b0; // next cycle issue first request
                    base_addr   <= {atag, idx, {OFF_BITS{1'b0}}};
                end
            end else begin
                if (valid[miss_idx] && (tag[miss_idx] == miss_tag)) begin
                    // Line was populated externally; drop the outstanding miss.
                    miss_active <= 1'b0;
                    miss_issue  <= 1'b0;
                end else begin
                    // Handshaked refill: issue one request per beat; store when b_valid
                    if (b_valid) begin
                        data[{miss_idx, miss_cnt}] <= b_rdata[23:0];
                        miss_issue <= 1'b0;
                        if (miss_cnt == {OFF_BITS{1'b1}}) begin
                            valid[miss_idx] <= 1'b1;
                            tag[miss_idx]   <= miss_tag;
                            miss_active     <= 1'b0;
                        end else begin
                            miss_cnt <= miss_cnt + 1'b1;
                        end
                    end else begin
                        // Waiting for valid; remember we've issued the request
                        if (!miss_issue)
                            miss_issue <= 1'b1;
                    end
                end
            end
        end
    end
endmodule


module dcache_16x16_24(
    input  wire                 clk,
    input  wire                 rst,
    // Front side (to MA/MO) mirrors mem.v dual-port interface
    input  wire                 f_we    [0:1],
    input  wire [`HBIT_ADDR:0]  f_addr  [0:1],
    input  wire [`HBIT_ADDR:0]  f_wdata [0:1], // 48-bit packed for 48-bit ops
    input  wire                 f_is48  [0:1],
    output reg  [`HBIT_ADDR:0]  f_rdata [0:1],
    output wire                 ow_stall,
    // Backing memory side (private, BRAM-like: mem.v instance)
    output reg  [`HBIT_ADDR:0]  b_addr,
    output reg                  b_req,
    output reg                  b_we,
    output reg  [`HBIT_ADDR:0]  b_wdata,
    output reg                  b_is48,
    input  wire                 b_valid,
    input  wire [`HBIT_ADDR:0]  b_rdata
);
    localparam OFF_BITS = 4;   // 16 words per line
    localparam IDX_BITS = 4;   // 16 lines
    localparam TAG_BITS = 48 - OFF_BITS - IDX_BITS;

    // Cache arrays
    reg [23:0]         data [0:(1<< (IDX_BITS+OFF_BITS)) - 1]; // 256 words
    reg [TAG_BITS-1:0] tag  [0:(1<<IDX_BITS) - 1];
    reg                valid[0:(1<<IDX_BITS) - 1];

    // Front decode helpers per port
    wire [OFF_BITS-1:0] off_p0 = f_addr[0][OFF_BITS-1:0];
    wire [IDX_BITS-1:0] idx_p0 = f_addr[0][OFF_BITS+IDX_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0] tag_p0 = f_addr[0][`HBIT_ADDR:OFF_BITS+IDX_BITS];
    wire [47:0]         addr0_nxt = f_addr[0] + 48'd1;
    wire [OFF_BITS-1:0] off0_nxt  = addr0_nxt[OFF_BITS-1:0];
    wire [IDX_BITS-1:0] idx0_nxt  = addr0_nxt[OFF_BITS+IDX_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0] tag0_nxt  = addr0_nxt[`HBIT_ADDR:OFF_BITS+IDX_BITS];

    wire [OFF_BITS-1:0] off_p1 = f_addr[1][OFF_BITS-1:0];
    wire [IDX_BITS-1:0] idx_p1 = f_addr[1][OFF_BITS+IDX_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0] tag_p1 = f_addr[1][`HBIT_ADDR:OFF_BITS+IDX_BITS];
    wire [47:0]         addr1_nxt = f_addr[1] + 48'd1;
    wire [OFF_BITS-1:0] off1_nxt  = addr1_nxt[OFF_BITS-1:0];
    wire [IDX_BITS-1:0] idx1_nxt  = addr1_nxt[OFF_BITS+IDX_BITS-1:OFF_BITS];
    wire [TAG_BITS-1:0] tag1_nxt  = addr1_nxt[`HBIT_ADDR:OFF_BITS+IDX_BITS];

    wire hit_p0 = valid[idx_p0] && (tag[idx_p0] == tag_p0);
    wire hit_p1 = valid[idx_p1] && (tag[idx_p1] == tag_p1);
    // For 48-bit reads crossing a line (off==15), require the next line to be present too
    wire hit_p0_48_ok = hit_p0 && (!f_is48[0] || (off_p0 != {OFF_BITS{1'b1}}) || (valid[idx0_nxt] && (tag[idx0_nxt] == tag0_nxt)));
    wire hit_p1_48_ok = hit_p1 && (!f_is48[1] || (off_p1 != {OFF_BITS{1'b1}}) || (valid[idx1_nxt] && (tag[idx1_nxt] == tag1_nxt)));

    // Simple policy: stall core if any access misses until refill completes.
    reg                miss_active;
    reg                miss_issue;   // request issued for current beat
    reg [IDX_BITS-1:0] miss_idx;
    reg [TAG_BITS-1:0] miss_tag;
    reg [OFF_BITS-1:0] miss_cnt;     // request counter
    reg [OFF_BITS-1:0] miss_req_cnt; // request pointer
    reg [47:0]         base_addr;
    assign ow_stall = miss_active;

    // Backing memory control
    // One access per cycle: either refill word, or write-through store.
    // Prioritize refill when active; otherwise, service write-throughs.
    reg                pend_store;
    reg [`HBIT_ADDR:0] pend_store_addr;
    reg [`HBIT_ADDR:0] pend_store_wdata;
    reg                pend_store_is48;
    reg                refill_prev_valid;
    reg [OFF_BITS-1:0] refill_prev_idx;
    reg [23:0]         refill_prev_data;

    always @(*) begin
        b_addr  = 48'b0;
        b_req   = 1'b0;
        b_we    = 1'b0;
        b_wdata = 48'b0;
        b_is48  = 1'b0;
        if (miss_active) begin
            b_addr = base_addr + {44'b0, miss_req_cnt};
            if (!miss_issue && (miss_req_cnt <= {OFF_BITS{1'b1}}))
                b_req  = 1'b1;
            // writes are blocked during refill
        end else if (pend_store) begin
            b_addr  = pend_store_addr;
            b_we    = 1'b1;
            b_wdata = pend_store_wdata;
            b_is48  = pend_store_is48;
        end
    end
`ifndef SYNTHESIS
    // Debug: show write-through operations to backing memory
    always @(posedge clk) begin
        if (!rst && !miss_active && pend_store) begin
            $display("[DC] WTHRU addr=%0d data_lo=%h data_hi=%h is48=%0d", pend_store_addr,
                     pend_store_wdata[23:0], pend_store_wdata[47:24], pend_store_is48);
        end
    end
`endif
    // Read datapath to front (registered like mem.v)
    reg [47:0] rd_p0, rd_p1;
    always @(*) begin
        // default
        rd_p0 = 48'b0; rd_p1 = 48'b0;
        // Port 0
        if (f_is48[0]) begin
            // 48-bit assemble from two 24b words
            // If cross-line, will likely miss; policy: rely on refill logic to
            // make both words available; otherwise returns partial zeros.
            rd_p0 = { data[{idx_p0, off_p0} + 1'b1], data[{idx_p0, off_p0}] };
        end else begin
            rd_p0 = {24'b0, data[{idx_p0, off_p0}]};
        end
        // Port 1
        if (f_is48[1]) begin
            rd_p1 = { data[{idx_p1, off_p1} + 1'b1], data[{idx_p1, off_p1}] };
        end else begin
            rd_p1 = {24'b0, data[{idx_p1, off_p1}]};
        end
    end
    // Miss detection wires (combinational)
    reg init_done;
    wire miss0 = init_done && (!f_we[0]) && (!hit_p0_48_ok);
    wire miss1 = init_done && (!f_we[1]) && (!hit_p1_48_ok);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            f_rdata[0] <= 48'b0;
            f_rdata[1] <= 48'b0;
        end else if (!miss_active) begin
            // Update front-side read data only when not refilling.
            // During a miss/refill (including cross-line second phase), hold
            // outputs stable to avoid propagating transient/old values.
            f_rdata[0] <= rd_p0;
            f_rdata[1] <= rd_p1;
        end else begin
            f_rdata[0] <= f_rdata[0];
            f_rdata[1] <= f_rdata[1];
        end
    end

    // Miss state for single outstanding refill, with optional second line for cross-line 48b read
    reg                miss_need_second;
    reg [IDX_BITS-1:0] miss_idx2;
    reg [TAG_BITS-1:0] miss_tag2;
    integer j;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            miss_active <= 1'b0;
            miss_idx    <= {IDX_BITS{1'b0}};
            miss_tag    <= {TAG_BITS{1'b0}};
            miss_cnt    <= {OFF_BITS{1'b0}};
            miss_req_cnt <= {OFF_BITS{1'b0}};
            miss_issue  <= 1'b0;
            base_addr   <= 48'b0;
            miss_need_second <= 1'b0;
            miss_idx2   <= {IDX_BITS{1'b0}};
            miss_tag2   <= {TAG_BITS{1'b0}};
            pend_store  <= 1'b0;
            pend_store_addr  <= 48'b0;
            pend_store_wdata <= 48'b0;
            pend_store_is48  <= 1'b0;
            refill_prev_valid <= 1'b0;
            refill_prev_idx   <= {OFF_BITS{1'b0}};
            refill_prev_data  <= 24'b0;
            init_done         <= 1'b0;
            for (j = 0; j < (1<<IDX_BITS); j = j + 1) begin
                valid[j] <= 1'b0;
                tag[j]   <= {TAG_BITS{1'b0}};
            end
        end else begin
            init_done <= 1'b1;
            // Detect misses on read operations (loads)
            // The MA stage already set the address; the MO stage consumes it
            // one cycle later using the selected port. We conservatively
            // trigger refill if either port read misses.
            if (!miss_active) begin
                // Only consider as read if not writing on that port
                if (miss0 || miss1) begin
`ifndef SYNTHESIS
                    integer dbg_port;
                    reg [47:0] dbg_addr;
                    dbg_port = (miss0 === 1'b1) ? 0 : 1;
                    dbg_addr = (dbg_port == 0) ? f_addr[0] : f_addr[1];
                    $display("[DC] MISS port=%0d addr=%0d idx=%0d off=%0d", dbg_port, dbg_addr, (dbg_port==0 ? idx_p0 : idx_p1), (dbg_port==0 ? off_p0 : off_p1));
`endif
                    miss_active <= 1'b1;
                    // Choose the port to service (prefer p0)
                    if (miss0) begin
                        miss_idx  <= idx_p0;
                        miss_tag  <= tag_p0;
                        base_addr <= {tag_p0, idx_p0, {OFF_BITS{1'b0}}};
                        // Need second line only if 48b and cross-line and that second line isn't already present
                        miss_need_second <= (f_is48[0] && (off_p0 == {OFF_BITS{1'b1}}) && !(valid[idx0_nxt] && (tag[idx0_nxt] == tag0_nxt)));
                        miss_idx2 <= idx0_nxt;
                        miss_tag2 <= tag0_nxt;
                    end else begin
                        miss_idx  <= idx_p1;
                        miss_tag  <= tag_p1;
                        base_addr <= {tag_p1, idx_p1, {OFF_BITS{1'b0}}};
                        miss_need_second <= (f_is48[1] && (off_p1 == {OFF_BITS{1'b1}}) && !(valid[idx1_nxt] && (tag[idx1_nxt] == tag1_nxt)));
                        miss_idx2 <= idx1_nxt;
                        miss_tag2 <= tag1_nxt;
                    end
                    miss_cnt    <= {OFF_BITS{1'b0}};
                    miss_req_cnt <= {OFF_BITS{1'b0}};
                    miss_issue  <= 1'b0; // prime for first request
                    refill_prev_valid <= 1'b0;
                end else begin
                    // No miss; look for store to push to backing (write-through)
                    pend_store <= 1'b0;
                    // Port 0 store
                    if (f_we[0]) begin
                        if (f_is48[0]) begin
                            // write two words to cache (may cross line)
                            data[{idx_p0, off_p0}]       <= f_wdata[0][23:0];
                            data[{idx_p0, off_p0} + 1'b1]<= f_wdata[0][47:24];
                            // If crossing to next line, set valid/tag for that line too
                            if (off_p0 == {OFF_BITS{1'b1}}) begin
                                valid[idx0_nxt] <= 1'b1;
                                tag[idx0_nxt]   <= tag0_nxt;
                            end
                        end else begin
                            data[{idx_p0, off_p0}]       <= f_wdata[0][23:0];
                        end
                        // Set as pending write-through
                        pend_store        <= 1'b1;
                        pend_store_addr   <= f_addr[0];
                        pend_store_wdata  <= f_wdata[0];
                        pend_store_is48   <= f_is48[0];
                        // Mark line valid and update tag (write-allocate)
                        valid[idx_p0] <= 1'b1;
                        tag[idx_p0]   <= tag_p0;
                    end
                    // Port 1 store (will override pend_store if also present)
                    if (f_we[1]) begin
                        if (f_is48[1]) begin
                            data[{idx_p1, off_p1}]       <= f_wdata[1][23:0];
                            data[{idx_p1, off_p1} + 1'b1]<= f_wdata[1][47:24];
                            if (off_p1 == {OFF_BITS{1'b1}}) begin
                                valid[idx1_nxt] <= 1'b1;
                                tag[idx1_nxt]   <= tag1_nxt;
                            end
                        end else begin
                            data[{idx_p1, off_p1}]       <= f_wdata[1][23:0];
                        end
                        pend_store        <= 1'b1;
                        pend_store_addr   <= f_addr[1];
                        pend_store_wdata  <= f_wdata[1];
                        pend_store_is48   <= f_is48[1];
                        valid[idx_p1] <= 1'b1;
                        tag[idx_p1]   <= tag_p1;
                    end
                    refill_prev_valid <= 1'b0;
                end
            end else begin
                // Refill in progress: capture when data valid
                if (b_valid) begin
                    if (refill_prev_valid) begin
                        data[{miss_idx, refill_prev_idx}] <= refill_prev_data;
                    end
                    refill_prev_valid <= 1'b1;
                    refill_prev_idx   <= miss_cnt;
                    refill_prev_data  <= b_rdata[23:0];
                    miss_issue <= 1'b0;
                    if (miss_cnt == {OFF_BITS{1'b1}}) begin
                        // Completed current line
                        data[{miss_idx, miss_cnt}] <= b_rdata[23:0];
                        refill_prev_valid <= 1'b0;
                        valid[miss_idx] <= 1'b1;
                        tag[miss_idx]   <= miss_tag;
                        if (miss_need_second) begin
                            // Start second-line refill now
                            miss_need_second <= 1'b0;
                            miss_idx    <= miss_idx2;
                            miss_tag    <= miss_tag2;
                            base_addr   <= {miss_tag2, miss_idx2, {OFF_BITS{1'b0}}};
                            miss_cnt    <= {OFF_BITS{1'b0}};
                            miss_req_cnt <= {OFF_BITS{1'b0}};
                            miss_issue  <= 1'b0; // prime for first beat
                        end else begin
                            miss_active <= 1'b0;
                            // stores postponed during refill will be attempted next
                            pend_store  <= 1'b0;
                        end
                    end else begin
                        miss_cnt <= miss_cnt + 1'b1;
                    end
                end else begin
                    // Waiting for data; remember we issued the request
                    if (!miss_issue) begin
                        miss_issue <= 1'b1;
                        if (miss_req_cnt != {OFF_BITS{1'b1}})
                            miss_req_cnt <= miss_req_cnt + 1'b1;
                    end
                end
            end
        end
    end
endmodule
