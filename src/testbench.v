// testbench.v
// Basic simulation testbench for the Henad core.  The goal is simply
// to exercise the pipeline and print out the program counter value at
// every stage so that the flow through the pipeline can be observed.

`timescale 1ns/1ps

module testbench;
    // Clock and reset
    reg clk;
    reg rst;

    // Instantiate the core
    henad uut (
        .clk(clk),
        .rst(rst)
    );

    // Generate an 8MHz clock -> 125ns period -> 62.5ns half period
    initial clk = 1'b0;
    always #62.5 clk = ~clk;

    // Drive reset and finish after a number of cycles
    initial begin
        rst = 1'b1;
        // Hold reset for two clock cycles
        #250;
        rst = 1'b0;

        // Let the simulation run for some cycles
        repeat (20) @(posedge clk);
        $finish;
    end

    // Display reset and PC values on every tick
    integer tick = 0;
    always @(posedge clk) begin
        $display("tick %0d : rst=%b IA=%h IAIF=%h IFID=%h IDEX=%h EXMA=%h MAMO=%h MORA=%h RARO=%h FINAL=%h",
                 tick, rst,
                 uut.ia_pc,
                 uut.iaif_pc,
                 uut.ifid_pc,
                 uut.idex_pc,
                 uut.exma_pc,
                 uut.mamo_pc,
                 uut.mora_pc,
                 uut.raro_pc,
                 uut.final_pc);
        $display("tick %0d : IFID_instr=%h IDEX_instr=%h EXMA_instr=%h MAMO_instr=%h MORA_instr=%h RARO_instr=%h FINAL_instr=%h",
                 tick,
                 uut.ifid_instr,
                 uut.idex_instr,
                 uut.exma_instr,
                 uut.mamo_instr,
                 uut.mora_instr,
                 uut.raro_instr,
                 uut.final_instr);
        $display("tick %0d : IFID_set=%h IDEX_set=%h EXMA_set=%h MAMO_set=%h MORA_set=%h RARO_set=%h FINAL_set=%h",
                 tick,
                 uut.ifid_set,
                 uut.idex_set,
                 uut.exma_set,
                 uut.mamo_set,
                 uut.mora_set,
                 uut.raro_set,
                 uut.final_set);
        tick = tick + 1;
    end
endmodule
