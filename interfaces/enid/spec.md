# enid OpenFabric (OpenBus-style) Specification

## Goals

- Point-to-point, full-duplex LVDS links aggregated by a non-blocking star switch.
- Packetized transactions (memory, messages) with backpressure and reliability.
- Small, FPGA-friendly implementation at 100–400 MHz prototype speeds.
- Strict layering: PHY (LVDS), LINK (flits+credits), EP (transactions).

## Addressing

- Global 48-bit address: `[47:44] dest_mod | [43:42] dest_sub | [41:6] offset | [5:0] reserved`.
- Source ID in header: `[src_mod:4][src_sub:2]` for diagnostics and response routing.
- Max 16 modules, 4 sub-endpoints per module (can be expanded later).

## Layers

- PHY: source-synchronous LVDS, DDR per lane. 2, 4 or 6 lanes per port. Forwarded clock per port.
- LINK: flitized framing with credits; cut-through capable; CRC-16 over header and CRC-32 over payload (optional in proto-1).
- EP (Endpoint): memory and message transactions; maps to local fabric (e.g., AXI-lite/Wishbone/amber-fabric).

## Link Interface (FPGA-internal)

Clocking per direction; either use forwarded clock from PHY or a local recovered clock. Signals per direction:

- l*_clk: link clock for that direction.
- l*_valid: flit valid.
- l*_ready: flit accepted (creditless mode) or always 1 in credit mode.
- l*_flit[LINK_W-1:0]: flit payload.
- l*_sof, l*_eof: start/end of packet markers.
- l*_vc[1:0]: virtual channel (0=ctrl, 1=data, others reserved).
- l*_credit[CR_W-1:0]: credit return side-band (if credit-based mode enabled).

Default flow control is credit-based. A receiver issues N credits (its FIFO depth). Each accepted flit consumes 1 credit. Credits are returned as the receiver frees FIFO entries and are encoded as deltas on l*_credit.

## Packet Format (on LINK flits)

Header (fixed 64-bit logical header, can be segmented into flits):
- ver[3:0], type[3:0] (0=mem,1=msg,2=ack,3=nack)
- vc[1:0], flags[5:0] (prio, cut-through allowed, etc.)
- dest_mod[3:0], dest_sub[1:0]
- src_mod[3:0], src_sub[1:0]
- length[15:0] (bytes for payload)
- seq[7:0]
- hdr_crc16[15:0]

Type=mem payload options:
- op[1:0] (0=RD,1=WR), reserved[5:0]
- addr[35:0]
- For WR: payload data follows; For RD: no payload.

Type=msg payload options:
- msg_class[7:0], msg_tag[7:0]
- payload data follows (length bytes).

Tail:
- pay_crc32[31:0] (optional in proto-1; enable for debug/integration).

Ordering: in-order per {src,dest,vc,seq}. Switch must preserve flit order on a given output; endpoint reassembles by seq.

## Endpoint Transaction Interface (EP)

Two decoupled channels with ready/valid handshakes.

Request channel (from local fabric into EP):
- req_valid, req_ready
- req_type[1:0] (0=mem,1=msg)
- req_mem_op[1:0] (0=RD,1=WR)
- req_dest_mod[3:0], req_dest_sub[1:0]
- req_addr[35:0]
- req_len[15:0]
- For WR streams: req_wvalid, req_wready, req_wdata[DATA_W-1:0], req_wlast

Response channel (from EP to local fabric):
- rsp_valid, rsp_ready
- rsp_status[1:0] (0=OK,1=ERR,2=RETRY)
- rsp_len[15:0]
- For RD/MSG: rsp_rvalid, rsp_rready, rsp_rdata[DATA_W-1:0], rsp_rlast

This EP can be trivially bridged to AXI-lite, Wishbone, or a custom amber-fabric.

## Switch Architecture

- N-port input-queued crossbar with per-output round-robin arbitration.
- Each ingress: small per-VC FIFO; parses header; determines egress port via routing table indexed by dest_mod.
- Cut-through: upon header parse and egress grant, forward flits immediately; backpressure via credits or ready.
- Parallelism: all ports operate concurrently; contention only on shared outputs.
- Optional VOQs: for stronger HoL blocking avoidance, upgrade ingress to per-egress FIFOs (can be a later step).

Routing table:
- route[0..15] -> egress_port_id (4 bits) and optional strict priority per destination.
- Broadcast (reserved dest_mod 0xF) can be disabled initially.

## Reliability

- Header CRC mandatory; payload CRC optional (proto-1 can disable to save area).
- On CRC error, receiver drops packet and issues NACK with {src,dest,seq}; endpoint performs retry if upper layer requires.
- Control VC is lossless; data VC best-effort unless payload CRC+retry is enabled.

## Clocks and CDC

- Per-port Rx/Tx are clocked by PHY forwarded clocks.
- Ingress includes dual-clock FIFO to core switch clock domain.
- Egress includes dual-clock FIFO from core to Tx domain.

## Parameterization

- LINK_W: width of flit in bits after deserialization (e.g., 16/32 depending on lanes and gear).
- DATA_W: local EP data width (e.g., 24/32).
- N_PORTS: switch port count (e.g., 8).
- CR_W: credit counter width (e.g., 4..8 depending on FIFO depth).

## Mapping to Current Repo

- processors/iris/src uses an AXI-like local interconnect; keep that local. Iris connects to enid via the EP.
- units/ada/ada.md already sketches EP/LINK/PHY: this spec fills in signals, flow control, and packetization.
- Switch resides on board-ivy; each module integrates identical enid PHY+LINK+EP IP, parameterized by module ID.

## Why not per-module bespoke SerDes?

- Consistency: a common PHY+LINK avoids incompatibilities and halves validation matrix.
- Reuse: same core across iris, nova, lyra, etc., with only parameters changed.
- Modularity: endpoint is where module-specific behavior lives (address mapping, services), not the link itself.

---

Proto-1 recommendation: 2 lanes per direction, DDR, LINK_W=16, credit-based flow control with depth=8, CRC-16 header only, cut-through enabled, two VCs (ctrl/data).
