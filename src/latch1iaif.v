// latch1iaif.v
module latch1iaif(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [11:0] pc_in,
    output reg  [11:0] pc_out
);
    // Simple pipeline latch between the Instruction Address and
    // Instruction Fetch stages.  It just stores the program counter
    // value from stage1ia for use by stage1if on the next clock edge.
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out <= 12'b0;
        end else if (enable) begin
            pc_out <= pc_in;
        end
    end
endmodule
