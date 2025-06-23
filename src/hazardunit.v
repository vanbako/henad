// hazardunit.v
`include "src/opcodes.vh"
`include "src/iset.vh"

// Hazard detection unit for simple read-after-write stalls. The unit looks at
// the register addresses used by the decode stage and compares them with the
// destination registers of instructions in the pipeline that have not yet
// written their results back. If a match is found, a stall signal is asserted so
// that the IF and ID stages can be paused.
module hazardunit(
    // Register numbers currently being read in the decode stage
    input  wire [3:0] id_src_gp,
    input  wire [3:0] id_tgt_gp,

    // Instructions further down the pipeline.  Only the sets and opcodes are
    // required to determine if they will write back to the register file.
    input  wire [11:0] idex_instr,
    input  wire [3:0]  idex_set,
    input  wire [11:0] exma_instr,
    input  wire [3:0]  exma_set,
    input  wire [11:0] mamo_instr,
    input  wire [3:0]  mamo_set,

    // Asserted when a hazard is detected
    output wire        stall
);
    // Bring in the shared reg_write_fn helper
    `define DEFINE_REG_WRITE_FN
    `include "src/iset.vh"
    `undef DEFINE_REG_WRITE_FN

    // Destination register numbers in the stages ahead of decode
    wire [3:0] ex_waddr = idex_instr[7:4];
    wire [3:0] ma_waddr = exma_instr[7:4];
    wire [3:0] mo_waddr = mamo_instr[7:4];

    wire hazard_ex = reg_write_fn(idex_set,  idex_instr[11:8]) &&
                     ((ex_waddr == id_src_gp) || (ex_waddr == id_tgt_gp));
    wire hazard_ma = reg_write_fn(exma_set,  exma_instr[11:8]) &&
                     ((ma_waddr == id_src_gp) || (ma_waddr == id_tgt_gp));
    wire hazard_mo = reg_write_fn(mamo_set, mamo_instr[11:8]) &&
                     ((mo_waddr == id_src_gp) || (mo_waddr == id_tgt_gp));

    assign stall = hazard_ex || hazard_ma || hazard_mo;
endmodule
