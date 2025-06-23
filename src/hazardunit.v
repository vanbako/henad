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
    // -------------------------------------------------------------
    // Helper function used to decide if an instruction writes to the
    // general purpose register file.  The logic mirrors the write-back
    // decision used in stage5ro so that this unit remains consistent
    // with the final pipeline stage.
    function automatic reg_write_fn;
        input [3:0] set;
        input [3:0] opc;
        begin
            reg_write_fn = ({set, opc} == {`ISET_R,  `OPC_R_MOV})  ||
                          ({set, opc} == {`ISET_I,  `OPC_I_MOVi}) ||
                          ({set, opc} == {`ISET_IS, `OPC_IS_MOVis}) ||
                          ({set, opc} == {`ISET_R,  `OPC_R_ADD})  ||
                          ({set, opc} == {`ISET_I,  `OPC_I_ADDi}) ||
                          ({set, opc} == {`ISET_RS, `OPC_RS_ADDs}) ||
                          ({set, opc} == {`ISET_IS, `OPC_IS_ADDis})||
                          ({set, opc} == {`ISET_R,  `OPC_R_SUB})  ||
                          ({set, opc} == {`ISET_I,  `OPC_I_SUBi}) ||
                          ({set, opc} == {`ISET_RS, `OPC_RS_SUBs}) ||
                          ({set, opc} == {`ISET_IS, `OPC_IS_SUBis})||
                          ({set, opc} == {`ISET_R,  `OPC_R_NOT})  ||
                          ({set, opc} == {`ISET_R,  `OPC_R_AND})  ||
                          ({set, opc} == {`ISET_I,  `OPC_I_ANDi}) ||
                          ({set, opc} == {`ISET_R,  `OPC_R_OR})   ||
                          ({set, opc} == {`ISET_I,  `OPC_I_ORi})  ||
                          ({set, opc} == {`ISET_R,  `OPC_R_XOR})  ||
                          ({set, opc} == {`ISET_I,  `OPC_I_XORi}) ||
                          ({set, opc} == {`ISET_R,  `OPC_R_SL})   ||
                          ({set, opc} == {`ISET_I,  `OPC_I_SLi})  ||
                          ({set, opc} == {`ISET_R,  `OPC_R_SR})   ||
                          ({set, opc} == {`ISET_I,  `OPC_I_SRi})  ||
                          ({set, opc} == {`ISET_RS, `OPC_RS_SRs}) ||
                          ({set, opc} == {`ISET_IS, `OPC_IS_SRis})||
                          ({set, opc} == {`ISET_R,  `OPC_R_LD})   ||
                          ({set, opc} == {`ISET_I,  `OPC_I_LDi})  ||
                          ({set, opc} == {`ISET_I,  `OPC_I_Li})   ||
                          ({set, opc} == {`ISET_IS, `OPC_IS_Lis});
        end
    endfunction

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
