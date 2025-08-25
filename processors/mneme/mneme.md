# Diad-Mneme Processor

## Overview
- **Role**: Mass storage controller
- **Word size**: 24-bit (diad)
- **Design goal**: Fast access to large persistent storage

## Architecture
- Handles SATA/NVMe-like protocols
- DMA engine for high-speed transfers

## Memory
- SDRAM
- Flash or SSD devices

## Interfaces
- lygo via unit-kairos
- SATA/NVMe-like storage interface

## Prototype 1 Parameters
- Frequency: 25–50 MHz (TBD)
- FPGA: ULX3S

## Roadmap
- SSD support
- Parallel access for faster streaming
