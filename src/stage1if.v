// stage1if.v
module stage1if(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable_in,
    output wire        enable_out,
    input  wire [11:0] pc_in,
    output reg  [11:0] pc_out,
    output reg  [11:0] instr_out,
    // Instruction memory interface
    input  wire [11:0] instr_mem_data
);
    // Propagate enable directly to the next stage
    assign enable_out = enable_in;

    // Latch the instruction and program counter when enabled
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out    <= 12'b0;
            instr_out <= 12'b0;
        end else if (enable_in) begin
            pc_out    <= pc_in;
            instr_out <= instr_mem_data;
        end
    end
endmodule
