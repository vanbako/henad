`include "src/sizes.vh"
`include "src/csr.vh"

module math24_async(
    input  wire                iw_clk,
    input  wire                iw_rst,
    // Tapped CSR values for control/operands
    input  wire [`HBIT_DATA:0] iw_math_ctrl,
    input  wire [`HBIT_DATA:0] iw_math_opa,
    input  wire [`HBIT_DATA:0] iw_math_opb,
    input  wire [`HBIT_DATA:0] iw_math_opc,
    // Write-back port into CSR file
    output reg                 ow_csr_wen,
    output reg  [`HBIT_TGT_CSR:0] ow_csr_waddr,
    output reg  [`HBIT_DATA:0] ow_csr_wdata
);
    // Decode control
    wire start = iw_math_ctrl[0];
    // Extend OP to 5 bits to allow more operations
    wire [4:0] op = iw_math_ctrl[5:1];

    // Internal state
    reg  busy;
    reg  ready;
    reg  div0;
    reg  [2:0] wstep; // writeback sequencing: 0 idle, 1..N write regs
    reg  [47:0] prod;
    reg  [23:0] quot;
    reg  [23:0] rem;
    reg  [23:0] root;
    reg  [4:0]  latched_op;
    reg  [23:0] opa_l;
    reg  [23:0] opb_l;

    // Combinational integer sqrt (non-restoring) for 24-bit input
    function automatic [23:0] isqrt24;
        input [23:0] x;
        reg [11:0] r;
        reg [11:0] t;
        integer k;
        begin
            r = 12'd0;
            for (k = 11; k >= 0; k = k - 1) begin
                t = r | (12'd1 << k);
                if ((t * t) <= x)
                    r = t;
            end
            isqrt24 = {12'd0, r};
        end
    endfunction

    // 12-bit lane-wise helpers (wrap-around per lane)
    function automatic [23:0] add12_diad;
        input [23:0] a;
        input [23:0] b;
        reg [11:0] al, ah, bl, bh;
        reg [11:0] sl, sh;
        begin
            al = a[11:0];  ah = a[23:12];
            bl = b[11:0];  bh = b[23:12];
            sl = (al + bl) & 12'hFFF;
            sh = (ah + bh) & 12'hFFF;
            add12_diad = {sh, sl};
        end
    endfunction

    function automatic [23:0] sub12_diad;
        input [23:0] a;
        input [23:0] b;
        reg [11:0] al, ah, bl, bh;
        reg [11:0] rl, rh;
        begin
            al = a[11:0];  ah = a[23:12];
            bl = b[11:0];  bh = b[23:12];
            rl = (al - bl) & 12'hFFF;
            rh = (ah - bh) & 12'hFFF;
            sub12_diad = {rh, rl};
        end
    endfunction

    function automatic [23:0] neg12_diad;
        input [23:0] a;
        reg [11:0] al, ah;
        reg [11:0] nl, nh;
        begin
            al = a[11:0];  ah = a[23:12];
            nl = (~al + 12'd1) & 12'hFFF;
            nh = (~ah + 12'd1) & 12'hFFF;
            neg12_diad = {nh, nl};
        end
    endfunction

    function automatic [23:0] mul12_diad;
        input [23:0] a;
        input [23:0] b;
        reg [11:0] al, ah, bl, bh;
        reg [11:0] pl, ph;
        begin
            al = a[11:0];  ah = a[23:12];
            bl = b[11:0];  bh = b[23:12];
            pl = (al * bl) & 12'hFFF;
            ph = (ah * bh) & 12'hFFF;
            mul12_diad = {ph, pl};
        end
    endfunction

    function automatic [11:0] isqrt12;
        input [11:0] x;
        reg [5:0] r;
        reg [5:0] t;
        integer k;
        begin
            r = 6'd0;
            for (k = 5; k >= 0; k = k - 1) begin
                t = r | (6'd1 << k);
                if ((t * t) <= x)
                    r = t;
            end
            isqrt12 = {6'd0, r};
        end
    endfunction

    // Default outputs
    always @* begin
        ow_csr_wen   = 1'b0;
        ow_csr_waddr = {(`HBIT_TGT_CSR+1){1'b0}};
        ow_csr_wdata = {(`HBIT_DATA+1){1'b0}};
        if (wstep != 3'd0) begin
            ow_csr_wen = 1'b1;
            case (wstep)
                3'd1: begin
                    // Clear START bit in CTRL to ack
                    ow_csr_waddr = `CSR_IDX_MATH_CTRL;
                    ow_csr_wdata = {iw_math_ctrl[`HBIT_DATA:1], 1'b0};
                end
                3'd2: begin
                    // Set STATUS: normally BUSY, but if div0 already known, mark READY immediately
                    ow_csr_waddr = `CSR_IDX_MATH_STATUS;
                    ow_csr_wdata = div0 ? {21'd0, 1'b1, 1'b0, 1'b1}
                                         : {21'd0, 1'b0, 1'b1, 1'b0};
                end
                3'd3: begin
                    // Write RES0
                    ow_csr_waddr = `CSR_IDX_MATH_RES0;
                    case (latched_op)
                        5'h00: ow_csr_wdata = prod[23:0];        // MULU low
                        5'h01: ow_csr_wdata = quot;               // DIVU q
                        5'h02: ow_csr_wdata = rem;                // MODU remainder
                        5'h03: ow_csr_wdata = root;               // SQRTU
                        5'h04: ow_csr_wdata = prod[23:0];        // MULS low
                        5'h05: ow_csr_wdata = quot;               // DIVS q
                        5'h06: ow_csr_wdata = rem;                // MODS r
                        5'h07: ow_csr_wdata = root;               // ABS_S uses root as temp
                        5'h08: ow_csr_wdata = quot;               // MIN_U uses quot as temp
                        5'h09: ow_csr_wdata = quot;               // MAX_U
                        5'h0A: ow_csr_wdata = quot;               // MIN_S
                        5'h0B: ow_csr_wdata = quot;               // MAX_S
                        5'h0C: ow_csr_wdata = rem;                // CLAMP_U uses rem as temp
                        5'h0D: ow_csr_wdata = rem;                // CLAMP_S
                        5'h0E: ow_csr_wdata = quot;               // ADD24 result in quot
                        5'h0F: ow_csr_wdata = quot;               // SUB24 result in quot
                        5'h10: ow_csr_wdata = quot;               // NEG24 result in quot
                        5'h11: ow_csr_wdata = quot;               // ADD12 diad result in quot
                        5'h12: ow_csr_wdata = quot;               // SUB12 diad result in quot
                        5'h13: ow_csr_wdata = quot;               // NEG12 diad result in quot
                        5'h14: ow_csr_wdata = quot;               // MUL12 diad result (lane-wise, 12-bit wrap)
                        5'h15: ow_csr_wdata = quot;               // DIV12 diad quotient
                        5'h16: ow_csr_wdata = rem;                // MOD12 diad remainder
                        5'h17: ow_csr_wdata = root;               // SQRT12 diad
                        5'h18: ow_csr_wdata = root;               // ABS12_S diad
                        5'h19: ow_csr_wdata = quot;               // MIN12_U diad
                        5'h1A: ow_csr_wdata = quot;               // MAX12_U diad
                        5'h1B: ow_csr_wdata = quot;               // MIN12_S diad
                        5'h1C: ow_csr_wdata = quot;               // MAX12_S diad
                        5'h1D: ow_csr_wdata = rem;                // CLAMP12_U diad
                        5'h1E: ow_csr_wdata = rem;                // CLAMP12_S diad
                        default: ow_csr_wdata = {(`HBIT_DATA+1){1'b0}};
                    endcase
                end
                3'd4: begin
                    // Write RES1
                    ow_csr_waddr = `CSR_IDX_MATH_RES1;
                    case (latched_op)
                        5'h00: ow_csr_wdata = prod[47:24];       // MULU high
                        5'h01: ow_csr_wdata = rem;               // DIVU remainder
                        5'h04: ow_csr_wdata = prod[47:24];       // MULS high
                        5'h05: ow_csr_wdata = rem;               // DIVS remainder
                        5'h15: ow_csr_wdata = rem;               // DIV12 diad remainder
                        default: ow_csr_wdata = {(`HBIT_DATA+1){1'b0}};
                    endcase
                end
                3'd5: begin
                    // Update STATUS: READY=1, BUSY=0, DIV0 flag if any
                    ow_csr_waddr = `CSR_IDX_MATH_STATUS;
                    ow_csr_wdata = {21'd0, div0, 1'b0, 1'b1};
                end
                default: begin
                    ow_csr_wen   = 1'b0;
                end
            endcase
        end
    end

    // Sequential control
    always @(posedge iw_clk or posedge iw_rst) begin
        if (iw_rst) begin
            busy       <= 1'b0;
            ready      <= 1'b0;
            div0       <= 1'b0;
            wstep      <= 3'd0;
            prod       <= 48'd0;
            quot       <= 24'd0;
            rem        <= 24'd0;
            root       <= 24'd0;
            latched_op <= 5'd0;
            opa_l      <= 24'd0;
            opb_l      <= 24'd0;
        end else begin
            if (wstep != 3'd0) begin
                // Advance writeback sequence
                if (wstep == 3'd5) begin
                    wstep <= 3'd0; // done
                    busy  <= 1'b0;
                    ready <= 1'b1;
                end else begin
                    wstep <= wstep + 3'd1;
                end
            end else if (start && !busy) begin
                // Latch operation and operands on start
                busy       <= 1'b1;
                ready      <= 1'b0;
                div0       <= 1'b0;
            latched_op <= op;
            opa_l      <= iw_math_opa;
            opb_l      <= iw_math_opb;
            // Compute results (1-cycle latency overall via writeback pipelining)
                case (op)
                    5'h00: begin // MULU
                        prod <= iw_math_opa * iw_math_opb;
                        quot <= 24'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    5'h01: begin // DIVU
                        if (iw_math_opb == 24'd0) begin
                            div0 <= 1'b1; quot <= 24'd0; rem  <= 24'd0;
                        end else begin
                            quot <= iw_math_opa / iw_math_opb;
                            rem  <= iw_math_opa % iw_math_opb;
                        end
                        prod <= 48'd0; root <= 24'd0;
                    end
                    5'h02: begin // MODU
                        if (iw_math_opb == 24'd0) begin
                            div0 <= 1'b1; rem  <= 24'd0;
                        end else begin
                            rem  <= iw_math_opa % iw_math_opb;
                        end
                        prod <= 48'd0; quot <= 24'd0; root <= 24'd0;
                    end
                    5'h03: begin // SQRTU
                        root <= isqrt24(iw_math_opa);
                        prod <= 48'd0; quot <= 24'd0; rem  <= 24'd0;
                    end
                    5'h04: begin // MULS
                        prod <= $signed(iw_math_opa) * $signed(iw_math_opb);
                        quot <= 24'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    5'h05: begin // DIVS
                        if (iw_math_opb == 24'd0) begin
                            div0 <= 1'b1; quot <= 24'd0; rem <= 24'd0;
                        end else begin
                            quot <= $signed(iw_math_opa) / $signed(iw_math_opb);
                            rem  <= $signed(iw_math_opa) % $signed(iw_math_opb);
                        end
                        prod <= 48'd0; root <= 24'd0;
                    end
                    5'h06: begin // MODS
                        if (iw_math_opb == 24'd0) begin
                            div0 <= 1'b1; rem <= 24'd0;
                        end else begin
                            rem  <= $signed(iw_math_opa) % $signed(iw_math_opb);
                        end
                        prod <= 48'd0; quot <= 24'd0; root <= 24'd0;
                    end
                    5'h07: begin // ABS_S (result into root)
                        root <= ($signed(iw_math_opa) < 0) ? -$signed(iw_math_opa) : iw_math_opa;
                        prod <= 48'd0; quot <= 24'd0; rem  <= 24'd0;
                    end
                    5'h08: begin // MIN_U (result into quot)
                        quot <= (iw_math_opa < iw_math_opb) ? iw_math_opa : iw_math_opb;
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    5'h09: begin // MAX_U (result into quot)
                        quot <= (iw_math_opa > iw_math_opb) ? iw_math_opa : iw_math_opb;
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    5'h0A: begin // MIN_S (result into quot)
                        quot <= ($signed(iw_math_opa) < $signed(iw_math_opb)) ? iw_math_opa : iw_math_opb;
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    5'h0B: begin // MAX_S (result into quot)
                        quot <= ($signed(iw_math_opa) > $signed(iw_math_opb)) ? iw_math_opa : iw_math_opb;
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    5'h0C: begin // CLAMP_U (rem holds result)
                        // clamp OPA to [OPC, OPB]
                        if (iw_math_opa < iw_math_opc)      rem <= iw_math_opc;
                        else if (iw_math_opa > iw_math_opb) rem <= iw_math_opb;
                        else                                rem <= iw_math_opa;
                        prod <= 48'd0; quot <= 24'd0; root <= 24'd0;
                    end
                    5'h0D: begin // CLAMP_S (rem holds result)
                        // clamp OPA to [OPC, OPB] signed
                        if ($signed(iw_math_opa) < $signed(iw_math_opc))      rem <= iw_math_opc;
                        else if ($signed(iw_math_opa) > $signed(iw_math_opb)) rem <= iw_math_opb;
                        else                                                  rem <= iw_math_opa;
                        prod <= 48'd0; quot <= 24'd0; root <= 24'd0;
                    end
                    5'h0E: begin // ADD24 (wrap-around)
                        quot <= (iw_math_opa + iw_math_opb) & 24'hFFFFFF;
                        prod <= 48'd0; rem <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h0F: begin // SUB24 (wrap-around)
                        quot <= (iw_math_opa - iw_math_opb) & 24'hFFFFFF;
                        prod <= 48'd0; rem <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h10: begin // NEG24 (two's complement)
                        quot <= ((~iw_math_opa) + 24'd1) & 24'hFFFFFF;
                        prod <= 48'd0; rem <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h11: begin // ADD12 diad (lane-wise)
                        quot <= add12_diad(iw_math_opa, iw_math_opb);
                        prod <= 48'd0; rem <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h12: begin // SUB12 diad (lane-wise)
                        quot <= sub12_diad(iw_math_opa, iw_math_opb);
                        prod <= 48'd0; rem <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h13: begin // NEG12 diad (lane-wise)
                        quot <= neg12_diad(iw_math_opa);
                        prod <= 48'd0; rem <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h14: begin // MUL12 diad (lane-wise unsigned)
                        quot <= mul12_diad(iw_math_opa, iw_math_opb);
                        prod <= 48'd0; rem <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h15: begin // DIV12 diad (lane-wise unsigned)
                        reg [11:0] al, ah, bl, bh;
                        reg [11:0] ql, qh, rl, rh;
                        reg any_div0;
                        al = iw_math_opa[11:0];  ah = iw_math_opa[23:12];
                        bl = iw_math_opb[11:0];  bh = iw_math_opb[23:12];
                        any_div0 = 1'b0;
                        if (bl == 12'd0) begin ql = 12'd0; rl = 12'd0; any_div0 = 1'b1; end
                        else begin ql = (al / bl) & 12'hFFF; rl = (al % bl) & 12'hFFF; end
                        if (bh == 12'd0) begin qh = 12'd0; rh = 12'd0; any_div0 = 1'b1; end
                        else begin qh = (ah / bh) & 12'hFFF; rh = (ah % bh) & 12'hFFF; end
                        quot <= {qh, ql};
                        rem  <= {rh, rl};
                        div0 <= any_div0;
                        prod <= 48'd0; root <= 24'd0;
                    end
                    5'h16: begin // MOD12 diad (lane-wise unsigned)
                        reg [11:0] al, ah, bl, bh;
                        reg [11:0] rl, rh;
                        reg any_div0;
                        al = iw_math_opa[11:0];  ah = iw_math_opa[23:12];
                        bl = iw_math_opb[11:0];  bh = iw_math_opb[23:12];
                        any_div0 = 1'b0;
                        if (bl == 12'd0) begin rl = 12'd0; any_div0 = 1'b1; end
                        else begin rl = (al % bl) & 12'hFFF; end
                        if (bh == 12'd0) begin rh = 12'd0; any_div0 = 1'b1; end
                        else begin rh = (ah % bh) & 12'hFFF; end
                        quot <= 24'd0; rem <= {rh, rl}; prod <= 48'd0; root <= 24'd0; div0 <= any_div0;
                    end
                    5'h17: begin // SQRT12 diad (lane-wise unsigned)
                        reg [11:0] al, ah;
                        al = iw_math_opa[11:0];  ah = iw_math_opa[23:12];
                        root <= {isqrt12(ah), isqrt12(al)};
                        prod <= 48'd0; quot <= 24'd0; rem  <= 24'd0; div0 <= 1'b0;
                    end
                    5'h18: begin // ABS12_S diad (lane-wise)
                        reg [11:0] al, ah;
                        reg [11:0] nl, nh;
                        al = iw_math_opa[11:0];  ah = iw_math_opa[23:12];
                        nl = al[11] ? ((~al + 12'd1) & 12'hFFF) : al;
                        nh = ah[11] ? ((~ah + 12'd1) & 12'hFFF) : ah;
                        root <= {nh, nl};
                        prod <= 48'd0; quot <= 24'd0; rem  <= 24'd0; div0 <= 1'b0;
                    end
                    5'h19: begin // MIN12_U diad
                        reg [11:0] al, ah, bl, bh;
                        reg [11:0] rl, rh;
                        al = iw_math_opa[11:0];  ah = iw_math_opa[23:12];
                        bl = iw_math_opb[11:0];  bh = iw_math_opb[23:12];
                        rl = (al < bl) ? al : bl;
                        rh = (ah < bh) ? ah : bh;
                        quot <= {rh, rl};
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h1A: begin // MAX12_U diad
                        reg [11:0] al, ah, bl, bh;
                        reg [11:0] rl, rh;
                        al = iw_math_opa[11:0];  ah = iw_math_opa[23:12];
                        bl = iw_math_opb[11:0];  bh = iw_math_opb[23:12];
                        rl = (al > bl) ? al : bl;
                        rh = (ah > bh) ? ah : bh;
                        quot <= {rh, rl};
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h1B: begin // MIN12_S diad
                        reg  signed [11:0] al, ah, bl, bh;
                        reg  signed [11:0] rl, rh;
                        al = iw_math_opa[11:0];  ah = iw_math_opa[23:12];
                        bl = iw_math_opb[11:0];  bh = iw_math_opb[23:12];
                        rl = (al < bl) ? al : bl;
                        rh = (ah < bh) ? ah : bh;
                        quot <= {rh, rl};
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h1C: begin // MAX12_S diad
                        reg  signed [11:0] al, ah, bl, bh;
                        reg  signed [11:0] rl, rh;
                        al = iw_math_opa[11:0];  ah = iw_math_opa[23:12];
                        bl = iw_math_opb[11:0];  bh = iw_math_opb[23:12];
                        rl = (al > bl) ? al : bl;
                        rh = (ah > bh) ? ah : bh;
                        quot <= {rh, rl};
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h1D: begin // CLAMP12_U diad
                        reg [11:0] al, ah, bl, bh, cl, ch;
                        reg [11:0] rl, rh;
                        al = iw_math_opa[11:0];  ah = iw_math_opa[23:12];
                        bl = iw_math_opb[11:0];  bh = iw_math_opb[23:12]; // max
                        cl = iw_math_opc[11:0];  ch = iw_math_opc[23:12]; // min
                        // clamp per lane unsigned
                        rl = (al < cl) ? cl : ((al > bl) ? bl : al);
                        rh = (ah < ch) ? ch : ((ah > bh) ? bh : ah);
                        rem <= {rh, rl};
                        prod <= 48'd0; quot <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    5'h1E: begin // CLAMP12_S diad
                        reg  signed [11:0] al, ah, bl, bh, cl, ch;
                        reg  signed [11:0] rl, rh;
                        al = iw_math_opa[11:0];  ah = iw_math_opa[23:12];
                        bl = iw_math_opb[11:0];  bh = iw_math_opb[23:12]; // max
                        cl = iw_math_opc[11:0];  ch = iw_math_opc[23:12]; // min
                        // clamp per lane signed
                        rl = (al < cl) ? cl : ((al > bl) ? bl : al);
                        rh = (ah < ch) ? ch : ((ah > bh) ? bh : ah);
                        rem <= {rh, rl};
                        prod <= 48'd0; quot <= 24'd0; root <= 24'd0; div0 <= 1'b0;
                    end
                    default: begin
                        prod <= 48'd0; quot <= 24'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                endcase
                // Begin writeback sequence next cycle
                wstep <= 3'd1;
            end else begin
                // Idle
                ready <= ready; // hold
            end
        end
    end
endmodule
