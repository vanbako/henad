# unit-kairos

## Overview
- **Role**: Standard base unit inside every module
- **Core**: diad-atomos (embedded 24-bit RISC-like core)
- **Interfaces**: Lygo endpoint
- **Memory**: SDRAM + Flash (firmware)

## Functions
- Provides module-level management & firmware
- Bridges local processor (e.g. cosmos, optiko) to lygo fabric
- Executes housekeeping tasks

## Components
- diad-atomos core
- SDRAM
- Flash storage
- Lygo PHY

## Prototype 1 Notes
- Clock: 25 MHz
- Implemented on ULX3S FPGA

## Future Options
- Merge unit-lygo + unit-atomos into one unit
- Larger SDRAM footprint
