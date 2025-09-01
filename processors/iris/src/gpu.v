// Parameter definitions
parameter N_CORES  = 8;
parameter DATA_WIDTH = 24;

module gw5ast_8x24gpu (
    input wire clk,
    input wire rst_n,

    // Inputs/outputs for each core (simulated here; in practice, you'd connect to AXI buses)
    input  wire [DATA_WIDTH-1:0] axi_data_in[N_CORES-1:0],
    output reg  [DATA_WIDTH-1:0] axi_data_out[N_CORES-1:0],
    input  wire                  axi_valid_in[N_CORES-1:0],
    output reg                   axi_ready_out[N_CORES-1:0],

    // Internal signals
    output reg [DATA_WIDTH-1:0] core_result[N_CORES-1:0]
);

integer i;

generate
    for (i = 0; i < N_CORES; i++) begin : generate_cores
        gw5ast_core inst (
            .clk(clk),
            .rst_n(rst_n),
            .axi_data_in(axi_data_in[i]),
            .axi_data_out(axi_data_out[i]),
            .axi_valid_in(axi_valid_in[i]),
            .axi_ready_out(axi_ready_out[i]),
            .mem_axi_data_in(mem_data_in[i]),
            .mem_axi_data_out(mem_data_out[i]),
            .mem_axi_valid_in(mem_valid_in[i]),
            .mem_axi_ready_out(mem_ready_out[i]),
            .result(core_result[i])
        );
    end
endgenerate

// Memory instances
gw5ast_memory #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(16)) mem_inst[N_CORES-1:0] (
    .clk(clk),
    .rst_n(rst_n),

    // AXI-Lite interface for memory transactions (each core uses its own memory)
    .axi_awvalid(mem_axi_awvalid[i]),
    .axi_awready(mem_axi_awready[i]),
    .axi_awaddr(mem_axi_awaddr[i]),
    .axi_wvalid(mem_axi_wvalid[i]),
    .axi_wready(mem_axi_wready[i]),
    .axi_wdata(mem_axi_wdata[i]),
    .axi_wstrb(mem_axi_wstrb[i]),
    .axi_wlast(mem_axi_wlast[i]),
    .axi_rdata(mem_axi_rdata[i]),
    .axi_rvalid(mem_axi_rvalid[i]),
    .axi_rready(mem_axi_rready[i]),
    .axi_rresp(mem_axi_rresp[i]),
    .axi_rlast(mem_axi_rlast[i]),
    .axi_bresp(mem_axi_bresp[i]),
    .axi_bvalid(mem_axi_bvalid[i]),
    .axi_bready(mem_axi_bready[i]),

    // Memory interface (each core uses its own memory)
    .mem_addr(axi_data_in[i][15:0]), // Example: Use lower 16 bits for address
    .mem_wdata(axi_data_in[i]),
    .mem_rdata(mem_data_out[i]),
    .mem_we(axi_valid_in[i]),
    .mem_be(4'd15),
    .mem_ce(1'b1)
);

// Assign memory signals to top-level interface (dummy assignment; replace with actual AXI interface)
assign mem_axi_awvalid = 0;
assign mem_axi_awready = 1;
assign mem_axi_awaddr = 0;
assign mem_axi_wdata = 24'd0;
assign mem_axi_wstrb = 4'd0;
assign mem_axi_wlast = 0;
assign mem_axi_rdata = 24'd0;
assign mem_axi_rvalid = 0;
assign mem_axi_rready = 1;
assign mem_axi_bresp = 2'd0;
assign mem_axi_bvalid = 0;

// Assign memory interface to top-level signals
for (i = 0; i < N_CORES; i++) begin : assign_memory_signals
    assign axi_data_out[i] = inst.axi_data_out;
    assign axi_ready_out[i] = inst.axi_ready_out;
    assign mem_valid_in[i] = inst.mem_axi_valid_in;
    assign mem_ready_out[i] = inst.mem_axi_ready_out;
    assign mem_data_in[i] = inst.mem_axi_data_in;
end

// Assign memory interface to top-level signals
for (i = 0; i < N_CORES; i++) begin : assign_memory_signals
    assign axi_data_out[i] = inst.axi_data_out;
    assign axi_ready_out[i] = inst.axi_ready_out;
    assign mem_valid_in[i] = inst.mem_axi_valid_in;
    assign mem_ready_out[i] = inst.mem_axi_ready_out;
    assign mem_data_in[i] = inst.mem_axi_data_in;
end

endmodule
