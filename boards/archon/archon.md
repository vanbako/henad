# board-archon

## Overview
- **Role**: Central hub board for Henad
- **Core Components**:
  - unit-kairos
  - 8× port lygo switch
  - Power distribution
  - Fan connectors

## Features
- Central interconnect hub for modules
- Supports up to 8 external lygo connections
- Provides regulated power from 24V input
- Single JTAG connector with switchable access to module JTAGs

## Physical
- Power: 24V input
- Cooling: 2× fan connectors
- 8× external lygo connectors
- Debug: shared JTAG header, reset lines, status LEDs

## Prototype 1 Parameters
- Platform: ULX3S FPGA
- Dedicated ULX3S board for hub and routing logic
- Switch: FPGA-based lygo router
- JTAG: single header switched between module targets
- Signal integrity: LVDS termination and decoupling on lygo ports
- Power: sequencing and over-current protection
- Thermal: fan control or temperature monitoring

## Roadmap
- Add diagnostics/monitoring
- Higher lygo link speeds
