`timescale 1ns/1ps

`include "src/sizes.vh"
`include "src/opcodes.vh"
`include "src/cr.vh"
`include "src/sr.vh"
`include "src/pstate.vh"

module opclass7_tb;
    reg clk;
    reg rst;

    amber u_amber (
        .iw_clk(clk),
        .iw_rst(rst)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic run_cycles;
        input integer count;
        integer ii;
        begin
            for (ii = 0; ii < count; ii = ii + 1)
                @(posedge clk);
        end
    endtask

    task automatic apply_reset;
        begin
            rst = 1'b1;
            run_cycles(6);
            rst = 1'b0;
        end
    endtask

    task automatic clear_imem;
        integer idx;
        begin
            for (idx = 0; idx < 32; idx = idx + 1)
                u_amber.u_imem.r_mem[idx] = 24'd0;
        end
    endtask

    task automatic load_single_instr;
        input [23:0] instr;
        begin
            clear_imem();
            u_amber.u_imem.r_mem[0] = instr;
            u_amber.u_imem.r_mem[1] = { `OPC_HLT, 16'd0 };
        end
    endtask

    task automatic set_gp;
        input integer idx;
        input [23:0] value;
        begin
            u_amber.u_reggp.r_gp[idx] = value;
        end
    endtask

    task automatic set_cr;
        input integer idx;
        input [47:0] base;
        input [47:0] len;
        input [47:0] cur;
        input [23:0] perms;
        input [23:0] attr;
        input bit tag;
        begin
            u_amber.u_regcr.r_base[idx]  = base;
            u_amber.u_regcr.r_len[idx]   = len;
            u_amber.u_regcr.r_cur[idx]   = cur;
            u_amber.u_regcr.r_perms[idx] = perms;
            u_amber.u_regcr.r_attr[idx]  = attr;
            u_amber.u_regcr.r_tag[idx]   = tag;
        end
    endtask

    task automatic set_sr;
        input integer idx;
        input [47:0] value;
        begin
            u_amber.u_regsr.r_sr[idx] = value;
        end
    endtask

    task automatic store48;
        input integer addr;
        input [47:0] value;
        begin
            u_amber.u_dmem.r_mem[addr]     = value[23:0];
            u_amber.u_dmem.r_mem[addr + 1] = value[47:24];
        end
    endtask

    task automatic expect_mem48;
        input integer addr;
        input [47:0] expected;
        input [127:0] label;
        begin
            if (u_amber.u_dmem.r_mem[addr] !== expected[23:0] ||
                u_amber.u_dmem.r_mem[addr + 1] !== expected[47:24]) begin
                $display("FAIL (%s): mem[%0d:%0d]=%h_%h expected %h_%h",
                         label, addr + 1, addr,
                         u_amber.u_dmem.r_mem[addr + 1], u_amber.u_dmem.r_mem[addr],
                         expected[47:24], expected[23:0]);
                $fatal;
            end
        end
    endtask

    task automatic expect_no_trap;
        input [127:0] label;
        reg [47:0] pstate;
        begin
            pstate = u_amber.u_regsr.r_sr[`SR_IDX_PSTATE];
            if (pstate[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO] !== `PSTATE_CAUSE_NONE) begin
                $display("FAIL (%s): unexpected trap cause %02h", label,
                         pstate[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO]);
                $fatal;
            end
            if (pstate[`PSTATE_BIT_TPE] !== 1'b0) begin
                $display("FAIL (%s): PSTATE.TPE should be 0 on non-trap", label);
                $fatal;
            end
        end
    endtask

    task automatic expect_trap;
        input [7:0] cause;
        input [127:0] label;
        reg [47:0] pstate;
        reg [47:0] lr;
        begin
            pstate = u_amber.u_regsr.r_sr[`SR_IDX_PSTATE];
            lr     = u_amber.u_regsr.r_sr[`SR_IDX_LR];
            if (pstate[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO] !== cause) begin
                $display("FAIL (%s): trap cause %02h expected %02h", label,
                         pstate[`PSTATE_CAUSE_HI:`PSTATE_CAUSE_LO], cause);
                $fatal;
            end
            if (lr == 48'd0) begin
                $display("FAIL (%s): LR not written on trap", label);
                $fatal;
            end
            if (pstate[`PSTATE_BIT_TPE] !== 1'b1 || pstate[`PSTATE_BIT_MODE] !== 1'b1) begin
                $display("FAIL (%s): PSTATE trap bits TPE=%b MODE=%b", label,
                         pstate[`PSTATE_BIT_TPE], pstate[`PSTATE_BIT_MODE]);
                $fatal;
            end
        end
    endtask

    function automatic [23:0] enc_pushur;
        input int cr_t;
        input int dr_s;
        reg [1:0] cr_bits;
        reg [3:0] dr_bits;
        begin
            cr_bits = cr_t[1:0];
            dr_bits = dr_s[3:0];
            enc_pushur = { `OPC_PUSHur, cr_bits, dr_bits, 10'b0 };
        end
    endfunction

    function automatic [23:0] enc_pushaur;
        input int cr_t;
        input int cr_s;
        reg [1:0] crt_bits;
        reg [1:0] crs_bits;
        begin
            crt_bits = cr_t[1:0];
            crs_bits = cr_s[1:0];
            enc_pushaur = { `OPC_PUSHAur, crt_bits, crs_bits, 12'b0 };
        end
    endfunction

    function automatic [23:0] enc_popur;
        input int dr_t;
        input int cr_s;
        reg [3:0] dr_bits;
        reg [1:0] cr_bits;
        begin
            dr_bits = dr_t[3:0];
            cr_bits = cr_s[1:0];
            enc_popur = { `OPC_POPur, dr_bits, cr_bits, 10'b0 };
        end
    endfunction

    function automatic [23:0] enc_popaur;
        input int cr_t;
        input int cr_s;
        reg [1:0] cr_t_bits;
        reg [1:0] cr_s_bits;
        begin
            cr_t_bits = cr_t[1:0];
            cr_s_bits = cr_s[1:0];
            enc_popaur = { `OPC_POPAur, cr_t_bits, cr_s_bits, 12'b0 };
        end
    endfunction

    task automatic exec_pushur;
        input int cr_idx;
        input int dr_idx;
        input [47:0] base;
        input [47:0] len;
        input [47:0] cur;
        input [23:0] perms;
        input [23:0] attr;
        input bit tag;
        input [23:0] dr_value;
        input bit expect_trap_flag;
        input [7:0] trap_cause;
        input [127:0] label;
        int new_addr;
        reg [23:0] sentinel;
        begin
            apply_reset();
            set_sr(`SR_IDX_LR, 48'd0);
            set_sr(`SR_IDX_PSTATE, 48'd0);
            set_cr(cr_idx, base, len, cur, perms, attr, tag);
            set_gp(dr_idx, dr_value);
            load_single_instr(enc_pushur(cr_idx, dr_idx));
            new_addr = cur - 48'd1;
            sentinel = 24'h00FACE;
            if (new_addr >= 0 && new_addr < 4096)
                u_amber.u_dmem.r_mem[new_addr] = sentinel;
            run_cycles(320);
            if (expect_trap_flag) begin
                expect_trap(trap_cause, label);
                if (new_addr >= 0 && new_addr < 4096 && u_amber.u_dmem.r_mem[new_addr] !== sentinel) begin
                    $display("FAIL (%s): memory modified despite trap", label);
                    $fatal;
                end
            end else begin
                expect_no_trap(label);
                if (u_amber.u_regcr.r_cur[cr_idx] !== (cur - 48'd1)) begin
                    $display("FAIL (%s): CR%0d.cur=%0d expected %0d", label, cr_idx,
                             u_amber.u_regcr.r_cur[cr_idx], cur - 48'd1);
                    $fatal;
                end
                if (new_addr < 0 || new_addr >= 4096) begin
                    $display("FAIL (%s): computed store address out of TB range", label);
                    $fatal;
                end
                if (u_amber.u_dmem.r_mem[new_addr] !== dr_value) begin
                    $display("FAIL (%s): mem[%0d]=%h expected %h", label, new_addr,
                             u_amber.u_dmem.r_mem[new_addr], dr_value);
                    $fatal;
                end
            end
        end
    endtask

    task automatic exec_pushaur;
        input int cr_dst;
        input int cr_src;
        input [47:0] dst_base;
        input [47:0] dst_len;
        input [47:0] dst_cur;
        input [23:0] dst_perms;
        input [23:0] dst_attr;
        input bit dst_tag;
        input [47:0] src_base;
        input [47:0] src_len;
        input [47:0] src_cur;
        input [23:0] src_perms;
        input [23:0] src_attr;
        input bit src_tag;
        input bit expect_trap_flag;
        input [7:0] trap_cause;
        input [127:0] label;
        int addr_base;
        integer ww;
        reg [23:0] sentinel;
        begin
            apply_reset();
            set_sr(`SR_IDX_LR, 48'd0);
            set_sr(`SR_IDX_PSTATE, 48'd0);
            set_cr(cr_dst, dst_base, dst_len, dst_cur, dst_perms, dst_attr, dst_tag);
            set_cr(cr_src, src_base, src_len, src_cur, src_perms, src_attr, src_tag);
            load_single_instr(enc_pushaur(cr_dst, cr_src));
            addr_base = dst_cur - 48'd12;
            sentinel = 24'h00CAFE;
            for (ww = 0; ww < 12; ww = ww + 1) begin
                int idx;
                idx = addr_base + ww;
                if (idx >= 0 && idx < 4096)
                    u_amber.u_dmem.r_mem[idx] = sentinel;
            end
            run_cycles(800);
            if (expect_trap_flag) begin
                expect_trap(trap_cause, label);
                for (ww = 0; ww < 12; ww = ww + 1) begin
                    int idx;
                    idx = addr_base + ww;
                    if (idx >= 0 && idx < 4096 && u_amber.u_dmem.r_mem[idx] !== sentinel) begin
                        $display("FAIL (%s): cap store modified mem[%0d] despite trap", label, idx);
                        $fatal;
                    end
                end
                if (u_amber.u_regcr.r_cur[cr_dst] !== dst_cur) begin
                    $display("FAIL (%s): CR%0d.cur changed on trap", label, cr_dst);
                    $fatal;
                end
            end else begin
                expect_no_trap(label);
                if (u_amber.u_regcr.r_cur[cr_dst] !== (dst_cur - 48'd12)) begin
                    $display("FAIL (%s): CR%0d.cur=%0d expected %0d", label, cr_dst,
                             u_amber.u_regcr.r_cur[cr_dst], dst_cur - 48'd12);
                    $fatal;
                end
                expect_mem48(addr_base + 0, src_base, label);
                expect_mem48(addr_base + 2, src_len,  label);
                expect_mem48(addr_base + 4, src_cur,  label);
                expect_mem48(addr_base + 6, {24'd0, src_perms}, label);
                expect_mem48(addr_base + 8, {24'd0, src_attr},  label);
                expect_mem48(addr_base + 10, {47'd0, src_tag},  label);
            end
        end
    endtask

    task automatic exec_popur;
        input int dr_dst;
        input int cr_src;
        input [47:0] base;
        input [47:0] len;
        input [47:0] cur;
        input [23:0] perms;
        input [23:0] attr;
        input bit tag;
        input [23:0] mem_value;
        input bit expect_trap_flag;
        input [7:0] trap_cause;
        input [127:0] label;
        int addr;
        reg [23:0] sentinel;
        begin
            apply_reset();
            set_sr(`SR_IDX_LR, 48'd0);
            set_sr(`SR_IDX_PSTATE, 48'd0);
            set_cr(cr_src, base, len, cur, perms, attr, tag);
            set_gp(dr_dst, 24'h00BAD0);
            load_single_instr(enc_popur(dr_dst, cr_src));
            addr = cur;
            sentinel = 24'h00BEEF;
            if (addr >= 0 && addr < 4096)
                u_amber.u_dmem.r_mem[addr] = mem_value;
            run_cycles(320);
            if (expect_trap_flag) begin
                expect_trap(trap_cause, label);
                if (u_amber.u_reggp.r_gp[dr_dst] !== 24'h00BAD0) begin
                    $display("FAIL (%s): DR%0d changed despite trap", label, dr_dst);
                    $fatal;
                end
            end else begin
                expect_no_trap(label);
                if (u_amber.u_reggp.r_gp[dr_dst] !== mem_value) begin
                    $display("FAIL (%s): DR%0d=%h expected %h", label, dr_dst,
                             u_amber.u_reggp.r_gp[dr_dst], mem_value);
                    $fatal;
                end
                if (u_amber.u_regcr.r_cur[cr_src] !== (cur + 48'd1)) begin
                    $display("FAIL (%s): CR%0d.cur=%0d expected %0d", label, cr_src,
                             u_amber.u_regcr.r_cur[cr_src], cur + 48'd1);
                    $fatal;
                end
            end
        end
    endtask

    task automatic exec_popaur;
        input int cr_dst;
        input int cr_src;
        input [47:0] dst_base_init;
        input [47:0] dst_len_init;
        input [47:0] dst_cur_init;
        input [23:0] dst_perms_init;
        input [23:0] dst_attr_init;
        input bit dst_tag_init;
        input [47:0] src_base;
        input [47:0] src_len;
        input [47:0] src_cur;
        input [23:0] src_perms;
        input [23:0] src_attr;
        input bit src_tag;
        input [47:0] exp_base;
        input [47:0] exp_len;
        input [47:0] exp_cur;
        input [23:0] exp_perms;
        input [23:0] exp_attr;
        input bit exp_tag;
        input bit expect_trap_flag;
        input [7:0] trap_cause;
        input [127:0] label;
        int addr_base;
        begin
            apply_reset();
            set_sr(`SR_IDX_LR, 48'd0);
            set_sr(`SR_IDX_PSTATE, 48'd0);
            set_cr(cr_dst, dst_base_init, dst_len_init, dst_cur_init,
                   dst_perms_init, dst_attr_init, dst_tag_init);
            set_cr(cr_src, src_base, src_len, src_cur, src_perms, src_attr, src_tag);
            load_single_instr(enc_popaur(cr_dst, cr_src));
            addr_base = src_cur;
            store48(addr_base + 0, exp_base);
            store48(addr_base + 2, exp_len);
            store48(addr_base + 4, exp_cur);
            store48(addr_base + 6, {24'd0, exp_perms});
            store48(addr_base + 8, {24'd0, exp_attr});
            store48(addr_base + 10, {47'd0, exp_tag});
            run_cycles(800);
            if (expect_trap_flag) begin
                expect_trap(trap_cause, label);
                if (u_amber.u_regcr.r_base[cr_dst] !== dst_base_init) begin
                    $display("FAIL (%s): CR%0d.base changed on trap", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_len[cr_dst] !== dst_len_init) begin
                    $display("FAIL (%s): CR%0d.len changed on trap", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_cur[cr_dst] !== dst_cur_init) begin
                    $display("FAIL (%s): CR%0d.cur changed on trap", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_perms[cr_dst] !== dst_perms_init) begin
                    $display("FAIL (%s): CR%0d.perms changed on trap", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_attr[cr_dst] !== dst_attr_init) begin
                    $display("FAIL (%s): CR%0d.attr changed on trap", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_tag[cr_dst] !== dst_tag_init) begin
                    $display("FAIL (%s): CR%0d.tag changed on trap", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_cur[cr_src] !== src_cur) begin
                    $display("FAIL (%s): CR%0d.cur (source) changed on trap", label, cr_src);
                    $fatal;
                end
            end else begin
                expect_no_trap(label);
                if (u_amber.u_regcr.r_cur[cr_src] !== (src_cur + 48'd12)) begin
                    $display("FAIL (%s): CR%0d.cur=%0d expected %0d", label, cr_src,
                             u_amber.u_regcr.r_cur[cr_src], src_cur + 48'd12);
                    $fatal;
                end
                if (u_amber.u_regcr.r_base[cr_dst] !== exp_base) begin
                    $display("FAIL (%s): CR%0d.base mismatch", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_len[cr_dst] !== exp_len) begin
                    $display("FAIL (%s): CR%0d.len mismatch", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_cur[cr_dst] !== exp_cur) begin
                    $display("FAIL (%s): CR%0d.cur field mismatch", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_perms[cr_dst] !== exp_perms) begin
                    $display("FAIL (%s): CR%0d.perms mismatch", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_attr[cr_dst] !== exp_attr) begin
                    $display("FAIL (%s): CR%0d.attr mismatch", label, cr_dst);
                    $fatal;
                end
                if (u_amber.u_regcr.r_tag[cr_dst] !== exp_tag) begin
                    $display("FAIL (%s): CR%0d.tag mismatch", label, cr_dst);
                    $fatal;
                end
            end
        end
    endtask

    initial begin
        rst = 1'b0;
        run_cycles(1);

        // PUSHur success
        exec_pushur(0, 1, 48'd200, 48'd32, 48'd210,
                    24'd1 << `CR_PERM_W_BIT, 24'd0, 1'b1,
                    24'h00A5B6, 1'b0, 8'h00, "PUSHur ok");
        // PUSHur traps
        exec_pushur(0, 1, 48'd200, 48'd32, 48'd210,
                    24'd1 << `CR_PERM_W_BIT, 24'd0, 1'b0,
                    24'h001234, 1'b1, `PSTATE_CAUSE_CAP_TAG, "PUSHur tag");
        exec_pushur(0, 1, 48'd200, 48'd32, 48'd210,
                    24'd1 << `CR_PERM_W_BIT, 24'h000001, 1'b1,
                    24'h005678, 1'b1, `PSTATE_CAUSE_CAP_SEAL, "PUSHur seal");
        exec_pushur(0, 1, 48'd200, 48'd32, 48'd210,
                    24'd0, 24'd0, 1'b1,
                    24'h00BEEF, 1'b1, `PSTATE_CAUSE_CAP_PERM, "PUSHur perm");
        exec_pushur(0, 1, 48'd120, 48'd16, 48'd120,
                    24'd1 << `CR_PERM_W_BIT, 24'd0, 1'b1,
                    24'h0000AA, 1'b1, `PSTATE_CAUSE_CAP_OOB, "PUSHur underflow");

        // PUSHAur success
        exec_pushaur(0, 2,
                     48'd400, 48'd80, 48'd420,
                     (24'd1 << `CR_PERM_W_BIT) | (24'd1 << `CR_PERM_SC_BIT), 24'd0, 1'b1,
                     48'h000123_456789, 48'd96, 48'h000123_4567AA,
                     24'h00AA55, 24'h000055, 1'b1,
                     1'b0, 8'h00, "PUSHAur ok");
        // PUSHAur traps
        exec_pushaur(0, 2,
                     48'd400, 48'd80, 48'd420,
                     (24'd1 << `CR_PERM_W_BIT) | (24'd1 << `CR_PERM_SC_BIT), 24'd0, 1'b0,
                     48'h000123_456789, 48'd96, 48'h000123_4567AA,
                     24'h00AA55, 24'h000055, 1'b1,
                     1'b1, `PSTATE_CAUSE_CAP_TAG, "PUSHAur tag");
        exec_pushaur(0, 2,
                     48'd400, 48'd80, 48'd420,
                     (24'd1 << `CR_PERM_W_BIT) | (24'd1 << `CR_PERM_SC_BIT), 24'h000001, 1'b1,
                     48'h000123_456789, 48'd96, 48'h000123_4567AA,
                     24'h00AA55, 24'h000055, 1'b1,
                     1'b1, `PSTATE_CAUSE_CAP_SEAL, "PUSHAur seal");
        exec_pushaur(0, 2,
                     48'd400, 48'd80, 48'd420,
                     24'd1 << `CR_PERM_W_BIT, 24'd0, 1'b1,
                     48'h000123_456789, 48'd96, 48'h000123_4567AA,
                     24'h00AA55, 24'h000055, 1'b1,
                     1'b1, `PSTATE_CAUSE_CAP_PERM, "PUSHAur perm");
        exec_pushaur(0, 2,
                     48'd400, 48'd80, 48'd405,
                     (24'd1 << `CR_PERM_W_BIT) | (24'd1 << `CR_PERM_SC_BIT), 24'd0, 1'b1,
                     48'h000123_456789, 48'd96, 48'h000123_4567AA,
                     24'h00AA55, 24'h000055, 1'b1,
                     1'b1, `PSTATE_CAUSE_CAP_OOB, "PUSHAur underflow");

        // POPur success
        exec_popur(3, 0, 48'd200, 48'd32, 48'd209,
                   (24'd1 << `CR_PERM_R_BIT), 24'd0, 1'b1,
                   24'h00CC77, 1'b0, 8'h00, "POPur ok");
        // POPur traps
        exec_popur(3, 0, 48'd200, 48'd32, 48'd209,
                   (24'd1 << `CR_PERM_R_BIT), 24'd0, 1'b0,
                   24'h00CC77, 1'b1, `PSTATE_CAUSE_CAP_TAG, "POPur tag");
        exec_popur(3, 0, 48'd200, 48'd32, 48'd209,
                   (24'd1 << `CR_PERM_R_BIT), 24'h000001, 1'b1,
                   24'h00CC77, 1'b1, `PSTATE_CAUSE_CAP_SEAL, "POPur seal");
        exec_popur(3, 0, 48'd200, 48'd32, 48'd209,
                   24'd0, 24'd0, 1'b1,
                   24'h00CC77, 1'b1, `PSTATE_CAUSE_CAP_PERM, "POPur perm");
        exec_popur(3, 0, 48'd200, 48'd32, 48'd232,
                   (24'd1 << `CR_PERM_R_BIT), 24'd0, 1'b1,
                   24'h00CC77, 1'b1, `PSTATE_CAUSE_CAP_OOB, "POPur empty");

        // POPAur success
        exec_popaur(1, 0,
                    48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b0,
                    48'd600, 48'd80, 48'd612,
                    (24'd1 << `CR_PERM_LC_BIT), 24'd0, 1'b1,
                    48'h000ABC_DEF012, 48'd64, 48'h000ABC_DEF034,
                    24'h00CC55, 24'h0000AA, 1'b1,
                    1'b0, 8'h00, "POPAur ok");
        // POPAur traps
        exec_popaur(1, 0,
                    48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b0,
                    48'd600, 48'd80, 48'd612,
                    (24'd1 << `CR_PERM_LC_BIT), 24'd0, 1'b0,
                    48'h000ABC_DEF012, 48'd64, 48'h000ABC_DEF034,
                    24'h00CC55, 24'h0000AA, 1'b1,
                    1'b1, `PSTATE_CAUSE_CAP_TAG, "POPAur tag");
        exec_popaur(1, 0,
                    48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b0,
                    48'd600, 48'd80, 48'd612,
                    (24'd1 << `CR_PERM_LC_BIT), 24'h000001, 1'b1,
                    48'h000ABC_DEF012, 48'd64, 48'h000ABC_DEF034,
                    24'h00CC55, 24'h0000AA, 1'b1,
                    1'b1, `PSTATE_CAUSE_CAP_SEAL, "POPAur seal");
        exec_popaur(1, 0,
                    48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b0,
                    48'd600, 48'd80, 48'd612,
                    24'd0, 24'd0, 1'b1,
                    48'h000ABC_DEF012, 48'd64, 48'h000ABC_DEF034,
                    24'h00CC55, 24'h0000AA, 1'b1,
                    1'b1, `PSTATE_CAUSE_CAP_PERM, "POPAur perm");
        exec_popaur(1, 0,
                    48'd0, 48'd0, 48'd0, 24'd0, 24'd0, 1'b0,
                    48'd600, 48'd80, 48'd680,
                    (24'd1 << `CR_PERM_LC_BIT), 24'd0, 1'b1,
                    48'h000ABC_DEF012, 48'd64, 48'h000ABC_DEF034,
                    24'h00CC55, 24'h0000AA, 1'b1,
                    1'b1, `PSTATE_CAUSE_CAP_OOB, "POPAur empty");

        $display("opclass7_tb PASS");
        $finish;
    end
endmodule
