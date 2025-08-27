# interface-lygo

## Overview

- **Type**: Full-duplex LVDS interconnect
- **Purpose**: Standard connection between modules and [board-archon](../../boards/archon/archon.md)
- **Clocking**: 2× clock per port

## Physical

- Signaling: `rx- rx+ / tx- tx+` per lane
- Connectors: 8 slots on [board-archon](../../boards/archon/archon.md)
- Aux lines: spare single-ended pins can carry module JTAG (TCK, TMS, TDI, TDO, TRST)

## Performance

- Prototype 1 frequency: 25 MHz
- Bandwidth per lane: 1 lane = 1 bit, So 25Mbit per lane (prototype-1)
- Low latency, suitable for synchronous game workloads

## Protocol

- shared address space: (48 bit addresses) each module has 36 bit addressable, 4 bits for a max of 16 modules and 2 bits for sub-module (dedicated links) leaves 6 bits spare
- Data framing: custom lightweight packet format (to be defined)
- Control: implicit through [unit-kairos](../../units/kairos/kairos.md) firmware
- Error correction: planned for future revisions

## Roadmap

- Increase link speed beyond 25 MHz
- Possible high-speed serial encoding
