# Diad-amber Processor

## Overview

- **Role**: Embedded 24-bit RISC-like core for control tasks
- **Word size**: 24-bit (diad)
- **Addressing**: 24-bit (diad)
- **Design goal**: Lightweight firmware engine for modules

## Architecture

- ISA: RISC-like, 24-bit instructions
- Pipeline: fetch, decode, execute, memory, writeback
- Operations: 24 bit Integer + basic control ops
- interrupts

## Memory

- Registers: 24-bit wide
- SDRAM (via unit-ada)
- Flash firmware

## Interfaces

- enid endpoint
- local memory bus

## Prototype 1 Parameters

- Frequency: 100 MHz
- FPGA platform: Arora-V

## Future Extensions

- Possible merge with unit-enid
- Improved debugging support

## Async Int24 Math (MUL/DIV/MOD/SQRT/MIN/MAX/ABS/CLAMP)

Amber exposes a tiny asynchronous 24‑bit integer math unit through CSRs. The core never stalls; firmware triggers an operation and polls a status bit. Results are placed in CSRs when ready.

- CSRs
  - `CSR[0x10] MATH_CTRL`: bit0 `START`; bits[4:1] `OP`
  - `CSR[0x11] MATH_STATUS`: bit0 `READY`; bit1 `BUSY`; bit2 `DIV0`
  - `CSR[0x12] MATH_OPA`: operand A (24‑bit)
  - `CSR[0x13] MATH_OPB`: operand B (24‑bit)
  - `CSR[0x16] MATH_OPC`: optional third operand (e.g. clamp min)
  - `CSR[0x14] MATH_RES0`: result low (MUL: product[23:0], DIV: quotient, MOD/SQRT: result)
  - `CSR[0x15] MATH_RES1`: result high (MUL: product[47:24], DIV: remainder, else 0)

- Usage (pseudo‑assembly)
  - `CSRWR MATH_OPA, Ds` and `CSRWR MATH_OPB, Dt`
  - `CSRWR MATH_CTRL, (START | OP=<...>)`
  - Poll: `CSRRD MATH_STATUS -> D0`; test `READY`
  - Read: `CSRRD MATH_RES0 -> Dx` (and `MATH_RES1` if needed)

Notes
- Ops (bits[4:1] `OP`)
  - `0x0 MULU` unsigned: RES0=product[23:0], RES1=product[47:24]
  - `0x1 DIVU` unsigned: RES0=quotient, RES1=remainder; sets `DIV0` when OPB=0
  - `0x2 MODU` unsigned: RES0=remainder
  - `0x3 SQRTU` unsigned: RES0=floor(sqrt(OPA)) (12‑bit significant)
  - `0x4 MULS` signed: RES0/RES1 as MULU but signed operands
  - `0x5 DIVS` signed: RES0=quotient, RES1=remainder (C semantics; trunc toward 0)
  - `0x6 MODS` signed: RES0=remainder (C semantics)
  - `0x7 ABS_S` signed: RES0=abs(OPA)
  - `0x8 MIN_U`, `0x9 MAX_U`: unsigned min/max of A,B → RES0
  - `0xA MIN_S`, `0xB MAX_S`: signed min/max → RES0
  - `0xC CLAMP_U` unsigned: clamp A to [`OPC`, `OPB`] → RES0
  - `0xD CLAMP_S` signed: clamp A to [`OPC`, `OPB`] → RES0
- Division by zero sets `DIV0` and zeroes results.
- SQRT returns floor(sqrt(OPA)) in `RES0` (12‑bit significant).
- Values are int24; ops are unsigned or signed per opcode.

Assembler integration
- The Amber assembler provides built-in CSR aliases and math constants: `MATH_CTRL`, `MATH_STATUS`, `MATH_OPA`, `MATH_OPB`, `MATH_OPC`, `MATH_RES0`, `MATH_RES1`, `MATH_CTRL_START`, `MATH_STATUS_READY`, and pre-shifted `MATH_OP_*` codes.
- Convenience macros expand to full CSR sequences (write operands, kick, poll `READY`, read results):
  - `MULU24/MULS24 DRa, DRb, DRlo, DRhi, DRtmp`
  - `DIVU24/DIVS24 DRa, DRb, DRq, DRr, DRtmp`
  - `MODU24/MODS24 DRa, DRb, DRr, DRtmp`
  - `SQRTU24 DRa, DRres, DRtmp`
  - `ABS_S24 DRa, DRres, DRtmp`
  - `MIN_U24/MAX_U24/MIN_S24/MAX_S24 DRa, DRb, DRres, DRtmp`
  - `CLAMP_U24/CLAMP_S24 DRa, DRmin, DRmax, DRres, DRtmp`
- Example (unsigned divide): `DIVU24 DR1, DR2, DR3, DR4, DR0`  ; DR3=quot, DR4=rem, DR0 scratch

## Testbench

- File: `processors/amber/src/math24_async_tb.v`
- Instantiates `regcsr` and `math24_async` together and exercises:
  - MULU, DIVU (incl. div0), DIVS, MIN_U, MAX_S, ABS_S, CLAMP_U, CLAMP_S, SQRTU
- Run with Icarus Verilog or your simulator of choice. Passes print `math24_async_tb: PASS`.

## Privilege Modes

- Two modes: user (U) and kernel (K).
- Mode bit lives in CSR[STATUS][0]; reset enters K mode.
- `SWI imm12` traps to an absolute handler address (assembled via three `LUIUI` banks + `imm12`), saves `PC+1` into `LR`, and enters K mode.
- `SRET` returns to `LR+1` and drops back to U mode.
- CSR[STATUS] is readable via `CSRRD`; writes to CSR[STATUS] are only honored in K mode.

## Further Documentation

For more detailed information, refer to:

- [Design Documentation](./design/design.md) – Detailed hardware design and pipeline overview.
- [Opcode Definitions](./design/opcode.md) – Complete opcode and micro‑op specifications.
