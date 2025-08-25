# Diad-Optiko Processor

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

## Memory
- VRAM (module-optiko)
- SD card

## Interfaces
- lygos via unit-kairos
- HDMI output

## Prototype 1 Parameters
- Frequency: TBD (25–50 MHz)
- FPGA: ULX3S

## Roadmap
- Hardware sprite expansion
- Hardware scaling/rotation
- SSD support
