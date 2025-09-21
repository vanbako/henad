# amber design

## About

The diad-amber 8-stage microarchitecture core, with a CHERI capability model adapted to a 24-bit BAU and 48-bit addressing. The core is in-order with no speculation, focusing on simplicity and strong default safety.

## Details

- Board: Arora-V
- Instruction width and GP data: BAU 24-bit
- Special registers: 48-bit (tetrad)
- Memory model:
  - 24-bit BAU, 48-bit physical addressing
  - Virtual memory via 4K-word pages and a 3-level MMU/TLB (see `mmu.md`)
  - No I/D caches (future)
- Execution:
  - No branch prediction; no out-of-order; no speculation
  - Interrupts to be added; CHERI checks integrated in XT/MA
- Pipeline implementation:
  - ISA → micro-ops split in XT
  - Handshake between stages; no multi-cycle µops
  - BRAMs for I/D memories (1-cycle latency)
- Boot: bootloader (current benches load memory images)
- Branching: BCC/JCC/BAL resolve in XT; IF/ID squashed on taken

## Instruction Format

- 24-bit instruction word. Unused bits are reserved (encode as zero).
- Condition codes (4-bit): `AL=0, EQ=1, NE=2, LT=3, GT=4, LE=5, GE=6, BT=7, AT=8, BE=9, AE=A`.
- Immediates:
  - 12-bit immediates (optionally combined with `LUIui` immediate banks)
  - Other imm sizes maximize branch/jump reach

Flags consulted

- Signed comparisons: Z, N, V
- Unsigned comparisons: C (and Z where relevant)

Instruction suffixes

- `ur`: unsigned reg–reg
- `ui`: unsigned immediate
- `sr`: signed reg–reg
- `si`: signed immediate
- `so`: signed offset (PC-relative or base+offset)

Assembly convention: last operand is the target.

Notes

- Moves update Z; address/capability ops generally don’t update arithmetic flags.
- 48-bit memory transfers are little endian (2×24-bit BAU).

## CHERI Overview (Amber)

- Capability registers: 4 × `CR0..CR3` (128-bit + tag), used as bases for all loads/stores.
- Each capability encodes: base (48), length (48), cursor (48), perms (R/W/X/LC/SC/SB bits minimum), sealed bit, otype, tag.
- Default capabilities (CSR): `PCC` (code), `DDC` (default data), `SCC` (shadow-call stack region).
- Memory checks: tag, perms, bounds, seal enforced on MA/MO for data, and via `PCC` for instruction fetch; violations raise a software interrupt and set `PSTATE.cause`.
- CFI: `BTP` alignment pads; `LR`/`SSP` shadow call stack for returns; no indirect branch prediction.

## Order of Implementation

1. CFI (BTP, LR/SSP shadow stack)
2. CSR (incl. default capabilities)
3. Software interrupts (faults, trap-on-overflow)
4. Interrupts
5. I/D caches
6. Atomics

## Pipeline Stages

1. IA: Instruction Address
2. IF: Instruction Fetch
3. ID: Instruction Decode
4. XT: Translate (µop expansion, CHERI operand prep)
5. EX: Execute
6. MA: Memory Address (CHERI check)
7. MO: Memory Operation
8. WB: Write Back

## Registers

- Data: `D0..D15` (16 × 24-bit). Encoding uses 4-bit register fields.
- Special (48-bit):
  - `LR`: link register
  - `SSP`: shadow stack pointer (CFI)
  - `PSTATE`: mode (K/U), `Z,N,C,V`, interrupt enable, trap cause
  - `PC`: program counter
- Capability: `CR0..CR3` (128-bit + tag). Used by loads/stores and capability ops.

IR (micro-architectural)

- `uimm` banks: 3 × 12-bit immediate banks loaded by `LUIui` and consumed by `..ui`/long-immediate control-flow forms.
  - Formation: 24-bit immediates use `{uimm[11:0], imm12}`; 48-bit absolute targets use `{uimm[35:0], imm12}` via three `LUIui` banks + `imm12`.
  - Lifetime: latched in EX, cleared on reset and on pipeline flush/branch so banks never cross control-flow boundaries; not architecturally visible.
  - Safety: using a `..ui` without loading the relevant bank(s) is specified to raise `UIMM_STATE` (checked semantics; implementation TBD in trap path).

SR vs CSR

- `LR`, `SSP`, `PSTATE`, and `PC` are architected 48-bit SRs for fast µop access.
- Kernel code observes/controls these via CSR mirrors at 0x000–0x009; user writes to these CSRs are ignored.

PC aliasing and SR file

- The core maintains `PC` as the IA/fetch pipeline register; SR exposes a logical `PC` alias for moves and addressing µops.
- Reads of `SR[PC]` reflect the in-flight pipeline `PC` (not the SR array cell).
- Writes to `PC` happen via control-flow (branch/jump/return) semantics, not by blindly storing to an SR cell. Micro-ops that appear to write `PC` translate to the appropriate branch target update.
- This keeps the architectural view with 4 SRs while letting the implementation hold `PC` in the pipeline for timing.

## Memory

- Physical 48-bit addressing, BAU=24-bit.
- All loads/stores are of the form `LD/ST #offs(CRs), DRt/DRs` with signed offsets. Hardware validates `CRs`.
- Shadow call stack uses a dedicated capability (CSR `SCC`) and `SSP` cursor. Calls push return addresses under CHERI bounds; `RET` pops and verifies.
- Future addressing note: when virtual memory is introduced, VA remains BAU=24 with 48-bit addressability. Physical addressing will map to a 6-bit port ID + 42-bit local address.

## Software Interrupts and Syscall

- `SYSCALL #idx`: enters kernel mode via a sealed entry capability (not via SWI).
- Software interrupts are used for faults and trap-on-overflow arithmetic. Fault classes include: OOB, tag clear, perm, sealed/type, exec perm, alignment, div-by-zero, arithmetic overflow.

## Modules

- testbench
- amber
- regdr, regsr, regcsr, regcr (capability reg file)
- mem (instruction and data)
- stage_ia, stage_if, stage_xt, stage_id, stage_ex, stage_ma, stage_mo, stage_wb
