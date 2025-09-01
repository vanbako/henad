# Diad-ethel Processor

## Overview

- **Role**: Main CPU of Henad
- **Cores**: 1-core configuration
- **Word size**: 24-bit (diad)
- **Addressing**: 48-bit (tetrad)
- **Design goal**: Efficient general-purpose processing for games

## Architecture

- RISC-like design
- 24-bit instruction/data width
- Supports 24-bit integer, fixed point, floating point
- 48-bit address width
- Pipeline: fetch, translate, decode, execute, memory, writeback
- interrupts, i-cache, d-cache, mmu, isa/µ-ops, kernel/user

## Memory

- SDRAM (module-ethel)
- SD storage

## Interfaces

- enid via unit-ada
- Local memory

## Prototype 1 Parameters

- Frequency: 50 MHz
- FPGA: ULX3S

## Roadmap

- Multicore 2 and 4 cores
- Higher frequencies
- SSD support
