# Diad-Dikto Processor

## Overview

- **Role**: Network processor
- **Word size**: 24-bit (diad)
- **Design goal**: Packet processing for online multiplayer

## Architecture

- RISC-like core with networking accelerators
- Hardware support for checksums and packet filtering

## Memory

- SDRAM (via module-dikto)

## Interfaces

- lygo via unit-kairos
- RJ45-like physical interface

## Prototype 1 Parameters

- Frequency: 25 MHz (TBD)
- FPGA: ULX3S

## Roadmap

- Higher link speeds
- Custom low-latency protocols
