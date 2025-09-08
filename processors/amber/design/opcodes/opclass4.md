# opclass 0100 Loads/Stores

offsets are always signed

- ## LDso #imm10(ARs), DRt

| operation                        | µop                   | isa                |
|----------------------------------|-----------------------|--------------------|
| DRt = (ARs + sign_extend(imm10)) | LDso #imm10(ARs), DRt | load imm10(as), dt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0000  |
| [15-12]   | DRt         |       |
| [11-10]   | ARs         |       |
| [ 9- 0]   | imm10       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## STso DRs, #imm10(ARt)

| operation                        | µop                   | isa                 |
|----------------------------------|-----------------------|---------------------|
| (ARt + sign_extend(imm10)) = DRs | STso DRs, #imm10(ARt) | store ds, imm10(at) |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0001  |
| [15-14]   | ARt         |       |
| [13-10]   | DRs         |       |
| [ 9- 0]   | imm10       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## STui #imm12, (ARt)

| operation                   | µop                | isa                         |
|-----------------------------|--------------------|-----------------------------|
| (ARt) = {uimm[11-0], imm12} | STui #imm12, (ARt) | store imm24, (at)           |
|                             |                    | macro                       |
|                             |                    |   LUIui #0, #imm24[23-12]   |
|                             |                    |   STui  #imm24[11-0], (ARt) |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0010  |
| [15-14]   | ARt         |       |
| [13-12]   | reserved    | 00    |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## STsi #imm12, (ARt)

| operation                  | µop                | isa                 |
|----------------------------|--------------------|---------------------|
| (ARt) = sign_extend(imm12) | STsi #imm12, (ARt) | store.s imm12, (at) |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0011  |
| [15-14]   | ARt         |       |
| [13-12]   | reserved    | 00    |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## LDAso #imm12(ARs), ARt

| operation                        | µop                    | isa                |
|----------------------------------|------------------------|--------------------|
| ARt = (ARs + sign_extend(imm12)) | LDAso #imm12(ARs), ARt | load imm12(as), at |
| comment: signed + operation      |                        |                    |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0100  |
| [15-14]   | ARt         |       |
| [13-12]   | ARs         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## STAso ARs, #imm12(ARt)

| operation                        | µop                    | isa                 |
|----------------------------------|------------------------|---------------------|
| (ARt + sign_extend(imm12)) = ARs | STAso ARs, #imm12(ARt) | store as, imm12(at) |
| comment: signed + operation      |                        |                     |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0101  |
| [15-14]   | ARt         |       |
| [13-12]   | ARs         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |
