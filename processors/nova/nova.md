# Diad-nova Processor

## Overview

- **Role**: Neural network accelerator
- **Word size**: 24-bit (diad)
- **Design goal**: Matrix and vector math for AI workloads

## Architecture

- SIMD-style execution units
- 24-bit integer and floating-point operations

## Memory

- SDRAM
- SD card or SSD for model storage

## Interfaces

- enid via unit-ada

## Prototype 1 Parameters

- Frequency: 25–50 MHz (TBD)
- FPGA: ULX3S

## Roadmap

- Hardware tensor instructions
- SSD support for larger models
- Higher throughput
