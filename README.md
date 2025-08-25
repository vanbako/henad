# Henad Game System Documentation

Henad is a modular **24-bit game system** where all registers and memory are 24-bit wide (diad).  
Addresses extend to 48-bit (tetrad) when needed.  
The design is fully modular, with each function (CPU, graphics, sound, input, etc.) implemented as a separate module connected via the **lygos interconnect**.

This repository contains documentation split by **processors, units, modules, board, and interfaces**.

---

## 📚 Documentation Index

### 🔗 Interfaces
- [interface-lygo](interfaces/lygo/lygo.md)

### 🔧 Units
- [unit-kairos](units/kairos/kairos.md)

### 🖥️ board
- [board-archon](boards/archon/archon.md)

### ⚙️ Diad processors
- [diad-atomos](processors/atomos/atomos.md) – control/firmware core
- [diad-cosmos](processors/cosmos/cosmos.md) – main CPU
- [diad-optiko](processors/optik/optiko.md) – graphics/display processor
- [diad-Echos](processors/echos/echos.md) – sound processor
- [diad-hapto](processors/hapto/hapto.md) – input processor
- [diad-dikto](processors/dikto/dikto.md) – network processor
- [diad-mneme](processors/mneme/mneme.md) – mass storage processor
- [diad-noos](processors/noos/noos.md) – neural network processor

### 🎛️ Modules
Each module is built around a **unit-kairos** and one specialized processor:
- **module-cosmos** → diad-cosmos (CPU)
- **module-optiko** → diad-optiko (Graphics/GPU)
- **module-echos** → diad-echos (Audio)
- **module-hapto** → diad-hapto (Input)
- **module-dikto** → diad-dikto (Network)
- **module-mneme** → diad-mneme (Storage)
- **module-noos** → diad-noos (Neural)

*(Module `.md` files can be added as they expand in detail.)*

---

## 📖 Glossary
- **diad** = 24-bit word (data, math, characters, pixels)
- **tetrad** = 48-bit (used for addresses)
- **lygos** = full-duplex LVDS interconnect
- **kairos** = base control unit (Atomos + memory + endpoint)
- **archon** = main board (hub + switch + power)

---

## 🛠️ Prototype 1 Notes
- Platform: **ULX3S FPGA boards**
- One ULX3S board per module and for the board-archon
- The kairos unit is in the same fpga
- Target frequencies:
  - lygos: **25 MHz**
  - Diad-atomos: **25 MHz**
  - diad-cosmos: **50 MHz**
