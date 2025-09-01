# unit-ada

## Overview

- **Role**: Standard base unit inside every module
- **Core**: [diad-amber](../../processors/amber/amber.md) (embedded 24-bit RISC-like core)
- **Interfaces**: [enid](../../interfaces/enid/enid.md) endpoint
- **Memory**: SDRAM + Flash (firmware)

## Functions

- Provides module-level management & firmware
- Bridges local processor (e.g. ethel, iris) to [enid](../../interfaces/enid/enid.md) fabric
- Executes housekeeping tasks

## Components

- [diad-amber core](../../processors/amber/amber.md)
- SDRAM
- Flash storage
- [enid](../../interfaces/enid/enid.md) PHY

## Prototype 1 Notes

- Clock: 25 MHz
- Implemented on ULX3S FPGA

## Future Options

- Merge unit-enid + unit-amber into one unit
- Larger SDRAM footprint
