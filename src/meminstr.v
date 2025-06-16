// meminstr.v
// Instruction Memory (4096x12, read-only)
module meminstr(
    input wire clk,
    input wire [11:0] addr,
    output reg [11:0] data
);
    reg [11:0] mem [0:4095];

    // Initialize instruction memory from a hex file
    initial begin
        integer i;
        // Preinitialize all memory locations to zeros.
        for (i = 0; i < 4096; i = i + 1)
            mem[i] = 12'b0;
        // Load specified instructions; remaining words are zero.
        $readmemh("instr_mem_init.hex", mem);
    end

    always @(posedge clk) begin
        data <= mem[addr];
    end
    // Memory initialization can be added here
endmodule
