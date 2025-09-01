# board-ivy

## Overview

- **Role**: Direct enid connections, temperature and fan control
- **Core Components**:
  - [unit-ada](../../units/ada/ada.md)
  - Fan connector(s)

## Features

- Single JTAG connector with switchable access to module JTAGs

## Physical

- Power: 24V input
- Cooling: 1× fan connectors
- 8× external [enid](../../interfaces/enid/enid.md) connectors / slots with 2 ports of 6 lanes.
  each slot has one port directly connected to left and one port directly connected to right
  for low-latency enid between neighbours
- Debug: shared JTAG header, reset lines, status LEDs

## Prototype 1 Parameters

- Platform: Arora-V
- Dedicated Arora-V board for hub and routing logic
- JTAG: single header switched between module targets
- Signal integrity: LVDS termination and decoupling on [enid](../../interfaces/enid/enid.md) ports
- Thermal: fan control or temperature monitoring

## Roadmap

- Add diagnostics/monitoring
- Higher enid link speeds
