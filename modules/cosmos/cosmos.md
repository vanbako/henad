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
graph TB
   subgraph cosmos
      COSMOS-CORE@{ shape: rect, label: "cosmos-core" }
      COSMOS-MMU@{ shape: rect, label: "cosmos-mmu" }
      COSMOS-FABRIC@{ shape: rect, label: "cosmos-fabric" }
      COSMOS-SDRAM@{ shape: bow-rect, label: "cosmos-sdram" }
      COSMOS-SDRAM-CTRL@{ shape: rect, label: "cosmos-sdram-ctrl" }
      DMA@{ shape: rect, label: "dma" }
      COSMOS-CORE <-->|"load/store bus<br/>virt addr"| COSMOS-MMU
      COSMOS-MMU <-->|"memory bus<br/>phys addr"| COSMOS-FABRIC
      COSMOS-SDRAM <-->|"sdram signals"| COSMOS-SDRAM-CTRL
      COSMOS-SDRAM-CTRL <-->|"fabric<br/>slave port"| COSMOS-FABRIC
      COSMOS-FABRIC <-->|"fabric<br/>master port"| DMA
   end
   subgraph lygo-seg0[lygo-0]
      LYGO0-EP@{ shape: rect, label: "lygo-ep" }
      LYGO0-LINK@{ shape: rect, label: "lygo-link" }
      LYGO0-PHY@{ shape: rect, label: "lygo-phy" }
      LYGO0-EP <-->|"transaction ↔<br/>link packet interface"| LYGO0-LINK
      LYGO0-LINK <-->|"framed link protocol<br/>(flits + credits)"| LYGO0-PHY
   end
   subgraph atomos
      ATOMOS-CORE@{ shape: rect, label: "atomos-core" }
      ATOMOS-FABRIC@{ shape: rect, label: "atomos-fabric" }
      ATOMOS-SRAM@{ shape: bow-rect, label: "atomos-sram" }
      ATOMOS-SRAM <-->|"memory bus<br/>phys addr"| ATOMOS-FABRIC
      ATOMOS-CORE <-->|"load/store bus<br/>phys addr"| ATOMOS-FABRIC
   end
   subgraph lygo-seg1[lygo-1]
      LYGO1-EP@{ shape: rect, label: "lygo-ep" }
      LYGO1-LINK@{ shape: rect, label: "lygo-link" }
      LYGO1-PHY@{ shape: rect, label: "lygo-phy" }
      LYGO1-EP <-->|"transaction ↔<br/>link packet interface"| LYGO1-LINK
      LYGO1-LINK <-->|"framed link protocol<br/>(flits + credits)"| LYGO1-PHY
   end
   subgraph lygo-seg2[lygo-2]
      LYGO2-EP@{ shape: rect, label: "lygo-ep" }
      LYGO2-LINK@{ shape: rect, label: "lygo-link" }
      LYGO2-PHY@{ shape: rect, label: "lygo-phy" }
      LYGO2-EP <-->|"transaction ↔<br/>link packet interface"| LYGO2-LINK
      LYGO2-LINK <-->|"framed link protocol<br/>(flits + credits)"| LYGO2-PHY
   end
   COSMOS-FABRIC <-->|"control-plane<br/>access"| LYGO0-EP
   ATOMOS-FABRIC <-->|"control-plane<br/>access"| LYGO0-EP
   COSMOS-FABRIC <-->|"control-plane<br/>access"| LYGO1-EP
   COSMOS-FABRIC <-->|"control-plane<br/>access"| LYGO2-EP
```

## Prototype 1 Parameters

- FPGA: ULX3S
- Clock: 50 MHz (proto-1)

## Roadmap

- Expand to 4 cores
- Support SSD storage
- Higher clock speeds
