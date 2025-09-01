// Bridge from GMI (custom GPU memory interface) to enid endpoint
`include "../../interfaces/enid/src/enid_defs.vh"
`include "gmi_defs.vh"

module gmi_enid_bridge #(
    parameter integer ADDR_WIDTH = `GMI_ADDR_W,
    parameter integer DATA_WIDTH = `GMI_DATA_W,
    parameter [(`ENID_MODULE_ID_W-1):0] DEST_MOD = 4'd1,
    parameter [(`ENID_SUB_ID_W-1):0]    DEST_SUB = 2'd0,
    parameter integer EP_DATA_W = 32
)(
    input  wire                        clk,
    input  wire                        rst_n,

    // GMI slave side
    input  wire                        s_req_valid,
    output reg                         s_req_ready,
    input  wire                        s_req_write,
    input  wire [ADDR_WIDTH-1:0]       s_req_addr,
    input  wire [DATA_WIDTH-1:0]       s_req_wdata,

    output reg                         s_rsp_valid,
    input  wire                        s_rsp_ready,
    output reg [1:0]                   s_rsp_status,
    output reg [DATA_WIDTH-1:0]        s_rsp_rdata,

    // enid endpoint request/response
    output reg                         req_valid,
    input  wire                        req_ready,
    output reg [1:0]                   req_type,    // 0=mem
    output reg [1:0]                   req_mem_op,  // 0=RD,1=WR
    output reg [`ENID_MODULE_ID_W-1:0] req_dest_mod,
    output reg [`ENID_SUB_ID_W-1:0]    req_dest_sub,
    output reg [`ENID_ADDR_W-1:0]      req_addr,
    output reg [`ENID_LEN_W-1:0]       req_len,

    output reg                         req_wvalid,
    input  wire                        req_wready,
    output reg [EP_DATA_W-1:0]         req_wdata,
    output reg                         req_wlast,

    input  wire                        rsp_valid,
    output reg                         rsp_ready,
    input  wire [1:0]                  rsp_status,
    input  wire [`ENID_LEN_W-1:0]      rsp_len,

    input  wire                        rsp_rvalid,
    output reg                         rsp_rready,
    input  wire [EP_DATA_W-1:0]        rsp_rdata,
    input  wire                        rsp_rlast
);

    localparam ST_IDLE  = 3'd0;
    localparam ST_HDR   = 3'd1;
    localparam ST_WDATA = 3'd2;
    localparam ST_WRESP = 3'd3;
    localparam ST_RWAIT = 3'd4;
    localparam ST_RDAT  = 3'd5;

    reg [2:0]            st;
    reg [ADDR_WIDTH-1:0] c_addr;
    reg [DATA_WIDTH-1:0] c_wdata;
    reg                   c_is_wr;

    wire [EP_DATA_W-1:0] packed_wdata = { {(EP_DATA_W-DATA_WIDTH){1'b0}}, c_wdata };

    always @(*) begin
        // defaults
        s_req_ready  = 1'b0;
        s_rsp_valid  = 1'b0;
        s_rsp_status = `GMI_OK;
        s_rsp_rdata  = {DATA_WIDTH{1'b0}};

        req_valid    = 1'b0;
        req_type     = 2'd0;
        req_mem_op   = 2'd0;
        req_dest_mod = DEST_MOD;
        req_dest_sub = DEST_SUB;
        req_addr     = {`ENID_ADDR_W{1'b0}};
        req_len      = 16'd4;
        req_wvalid   = 1'b0;
        req_wdata    = {EP_DATA_W{1'b0}};
        req_wlast    = 1'b0;
        rsp_ready    = 1'b0;
        rsp_rready   = 1'b0;

        case (st)
            ST_IDLE: begin
                if (s_req_valid) begin
                    s_req_ready = 1'b1; // take one request
                end
            end
            ST_HDR: begin
                req_valid  = 1'b1;
                req_mem_op = c_is_wr ? 2'd1 : 2'd0;
                req_addr   = {{(`ENID_ADDR_W-ADDR_WIDTH){1'b0}}, c_addr};
            end
            ST_WDATA: begin
                req_wvalid = 1'b1;
                req_wdata  = packed_wdata;
                req_wlast  = 1'b1;
                rsp_ready  = 1'b1;
            end
            ST_WRESP: begin
                if (rsp_valid) begin
                    s_rsp_valid  = 1'b1;
                    s_rsp_status = (rsp_status==2'd0) ? `GMI_OK : `GMI_ERR;
                end
            end
            ST_RWAIT: begin
                rsp_rready = 1'b1;
            end
            ST_RDAT: begin
                if (rsp_rvalid) begin
                    s_rsp_valid = 1'b1;
                    s_rsp_rdata = rsp_rdata[DATA_WIDTH-1:0];
                end
            end
            default: ;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st     <= ST_IDLE;
            c_addr <= {ADDR_WIDTH{1'b0}};
            c_wdata<= {DATA_WIDTH{1'b0}};
            c_is_wr<= 1'b0;
        end else begin
            case (st)
                ST_IDLE: begin
                    if (s_req_valid && s_req_ready) begin
                        c_addr  <= s_req_addr;
                        c_wdata <= s_req_wdata;
                        c_is_wr <= s_req_write;
                        st      <= ST_HDR;
                    end
                end
                ST_HDR: begin
                    if (req_valid && req_ready) begin
                        st <= c_is_wr ? ST_WDATA : ST_RWAIT;
                    end
                end
                ST_WDATA: begin
                    if (req_wvalid && req_wready) begin
                        st <= ST_WRESP;
                    end
                end
                ST_WRESP: begin
                    if (s_rsp_valid && s_rsp_ready) begin
                        st <= ST_IDLE;
                    end
                end
                ST_RWAIT: begin
                    if (rsp_rvalid) begin
                        st <= ST_RDAT;
                    end
                end
                ST_RDAT: begin
                    if (s_rsp_valid && s_rsp_ready) begin
                        st <= ST_IDLE;
                    end
                end
                default: st <= ST_IDLE;
            endcase
        end
    end

endmodule

