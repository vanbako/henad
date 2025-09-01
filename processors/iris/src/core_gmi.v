// gw5ast_core variant using custom GMI instead of AXI
`include "gmi_defs.vh"

module gw5ast_core_gmi #(
    parameter DATA_WIDTH = `GMI_DATA_W,
    parameter ADDR_WIDTH = `GMI_ADDR_W
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Simple command input (matches previous core usage)
    input  wire                  cmd_valid,
    output wire                  cmd_ready,
    input  wire                  cmd_write,
    input  wire [ADDR_WIDTH-1:0] cmd_addr,
    input  wire [DATA_WIDTH-1:0] cmd_wdata,
    output reg  [DATA_WIDTH-1:0] cmd_rdata,

    // GMI master request/response
    output reg                   gmi_req_valid,
    input  wire                  gmi_req_ready,
    output reg                   gmi_req_write,
    output reg  [ADDR_WIDTH-1:0] gmi_req_addr,
    output reg  [DATA_WIDTH-1:0] gmi_req_wdata,

    input  wire                  gmi_rsp_valid,
    input  wire [1:0]            gmi_rsp_status,
    input  wire [DATA_WIDTH-1:0] gmi_rsp_rdata,
    output reg                   gmi_rsp_ready,

    // Result observation
    output reg [DATA_WIDTH-1:0]  result
);

    localparam ST_IDLE   = 2'd0;
    localparam ST_REQ    = 2'd1;
    localparam ST_RESP   = 2'd2;

    reg [1:0]            st;
    reg [ADDR_WIDTH-1:0] c_addr;
    reg [DATA_WIDTH-1:0] c_wdata;
    reg                   c_is_wr;

    assign cmd_ready = (st == ST_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st            <= ST_IDLE;
            gmi_req_valid <= 1'b0;
            gmi_req_write <= 1'b0;
            gmi_req_addr  <= {ADDR_WIDTH{1'b0}};
            gmi_req_wdata <= {DATA_WIDTH{1'b0}};
            gmi_rsp_ready <= 1'b0;
            cmd_rdata     <= {DATA_WIDTH{1'b0}};
            result        <= {DATA_WIDTH{1'b0}};
            c_addr        <= {ADDR_WIDTH{1'b0}};
            c_wdata       <= {DATA_WIDTH{1'b0}};
            c_is_wr       <= 1'b0;
        end else begin
            case (st)
                ST_IDLE: begin
                    gmi_req_valid <= 1'b0;
                    gmi_rsp_ready <= 1'b0;
                    if (cmd_valid && cmd_ready) begin
                        c_is_wr       <= cmd_write;
                        c_addr        <= cmd_addr;
                        c_wdata       <= cmd_wdata;
                        gmi_req_addr  <= cmd_addr;
                        gmi_req_wdata <= cmd_wdata;
                        gmi_req_write <= cmd_write;
                        gmi_req_valid <= 1'b1;
                        st            <= ST_REQ;
                    end
                end
                ST_REQ: begin
                    if (gmi_req_valid && gmi_req_ready) begin
                        gmi_req_valid <= 1'b0;
                        gmi_rsp_ready <= 1'b1;
                        st            <= ST_RESP;
                    end
                end
                ST_RESP: begin
                    if (gmi_rsp_valid && gmi_rsp_ready) begin
                        if (!c_is_wr) begin
                            cmd_rdata <= gmi_rsp_rdata;
                            result    <= gmi_rsp_rdata;
                        end
                        gmi_rsp_ready <= 1'b0;
                        st            <= ST_IDLE;
                    end
                end
                default: st <= ST_IDLE;
            endcase
        end
    end

endmodule

