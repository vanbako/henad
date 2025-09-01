# Module-iris

## Overview

- **Role**: Graphics and display module
- **Core Processor**: [diad-iris](../../processors/iris/iris.md)
- **Base Unit**: [unit-ada](../../units/ada/ada.md)
- **Interconnect**: [enid](../../interfaces/enid/enid.md)

## Features

- 2D/3D rendering and blitter operations
- Handles 24-bit RGB pixels
- HDMI output for video

## Architecture

- [diad-iris processor](../../processors/iris/iris.md)
- SDRAM acting as VRAM
- HDMI transmitter

## Prototype 1 Parameters

- FPGA: ULX3S (dedicated board)
- Clock: 25–50 MHz (TBD)

## Roadmap

- Hardware scaling and rotation
- Expanded VRAM capacity
