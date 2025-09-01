# Module-ethel

## Overview

- **Role**: Central CPU module of henad
- **Core Processor**: [diad-ethel](../../processors/ethel/ethel.md)
- **Base Unit**: [unit-ada](../../units/ada/ada.md)
- **Interconnect**: [enid](../../interfaces/enid/enid.md)

## Features

- Main general-purpose CPU
- 24-bit integer, fixed-point, floating-point math
- 48-bit addressing

## Architecture

- [diad-ethel processor](../../processors/ethel/ethel.md)
- SDRAM for program/data memory
- SD card storage

```mermaid
graph TB
   subgraph ethel
      ETHEL-CORE@{ shape: rect, label: "ethel-core" }
      ETHEL-MMU@{ shape: rect, label: "ethel-mmu" }
      ETHEL-FABRIC@{ shape: rect, label: "ethel-fabric" }
      ETHEL-SDRAM@{ shape: bow-rect, label: "ethel-sdram" }
      ETHEL-SDRAM-CTRL@{ shape: rect, label: "ethel-sdram-ctrl" }
      DMA@{ shape: rect, label: "dma" }
      ETHEL-CORE <-->|"load/store bus<br/>virt addr"| ETHEL-MMU
      ETHEL-MMU <-->|"memory bus<br/>phys addr"| ETHEL-FABRIC
      ETHEL-SDRAM <-->|"sdram signals"| ETHEL-SDRAM-CTRL
      ETHEL-SDRAM-CTRL <-->|"fabric<br/>slave port"| ETHEL-FABRIC
      ETHEL-FABRIC <-->|"fabric<br/>master port"| DMA
   end
   subgraph enid-0[enid-0]
      ENID0-EP@{ shape: rect, label: "enid-ep" }
      ENID0-LINK@{ shape: rect, label: "enid-link" }
      ENID0-PHY@{ shape: rect, label: "enid-phy" }
      ENID0-EP <-->|"transaction ↔<br/>link packet interface"| ENID0-LINK
      ENID0-LINK <-->|"framed link protocol<br/>(flits + credits)"| ENID0-PHY
   end
   subgraph amber
      AMBER-CORE@{ shape: rect, label: "amber-core" }
      AMBER-FABRIC@{ shape: rect, label: "amber-fabric" }
      AMBER-SRAM@{ shape: bow-rect, label: "amber-sram" }
      AMBER-SRAM <-->|"memory bus<br/>phys addr"| AMBER-FABRIC
      AMBER-CORE <-->|"load/store bus<br/>phys addr"| AMBER-FABRIC
   end
   subgraph enid-1[enid-1]
      ENID1-EP@{ shape: rect, label: "enid-ep" }
      ENID1-LINK@{ shape: rect, label: "enid-link" }
      ENID1-PHY@{ shape: rect, label: "enid-phy" }
      ENID1-EP <-->|"transaction ↔<br/>link packet interface"| ENID1-LINK
      ENID1-LINK <-->|"framed link protocol<br/>(flits + credits)"| ENID1-PHY
   end
   subgraph enid-2[enid-2]
      ENID2-EP@{ shape: rect, label: "enid-ep" }
      ENID2-LINK@{ shape: rect, label: "enid-link" }
      ENID2-PHY@{ shape: rect, label: "enid-phy" }
      ENID2-EP <-->|"transaction ↔<br/>link packet interface"| ENID2-LINK
      ENID2-LINK <-->|"framed link protocol<br/>(flits + credits)"| ENID2-PHY
   end
   ETHEL-FABRIC <-->|"control-plane<br/>access"| ENID0-EP
   AMBER-FABRIC <-->|"control-plane<br/>access"| ENID0-EP
   ETHEL-FABRIC <-->|"control-plane<br/>access"| ENID1-EP
   ETHEL-FABRIC <-->|"control-plane<br/>access"| ENID2-EP
```

## Prototype 1 Parameters

- FPGA: ULX3S
- Clock: 50 MHz (proto-1)

## Roadmap

- Expand to 4 cores
- Support SSD storage
- Higher clock speeds
