# interface-lygo

## Overview
- **Type**: Full-duplex LVDS interconnect
- **Purpose**: Standard connection between modules and board-archon
- **Clocking**: 2× clock per port

## Physical
- Signaling: `rx- rx+ / tx- tx+` per lane
- Connectors: 8 ports on board-archon

## Performance
- Prototype 1 frequency: 25 MHz
- Bandwidth per lane: TBD (depends on framing width)
- Low latency, suitable for synchronous game workloads

## Protocol
- Data framing: custom lightweight packet format (to be defined)
- Control: implicit through unit-kairos firmware
- Error correction: planned for future revisions

## Roadmap
- Increase link speed beyond 25 MHz
- Possible high-speed serial encoding
