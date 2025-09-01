# unit-ada

## Overview

- **Role**: Standard base unit inside every module
- **Core**: [diad-amber](../../processors/amber/amber.md) (embedded 24-bit RISC-like core)
- **Interfaces**: [enid](../../interfaces/enid/enid.md) endpoint
- **Memory**: SDRAM + Flash (firmware)

## Functions

- Provides module-level management & firmware
- Bridges local processor (e.g. ethel, iris) to [enid](../../interfaces/enid/enid.md) fabric
- Executes housekeeping tasks

## Components

- [diad-amber core](../../processors/amber/amber.md)
- [enid](../../interfaces/enid/enid.md) PHY

## Architecture

```mermaid
graph TB
   MODULE-FABRIC[module-fabric]
   subgraph ada
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
      AMBER-FABRIC <-->|"control-plane<br/>access"| ENID0-EP
   end
   MODULE-FABRIC <--> ENID0-EP
```

## Prototype 1 Notes

- Clock: 100 MHz
- Implemented on the Arora-V FPGA of each module
