# Henad Game System Documentation

Henad is a modular **24-bit game system** where all registers and memory are 24-bit wide, BAU (Basic Addressable Unit) = 24-bit.  
Addresses are 48-bit (tetrad).  
Iris, the gpu will have 12-bit (henad) math where two henads will be packed in one diad (BAU)
The design is fully modular, with each function (CPU, graphics, sound, input, etc.) implemented as a separate module connected via the **enid interconnect**.

This repository contains documentation split by **processors, units, modules, board, and interfaces**.

---

## 📚 Documentation Index

### 🔗 Interfaces

- [interface-enid](interfaces/enid/enid.md)

### 🔧 Units

- [unit-ada](units/ada/ada.md)

### 🖥️ boards

- [board-stella](boards/stella/stella.md)
- [board-ivy](boards/ivy/ivy.md)

### ⚙️ Diad processors

- [diad-amber](processors/amber/amber.md) – control/firmware core
- [diad-ethel](processors/ethel/ethel.md) – main CPU
- [diad-iris](processors/iris/iris.md) – graphics/display processor
- [diad-lyra](processors/lyra/lyra.md) – sound processor
- [diad-maeve](processors/maeve/maeve.md) – input processor
- [diad-clara](processors/clara/clara.md) – network processor
- [diad-opal](processors/opal/opal.md) – mass storage processor
- [diad-nova](processors/nova/nova.md) – neural network processor

### 🎛️ Modules

Each module is built around a **unit-ada** and one specialized processor:

- [module-ethel](modules/ethel/ethel.md) → [diad-ethel](processors/ethel/ethel.md) (CPU)
- [module-iris](modules/iris/iris.md) → [diad-iris](processors/iris/iris.md) (Graphics/GPU)
- [module-lyra](modules/lyra/lyra.md) → [diad-lyra](processors/lyra/lyra.md) (Audio)
- [module-maeve](modules/maeve/maeve.md) → [diad-maeve](processors/maeve/maeve.md) (Input)
- [module-clara](modules/clara/clara.md) → [diad-clara](processors/clara/clara.md) (Network)
- [module-opal](modules/opal/opal.md) → [diad-opal](processors/opal/opal.md) (Storage)
- [module-nova](modules/nova/nova.md) → [diad-nova](processors/nova/nova.md) (Neural)

---

## 📖 Glossary

- **diad** = 24-bit BAU (data, math, characters, pixels)
- **tetrad** = 48-bit (used for addresses)
- **enid** = full-duplex LVDS interconnect
- **ada** = base control unit (amber + memory + endpoint)
- **ivy** = main board (hub + switch + power)

---

## 🛠️ Prototype 1 Notes

- Platform: **Sipeed Gowin Arora-V FPGA boards**
- One Arora-V board per module and for the board-ivy
- The ada unit is in the same fpga
- Target frequencies:
  - enid: **100 MHz**
  - Diad-amber: **100 MHz**
  - diad-ethel: **100 MHz**
