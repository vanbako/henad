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
    // ID/EX latch outputs
    wire [11:0] idex_instr;
    wire [11:0] idex_pc;
    // EX/MA latch outputs
    wire [11:0] exma_instr;
    wire [11:0] exma_pc;
    // MA/MO latch outputs
    wire [11:0] mamo_instr;
    wire [11:0] mamo_pc;
    // MO/RA latch outputs
    wire [11:0] mora_instr;
    wire [11:0] mora_pc;
    // RA/RO latch outputs
    wire [11:0] raro_instr;
    wire [11:0] raro_pc;
    // Final RO stage outputs
    wire [11:0] final_instr;
    wire [11:0] final_pc;

    // Stage and control instantiations

    // Instruction Address control
    wire [11:0] iaif_pc;
    control1ia u_control1ia(
        .clk(clk),
        .rst(rst),
        .pc_in(if_pc),
        .pc_out(iaif_pc)
    );

    // IF stage control
    wire [11:0] next_pc;
    control1if u_control1if(
        .clk(clk),
        .rst(rst),
        // Feed the current fetch stage PC directly so the next PC
        // increment is based on the most recent value rather than the
        // one stored in the IA/IF latch. This keeps the PC advancing on
        // every clock tick.
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

    // ID stage control
    control2id u_control2id(
        .clk(clk),
        .rst(rst),
        .pc_in(ifid_pc),
        .instr_in(ifid_instr),
        .pc_out(idex_pc),
        .instr_out(idex_instr)
    );

    // EX stage control
    control3ex u_control3ex(
        .clk(clk),
        .rst(rst),
        .pc_in(idex_pc),
        .instr_in(idex_instr),
        .pc_out(exma_pc),
        .instr_out(exma_instr)
    );

    // Memory address stage control
    control4ma u_control4ma(
        .clk(clk),
        .rst(rst),
        .pc_in(exma_pc),
        .instr_in(exma_instr),
        .pc_out(mamo_pc),
        .instr_out(mamo_instr)
    );

    // Memory operation stage control
    control4mo u_control4mo(
        .clk(clk),
        .rst(rst),
        .pc_in(mamo_pc),
        .instr_in(mamo_instr),
        .pc_out(mora_pc),
        .instr_out(mora_instr)
    );

    // Register address stage control
    control5ra u_control5ra(
        .clk(clk),
        .rst(rst),
        .pc_in(mora_pc),
        .instr_in(mora_instr),
        .pc_out(raro_pc),
        .instr_out(raro_instr)
    );

    // Register operation stage control
    control5ro u_control5ro(
        .clk(clk),
        .rst(rst),
        .pc_in(raro_pc),
        .instr_in(raro_instr),
        .pc_out(final_pc),
        .instr_out(final_instr)
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
            ex_pc <= idex_pc;
            ma_pc <= exma_pc;
            ro_pc <= final_pc;

            // Advance instructions
            id_instr <= ifid_instr;
            ex_instr <= idex_instr;
            ma_instr <= exma_instr;
            ro_instr <= final_instr;
        end
    end
endmodule
