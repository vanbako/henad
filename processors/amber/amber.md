# Diad-amber Processor

## Overview

- **Role**: Embedded 24-bit RISC-like core for control tasks
- **Word size**: 24-bit (diad)
- **Addressing**: 24-bit (diad)
- **Design goal**: Lightweight firmware engine for modules

## Architecture

- ISA: RISC-like, 24-bit instructions
- Pipeline: fetch, decode, execute, memory, writeback
- Operations: 24 bit Integer + basic control ops
- interrupts

## Memory

- Registers: 24-bit wide
- SDRAM (via unit-ada)
- Flash firmware

## Interfaces

- enid endpoint
- local memory bus

## Prototype 1 Parameters

- Frequency: 100 MHz
- FPGA platform: Arora-V

## Future Extensions

- Possible merge with unit-enid
- Improved debugging support

## Further Documentation

For more detailed information, refer to:

- [Design Documentation](./design/design.md) – Detailed hardware design and pipeline overview.
- [Opcode Definitions](./design/opcode.md) – Complete opcode and micro‑op specifications.
