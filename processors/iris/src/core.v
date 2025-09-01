module gw5ast_core #(
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 16,
    parameter ID_WIDTH   = 4
)(
    input  wire                       clk,
    input  wire                       rst_n,

    // Simple command interface (valid/ready)
    // cmd_write_in=1 -> write cmd uses cmd_addr_in/cmd_wdata_in
    // cmd_write_in=0 -> read  cmd uses cmd_addr_in, returns data on axi_data_out
    input  wire                       axi_valid_in,
    output wire                       axi_ready_out,
    input  wire                       cmd_write_in,
    input  wire [ADDR_WIDTH-1:0]      cmd_addr_in,
    input  wire [DATA_WIDTH-1:0]      cmd_wdata_in,
    output reg  [DATA_WIDTH-1:0]      axi_data_out,

    // AXI4 master towards memory
    output reg                        axi_awvalid,
    input  wire                       axi_awready,
    output reg [ADDR_WIDTH-1:0]       axi_awaddr,
    output reg [ID_WIDTH-1:0]         axi_awid,
    output reg [7:0]                  axi_awlen,
    output reg [2:0]                  axi_awsize,
    output reg [1:0]                  axi_awburst,
    output reg                        axi_awlock,
    output reg [3:0]                  axi_awcache,
    output reg [2:0]                  axi_awprot,
    output reg [3:0]                  axi_awqos,

    output reg                        axi_wvalid,
    input  wire                       axi_wready,
    output reg [DATA_WIDTH-1:0]       axi_wdata,
    output reg [3:0]                  axi_wstrb,
    output reg                        axi_wlast,

    input  wire                       axi_bvalid,
    output reg                        axi_bready,
    input  wire [1:0]                 axi_bresp,
    input  wire [ID_WIDTH-1:0]        axi_bid,

    output reg                        axi_arvalid,
    input  wire                       axi_arready,
    output reg [ADDR_WIDTH-1:0]       axi_araddr,
    output reg [ID_WIDTH-1:0]         axi_arid,
    output reg [7:0]                  axi_arlen,
    output reg [2:0]                  axi_arsize,
    output reg [1:0]                  axi_arburst,
    output reg                        axi_arlock,
    output reg [3:0]                  axi_arcache,
    output reg [2:0]                  axi_arprot,
    output reg [3:0]                  axi_arqos,

    input  wire                       axi_rvalid,
    output reg                        axi_rready,
    input  wire [DATA_WIDTH-1:0]      axi_rdata,
    input  wire [1:0]                 axi_rresp,
    input  wire                       axi_rlast,
    input  wire [ID_WIDTH-1:0]        axi_rid,

    // Result observation
    output reg [DATA_WIDTH-1:0]       result
);

    // Simple sequencer: perform either write or read transaction.
    localparam ST_IDLE  = 3'd0;
    localparam ST_WRITE = 3'd1;
    localparam ST_B     = 3'd2;
    localparam ST_AR    = 3'd3;
    localparam ST_R     = 3'd4;

    reg [2:0]                 state;
    reg [ADDR_WIDTH-1:0]      cur_addr;
    reg [DATA_WIDTH-1:0]      cur_wdata;
    reg                        cur_is_write;

    // Ready only when the core will accept a new command this cycle.
    assign axi_ready_out = (state == ST_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            axi_data_out<= {DATA_WIDTH{1'b0}};
            result      <= {DATA_WIDTH{1'b0}};

            axi_awvalid <= 1'b0;
            axi_awaddr  <= {ADDR_WIDTH{1'b0}};
            axi_awid    <= {ID_WIDTH{1'b0}};
            axi_awlen   <= 8'd0;
            axi_awsize  <= 3'd0;
            axi_awburst <= 2'b01; // INCR
            axi_awlock  <= 1'b0;
            axi_awcache <= 4'd0;
            axi_awprot  <= 3'd0;
            axi_awqos   <= 4'd0;
            axi_wvalid  <= 1'b0;
            axi_wdata   <= {DATA_WIDTH{1'b0}};
            axi_wstrb   <= 4'b0111; // 24-bit: lower 3 bytes
            axi_wlast   <= 1'b1;
            axi_bready  <= 1'b0;

            axi_arvalid <= 1'b0;
            axi_araddr  <= {ADDR_WIDTH{1'b0}};
            axi_arid    <= {ID_WIDTH{1'b0}};
            axi_arlen   <= 8'd0;
            axi_arsize  <= 3'd0;
            axi_arburst <= 2'b01; // INCR
            axi_arlock  <= 1'b0;
            axi_arcache <= 4'd0;
            axi_arprot  <= 3'd0;
            axi_arqos   <= 4'd0;
            axi_rready  <= 1'b0;

            cur_addr    <= {ADDR_WIDTH{1'b0}};
            cur_wdata   <= {DATA_WIDTH{1'b0}};
            cur_is_write<= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    // Accept new command only on valid & ready handshake
                    if (axi_valid_in && axi_ready_out) begin
                        cur_is_write <= cmd_write_in;
                        cur_addr     <= cmd_addr_in;
                        cur_wdata    <= cmd_wdata_in;
                        if (cmd_write_in) begin
                            // Launch write
                            axi_awaddr  <= cmd_addr_in;
                            axi_awid    <= {ID_WIDTH{1'b0}};
                            axi_awlen   <= 8'd0; // single beat
                            axi_awsize  <= 3'd0; // not used by local memory
                            axi_awburst <= 2'b01; // INCR
                            axi_awlock  <= 1'b0;
                            axi_awcache <= 4'd0;
                            axi_awprot  <= 3'd0;
                            axi_awqos   <= 4'd0;
                            axi_awvalid <= 1'b1;
                            axi_wdata   <= cmd_wdata_in;
                            axi_wvalid  <= 1'b1;
                            axi_wstrb   <= 4'b0111;
                            axi_wlast   <= 1'b1;
                            axi_bready  <= 1'b1;
                            state       <= ST_WRITE;
                        end else begin
                            // Launch read
                            axi_araddr  <= cmd_addr_in;
                            axi_arid    <= {ID_WIDTH{1'b0}};
                            axi_arlen   <= 8'd0; // single beat
                            axi_arsize  <= 3'd0;
                            axi_arburst <= 2'b01; // INCR
                            axi_arlock  <= 1'b0;
                            axi_arcache <= 4'd0;
                            axi_arprot  <= 3'd0;
                            axi_arqos   <= 4'd0;
                            axi_arvalid <= 1'b1;
                            axi_rready  <= 1'b1;
                            state       <= ST_AR;
                        end
                    end
                end

                ST_WRITE: begin
                    // Drop valids when each side handshakes
                    if (axi_awvalid && axi_awready)
                        axi_awvalid <= 1'b0;
                    if (axi_wvalid && axi_wready)
                        axi_wvalid <= 1'b0;
                    // Move on when both channels done
                    if (!axi_awvalid && !axi_wvalid) begin
                        state <= ST_B;
                    end
                end

                ST_B: begin
                    if (axi_bvalid && axi_bready) begin
                        axi_bready  <= 1'b0;
                        // Complete write; return to idle
                        state       <= ST_IDLE;
                    end
                end

                ST_AR: begin
                    if (axi_arvalid && axi_arready) begin
                        axi_arvalid <= 1'b0; // address accepted
                        state       <= ST_R;
                    end
                end

                ST_R: begin
                    if (axi_rvalid && axi_rready) begin
                        axi_data_out <= axi_rdata;
                        result       <= axi_rdata; // expose readback
                        if (axi_rlast) begin
                            axi_rready <= 1'b0;
                            state      <= ST_IDLE;
                        end
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
