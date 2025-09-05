// Native DDR3 refill/write-through shim for Gowin DDR3 Controller (Tang Mega 60K)
//
// Two cache clients (I-cache and D-cache) request 24-bit words by asserting
// `*_req` with a word address. The shim either:
//  - AMBER_GWDDR_SIM: services requests from an internal BRAM (mem.v) for
//    simulation, honoring 1-cycle read latency and simple writes.
//  - Otherwise: exposes the GOWIN DDR3 controller's native user interface ports
//    (cmd/cmd_en/addr/wr_data/rd_data/...) for integration.
//
// NOTE: The non-simulation path provides a minimal skeleton. It issues single
// read or write commands per 24-bit word. For production use, coalesce cache
// line refills into bursts (BL8) and pack/unpack the 24-bit words to/from the
// DDR user data bus width (typically 128 bits for x16 DQ in 1:4 mode).

`include "src/sizes.vh"

module amber_refill_gwddr #(
    parameter USER_DATA_W = 128,
    parameter ADDR_W      = 32
)(
    input  wire                  clk,
    input  wire                  rst,

    // I-cache read (24-bit word, in 48-bit bus)
    input  wire                  ic_req,
    input  wire [`HBIT_ADDR:0]   ic_addr,
    output reg                   ic_valid,
    output reg  [`HBIT_ADDR:0]   ic_rdata,

    // D-cache read and write-through
    input  wire                  dc_req,
    input  wire [`HBIT_ADDR:0]   dc_addr,
    output reg                   dc_valid,
    output reg  [`HBIT_ADDR:0]   dc_rdata,
    input  wire                  dc_we,
    input  wire [`HBIT_ADDR:0]   dc_wdata,
    input  wire                  dc_is48,

`ifndef AMBER_GWDDR_SIM
    // GOWIN DDR3 native user interface (subset)
    input  wire                  init_calib_complete,
    // Command interface
    output reg                   cmd_en,
    output reg  [2:0]            cmd,      // 000=WR, 001=RD
    output reg  [ADDR_W-1:0]     addr,
    input  wire                  cmd_ready,
    // Write data stream
    output reg  [USER_DATA_W-1:0] wr_data,
    output reg                   wr_data_en,
    output reg                   wr_data_end,
    input  wire                  wr_data_rdy,
    output reg  [(USER_DATA_W/8)-1:0] wr_data_mask,
    // Read data stream
    input  wire  [USER_DATA_W-1:0] rd_data,
    input  wire                  rd_data_valid,
    input  wire                  rd_data_end
`endif
);

