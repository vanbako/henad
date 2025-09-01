# Module-opal

## Overview

- **Role**: Mass storage module
- **Core Processor**: [diad-opal](../../processors/opal/opal.md)
- **Base Unit**: [unit-ada](../../units/ada/ada.md)
- **Interconnect**: [enid](../../interfaces/enid/enid.md)

## Features

- Fast access to large storage
- SATA/NVMe-like interface
- DMA transfer support

## Architecture

- [diad-opal processor](../../processors/opal/opal.md)
- SDRAM
- SATA/NVMe-like interface

## Prototype 1 Parameters

- FPGA: ULX3S (dedicated board)
- Clock: 25–50 MHz (TBD)

## Roadmap

- SSD support
- Parallel access for faster streaming
