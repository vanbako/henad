# board-stella

## Overview

- **Role**: Central switch board for Henad, temperature and fan control
- **Core Components**:
  - [unit-ada](../../units/ada/ada.md)
  - 8× port [enid](../../interfaces/enid/enid.md) switch
  - Power distribution
  - Fan connector(s)

## Features

- Central interconnect hub for modules
- Supports up to 8 external [enid](../../interfaces/enid/enid.md) connections
- Provides regulated power from 24V input

## Physical

- Power: 24V input
- Cooling: 1× fan connectors
- 8× external [enid](../../interfaces/enid/enid.md) connectors / slots

## Prototype 1 Parameters

- Platform: Arora-V FPGA
- Dedicated Arora-V board for hub and routing logic
- Switch: FPGA-based enid router
- Signal integrity: LVDS termination and decoupling on [enid](../../interfaces/enid/enid.md) ports
- Power: sequencing and over-current protection
- Thermal: fan control or temperature monitoring

## Roadmap

- Higher enid link speeds
