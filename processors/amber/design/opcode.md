# Instructions

## Preface

Bit-field annotations indicate bit positions in the 24-bit instruction word.
For example, [23-20] marks the high 4 bits, with the left number the most
significant bit and the right number the least significant.
Registers use the following naming:
  DRx - data registers, ARx - address registers, SRx - special registers.
Suffixes such as t and s denote target and source respectively.

## [opclass 0000](opcodes/opclass0.md) Core ALU (reg–reg, unsigned flags)

## [opclass 0001](opcodes/opclass1.md) Core ALU (imm/uimm, unsigned flags)

## [opclass 0010](opcodes/opclass2.md) Core ALU (reg–reg, signed flags)

## [opclass 0011](opcodes/opclass3.md) Core ALU (imm, signed flags / PC-rel)

## [opclass 0100](opcodes/opclass4.md) Loads/Stores

## opclass 0101 Reserved

## [opclass 0110](opcodes/opclass6.md) Address-register ALU & moves

## [opclass 0111](opcodes/opclass7.md) Control flow (absolute via AR / long immediates) & linkage

## [opclass 1000](opcodes/opclass8.md) Stack helpers

## [opclass 1001](opcodes/opclass9.md) CSR access

## [opclass 1010](opcodes/opclassa.md) privileged / kernel-only

## opclass 1011 MMU / TLB & Cache management

## opclass 1100 Atomics & SMP

## opclass 1101 Reserved

## opclass 1110 Reserved

## [opclass 1111](opcodes/opclassf.md) µop
