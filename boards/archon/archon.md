# board-archon

## Overview

- **Role**: Direct lygos connections, temperature and fan control
- **Core Components**:
  - [unit-kairos](../../units/kairos/kairos.md)
  - Fan connector(s)

## Features

- Single JTAG connector with switchable access to module JTAGs

## Physical

- Power: 24V input
- Cooling: 1× fan connectors
- 8× external [lygo](../../interfaces/lygo/lygo.md) connectors / slots with 2 ports of 6 lanes.
  each slot has one port directly connected to left and one port directly connected to right
  for low-latency lygos between neighbours
- Debug: shared JTAG header, reset lines, status LEDs

## Prototype 1 Parameters

- Platform: ULX3S FPGA
- Dedicated ULX3S board for hub and routing logic
- JTAG: single header switched between module targets
- Signal integrity: LVDS termination and decoupling on [lygo](../../interfaces/lygo/lygo.md) ports
- Thermal: fan control or temperature monitoring

## Roadmap

- Add diagnostics/monitoring
- Higher lygo link speeds
