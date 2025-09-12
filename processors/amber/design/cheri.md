# CHERI for Amber (24-bit BAU, 48-bit addressing)

## Goals

- Spatial memory safety with capabilities on a tiny in-order core.
- Keep Amber’s BAU (24-bit) and 48-bit addressing model intact.
- No MMU/virt and no speculation; checks happen before side effects.

## Capability Model

- Width: 128-bit capability plus an architectural tag bit.
- Fields (conceptual):
  - `base` (48): BAU address of the region start
  - `length` (48): BAU length of the region
  - `cursor` (48): BAU address for the current access (relative to base)
  - `perms`: includes at least `R` (read), `W` (write), `X` (execute), `LC` (load capability), `SC` (store capability), `SB` (setbounds)
  - `sealed` bit and `otype`
  - `tag`: valid/invalid (cleared on non-cap stores except where `SC` is set)

Notes

- A compressed internal encoding is allowed; the architectural view is as above.
- All addresses and lengths are in BAUs (24-bit words). Sub-BAU addressing is not supported.

## Register Sets

- Data registers: `D0..D15` (16 × 24-bit).
- Special registers (48-bit): `LR`, `SSP`, `PSTATE`, `PC`.
- Capability registers: `CR0..CR3` (128-bit + tag).
  - Default capabilities (CSR): `PCC` (code), `DDC` (default data), `SCC` (shadow-call stack).

## Capability Checks

Performed in MA/MO (memory) and fetch path (via `PCC`):

- Tag must be set.
- `cursor + access_width` within `[base, base+length)` (BAU-granular).
- `perms` must grant the operation (`R` for load, `W` for store, `LC/SC` for cap load/store).
- Sealed/type rules:
  - Data access on sealed caps is a fault.
  - `CSEAL`/`CUNSEAL` require `SB`/`S` perms and appropriate `otype`.
- Alignment: BAU aligned (24-bit); double-BAU ops require even BAU index.
- On violation: raise software interrupt; write cause into `PSTATE.cause`.

## Default Capabilities

- `PCC`: bounds the executable image. Instruction fetch must be within `PCC` and `X`-permitted.
- `DDC`: fallback data capability when an instruction does not name a `CRs` (Amber’s ISA names one explicitly in LD/ST).
- `SCC`: bounds the shadow call stack region; used by call/return micro-ops with `SSP` as the cursor.

## ISA Overview (CHERI-relevant)

- Loads/Stores (opclass 0100): `LDcso #offs(CRs), DRt` and `STcso DRs, #offs(CRt)`.
  - Signed offsets; BAU-granular; `perms.R`/`perms.W` required.
  - Capability loads/stores: `CLDcso`/`CSTcso` use `LC`/`SC` perms and move a full capability to/from `CRt`.
- Capability ops (opclass 0101): move/manipulate capabilities.
  - `CMOV CRs, CRt` — move capability (tag-preserving)
  - `CINC CRs, DRu, CRt` — `CRt.cursor = CRs.cursor + sign_extend(DRu)`
  - `CINCi #imm12, CRt` — immediate variant
  - `CSETB CRs, DRu, CRt` — set bounds to a length (perms `SB`)
  - `CSETBi #imm12, CRt` — immediate variant
  - `CGETP CRs, DRt` — extract perms mask to `DRt`
  - `CANDP DRs, CRt` — and perm mask (K-only if increasing perms)
  - `CSEAL CRs, CRseal, CRt` — seal with otype (needs `S`)
  - `CUNSEAL CRs, CRseal, CRt` — unseal (needs `S`)
  - `CGETT CRs, DRt` — get tag (1/0)
  - `CCLRT CRt` — clear tag (invalidate)
- Control flow (opclass 0110): `JSR/RET` leverage `SCC` and `SSP` for the shadow stack, with `BTP` pads.
  - Indirect jumps/calls must be within a valid executable capability (via `PCC`); otherwise a capability-exec fault.
- Arithmetic trap-on-overflow: variants of ADD/SUB (signed) raise a software interrupt if `V=1`.

## Faults (Software Interrupt Causes)

- `CAP_OOB`: out-of-bounds access
- `CAP_TAG`: tag cleared (invalid)
- `CAP_PERM`: missing permission (`R/W/X/LC/SC`)
- `CAP_SEAL`: sealed/type violation
- `CAP_ALIGN`: misalignment for the access width
- `ARITH_OVF`: signed overflow (trap-on-overflow variants)
- `DIV_ZERO`: divide-by-zero
- `EXEC_PERM`: fetch without execute permission in `PCC`
 - `ARITH_RANGE`: shift count out of range (≥ 24)
 - `UIMM_STATE`: use of `..ui` instruction without valid `LUIui` bank state

The exact encoding of causes is reported in `PSTATE.cause` and surfaced via the software interrupt vector.

## Syscall vs. Software Interrupt

- Syscall: `SYSCALL #idx` transfers to kernel via a sealed entry capability and does not use the SWI path.
- Software interrupts are reserved for faults and explicit trap-on-overflow arithmetic.

## Encoding Notes

- To keep encoding compact and compatible with existing field widths, `CR` indices reuse the former `AR` 2-bit fields (`CR0..CR3`). The design can be extended in a future encoding revision if more `CR` are needed.
- DR fields remain 4 bits, but `D15` is reserved and must encode zero in well-formed programs (hardware may trap on `D15`).
