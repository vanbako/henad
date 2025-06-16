// henad.v
// Top-level Henad 5-stage RISC core
module henad(
    input wire clk,
    input wire rst
);
    reg [11:0] ia_pc; // instruction address stage PC

    wire [11:0] instr_mem_data;
    wire [11:0] instr_mem_addr;

    wire [11:0] iaif_pc;
    wire [11:0] ifid_pc;
    wire [11:0] idex_pc;
    wire [11:0] exma_pc;
    wire [11:0] mamo_pc;
    wire [11:0] mora_pc;
    wire [11:0] raro_pc;
    wire [11:0] final_pc;

    wire [11:0] ifid_instr;
    wire [11:0] idex_instr;
    wire [11:0] exma_instr;
    wire [11:0] mamo_instr;
    wire [11:0] mora_instr;
    wire [11:0] raro_instr;
    wire [11:0] final_instr;

    // Update ia_pc every tick when rst is deasserted
    always @(posedge clk or posedge rst) begin
        if (rst)
            ia_pc <= 12'b0;
        else
            ia_pc <= ia_pc + 12'd1;
    end

    // Stage and control instantiations

    // IA stage control
    control1ia u_control1ia(
        .clk(clk),
        .rst(rst),
        .mem_addr(instr_mem_addr),
        .pc_in(ia_pc),
        .pc_out(iaif_pc)
    );

    // IF stage control
    control1if u_control1if(
        .clk(clk),
        .rst(rst),
        .pc_in(iaif_pc),
        .pc_out(ifid_pc),
        .instr_out(ifid_instr),
        .instr_mem_data(instr_mem_data)
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
endmodule
