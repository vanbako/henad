// Simple round-robin AXI-lite (single-beat) N:1 arbiter
// - One outstanding transaction at a time
// - Supports AW/W/B and AR/R channels
// - Demuxes responses to the owning master

module axi_rr_arb #(
    parameter integer N         = 8,
    parameter integer ADDR_WIDTH= 16,
    parameter integer DATA_WIDTH= 24,
    parameter integer ID_WIDTH  = 4
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // Masters (from cores)
    input  wire [N-1:0]                 m_awvalid,
    output reg  [N-1:0]                 m_awready,
    input  wire [N*ADDR_WIDTH-1:0]      m_awaddr,
    input  wire [N*ID_WIDTH-1:0]        m_awid,
    input  wire [N*8-1:0]               m_awlen,
    input  wire [N*3-1:0]               m_awsize,
    input  wire [N*2-1:0]               m_awburst,

    input  wire [N-1:0]                 m_wvalid,
    output reg  [N-1:0]                 m_wready,
    input  wire [N*DATA_WIDTH-1:0]      m_wdata,
    input  wire [N*4-1:0]               m_wstrb,
    input  wire [N-1:0]                 m_wlast,

    output reg  [N-1:0]                 m_bvalid,
    input  wire [N-1:0]                 m_bready,
    output reg  [N*2-1:0]               m_bresp,
    output reg  [N*ID_WIDTH-1:0]        m_bid,

    input  wire [N-1:0]                 m_arvalid,
    output reg  [N-1:0]                 m_arready,
    input  wire [N*ADDR_WIDTH-1:0]      m_araddr,
    input  wire [N*ID_WIDTH-1:0]        m_arid,
    input  wire [N*8-1:0]               m_arlen,
    input  wire [N*3-1:0]               m_arsize,
    input  wire [N*2-1:0]               m_arburst,

    output reg  [N-1:0]                 m_rvalid,
    input  wire [N-1:0]                 m_rready,
    output reg  [N*DATA_WIDTH-1:0]      m_rdata,
    output reg  [N*2-1:0]               m_rresp,
    output reg  [N-1:0]                 m_rlast,
    output reg  [N*ID_WIDTH-1:0]        m_rid,

    // Single slave port (to downstream target)
    output reg                          s_awvalid,
    input  wire                         s_awready,
    output reg [ADDR_WIDTH-1:0]         s_awaddr,
    output reg [ID_WIDTH-1:0]           s_awid,
    output reg [7:0]                    s_awlen,
    output reg [2:0]                    s_awsize,
    output reg [1:0]                    s_awburst,

    output reg                          s_wvalid,
    input  wire                         s_wready,
    output reg [DATA_WIDTH-1:0]         s_wdata,
    output reg [3:0]                    s_wstrb,
    output reg                          s_wlast,

    input  wire                         s_bvalid,
    output reg                          s_bready,
    input  wire [1:0]                   s_bresp,
    input  wire [ID_WIDTH-1:0]          s_bid,

    output reg                          s_arvalid,
    input  wire                         s_arready,
    output reg [ADDR_WIDTH-1:0]         s_araddr,
    output reg [ID_WIDTH-1:0]           s_arid,
    output reg [7:0]                    s_arlen,
    output reg [2:0]                    s_arsize,
    output reg [1:0]                    s_arburst,

    input  wire                         s_rvalid,
    output reg                          s_rready,
    input  wire [DATA_WIDTH-1:0]        s_rdata,
    input  wire [1:0]                   s_rresp,
    input  wire                         s_rlast,
    input  wire [ID_WIDTH-1:0]          s_rid
);

    localparam RESP_OKAY = 2'b00;

    reg [$clog2(N)-1:0] owner;
    reg [$clog2(N)-1:0] next_ptr;
    reg                  busy;
    reg                  is_write;

    integer k;

    // Default combinational resets
    always @(*) begin
        // default: deassert all master outputs
        m_awready = {N{1'b0}};
        m_wready  = {N{1'b0}};
        m_bvalid  = {N{1'b0}};
        m_bresp   = {N*2{1'b0}};
        m_bid     = {N*ID_WIDTH{1'b0}};
        m_arready = {N{1'b0}};
        m_rvalid  = {N{1'b0}};
        m_rdata   = {N*DATA_WIDTH{1'b0}};
        m_rresp   = {N*2{1'b0}};
        m_rlast   = {N{1'b0}};
        m_rid     = {N*ID_WIDTH{1'b0}};

        // default: deassert slave valids
        s_awvalid = 1'b0; s_awaddr= {ADDR_WIDTH{1'b0}}; s_awid= {ID_WIDTH{1'b0}}; s_awlen=8'd0; s_awsize=3'd0; s_awburst=2'b01;
        s_wvalid  = 1'b0; s_wdata= {DATA_WIDTH{1'b0}}; s_wstrb=4'b0111; s_wlast=1'b1;
        s_bready  = 1'b0;
        s_arvalid = 1'b0; s_araddr= {ADDR_WIDTH{1'b0}}; s_arid= {ID_WIDTH{1'b0}}; s_arlen=8'd0; s_arsize=3'd0; s_arburst=2'b01;
        s_rready  = 1'b0;

        if (!busy) begin
            // Arbitration: simple round-robin among any AW/W pair ready, then AR
            integer selw, selr, idx;
            selw = -1; selr = -1;
            for (k = 0; k < N; k = k + 1) begin
                idx = (next_ptr + k) % N;
                if (selw == -1 && m_awvalid[idx] && m_wvalid[idx]) selw = idx;
            end
            if (selw != -1) begin
                s_awvalid = 1'b1;
                s_wvalid  = 1'b1;
                s_awaddr  = m_awaddr[selw*ADDR_WIDTH +: ADDR_WIDTH];
                s_awid    = m_awid  [selw*ID_WIDTH   +: ID_WIDTH];
                s_wdata   = m_wdata[selw*DATA_WIDTH +: DATA_WIDTH];
                s_wstrb   = m_wstrb[selw*4          +: 4];
                m_awready[selw] = s_awready;
                m_wready [selw] = s_wready;
            end else begin
                for (k = 0; k < N; k = k + 1) begin
                    idx = (next_ptr + k) % N;
                    if (selr == -1 && m_arvalid[idx]) selr = idx;
                end
                if (selr != -1) begin
                    s_arvalid = 1'b1;
                    s_araddr  = m_araddr[selr*ADDR_WIDTH +: ADDR_WIDTH];
                    s_arid    = m_arid  [selr*ID_WIDTH   +: ID_WIDTH];
                    m_arready[selr] = s_arready;
                end
            end
        end else begin
            // Busy: drive data/ready for current owner
            if (is_write) begin
                // Write data already sent. Wait for B and present to owner
                s_bready = m_bready[owner];
                m_bvalid[owner] = s_bvalid;
                m_bresp [owner*2 +: 2] = s_bresp;
                m_bid   [owner*ID_WIDTH +: ID_WIDTH] = s_bid;
            end else begin
                s_rready = m_rready[owner];
                m_rvalid[owner] = s_rvalid;
                m_rdata [owner*DATA_WIDTH +: DATA_WIDTH] = s_rdata;
                m_rresp [owner*2 +: 2] = s_rresp;
                m_rlast [owner] = s_rlast;
                m_rid   [owner*ID_WIDTH +: ID_WIDTH] = s_rid;
            end
        end
    end

    // State: track owner/busy transitions
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy     <= 1'b0;
            is_write <= 1'b0;
            owner    <= {($clog2(N)){1'b0}};
            next_ptr <= {($clog2(N)){1'b0}};
        end else begin
            if (!busy) begin
                // Capture when a handshake occurs to make us busy
                integer cidx;
                // Write capture
                for (j = 0; j < N; j = j + 1) begin
                    cidx = (next_ptr + j) % N;
                    if (m_awvalid[cidx] && m_wvalid[cidx] && s_awready && s_wready) begin
                        owner    <= cidx;
                        next_ptr <= cidx + 1;
                        busy     <= 1'b1;
                        is_write <= 1'b1;
                    end
                end
                // Read capture
                if (!busy) begin
                    for (j = 0; j < N; j = j + 1) begin
                        cidx = (next_ptr + j) % N;
                        if (m_arvalid[cidx] && s_arready) begin
                            owner    <= cidx;
                            next_ptr <= cidx + 1;
                            busy     <= 1'b1;
                            is_write <= 1'b0;
                        end
                    end
                end
            end else begin
                // Completion detection
                if (is_write) begin
                    if (s_bvalid && m_bready[owner]) begin
                        busy <= 1'b0;
                    end
                end else begin
                    if (s_rvalid && s_rlast && m_rready[owner]) begin
                        busy <= 1'b0;
                    end
                end
            end
        end
    end

endmodule
