# interface-lygo

## Overview
- **Type**: Full-duplex LVDS interconnect
- **Purpose**: Standard connection between modules and [board-archon](../../boards/archon/archon.md)
- **Clocking**: 2× clock per port

## Physical
- Signaling: `rx- rx+ / tx- tx+` per lane
- Connectors: 8 ports on [board-archon](../../boards/archon/archon.md)
- Aux lines: spare single-ended pins can carry module JTAG (TCK, TMS, TDI, TDO, TRST)

## Performance
- Prototype 1 frequency: 25 MHz
- Bandwidth per lane: TBD (depends on framing width)
- Low latency, suitable for synchronous game workloads

## Protocol
- Data framing: custom lightweight packet format (to be defined)
- Control: implicit through [unit-kairos](../../units/kairos/kairos.md) firmware
- Error correction: planned for future revisions

## Roadmap
- Increase link speed beyond 25 MHz
- Possible high-speed serial encoding
