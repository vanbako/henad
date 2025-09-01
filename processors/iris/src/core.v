module gw5ast_core #(
    parameter DATA_WIDTH = 24,
    parameter ADDR_WIDTH = 16
)(
    input  wire                       clk,
    input  wire                       rst_n,

    // Simple input/output stream per core (for demo/testing)
    input  wire [DATA_WIDTH-1:0]      axi_data_in,
    output reg  [DATA_WIDTH-1:0]      axi_data_out,
    input  wire                       axi_valid_in,
    output wire                       axi_ready_out,

    // AXI-Lite master towards memory
    output reg                        axi_awvalid,
    input  wire                       axi_awready,
    output reg [ADDR_WIDTH-1:0]       axi_awaddr,

    output reg                        axi_wvalid,
    input  wire                       axi_wready,
    output reg [DATA_WIDTH-1:0]       axi_wdata,
    output reg [3:0]                  axi_wstrb,
    output reg                        axi_wlast,

    input  wire                       axi_bvalid,
    output reg                        axi_bready,
    input  wire [1:0]                 axi_bresp,

    output reg                        axi_arvalid,
    input  wire                       axi_arready,
    output reg [ADDR_WIDTH-1:0]       axi_araddr,

    input  wire                       axi_rvalid,
    output reg                        axi_rready,
    input  wire [DATA_WIDTH-1:0]      axi_rdata,
    input  wire [1:0]                 axi_rresp,
    input  wire                       axi_rlast,

    // Result observation
    output reg [DATA_WIDTH-1:0]       result
);

    // Simple sequencer: on valid input, write to memory then read back.
    localparam ST_IDLE  = 3'd0;
    localparam ST_WRITE = 3'd1;
    localparam ST_B     = 3'd2;
    localparam ST_AR    = 3'd3;
    localparam ST_R     = 3'd4;

    reg [2:0]                 state;
    reg [ADDR_WIDTH-1:0]      cur_addr;
    reg [DATA_WIDTH-1:0]      in_data;

    assign axi_ready_out = (state == ST_IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= ST_IDLE;
            axi_data_out<= {DATA_WIDTH{1'b0}};
            result      <= {DATA_WIDTH{1'b0}};

            axi_awvalid <= 1'b0;
            axi_awaddr  <= {ADDR_WIDTH{1'b0}};
            axi_wvalid  <= 1'b0;
            axi_wdata   <= {DATA_WIDTH{1'b0}};
            axi_wstrb   <= 4'b0111; // 24-bit: lower 3 bytes
            axi_wlast   <= 1'b1;
            axi_bready  <= 1'b0;

            axi_arvalid <= 1'b0;
            axi_araddr  <= {ADDR_WIDTH{1'b0}};
            axi_rready  <= 1'b0;

            cur_addr    <= {ADDR_WIDTH{1'b0}};
            in_data     <= {DATA_WIDTH{1'b0}};
        end else begin
            case (state)
                ST_IDLE: begin
                    // Accept new command
                    if (axi_valid_in) begin
                        in_data    <= axi_data_in;
                        cur_addr   <= axi_data_in[ADDR_WIDTH-1:0];
                        // Launch write
                        axi_awaddr  <= axi_data_in[ADDR_WIDTH-1:0];
                        axi_awvalid <= 1'b1;
                        axi_wdata   <= axi_data_in;
                        axi_wvalid  <= 1'b1;
                        axi_wstrb   <= 4'b0111;
                        axi_wlast   <= 1'b1;
                        axi_bready  <= 1'b1;
                        state       <= ST_WRITE;
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
                        // Launch read
                        axi_araddr  <= cur_addr;
                        axi_arvalid <= 1'b1;
                        axi_rready  <= 1'b1;
                        state       <= ST_AR;
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
