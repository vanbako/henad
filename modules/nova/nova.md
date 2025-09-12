# Module-nova

## Overview

- **Role**: Neural network processor module (AI acceleration)
- **Core Processor**: [diad-nova](../../processors/nova/nova.md)
- **Base Unit**: [unit-ada](../../units/ada/ada.md)
- **Interconnect**: [enid](../../interfaces/enid/enid.md)

## Features

- Matrix/vector math acceleration
- 24-bit integer + floating-point ops (24-bit BAU)
- SIMD-style execution

## Architecture

- [diad-nova processor](../../processors/nova/nova.md)
- SDRAM
- SD card

## Prototype 1 Parameters

- FPGA: Arora-V (dedicated board)
- Clock: 100 MHz (TBD)

## Roadmap

- SSD support for large models
- Hardware tensor instructions
- Higher throughput for AI workloads
