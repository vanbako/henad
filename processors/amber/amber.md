# Diad-amber Processor

## Overview

- Role: 24-bit BAU RISC-like core with CHERI capabilities
- BAU: 24-bit (diad)
- Addressing: 48-bit (tetrad)
- Goals: simple, in-order, secure-by-default (no BP, no OoO)

## What’s New: CHERI for Amber

- Capability-based memory safety with 24-bit BAU and 48-bit addressing.
- All loads/stores and indirect control flow are checked against a capability (bounds, perms, tag, seal).
- No MMU/virt yet; CHERI still enforces spatial safety and coarse CFI.
- Clean split of ISA vs. micro-ops; checks occur in XT/MA without speculation.

## Architecture

- ISA: 24-bit instructions. Core ALU on 24-bit integers.
- Pipeline: IA → IF → ID → XT → EX → MA → MO → WB.
- Core safety: no branch prediction; no out-of-order; no speculation.
- Privilege: kernel and user mode; syscalls via `SYSCALL #idx` (not SWI).

## Registers

- DR: 16 data registers `D0..D15` (24-bit). Encoding uses 4-bit register fields.
- SR: 4 special registers (48-bit): `LR`, `SSP` (shadow stack pointer), `PSTATE`, `PC`.
  - `PSTATE` replaces the old `FL`; contains `Z,N,C,V`, mode bit (K/U), interrupt enables, and trap cause.
- CR: 4 capability registers `CR0..CR3` (128-bit + tag), used as bases for all memory accesses.
  - Each capability holds: base (48), length (48), perms (at least R/W/X/LC/SC/SB), sealed bit, otype, cursor (48), tag.
  - Default capabilities (CSR): `PCC` (code), `DDC` (default data), and `SCC` (shadow-call stack).

Implementation note: the legacy AR file has been replaced by the capability register file. All AR reads/writes in the core now map to the CR cursor field (`CRx.cursor`). This keeps existing AR-based data paths working while enabling CHERI semantics incrementally (bounds, perms, tags) around the same indices (ARx ≡ CRx).

## Memory and CHERI

- Address space: 48-bit physical addressing, BAU=24-bit. No I/D caches yet.
- Checks: a memory op `LD/ST` uses `CRs + offset`; hardware verifies tag, bounds, perms, sealed state.
- Faults: on tag/perm/OOB/alignment violations, raise a software interrupt (vectored), with cause recorded in `PSTATE`.
- Control-flow integrity: `BTP` pads plus shadow call stack via `SSP`; `RET` verifies structured returns.
 - Future addressing note: when virtual memory is added, VA remains 24-bit BAU with 48-bit addressability; physical memory decomposes to 6-bit port ID + 42-bit local address.

## Syscalls and Software Interrupts

- `SYSCALL #idx`: enters kernel at a sealed, capability-authenticated entry; not implemented via SWI.
- Software interrupts are reserved for faults and “trap-on-UB” arithmetic (e.g., overflow). Examples:
  - Capability faults: OOB, tag clear, permission, sealed/type, exec perms.
  - Arithmetic faults: signed overflow on `ADD/SUB` trap variants; divide-by-zero.

## Async Int24 Math (CSRs)

Amber keeps the async 24-bit math CSR block. It is unaffected by CHERI and remains optional firmware acceleration. See CSRs and macros under “Async Int24 Math” in the design docs.

## Privilege Modes

- Modes: user (U) and kernel (K); reset enters K.
- `SYSCALL #idx`: saves `PC+1` in `LR`, switches to K, and jumps via a kernel entry capability.
- `KRET`: returns to `LR+1` and drops back to U mode. Control transfers execute through `PCC` and are capability-checked.
- `PSTATE` holds current mode and last trap cause. CSR writes to control fields are K-only.

## Status and Roadmap

- Done in spec: capability register model; cap-checked loads/stores; syscall separation; CFI with `BTP/LR/SSP`.
- Not yet: MMU/virt, caches, atomics.

HDL status (current tree)

- Implemented CHERI ops: `CINC/CINCv`, `CINCi/CINCiv`, `CMOV`, `CSETB/CSETBi` (+ checked variants), `CANDP`, `CGETP`, `CGETT`, `CCLRT`, and CHERI-checked `LDcso/STcso`.
- Deferred: memory capability load/store `CLDcso/CSTcso` (full-width cap moves) pending a wider memory path/microcode sequence.

## Further Documentation

- Design: `processors/amber/design/design.md`
- ISA & opcodes: `processors/amber/design/opcode.md`
- CHERI details: `processors/amber/design/cheri.md`
 - CSR map: `processors/amber/design/csr.md`
