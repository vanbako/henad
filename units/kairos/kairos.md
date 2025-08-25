# unit-kairos

## Overview
- **Role**: Standard base unit inside every module
- **Core**: [diad-atomos](../../processors/atomos/atomos.md) (embedded 24-bit RISC-like core)
- **Interfaces**: [lygo](../../interfaces/lygo/lygo.md) endpoint
- **Memory**: SDRAM + Flash (firmware)

## Functions
- Provides module-level management & firmware
- Bridges local processor (e.g. cosmos, optiko) to [lygo](../../interfaces/lygo/lygo.md) fabric
- Executes housekeeping tasks

## Components
- [diad-atomos core](../../processors/atomos/atomos.md)
- SDRAM
- Flash storage
- [lygo](../../interfaces/lygo/lygo.md) PHY

## Prototype 1 Notes
- Clock: 25 MHz
- Implemented on ULX3S FPGA

## Future Options
- Merge unit-lygo + unit-atomos into one unit
- Larger SDRAM footprint
