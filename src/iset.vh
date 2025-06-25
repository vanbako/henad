// iset.vh
// Henad 12-bit RISC: Instruction Set Codes (for opcode set switching)
`ifndef ISET_VH
`define ISET_VH

// Instruction set codes (for opcode set switching)
`define ISET_R  4'h0 // Register set
`define ISET_RS 4'h1 // Register signed set
`define ISET_I  4'h2 // Immediate set
`define ISET_IS 4'h3 // Immediate signed set
`define ISET_S  4'h4 // Special set

`endif // ISET_VH

// -------------------------------------------------------------
// Common helper logic

// reg_write_fn
// Return 1 when the combination of instruction set and opcode
// writes to the general purpose register file.  Modules that
// require this function should define `DEFINE_REG_WRITE_FN` before
// including this header inside their scope.
`ifdef DEFINE_REG_WRITE_FN
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
                       ({set, opc} == {`ISET_I,  `OPC_I_LDi});
    end
endfunction
`endif // DEFINE_REG_WRITE_FN

// reg_src_read_fn
// Return 1 when the source general purpose register is read by the
// given instruction. Modules should define `DEFINE_REG_SRC_READ_FN`
// before including this header.
`ifdef DEFINE_REG_SRC_READ_FN
function automatic reg_src_read_fn;
    input [3:0] set;
    input [3:0] opc;
    begin
        reg_src_read_fn = ({set, opc} == {`ISET_R,  `OPC_R_MOV})  ||
                          ({set, opc} == {`ISET_R,  `OPC_R_ADD})  ||
                          ({set, opc} == {`ISET_RS, `OPC_RS_ADDs}) ||
                          ({set, opc} == {`ISET_R,  `OPC_R_SUB})  ||
                          ({set, opc} == {`ISET_RS, `OPC_RS_SUBs}) ||
                          ({set, opc} == {`ISET_R,  `OPC_R_CMP})  ||
                          ({set, opc} == {`ISET_RS, `OPC_RS_CMPs}) ||
                          ({set, opc} == {`ISET_R,  `OPC_R_AND})  ||
                          ({set, opc} == {`ISET_R,  `OPC_R_OR})   ||
                          ({set, opc} == {`ISET_R,  `OPC_R_XOR})  ||
                          ({set, opc} == {`ISET_R,  `OPC_R_SL})   ||
                          ({set, opc} == {`ISET_R,  `OPC_R_SR})   ||
                          ({set, opc} == {`ISET_RS, `OPC_RS_SRs}) ||
                          ({set, opc} == {`ISET_R,  `OPC_R_LD})   ||
                          ({set, opc} == {`ISET_I,  `OPC_I_LDi})  ||
                          ({set, opc} == {`ISET_R,  `OPC_R_ST});
    end
endfunction
`endif // DEFINE_REG_SRC_READ_FN

// reg_tgt_read_fn
// Return 1 when the target general purpose register is read by the
// given instruction. Modules should define `DEFINE_REG_TGT_READ_FN`
// before including this header.
`ifdef DEFINE_REG_TGT_READ_FN
function automatic reg_tgt_read_fn;
    input [3:0] set;
    input [3:0] opc;
    begin
        reg_tgt_read_fn = ({set, opc} == {`ISET_R,  `OPC_R_ADD})  ||
                          ({set, opc} == {`ISET_I,  `OPC_I_ADDi}) ||
                          ({set, opc} == {`ISET_RS, `OPC_RS_ADDs}) ||
                          ({set, opc} == {`ISET_IS, `OPC_IS_ADDis})||
                          ({set, opc} == {`ISET_R,  `OPC_R_SUB})  ||
                          ({set, opc} == {`ISET_I,  `OPC_I_SUBi}) ||
                          ({set, opc} == {`ISET_RS, `OPC_RS_SUBs}) ||
                          ({set, opc} == {`ISET_IS, `OPC_IS_SUBis})||
                          ({set, opc} == {`ISET_R,  `OPC_R_CMP})  ||
                          ({set, opc} == {`ISET_I,  `OPC_I_CMPi}) ||
                          ({set, opc} == {`ISET_RS, `OPC_RS_CMPs}) ||
                          ({set, opc} == {`ISET_IS, `OPC_IS_CMPis})||
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
                          ({set, opc} == {`ISET_R,  `OPC_R_BCC})  ||
                          ({set, opc} == {`ISET_R,  `OPC_R_ST})   ||
                          ({set, opc} == {`ISET_I,  `OPC_I_STi});
    end
endfunction
`endif // DEFINE_REG_TGT_READ_FN
