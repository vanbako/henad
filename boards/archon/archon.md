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

## Physical
- Power: 24V input
- Cooling: 2× fan connectors
- 8× external lygo connectors

## Prototype 1 Parameters
- Platform: ULX3S FPGA
- Dedicated ULX3S board for hub and routing logic
- Switch: FPGA-based lygo router

## Roadmap
- Add diagnostics/monitoring
- Higher lygo link speeds
