// henad.v
// Top-level Henad 5-stage RISC core
module henad(
    input wire clk,
    input wire rst
);
    // Pipeline registers
    // Program counter value for each stage
    reg [11:0] if_pc; // fetch stage PC
    reg [11:0] id_pc; // decode stage PC
    reg [11:0] ex_pc; // execute stage PC
    reg [11:0] ma_pc; // memory address stage PC
    reg [11:0] ro_pc; // register operation stage PC

    // Instruction flowing through the pipeline
    reg [11:0] id_instr;
    reg [11:0] ex_instr;
    reg [11:0] ma_instr;
    reg [11:0] ro_instr;

    // Instruction memory
    wire [11:0] instr_mem_data;
    wire [11:0] instr_mem_addr;

    // IF/ID latch outputs
    wire [11:0] ifid_instr;
    wire [11:0] ifid_pc;

    // IF stage (now handled in control1if)
    wire [11:0] next_pc;
    control1if u_control1if(
        .clk(clk),
        .rst(rst),
        .pc_in(if_pc),
        .pc_out(next_pc),
        .mem_addr(instr_mem_addr),
        .instr_mem_data(instr_mem_data),
        .ifid_instr(ifid_instr),
        .ifid_pc(ifid_pc)
    );
    meminstr u_meminstr(
        .clk(clk),
        .addr(instr_mem_addr),
        .data(instr_mem_data)
    );

    // Pipeline advance
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            if_pc <= 12'b0;
            id_pc <= 12'b0;
            ex_pc <= 12'b0;
            ma_pc <= 12'b0;
            ro_pc <= 12'b0;

            id_instr <= 12'b0;
            ex_instr <= 12'b0;
            ma_instr <= 12'b0;
            ro_instr <= 12'b0;
        end else begin
            // Advance pipeline
            // Update PCs
            if_pc <= next_pc;
            id_pc <= ifid_pc;
            ex_pc <= id_pc;
            ma_pc <= ex_pc;
            ro_pc <= ma_pc;

            // Advance instructions
            id_instr <= ifid_instr;
            ex_instr <= id_instr;
            ma_instr <= ex_instr;
            ro_instr <= ma_instr;
        end
    end
endmodule
