`include "src/sizes.vh"
`include "src/sr.vh"

module amber(
    input wire iw_clk,
    input wire iw_rst
);
    wire                w_imem_we    [0:1];
    wire [`HBIT_ADDR:0] w_imem_addr  [0:1];
    wire [`HBIT_DATA:0] w_imem_wdata [0:1];
    wire [`HBIT_DATA:0] w_imem_rdata [0:1];

    mem #(.READ_MEM(1)) u_imem(
        .iw_clk  (iw_clk),
        .iw_we   (w_imem_we),
        .iw_addr (w_imem_addr),
        .iw_wdata(w_imem_wdata),
        .or_rdata(w_imem_rdata)
    );

    wire                w_dmem_we    [0:1];
    wire [`HBIT_ADDR:0] w_dmem_addr  [0:1];
    wire [`HBIT_DATA:0] w_dmem_wdata [0:1];
    wire [`HBIT_DATA:0] w_dmem_rdata [0:1];

    mem #(.READ_MEM(0)) u_dmem(
        .iw_clk  (iw_clk),
        .iw_we   (w_dmem_we),
        .iw_addr (w_dmem_addr),
        .iw_wdata(w_dmem_wdata),
        .or_rdata(w_dmem_rdata)
    );

    wire                w_ia_valid;
    reg  [`HBIT_ADDR:0] r_ia_pc;
    wire [`HBIT_ADDR:0] w_iaif_pc;
    wire [`HBIT_ADDR:0] w_ifxt_pc;
    wire [`HBIT_ADDR:0] w_xtid_pc;
    wire [`HBIT_ADDR:0] w_idex_pc;
    wire [`HBIT_ADDR:0] w_exma_pc;
    wire [`HBIT_ADDR:0] w_mamo_pc;
    wire [`HBIT_ADDR:0] w_mowb_pc;
    wire [`HBIT_ADDR:0] w_wb_pc;

    wire [`HBIT_DATA:0] w_ifxt_instr;
    wire [`HBIT_DATA:0] w_xtid_instr;
    wire [`HBIT_DATA:0] w_idex_instr;
    wire [`HBIT_DATA:0] w_exma_instr;
    wire [`HBIT_DATA:0] w_mamo_instr;
    wire [`HBIT_DATA:0] w_mowb_instr;
    wire [`HBIT_DATA:0] w_wb_instr;

    wire [`HBIT_TGT_GP:0] w_gp_read_addr1;
    wire [`HBIT_TGT_GP:0] w_gp_read_addr2;
    wire [`HBIT_TGT_GP:0] w_gp_write_addr;
    wire [`HBIT_DATA:0]   w_gp_write_data;
    wire                  w_gp_write_enable;
    wire [`HBIT_DATA:0]   w_gp_read_data1;
    wire [`HBIT_DATA:0]   w_gp_read_data2;

    reggp u_reggp(
        .iw_clk         (iw_clk),
        .iw_rst         (iw_rst),
        .iw_read_addr1  (w_gp_read_addr1),
        .iw_read_addr2  (w_gp_read_addr2),
        .iw_write_addr  (w_gp_write_addr),
        .iw_write_data  (w_gp_write_data),
        .iw_write_enable(w_gp_write_enable),
        .ow_read_data1  (w_gp_read_data1),
        .ow_read_data2  (w_gp_read_data2)
    );

    wire [`HBIT_TGT_SR:0] w_sr_read_addr1;
    wire [`HBIT_TGT_SR:0] w_sr_read_addr2;
    wire [`HBIT_TGT_SR:0] w_sr_write_addr;
    wire [`HBIT_DATA:0]   w_sr_write_data;
    wire                  w_sr_write_enable;
    wire [`HBIT_DATA:0]   w_sr_write_pc;
    wire                  w_sr_write_pc_enable;
    wire [`HBIT_DATA:0]   w_sr_read_data1;
    wire [`HBIT_DATA:0]   w_sr_read_data2;

    regsr u_regsr(
        .iw_clk            (iw_clk),
        .iw_rst            (iw_rst),
        .iw_read_addr1     (w_sr_read_addr1),
        .iw_read_addr2     (w_sr_read_addr2),
        .iw_write_addr     (w_sr_write_addr),
        .iw_write_data     (w_sr_write_data),
        .iw_write_enable   (w_sr_write_enable),
        .ow_read_data1     (w_sr_read_data1),
        .ow_read_data2     (w_sr_read_data2)
    );

    // Address registers
    wire [`HBIT_TGT_AR:0] w_ar_read_addr1;
    wire [`HBIT_TGT_AR:0] w_ar_read_addr2;
    wire [`HBIT_TGT_AR:0] w_ar_write_addr;
    wire [`HBIT_ADDR:0]   w_ar_write_data;
    wire                  w_ar_write_enable;
    wire [`HBIT_ADDR:0]   w_ar_read_data1;
    wire [`HBIT_ADDR:0]   w_ar_read_data2;

    // AR writes driven by WB stage

    regar u_regar(
        .iw_clk         (iw_clk),
        .iw_rst         (iw_rst),
        .iw_read_addr1  (w_ar_read_addr1),
        .iw_read_addr2  (w_ar_read_addr2),
        .iw_write_addr  (w_ar_write_addr),
        .iw_write_data  (w_ar_write_data),
        .iw_write_enable(w_ar_write_enable),
        .ow_read_data1  (w_ar_read_data1),
        .ow_read_data2  (w_ar_read_data2)
    );

    wire                w_stall;
    wire                w_bubble;
    wire                w_branch_taken;
    wire [`HBIT_ADDR:0] w_branch_pc;

    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            r_ia_pc <= `SIZE_ADDR'b0;
        end else if (w_branch_taken) begin
            r_ia_pc <= w_branch_pc;
        end else if (w_stall) begin
            r_ia_pc <= r_ia_pc;
        end else begin
            r_ia_pc <= r_ia_pc + `SIZE_ADDR'd1;
        end
    end

    stg_ia u_stg_ia(
        .iw_clk     (iw_clk),
        .iw_rst     (iw_rst),
        .ow_mem_addr(w_imem_addr),
        .iw_pc      (r_ia_pc),
        .ow_pc      (w_iaif_pc),
        .ow_ia_valid(w_ia_valid),
        .iw_flush   (w_branch_taken),
        .iw_stall   (w_stall)
    );

    stg_if u_stg_if(
        .iw_clk     (iw_clk),
        .iw_rst     (iw_rst),
        .iw_mem_data(w_imem_rdata),
        .iw_ia_valid(w_ia_valid),
        .iw_pc      (w_iaif_pc),
        .ow_pc      (w_ifxt_pc),
        .ow_instr   (w_ifxt_instr),
        .iw_flush   (w_branch_taken),
        .iw_stall   (w_stall)
    );

    stg_xt u_stg_xt(
        .iw_clk     (iw_clk),
        .iw_rst     (iw_rst),
        .iw_pc      (w_ifxt_pc),
        .ow_pc      (w_xtid_pc),
        .iw_instr   (w_ifxt_instr),
        .ow_instr   (w_xtid_instr),
        .iw_flush   (w_branch_taken),
        .iw_stall   (w_stall)
    );

    wire [`HBIT_OPC:0]    w_opc;
    wire                  w_sgn_en;
    wire                  w_imm_en;
    wire [`HBIT_IMM14:0]  w_imm14_val;
    wire [`HBIT_IMM12:0]  w_imm12_val;
    wire [`HBIT_IMM10:0]  w_imm10_val;
    wire [`HBIT_IMM16:0]  w_imm16_val;
    wire [`HBIT_CC:0]     w_cc;
    wire                  w_has_src_gp;
    wire [`HBIT_TGT_GP:0] w_tgt_gp;
    wire                  w_tgt_gp_we;
    wire                  w_has_src_ar;
    wire [`HBIT_TGT_AR:0] w_src_ar;
    wire                  w_has_tgt_ar;
    wire [`HBIT_TGT_AR:0] w_tgt_ar;
    wire                  w_has_src_sr;
    wire [`HBIT_TGT_SR:0] w_tgt_sr;
    wire                  w_tgt_sr_we;
    wire [`HBIT_SRC_GP:0] w_src_gp;
    wire [`HBIT_SRC_SR:0] w_src_sr;

    stg_id u_stg_id(
        .iw_clk       (iw_clk),
        .iw_rst       (iw_rst),
        .iw_pc        (w_xtid_pc),
        .ow_pc        (w_idex_pc),
        .iw_instr     (w_xtid_instr),
        .ow_instr     (w_idex_instr),
        .ow_opc       (w_opc),
        .ow_sgn_en    (w_sgn_en),
        .ow_imm_en    (w_imm_en),
        .ow_imm14_val (w_imm14_val),
        .ow_imm12_val (w_imm12_val),
        .ow_imm10_val (w_imm10_val),
        .ow_imm16_val (w_imm16_val),
        .ow_cc        (w_cc),
        .ow_has_src_gp(w_has_src_gp),
        .ow_tgt_gp    (w_tgt_gp),
        .ow_tgt_gp_we (w_tgt_gp_we),
        .ow_has_src_ar(w_has_src_ar),
        .ow_src_ar    (w_src_ar),
        .ow_has_tgt_ar(w_has_tgt_ar),
        .ow_tgt_ar    (w_tgt_ar),
        .ow_has_src_sr(w_has_src_sr),
        .ow_tgt_sr    (w_tgt_sr),
        .ow_tgt_sr_we (w_tgt_sr_we),
        .ow_src_gp    (w_src_gp),
        .ow_src_sr    (w_src_sr),
        .iw_flush     (w_branch_taken),
        .iw_stall     (w_stall)
    );

    wire [`HBIT_OPC:0]    w_exma_opc;
    wire [`HBIT_TGT_GP:0] w_exma_tgt_gp;
    wire                  w_exma_tgt_gp_we;
    wire [`HBIT_TGT_SR:0] w_exma_tgt_sr;
    wire                  w_exma_tgt_sr_we;
    wire [`HBIT_TGT_AR:0] w_exma_tgt_ar;
    wire                  w_exma_tgt_ar_we;
    wire [`HBIT_ADDR:0]   w_exma_addr;
    wire [`HBIT_DATA:0]   w_exma_result;
    wire [`HBIT_ADDR:0]   w_exma_ar_result;

    wire [`HBIT_OPC:0]    w_mamo_opc;
    wire [`HBIT_TGT_GP:0] w_mamo_tgt_gp;
    wire                  w_mamo_tgt_gp_we;
    wire [`HBIT_TGT_SR:0] w_mamo_tgt_sr;
    wire                  w_mamo_tgt_sr_we;
    wire [`HBIT_DATA:0]   w_mamo_result;
    wire [`HBIT_TGT_AR:0] w_mamo_tgt_ar;
    wire                  w_mamo_tgt_ar_we;
    wire [`HBIT_ADDR:0]   w_mamo_ar_result;

    wire [`HBIT_OPC:0]    w_mowb_opc;
    wire [`HBIT_TGT_GP:0] w_mowb_tgt_gp;
    wire                  w_mowb_tgt_gp_we;
    wire [`HBIT_TGT_SR:0] w_mowb_tgt_sr;
    wire                  w_mowb_tgt_sr_we;
    wire [`HBIT_DATA:0]   w_mowb_result;
    wire [`HBIT_TGT_AR:0] w_mowb_tgt_ar;
    wire                  w_mowb_tgt_ar_we;
    wire [`HBIT_ADDR:0]   w_mowb_ar_result;

    wire [`HBIT_DATA:0]   w_src_gp_val;
    wire [`HBIT_DATA:0]   w_tgt_gp_val;
    wire [`HBIT_ADDR:0]   w_src_ar_val;
    wire [`HBIT_ADDR:0]   w_tgt_ar_val;
    wire [`HBIT_DATA:0]   w_src_sr_val;
    wire [`HBIT_DATA:0]   w_tgt_sr_val;

    assign w_gp_read_addr1 = w_src_gp;
    assign w_gp_read_addr2 = w_tgt_gp;
    assign w_ar_read_addr1 = w_has_src_ar ? w_src_ar : {(`HBIT_TGT_AR+1){1'b0}};
    assign w_ar_read_addr2 = w_has_tgt_ar ? w_tgt_ar : {(`HBIT_TGT_AR+1){1'b0}};
    assign w_sr_read_addr1 = w_src_sr;
    assign w_sr_read_addr2 = w_tgt_sr;

    forward u_forward(
        .iw_tgt_gp        (w_tgt_gp),
        .iw_tgt_gp_we     (w_tgt_gp_we),
        .iw_tgt_exma_gp   (w_exma_tgt_gp),
        .iw_tgt_exma_gp_we(w_exma_tgt_gp_we),
        .iw_tgt_mamo_gp   (w_mamo_tgt_gp),
        .iw_tgt_mamo_gp_we(w_mamo_tgt_gp_we),
        .iw_tgt_mowb_gp   (w_mowb_tgt_gp),
        .iw_tgt_mowb_gp_we(w_mowb_tgt_gp_we),
        .iw_tgt_sr        (w_tgt_sr),
        .iw_tgt_sr_we     (w_tgt_sr_we),
        .iw_tgt_exma_sr   (w_exma_tgt_sr),
        .iw_tgt_exma_sr_we(w_exma_tgt_sr_we),
        .iw_tgt_mamo_sr   (w_mamo_tgt_sr),
        .iw_tgt_mamo_sr_we(w_mamo_tgt_sr_we),
        .iw_tgt_mowb_sr   (w_mowb_tgt_sr),
        .iw_tgt_mowb_sr_we(w_mowb_tgt_sr_we),
        .iw_src_gp        (w_src_gp),
        .iw_src_sr        (w_src_sr),
        .iw_gp_read_data1 (w_gp_read_data1),
        .iw_gp_read_data2 (w_gp_read_data2),
        .iw_sr_read_data1 (w_sr_read_data1),
        .iw_sr_read_data2 (w_sr_read_data2),
        .iw_exma_result   (w_exma_result),
        .iw_mamo_result   (w_mamo_result),
        .iw_mowb_result   (w_mowb_result),
        .or_src_gp_val    (w_src_gp_val),
        .or_tgt_gp_val    (w_tgt_gp_val),
        .or_src_sr_val    (w_src_sr_val),
        .or_tgt_sr_val    (w_tgt_sr_val)
    );

    hazard u_hazard(
        .iw_clk           (iw_clk),
        .iw_rst           (iw_rst),
        .iw_idex_opc      (w_opc),
        .ow_stall         (w_stall)
    );

    stg_ex u_stg_ex(
        .iw_clk           (iw_clk),
        .iw_rst           (iw_rst),
        .iw_pc            (w_idex_pc),
        .ow_pc            (w_exma_pc),
        .iw_instr         (w_idex_instr),
        .ow_instr         (w_exma_instr),
        .iw_opc           (w_opc),
        .ow_opc           (w_exma_opc),
        .iw_sgn_en        (w_sgn_en),
        .iw_imm_en        (w_imm_en),
        .iw_imm14_val     (w_imm14_val),
        .iw_imm12_val     (w_imm12_val),
        .iw_imm10_val     (w_imm10_val),
        .iw_imm16_val     (w_imm16_val),
        .iw_cc            (w_cc),
        .iw_tgt_gp        (w_tgt_gp),
        .iw_tgt_gp_we     (w_tgt_gp_we),
        .ow_tgt_gp        (w_exma_tgt_gp),
        .ow_tgt_gp_we     (w_exma_tgt_gp_we),
        .iw_tgt_sr        (w_tgt_sr),
        .iw_tgt_sr_we     (w_tgt_sr_we),
        .ow_tgt_sr        (w_exma_tgt_sr),
        .ow_tgt_sr_we     (w_exma_tgt_sr_we),
        .iw_tgt_ar        (w_tgt_ar),
        .ow_tgt_ar        (w_exma_tgt_ar),
        .ow_tgt_ar_we     (w_exma_tgt_ar_we),
        .iw_src_gp        (w_src_gp),
        .iw_src_ar        (w_src_ar),
        .iw_src_sr        (w_src_sr),
        .ow_addr          (w_exma_addr),
        .ow_result        (w_exma_result),
        .ow_ar_result     (w_exma_ar_result),
        .ow_branch_taken  (w_branch_taken),
        .ow_branch_pc     (w_branch_pc),
        .iw_src_gp_val    (w_src_gp_val),
        .iw_tgt_gp_val    (w_tgt_gp_val),
        .iw_src_ar_val    (w_ar_read_data1),
        .iw_tgt_ar_val    (w_ar_read_data2),
        .iw_src_sr_val    (w_src_sr_val),
        .iw_tgt_sr_val    (w_tgt_sr_val),
        .iw_flush         (w_branch_taken),
        .iw_stall         (w_stall)
    );

    wire w_mem_mp;

    stg_ma u_stg_ma(
        .iw_clk      (iw_clk),
        .iw_rst      (iw_rst),
        .iw_pc       (w_exma_pc),
        .ow_pc       (w_mamo_pc),
        .iw_instr    (w_exma_instr),
        .ow_instr    (w_mamo_instr),
        .iw_opc      (w_exma_opc),
        .ow_opc      (w_mamo_opc),
        .iw_tgt_gp   (w_exma_tgt_gp),
        .iw_tgt_gp_we(w_exma_tgt_gp_we),
        .ow_tgt_gp   (w_mamo_tgt_gp),
        .ow_tgt_gp_we(w_mamo_tgt_gp_we),
        .iw_tgt_sr   (w_exma_tgt_sr),
        .iw_tgt_sr_we(w_exma_tgt_sr_we),
        .ow_tgt_sr   (w_mamo_tgt_sr),
        .ow_tgt_sr_we(w_mamo_tgt_sr_we),
        .iw_tgt_ar   (w_exma_tgt_ar),
        .iw_tgt_ar_we(w_exma_tgt_ar_we),
        .ow_tgt_ar   (w_mamo_tgt_ar),
        .ow_tgt_ar_we(w_mamo_tgt_ar_we),
        .ow_mem_mp   (w_mem_mp),
        .ow_mem_addr (w_dmem_addr),
        .iw_addr     (w_exma_addr),
        .iw_result   (w_exma_result),
        .ow_result   (w_mamo_result),
        .iw_ar_result(w_exma_ar_result),
        .ow_ar_result(w_mamo_ar_result)
    );

    stg_mo u_stg_mo(
        .iw_clk      (iw_clk),
        .iw_rst      (iw_rst),
        .iw_pc       (w_mamo_pc),
        .ow_pc       (w_mowb_pc),
        .iw_instr    (w_mamo_instr),
        .ow_instr    (w_mowb_instr),
        .iw_opc      (w_mamo_opc),
        .ow_opc      (w_mowb_opc),
        .iw_tgt_gp   (w_mamo_tgt_gp),
        .iw_tgt_gp_we(w_mamo_tgt_gp_we),
        .ow_tgt_gp   (w_mowb_tgt_gp),
        .ow_tgt_gp_we(w_mowb_tgt_gp_we),
        .iw_tgt_sr   (w_mamo_tgt_sr),
        .iw_tgt_sr_we(w_mamo_tgt_sr_we),
        .ow_tgt_sr   (w_mowb_tgt_sr),
        .ow_tgt_sr_we(w_mowb_tgt_sr_we),
        .iw_tgt_ar   (w_mamo_tgt_ar),
        .iw_tgt_ar_we(w_mamo_tgt_ar_we),
        .ow_tgt_ar   (w_mowb_tgt_ar),
        .ow_tgt_ar_we(w_mowb_tgt_ar_we),
        .iw_mem_mp   (w_mem_mp),
        .ow_mem_we   (w_dmem_we),
        .ow_mem_wdata(w_dmem_wdata),
        .iw_mem_rdata(w_dmem_rdata),
        .iw_result   (w_mamo_result),
        .ow_result   (w_mowb_result),
        .iw_ar_result(w_mamo_ar_result),
        .ow_ar_result(w_mowb_ar_result)
    );

    wire [`HBIT_OPC:0]    w_wb_opc;
    wire [`HBIT_TGT_GP:0] w_wb_tgt_gp;
    wire [`HBIT_TGT_SR:0] w_wb_tgt_sr;
    wire [`HBIT_DATA:0]   w_wb_result;

    stg_wb u_stg_wb(
        .iw_clk            (iw_clk),
        .iw_rst            (iw_rst),
        .iw_pc             (w_mowb_pc),
        .ow_pc             (w_wb_pc),
        .iw_instr          (w_mowb_instr),
        .ow_instr          (w_wb_instr),
        .ow_gp_write_addr  (w_gp_write_addr),
        .ow_gp_write_data  (w_gp_write_data),
        .ow_gp_write_enable(w_gp_write_enable),
        .ow_sr_write_addr  (w_sr_write_addr),
        .ow_sr_write_data  (w_sr_write_data),
        .ow_sr_write_enable(w_sr_write_enable),
        .iw_opc            (w_mowb_opc),
        .ow_opc            (w_wb_opc),
        .iw_tgt_gp         (w_mowb_tgt_gp),
        .iw_tgt_gp_we      (w_mowb_tgt_gp_we),
        .ow_tgt_gp         (w_wb_tgt_gp),
        .iw_tgt_sr         (w_mowb_tgt_sr),
        .iw_tgt_sr_we      (w_mowb_tgt_sr_we),
        .ow_tgt_sr         (w_wb_tgt_sr),
        .iw_tgt_ar         (w_mowb_tgt_ar),
        .iw_tgt_ar_we      (w_mowb_tgt_ar_we),
        .ow_ar_write_addr  (w_ar_write_addr),
        .ow_ar_write_data  (w_ar_write_data),
        .ow_ar_write_enable(w_ar_write_enable),
        .iw_result         (w_mowb_result),
        .iw_ar_result      (w_mowb_ar_result),
        .ow_result         (w_wb_result)
    );
endmodule
