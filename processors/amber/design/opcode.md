# Instructions

## Preface

Bit-field annotations indicate bit positions in the 24-bit instruction word.
For example, [23-20] marks the high 4 bits, with the left number the most
significant bit and the right number the least significant.
Registers naming in the CHERI revision:
  DRx - data registers (24-bit), CRx - capability registers (128-bit + tag), SRx - special registers (48-bit).
Suffixes such as t and s denote target and source respectively.

Trap variants

- Instructions with potential undefined behaviour have checked forms or semantics:
  - Signed arithmetic: `ADDsv/SUBsv/NEGsv` and immediate `ADDsiv/SUBsiv` trap on overflow (`ARITH_OVF`).
  - Shifts: immediate forms `SHLuiv/SHRuiv` and signed `SHRsiv` trap on counts ≥ 24 (`ARITH_RANGE`). Register shift forms raise `ARITH_RANGE` when count ≥ 24.
  - Capability ops: `CINCv/CINCiv` trap when cursor would leave bounds; `CSETBv/CSETBiv` trap on invalid/overflowed bounds.
  - UI imm-bank use: all `..ui` forms trap with `UIMM_STATE` if used without a valid `LUIui` bank load in the atomic window.

## [opclass 0000](opcodes/opclass0.md) Core ALU (reg–reg, unsigned flags)

## [opclass 0001](opcodes/opclass1.md) Core ALU (imm/uimm, unsigned flags)

## [opclass 0010](opcodes/opclass2.md) Core ALU (reg–reg, signed flags)

## [opclass 0011](opcodes/opclass3.md) Core ALU (imm, signed flags / PC-rel)

## [opclass 0100](opcodes/opclass4.md) CHERI Loads/Stores (via CR)

## [opclass 0101](opcodes/opclass5.md) CHERI Capability ops (moves, offset/bounds)

## [opclass 0110](opcodes/opclass6.md) Control flow (absolute via AR / long immediates) & linkage

## [opclass 0111](opcodes/opclass7.md) Stack helpers

## [opclass 1000](opcodes/opclass8.md) CSR access

## [opclass 1001](opcodes/opclass9.md) privileged / kernel-only

## opclass 1010 Reserved (future CHERI/VM/Cache)

## opclass 1011 Atomics & SMP

## opclass 1100 Reserved

## opclass 1101 Reserved

## opclass 1110 Reserved

## [opclass 1111](opcodes/opclassf.md) µop

See also: `processors/amber/design/cheri.md` for capability semantics, fault causes, and default capabilities (`PCC`, `DDC`, `SCC`).
