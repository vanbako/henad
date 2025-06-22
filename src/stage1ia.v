// stage1ia.v
module stage1ia(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable_in,
    output wire        enable_out,
    input  wire [11:0] pc_in,
    output reg  [11:0] pc_out,
    // Address output to the instruction memory
    output wire [11:0] mem_addr
);
    // The instruction memory address is simply the current program
    // counter value.
    assign mem_addr = pc_in;

    // Propagate enable to the next stage
    assign enable_out = enable_in;

    // Latch the program counter for use by the Instruction Fetch stage
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out <= 12'b0;
        end else if (enable_in) begin
            pc_out <= pc_in;
        end
    end
endmodule
