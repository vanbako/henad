// AXI-lite (single-beat) to enid endpoint transaction bridge
// Acts as a memory slave on AXI, emits EP requests for RD/WR

`include "../../interfaces/enid/src/enid_defs.vh"

module axi2enid #(
    parameter integer ADDR_WIDTH= 16,
    parameter integer DATA_WIDTH= 24,
    parameter integer ID_WIDTH  = 4,
    // Destination for remote memory service
    parameter [(`ENID_MODULE_ID_W-1):0] DEST_MOD = 4'd1,
    parameter [(`ENID_SUB_ID_W-1):0]    DEST_SUB = 2'd0,
    parameter integer EP_DATA_W = 32
)(
    input  wire                        clk,
    input  wire                        rst_n,

    // AXI-lite slave side (from arbiter)
    input  wire                        s_awvalid,
    output reg                         s_awready,
    input  wire [ADDR_WIDTH-1:0]       s_awaddr,
    input  wire [ID_WIDTH-1:0]         s_awid,
    input  wire [7:0]                  s_awlen,
    input  wire [2:0]                  s_awsize,
    input  wire [1:0]                  s_awburst,

    input  wire                        s_wvalid,
    output reg                         s_wready,
    input  wire [DATA_WIDTH-1:0]       s_wdata,
    input  wire [3:0]                  s_wstrb,
    input  wire                        s_wlast,

    output reg                         s_bvalid,
    input  wire                        s_bready,
    output reg [1:0]                   s_bresp,
    output reg [ID_WIDTH-1:0]          s_bid,

    input  wire                        s_arvalid,
    output reg                         s_arready,
    input  wire [ADDR_WIDTH-1:0]       s_araddr,
    input  wire [ID_WIDTH-1:0]         s_arid,
    input  wire [7:0]                  s_arlen,
    input  wire [2:0]                  s_arsize,
    input  wire [1:0]                  s_arburst,

    output reg                         s_rvalid,
    input  wire                        s_rready,
    output reg [DATA_WIDTH-1:0]        s_rdata,
    output reg [1:0]                   s_rresp,
    output reg                         s_rlast,
    output reg [ID_WIDTH-1:0]          s_rid,

    // enid Endpoint transaction interface (to enid_endpoint)
    output reg                         req_valid,
    input  wire                        req_ready,
    output reg [1:0]                   req_type,    // 0=mem,1=msg
    output reg [1:0]                   req_mem_op,  // 0=RD,1=WR
    output reg [`ENID_MODULE_ID_W-1:0] req_dest_mod,
    output reg [`ENID_SUB_ID_W-1:0]    req_dest_sub,
    output reg [`ENID_ADDR_W-1:0]      req_addr,
    output reg [`ENID_LEN_W-1:0]       req_len,

    // write data stream
    output reg                         req_wvalid,
    input  wire                        req_wready,
    output reg [EP_DATA_W-1:0]         req_wdata,
    output reg                         req_wlast,

    // response channel
    input  wire                        rsp_valid,
    output reg                         rsp_ready,
    input  wire [1:0]                  rsp_status,
    input  wire [`ENID_LEN_W-1:0]      rsp_len,

    // read data stream
    input  wire                        rsp_rvalid,
    output reg                         rsp_rready,
    input  wire [EP_DATA_W-1:0]        rsp_rdata,
    input  wire                        rsp_rlast
);

    localparam ST_IDLE   = 3'd0;
    localparam ST_W_HDR  = 3'd1;
    localparam ST_W_DATA = 3'd2;
    localparam ST_W_RESP = 3'd3;
    localparam ST_R_HDR  = 3'd4;
    localparam ST_R_DATA = 3'd5;

    reg [2:0]            st;
    reg [ADDR_WIDTH-1:0] c_addr;
    reg [ID_WIDTH-1:0]   c_id;
    reg [DATA_WIDTH-1:0] c_wdata;

    // Simple packing 24-bit -> 32-bit (LSBs used)
    wire [EP_DATA_W-1:0] wdata_packed = { {(EP_DATA_W-DATA_WIDTH){1'b0}}, c_wdata };

    // Default outputs
    always @(*) begin
        // AXI defaults
        s_awready = 1'b0;
        s_wready  = 1'b0;
        s_bvalid  = 1'b0; s_bresp = 2'b00; s_bid = c_id;
        s_arready = 1'b0;
        s_rvalid  = 1'b0; s_rdata = {DATA_WIDTH{1'b0}}; s_rresp=2'b00; s_rlast=1'b1; s_rid = c_id;

        // EP defaults
        req_valid = 1'b0; req_type = 2'd0; req_mem_op=2'd0;
        req_dest_mod = DEST_MOD; req_dest_sub = DEST_SUB; req_addr = {`ENID_ADDR_W{1'b0}}; req_len = 16'd0;
        req_wvalid = 1'b0; req_wdata = {EP_DATA_W{1'b0}}; req_wlast = 1'b0;
        rsp_ready  = 1'b0;
        rsp_rready = 1'b0;

        case (st)
            ST_IDLE: begin
                // Accept either a write (AW+W) or a read (AR)
                if (s_awvalid && s_wvalid) begin
                    s_awready = 1'b1;
                    s_wready  = 1'b1;
                end else if (s_arvalid) begin
                    s_arready = 1'b1;
                end
            end
            ST_W_HDR: begin
                req_valid   = 1'b1;
                req_type    = 2'd0; // mem
                req_mem_op  = 2'd1; // WR
                req_addr    = {{(`ENID_ADDR_W-ADDR_WIDTH){1'b0}}, c_addr};
                req_len     = 16'd4; // bytes (use 4 for alignment)
            end
            ST_W_DATA: begin
                req_wvalid = 1'b1;
                req_wdata  = wdata_packed;
                req_wlast  = 1'b1;
                rsp_ready  = 1'b1; // accept completion status
            end
            ST_W_RESP: begin
                // Convert EP response to AXI B channel
                if (rsp_valid) begin
                    s_bvalid = 1'b1;
                    s_bresp  = (rsp_status==2'd0) ? 2'b00 : 2'b10; // OK or SLVERR
                end
            end
            ST_R_HDR: begin
                req_valid   = 1'b1;
                req_type    = 2'd0; // mem
                req_mem_op  = 2'd0; // RD
                req_addr    = {{(`ENID_ADDR_W-ADDR_WIDTH){1'b0}}, c_addr};
                req_len     = 16'd4;
                rsp_rready  = 1'b1;
            end
            ST_R_DATA: begin
                // Wait for data; present on AXI R
                if (rsp_rvalid) begin
                    s_rvalid = 1'b1;
                    s_rdata  = rsp_rdata[DATA_WIDTH-1:0];
                    s_rresp  = 2'b00;
                    s_rlast  = 1'b1;
                end
            end
            default: ;
        endcase
    end

    // State transitions and captures
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st     <= ST_IDLE;
            c_addr <= {ADDR_WIDTH{1'b0}};
            c_id   <= {ID_WIDTH{1'b0}};
            c_wdata<= {DATA_WIDTH{1'b0}};
        end else begin
            case (st)
                ST_IDLE: begin
                    if (s_awvalid && s_wvalid && s_awready && s_wready) begin
                        c_addr  <= s_awaddr; c_id <= s_awid; c_wdata <= s_wdata;
                        st      <= ST_W_HDR;
                    end else if (s_arvalid && s_arready) begin
                        c_addr  <= s_araddr; c_id <= s_arid;
                        st      <= ST_R_HDR;
                    end
                end
                ST_W_HDR: begin
                    if (req_valid && req_ready) begin
                        st <= ST_W_DATA;
                    end
                end
                ST_W_DATA: begin
                    if (req_wvalid && req_wready) begin
                        st <= ST_W_RESP;
                    end
                end
                ST_W_RESP: begin
                    if (rsp_valid && s_bvalid && s_bready) begin
                        st <= ST_IDLE;
                    end
                end
                ST_R_HDR: begin
                    if (req_valid && req_ready) begin
                        st <= ST_R_DATA;
                    end
                end
                ST_R_DATA: begin
                    if (s_rvalid && s_rready) begin
                        st <= ST_IDLE;
                    end
                end
                default: st <= ST_IDLE;
            endcase
        end
    end

endmodule

