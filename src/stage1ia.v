// stage1ia.v
module stage1ia(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable_in,
    output wire        enable_out,
    input  wire [11:0] pc_in,
    output reg  [11:0] pc_out,
    output wire [11:0] mem_addr
);
    // Combined logic from control1ia, stage1ia, and latch1iaif
    
    assign mem_addr   = pc_in;
    assign enable_out = enable_in;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out <= 12'b0;
        end else if (enable_in) begin
            pc_out <= pc_in;
        end
    end
endmodule