`ifdef AMBER_GWDDR_SIM
    // ------------------------------------------------------------
    // Simulation path: use mem.v to back requests with 1-cycle latency
    // ------------------------------------------------------------
    // One shared BRAM port for simplicity (arbitrates IC over DC)
    wire                m_we    [0:1];
    wire [`HBIT_ADDR:0] m_addr  [0:1];
    wire [`HBIT_ADDR:0] m_wdata [0:1];
    wire                m_is48  [0:1];
    wire [`HBIT_ADDR:0] m_rdata [0:1];

    assign m_we[0]    = dc_we;          // use port 0 for writes
    assign m_addr[0]  = dc_addr;
    assign m_wdata[0] = dc_wdata;
    assign m_is48[0]  = dc_is48;

    // Use port 1 for reads; arbitrate ic_req over dc_req
    reg  [`HBIT_ADDR:0] r_req_addr;
    reg                 r_req_valid;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            r_req_valid <= 1'b0;
            r_req_addr  <= {(`HBIT_ADDR+1){1'b0}};
        end else begin
            r_req_valid <= 1'b0;
            if (ic_req) begin
                r_req_valid <= 1'b1;
                r_req_addr  <= ic_addr;
            end else if (dc_req) begin
                r_req_valid <= 1'b1;
                r_req_addr  <= dc_addr;
            end
        end
    end
    assign m_we[1]    = 1'b0;
    assign m_addr[1]  = r_req_addr;
    assign m_wdata[1] = {(`HBIT_ADDR+1){1'b0}};
    assign m_is48[1]  = 1'b0;

    mem #(.READ_MEM(0)) u_sim_mem(
        .iw_clk  (clk),
        .iw_we   (m_we),
        .iw_addr (m_addr),
        .iw_wdata(m_wdata),
        .iw_is48 (m_is48),
        .or_rdata(m_rdata)
    );

    // 1-cycle latency modeling: return valid one cycle after request
    reg rr_valid;
    reg ic_won;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rr_valid <= 1'b0;
            ic_won   <= 1'b0;
            ic_valid <= 1'b0;
            ic_rdata <= {(`HBIT_ADDR+1){1'b0}};
            dc_valid <= 1'b0;
            dc_rdata <= {(`HBIT_ADDR+1){1'b0}};
        end else begin
            rr_valid <= r_req_valid;
            ic_won   <= ic_req; // latch which client
            ic_valid <= 1'b0;
            dc_valid <= 1'b0;
            if (rr_valid) begin
                if (ic_won) begin
                    ic_rdata <= m_rdata[1];
                    ic_valid <= 1'b1;
                } else begin
                    dc_rdata <= m_rdata[1];
                    dc_valid <= 1'b1;
                end
            end
        end
    end

`else
    // ------------------------------------------------------------
    // Native DDR3 UI skeleton (single-beat commands; to be extended)
    // ------------------------------------------------------------
    localparam CMD_WR = 3'b000;
    localparam CMD_RD = 3'b001;

    reg busy;
    reg use_ic; // 1 if current transaction belongs to icache

    // Unpack/pack helpers for USER_DATA_W != 24*X would be added later
    // For now, place 24 bits into least-significant bits and mask others
    wire [(USER_DATA_W/8)-1:0] full_mask = { (USER_DATA_W/8){1'b0} };

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ic_valid    <= 1'b0;
            ic_rdata    <= {(`HBIT_ADDR+1){1'b0}};
            dc_valid    <= 1'b0;
            dc_rdata    <= {(`HBIT_ADDR+1){1'b0}};
            cmd_en      <= 1'b0;
            cmd         <= 3'b000;
            addr        <= {ADDR_W{1'b0}};
            wr_data     <= {USER_DATA_W{1'b0}};
            wr_data_en  <= 1'b0;
            wr_data_end <= 1'b0;
            wr_data_mask<= full_mask;
            busy        <= 1'b0;
            use_ic      <= 1'b0;
        end else begin
            ic_valid    <= 1'b0;
            dc_valid    <= 1'b0;
            wr_data_en  <= 1'b0;
            wr_data_end <= 1'b0;
            cmd_en      <= 1'b0;

            if (!busy && init_calib_complete) begin
                // Launch read first (icache has priority), else write
                if (ic_req) begin
                    use_ic <= 1'b1;
                    addr   <= ic_addr[ADDR_W-1:0];
                    cmd    <= CMD_RD;
                    cmd_en <= 1'b1;
                    if (cmd_ready) busy <= 1'b1;
                end else if (dc_req) begin
                    use_ic <= 1'b0;
                    addr   <= dc_addr[ADDR_W-1:0];
                    cmd    <= CMD_RD;
                    cmd_en <= 1'b1;
                    if (cmd_ready) busy <= 1'b1;
                end else if (dc_we) begin
                    use_ic <= 1'b0;
                    addr   <= dc_addr[ADDR_W-1:0];
                    cmd    <= CMD_WR;
                    cmd_en <= 1'b1;
                    if (cmd_ready) begin
                        busy <= 1'b1;
                        // Present one beat write (pack 24/48 into USER_DATA_W LSBs)
                        wr_data    <= { {(USER_DATA_W-24){1'b0}}, dc_wdata[23:0] };
                        wr_data_en <= 1'b1;
                        wr_data_end<= 1'b1;
                        wr_data_mask <= full_mask; // no mask on LSBs; adjust for real width
                    end
                end
            end

            // Read data return
            if (rd_data_valid && use_ic) begin
                ic_rdata <= {24'b0, rd_data[23:0]};
                ic_valid <= 1'b1;
                if (rd_data_end) busy <= 1'b0;
            end else if (rd_data_valid) begin
                dc_rdata <= {24'b0, rd_data[23:0]};
                dc_valid <= 1'b1;
                if (rd_data_end) busy <= 1'b0;
            end

            // End write when accepted; in real design use wr_data_rdy
            if (wr_data_en) begin
                busy <= 1'b0;
            end
        end
    end
`endif
endmodule
