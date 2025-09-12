# opclass 0100 CHERI Loads/Stores

Offsets are always signed. All addresses and lengths are in BAUs (24-bit words). `CRx` are capability registers; CHERI checks (tag/perms/bounds/seal) apply on every access.

- ## LDcso #imm10(CRs), DRt

| operation                               | µop                    | isa                   |
|-----------------------------------------|------------------------|-----------------------|
| DRt = (CRs.cursor + sign_extend(imm10)) | LDcso #imm10(CRs), DRt | load imm10(cs), dt    |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0000  |
| [15-12]   | DRt         |       |
| [11-10]   | CRs         |       |
| [ 9- 0]   | imm10       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## STcso DRs, #imm10(CRt)

| operation                               | µop                    | isa                    |
|-----------------------------------------|------------------------|------------------------|
| (CRt.cursor + sign_extend(imm10)) = DRs | STcso DRs, #imm10(CRt) | store ds, imm10(ct)    |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0001  |
| [15-14]   | CRt         |       |
| [13-10]   | DRs         |       |
| [ 9- 0]   | imm10       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## STui #imm12, (CRt)

| operation                      | µop                 | isa                        |
|--------------------------------|---------------------|----------------------------|
| (CRt.cursor) = {uimm, imm12}   | STui #imm12, (CRt)  | store imm24, (ct)          |
|                                |                     | macro                      |
|                                |                     |   LUIui #0, #imm24[23-12]  |
|                                |                     |   STui #imm24[11-0], (CRt) |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0010  |
| [15-14]   | CRt         |       |
| [13-12]   | reserved    | 00    |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## STsi #imm12, (CRt)

| operation                      | µop                 | isa                 |
|--------------------------------|---------------------|---------------------|
| (CRt.cursor) = sign_extend(imm12) | STsi #imm12, (CRt) | store.s imm12, (ct) |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0011  |
| [15-14]   | CRt         |       |
| [13-12]   | reserved    | 00    |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## CLDcso #imm10(CRs), CRt

| operation                                     | µop                      | isa                   |
|-----------------------------------------------|--------------------------|-----------------------|
| CRt = CAP_LOAD(CRs.cursor + sign_extend(imm10)) | CLDcso #imm10(CRs), CRt | load.cap imm10(cs), ct |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0100         |
| [19-16]   | subop       | 0100         |
| [15-14]   | CRt         |              |
| [13-12]   | CRs         |              |
| [11- 0]   | imm12       |              |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## CSTcso CRs, #imm10(CRt)

| operation                                      | µop                      | isa                    |
|------------------------------------------------|--------------------------|------------------------|
| CAP_STORE(CRt.cursor + sign_extend(imm10)) = CRs | CSTcso CRs, #imm10(CRt) | store.cap cs, imm10(ct) |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0100         |
| [19-16]   | subop       | 0101         |
| [15-14]   | CRt         |              |
| [13-12]   | CRs         |              |
| [11- 0]   | imm12       |              |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |
