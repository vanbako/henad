# board-pontifex

## Overview

- **Role**: Central switch board for Henad, temperature and fan control
- **Core Components**:
  - [unit-kairos](../../units/kairos/kairos.md)
  - 8× port [lygo](../../interfaces/lygo/lygo.md) switch
  - Power distribution
  - Fan connector(s)

## Features

- Central interconnect hub for modules
- Supports up to 8 external [lygo](../../interfaces/lygo/lygo.md) connections
- Provides regulated power from 24V input

## Physical

- Power: 24V input
- Cooling: 1× fan connectors
- 8× external [lygo](../../interfaces/lygo/lygo.md) connectors / slots

## Prototype 1 Parameters

- Platform: ULX3S FPGA
- Dedicated ULX3S board for hub and routing logic
- Switch: FPGA-based lygo router
- Signal integrity: LVDS termination and decoupling on [lygo](../../interfaces/lygo/lygo.md) ports
- Power: sequencing and over-current protection
- Thermal: fan control or temperature monitoring

## Roadmap

- Higher lygo link speeds
