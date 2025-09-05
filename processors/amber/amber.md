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

## Privilege Modes

- Two modes: user (U) and kernel (K).
- Mode bit lives in CSR[STATUS][0]; reset enters K mode.
- `SWI imm12` traps to an absolute handler address (assembled via three `LUIUI` banks + `imm12`), saves `PC+1` into `LR`, and enters K mode.
- `SRET` returns to `LR+1` and drops back to U mode.
- CSR[STATUS] is readable via `CSRRD`; writes to CSR[STATUS] are only honored in K mode.

## Further Documentation

For more detailed information, refer to:

- [Design Documentation](./design/design.md) – Detailed hardware design and pipeline overview.
- [Opcode Definitions](./design/opcode.md) – Complete opcode and micro‑op specifications.
