# Module-Cosmos

## Overview

- **Role**: Central CPU module of henad
- **Core Processor**: [diad-cosmos](../../processors/cosmos/cosmos.md)
- **Base Unit**: [unit-kairos](../../units/kairos/kairos.md)
- **Interconnect**: [lygo](../../interfaces/lygo/lygo.md)

## Features

- Main general-purpose CPU
- 24-bit integer, fixed-point, floating-point math
- 48-bit addressing

## Architecture

- [diad-cosmos processor](../../processors/cosmos/cosmos.md)
- SDRAM for program/data memory
- SD card storage

```mermaid
graph LR
   COSMOS-CORE[cosmos-core]
   COSMOS-MMU[cosmos-mmu]
   COSMOS-FABRIC[cosmos-fabric]
   COSMOS-SDRAM[cosmos-sdram]
   COSMOS-SDRAM-CTRL[cosmos-sdram-ctrl]
   DMA[dma]
   ATOMOS-CORE[atomos-core]
   ATOMOS-FABRIC[atomos-fabric]
   ATOMOS-SRAM[atomos-sram]
   LYGO-EP[lygo-ep]
   LYGO-LINK[lygo-link]
   LYGO-PHY[lygo-phy]
   subgraph cosmos
      direction TB
      COSMOS-CORE <-->|"Load/store bus<br/>virtual addr"| COSMOS-MMU
      COSMOS-MMU <-->|"Memory bus<br/>physical addr"| COSMOS-FABRIC
      COSMOS-SDRAM <-->|"DRAM signals"| COSMOS-SDRAM-CTRL
      COSMOS-SDRAM-CTRL <-->|"Fabric<br/>slave port"| COSMOS-FABRIC
      COSMOS-FABRIC <-->|"Fabric<br/>master port"| DMA
   end
   COSMOS-FABRIC <-->|"Fabric<br/>master port"| ATOMOS-FABRIC
   subgraph atomos
      direction TB
      ATOMOS-SRAM <--> ATOMOS-FABRIC
      ATOMOS-FABRIC <-->|"Load/store bus<br/>phys addr"| ATOMOS-CORE
   end
   subgraph lygo
      direction TB
      ATOMOS-FABRIC <-->|"Control-plane<br/>access"| LYGO-EP
      LYGO-EP <-->|"Transaction ↔<br/>Link packet interface"| LYGO-LINK
      LYGO-LINK <-->|"Framed link protocol<br/>(flits + credits)"| LYGO-PHY
   end
```

## Prototype 1 Parameters

- FPGA: ULX3S
- Clock: 50 MHz (proto-1)

## Roadmap

- Expand to 4 cores
- Support SSD storage
- Higher clock speeds
