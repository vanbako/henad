# Diad-iris Processor

## Overview

- **Role**: Display processor (graphics/video)
- **Word size**: 24-bit (diad)
- **Design goal**: Efficient 2D/3D rendering and blitter operations

## Architecture

- Supports:
  - 24-bit integer, 24 bit fixed-point and 24 bit floating-point math
  - Blitter operations
  - Sprite handling
- Works directly with 24-bit RGB pixels

## GPU Prototype Implementation

- **Module**: `gw5ast_8x24gpu`
- **Parallel cores**: 8 instances of `gw5ast_core` created with a generate block
- **Data path**: 24‑bit wide for inputs, outputs and calculations
- **Per‑core memory**: each core links to its own `gw5ast_memory` via an AXI‑Lite style interface
- **Core logic**: current core performs a simple accumulate operation on memory input
- **Result output**: each core exposes its computation result through `core_result`
- **Status**: early prototype; wiring for AXI buses and memory signal arrays still requires completion

## Memory

- VRAM (module-iris)
- SD card

## Interfaces

- enid via unit-ada
- HDMI output

## Prototype 1 Parameters

- Frequency: 100 MHz
- FPGA: Arora-V

## Roadmap

- Hardware sprite expansion
- Hardware scaling/rotation
- SSD support
