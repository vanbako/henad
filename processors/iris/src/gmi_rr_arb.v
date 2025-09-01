// Round-robin arbiter for N GMI masters to 1 GMI slave
`include "gmi_defs.vh"

module gmi_rr_arb #(
    parameter integer N          = 8,
    parameter integer ADDR_WIDTH = `GMI_ADDR_W,
    parameter integer DATA_WIDTH = `GMI_DATA_W
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // Masters
    input  wire [N-1:0]                 m_req_valid,
    output reg  [N-1:0]                 m_req_ready,
    input  wire [N-1:0]                 m_req_write,
    input  wire [N*ADDR_WIDTH-1:0]      m_req_addr,
    input  wire [N*DATA_WIDTH-1:0]      m_req_wdata,

    output reg  [N-1:0]                 m_rsp_valid,
    input  wire [N-1:0]                 m_rsp_ready,
    output reg  [N*2-1:0]               m_rsp_status,
    output reg  [N*DATA_WIDTH-1:0]      m_rsp_rdata,

    // Slave
    output reg                          s_req_valid,
    input  wire                         s_req_ready,
    output reg                          s_req_write,
    output reg [ADDR_WIDTH-1:0]         s_req_addr,
    output reg [DATA_WIDTH-1:0]         s_req_wdata,

    input  wire                         s_rsp_valid,
    output reg                          s_rsp_ready,
    input  wire [1:0]                   s_rsp_status,
    input  wire [DATA_WIDTH-1:0]        s_rsp_rdata
);

    reg [$clog2(N)-1:0] owner;
    reg [$clog2(N)-1:0] next_ptr;
    reg                  busy;
    reg                  owner_is_wr;

    integer i;

    always @(*) begin
        // Default
        m_req_ready  = {N{1'b0}};
        m_rsp_valid  = {N{1'b0}};
        m_rsp_status = {N*2{1'b0}};
        m_rsp_rdata  = {N*DATA_WIDTH{1'b0}};

        s_req_valid  = 1'b0;
        s_req_write  = 1'b0;
        s_req_addr   = {ADDR_WIDTH{1'b0}};
        s_req_wdata  = {DATA_WIDTH{1'b0}};
        s_rsp_ready  = 1'b0;

        if (!busy) begin
            // Select next master with a request
            integer sel, idx;
            sel = -1;
            for (i = 0; i < N; i = i + 1) begin
                idx = (next_ptr + i) % N;
                if (sel == -1 && m_req_valid[idx]) sel = idx;
            end
            if (sel != -1) begin
                s_req_valid = 1'b1;
                s_req_write = m_req_write[sel];
                s_req_addr  = m_req_addr [sel*ADDR_WIDTH +: ADDR_WIDTH];
                s_req_wdata = m_req_wdata[sel*DATA_WIDTH +: DATA_WIDTH];
                m_req_ready[sel] = s_req_ready;
            end
        end else begin
            // Drive response to owner
            s_rsp_ready                  = m_rsp_ready[owner];
            m_rsp_valid[owner]           = s_rsp_valid;
            m_rsp_status[owner*2 +: 2]   = s_rsp_status;
            m_rsp_rdata [owner*DATA_WIDTH +: DATA_WIDTH] = s_rsp_rdata;
        end
    end

    // State
    integer j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            owner    <= {($clog2(N)){1'b0}};
            next_ptr <= {($clog2(N)){1'b0}};
            busy     <= 1'b0;
            owner_is_wr <= 1'b0;
        end else begin
            if (!busy) begin
                // Latch owner when handshake occurs (only the selected master gets ready)
                for (j = 0; j < N; j = j + 1) begin
                    if (m_req_valid[(next_ptr+j)%N] && m_req_ready[(next_ptr+j)%N]) begin
                        owner       <= (next_ptr+j)%N;
                        next_ptr    <= ((next_ptr+j)%N) + 1;
                        busy        <= 1'b1;
                        owner_is_wr <= m_req_write[(next_ptr+j)%N];
                    end
                end
            end else begin
                // Complete on response handshake
                if (s_rsp_valid && m_rsp_ready[owner]) begin
                    busy <= 1'b0;
                end
            end
        end
    end

endmodule
