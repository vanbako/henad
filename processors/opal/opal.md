# Diad-opal Processor

## Overview

- **Role**: Mass storage controller
- **BAU**: 24-bit (diad)
- **Design goal**: Fast access to large persistent storage

## Architecture

- Handles SATA/NVMe-like protocols
- DMA engine for high-speed transfers

## Memory

- SDRAM
- Flash or SSD devices

## Interfaces

- enid via unit-ada
- SATA/NVMe-like storage interface

## Prototype 1 Parameters

- Frequency: 100 MHz
- FPGA: Arora-V

## Roadmap

- SSD support
- Parallel access for faster streaming
