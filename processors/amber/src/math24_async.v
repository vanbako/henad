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
    wire [3:0] op = iw_math_ctrl[4:1];

    // Internal state
    reg  busy;
    reg  ready;
    reg  div0;
    reg  [2:0] wstep; // writeback sequencing: 0 idle, 1..N write regs
    reg  [47:0] prod;
    reg  [23:0] quot;
    reg  [23:0] rem;
    reg  [23:0] root;
    reg  [3:0]  latched_op;
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
                        4'h0: ow_csr_wdata = prod[23:0];        // MULU low
                        4'h1: ow_csr_wdata = quot;               // DIVU q
                        4'h2: ow_csr_wdata = rem;                // MODU remainder
                        4'h3: ow_csr_wdata = root;               // SQRTU
                        4'h4: ow_csr_wdata = prod[23:0];        // MULS low
                        4'h5: ow_csr_wdata = quot;               // DIVS q
                        4'h6: ow_csr_wdata = rem;                // MODS r
                        4'h7: ow_csr_wdata = root;               // ABS_S uses root as temp
                        4'h8: ow_csr_wdata = quot;               // MIN_U uses quot as temp
                        4'h9: ow_csr_wdata = quot;               // MAX_U
                        4'hA: ow_csr_wdata = quot;               // MIN_S
                        4'hB: ow_csr_wdata = quot;               // MAX_S
                        4'hC: ow_csr_wdata = rem;                // CLAMP_U uses rem as temp
                        4'hD: ow_csr_wdata = rem;                // CLAMP_S
                        default: ow_csr_wdata = {(`HBIT_DATA+1){1'b0}};
                    endcase
                end
                3'd4: begin
                    // Write RES1
                    ow_csr_waddr = `CSR_IDX_MATH_RES1;
                    case (latched_op)
                        4'h0: ow_csr_wdata = prod[47:24];       // MULU high
                        4'h1: ow_csr_wdata = rem;               // DIVU remainder
                        4'h4: ow_csr_wdata = prod[47:24];       // MULS high
                        4'h5: ow_csr_wdata = rem;               // DIVS remainder
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
            latched_op <= 3'd0;
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
                    4'h0: begin // MULU
                        prod <= iw_math_opa * iw_math_opb;
                        quot <= 24'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    4'h1: begin // DIVU
                        if (iw_math_opb == 24'd0) begin
                            div0 <= 1'b1; quot <= 24'd0; rem  <= 24'd0;
                        end else begin
                            quot <= iw_math_opa / iw_math_opb;
                            rem  <= iw_math_opa % iw_math_opb;
                        end
                        prod <= 48'd0; root <= 24'd0;
                    end
                    4'h2: begin // MODU
                        if (iw_math_opb == 24'd0) begin
                            div0 <= 1'b1; rem  <= 24'd0;
                        end else begin
                            rem  <= iw_math_opa % iw_math_opb;
                        end
                        prod <= 48'd0; quot <= 24'd0; root <= 24'd0;
                    end
                    4'h3: begin // SQRTU
                        root <= isqrt24(iw_math_opa);
                        prod <= 48'd0; quot <= 24'd0; rem  <= 24'd0;
                    end
                    4'h4: begin // MULS
                        prod <= $signed(iw_math_opa) * $signed(iw_math_opb);
                        quot <= 24'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    4'h5: begin // DIVS
                        if (iw_math_opb == 24'd0) begin
                            div0 <= 1'b1; quot <= 24'd0; rem <= 24'd0;
                        end else begin
                            quot <= $signed(iw_math_opa) / $signed(iw_math_opb);
                            rem  <= $signed(iw_math_opa) % $signed(iw_math_opb);
                        end
                        prod <= 48'd0; root <= 24'd0;
                    end
                    4'h6: begin // MODS
                        if (iw_math_opb == 24'd0) begin
                            div0 <= 1'b1; rem <= 24'd0;
                        end else begin
                            rem  <= $signed(iw_math_opa) % $signed(iw_math_opb);
                        end
                        prod <= 48'd0; quot <= 24'd0; root <= 24'd0;
                    end
                    4'h7: begin // ABS_S (result into root)
                        root <= ($signed(iw_math_opa) < 0) ? -$signed(iw_math_opa) : iw_math_opa;
                        prod <= 48'd0; quot <= 24'd0; rem  <= 24'd0;
                    end
                    4'h8: begin // MIN_U (result into quot)
                        quot <= (iw_math_opa < iw_math_opb) ? iw_math_opa : iw_math_opb;
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    4'h9: begin // MAX_U (result into quot)
                        quot <= (iw_math_opa > iw_math_opb) ? iw_math_opa : iw_math_opb;
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    4'hA: begin // MIN_S (result into quot)
                        quot <= ($signed(iw_math_opa) < $signed(iw_math_opb)) ? iw_math_opa : iw_math_opb;
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    4'hB: begin // MAX_S (result into quot)
                        quot <= ($signed(iw_math_opa) > $signed(iw_math_opb)) ? iw_math_opa : iw_math_opb;
                        prod <= 48'd0; rem  <= 24'd0; root <= 24'd0;
                    end
                    4'hC: begin // CLAMP_U (rem holds result)
                        // clamp OPA to [OPC, OPB]
                        if (iw_math_opa < iw_math_opc)      rem <= iw_math_opc;
                        else if (iw_math_opa > iw_math_opb) rem <= iw_math_opb;
                        else                                rem <= iw_math_opa;
                        prod <= 48'd0; quot <= 24'd0; root <= 24'd0;
                    end
                    4'hD: begin // CLAMP_S (rem holds result)
                        // clamp OPA to [OPC, OPB] signed
                        if ($signed(iw_math_opa) < $signed(iw_math_opc))      rem <= iw_math_opc;
                        else if ($signed(iw_math_opa) > $signed(iw_math_opb)) rem <= iw_math_opb;
                        else                                                  rem <= iw_math_opa;
                        prod <= 48'd0; quot <= 24'd0; root <= 24'd0;
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
