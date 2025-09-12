# Amber CSR Map (BAU=24, addr=48)

This document enumerates architectural CSRs, PSTATE fields, capability-default CSR windows, and trap-cause codes. CSRRD/CSRWR operate on 24-bit words. Kernel-only indicates writes require kernel mode; reads may be permitted in user mode unless noted.

## Conventions

- CSR address space: 12-bit (`csr12` in ISA), range 0x000–0xFFF.
- Access width: 24-bit per CSR access. 48-bit values are split into `*_LO` (bits 23:0) and `*_HI` (bits 47:24).
- Capability windows expose 48-bit fields as pairs; tag and attributes are provided separately.

## Core Status / Control (0x000–0x00F)

- 0x000 PSTATE_LO (R:U/K, W:K) — PSTATE bits 23:0
- 0x001 PSTATE_HI (R:U/K, W:K) — PSTATE bits 47:24

PSTATE layout (48-bit)

- [0] Z: zero flag
- [1] N: negative flag
- [2] C: carry flag
- [3] V: overflow flag
- [4] IE: interrupt enable (reserved for future)
- [5] TPE: trap-pending (sticky until cleared by K)
- [7:6] reserved
- [8] MODE: 0=kernel, 1=user
- [15:9] reserved
- [23:16] TRAP_CAUSE: cause code (see table)
- [39:24] TRAP_INFO: optional auxiliary info (e.g., subcause, reg index)
- [47:40] reserved

Notes

- User-mode writes to PSTATE are ignored except for flag-affecting instructions; full writes require K-mode.
- TRAP_CAUSE/INFO are written by hardware on fault/interrupt entry; K-mode clears them after handling.

## Async Int24 Math (0x010–0x017)

- 0x010 MATH_CTRL (R/W:U/K): bit0 START; bits[4:1] OP
- 0x011 MATH_STATUS (R:U/K): bit0 READY; bit1 BUSY; bit2 DIV0
- 0x012 MATH_OPA (R/W:U/K)
- 0x013 MATH_OPB (R/W:U/K)
- 0x014 MATH_RES0 (R:U/K)
- 0x015 MATH_RES1 (R:U/K)
- 0x016 MATH_OPC (R/W:U/K)

## Default Capability Windows

All writes are K-only. Reads may be allowed in U-mode. Each window provides:

- `*_BASE_LO` (48-bit base, low word)
- `*_BASE_HI` (base, high word)
- `*_LEN_LO`  (48-bit length, low)
- `*_LEN_HI`  (length, high)
- `*_CUR_LO`  (48-bit cursor, low)
- `*_CUR_HI`  (cursor, high)
- `*_PERMS`   (permission bits)
- `*_ATTR`    (bit0 SEALED; bits[23:8] OTYPE[15:0])
- `*_TAG`     (RO: 1=tagged, 0=untagged; writing 0 clears tag; writing 1 requires K and may be ignored if invariants not met)

### DDC (Default Data Capability) — 0x020–0x028

- 0x020 DDC_BASE_LO, 0x021 DDC_BASE_HI
- 0x022 DDC_LEN_LO,  0x023 DDC_LEN_HI
- 0x024 DDC_CUR_LO,  0x025 DDC_CUR_HI
- 0x026 DDC_PERMS
- 0x027 DDC_ATTR
- 0x028 DDC_TAG

### PCC (Program Counter Capability) — 0x030–0x038

- 0x030 PCC_BASE_LO, 0x031 PCC_BASE_HI
- 0x032 PCC_LEN_LO,  0x033 PCC_LEN_HI
- 0x034 PCC_CUR_LO,  0x035 PCC_CUR_HI
- 0x036 PCC_PERMS (X must be set for fetch)
- 0x037 PCC_ATTR
- 0x038 PCC_TAG

### SCC (Shadow Call Capability) — 0x040–0x048

- 0x040 SCC_BASE_LO, 0x041 SCC_BASE_HI
- 0x042 SCC_LEN_LO,  0x043 SCC_LEN_HI
- 0x044 SCC_CUR_LO,  0x045 SCC_CUR_HI (mirrors SSP on call/ret)
- 0x046 SCC_PERMS
- 0x047 SCC_ATTR
- 0x048 SCC_TAG

Notes

- Writes that would violate CHERI invariants (e.g., sealed writes; base+len overflow; perms widening in U-mode) cause a software interrupt with cause `CAP_CFG` and are not applied.
- Changing `PCC` can redirect fetch; writes take effect only in K-mode and may pipeline-synchronize.

## Trap Cause Codes

Encoded into `PSTATE.TRAP_CAUSE` (bits [23:16]). Suggested values:

- 0x00 NONE: no trap
- 0x01 ARITH_OVF: signed overflow (ADD/SUB/NEG trap variants)
- 0x02 ARITH_RANGE: shift count out of range (≥ 24)
- 0x03 DIV_ZERO: divide-by-zero
- 0x10 CAP_OOB: out-of-bounds access
- 0x11 CAP_TAG: tag cleared (invalid)
- 0x12 CAP_PERM: lacking permission (R/W/X/LC/SC)
- 0x13 CAP_SEAL: sealed/type violation
- 0x14 CAP_ALIGN: misaligned access
- 0x15 EXEC_PERM: fetch without X permission in PCC
- 0x20 UIMM_STATE: invalid/absent `LUIui` bank for a `..ui` instruction
- 0x30 CAP_CFG: invalid capability CSR write (bounds/perms/seal rules)

`PSTATE.TRAP_INFO` may contain auxiliary data (implementation-defined), e.g., the offending CR index, DR index, or low 8 bits of the CSR address.

## Notes on Access Control

- CSRs affecting privilege, capabilities, or control flow are kernel-write-only.
- User-mode writes to such CSRs raise `CAP_CFG` (or are ignored) per implementation choice.
- Reads of default capability windows in U-mode are permitted for discoverability but may be masked (e.g., perms masked to user-visible subset).

