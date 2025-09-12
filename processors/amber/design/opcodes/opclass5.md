# opclass 0101 CHERI Capability ops (moves, offset/bounds)

- ## CMOV CRs, CRt

| operation | µop           | isa        |
|-----------|---------------|------------|
| CRt = CRs | CMOV CRs, CRt | cap_move   |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0101         |
| [19-16]   | subop       | 0001         |
| [15-14]   | CRt         |              |
| [13-12]   | CRs         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## CINC DRs, CRt

| operation                                | µop             | isa             |
|------------------------------------------|-----------------|-----------------|
| CRt.cursor += sign_extend(DRs)           | CINC DRs, CRt   | cap_inc ds, ct  |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0101       |
| [19-16]   | subop       | 0010       |
| [15-14]   | CRt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## CINCv DRs, CRt (trap on bounds)

| operation                                | µop              | isa                        |
|------------------------------------------|------------------|----------------------------|
| CRt.cursor += sign_extend(DRs)           | CINCv DRs, CRt   | cap_inc.v ds, ct           |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0101       |
| [19-16]   | subop       | 0012       |
| [15-14]   | CRt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v | trap condition                                           |
|---|---|---|---|----------------------------------------------------------|
| - | - | - | - | if resulting cursor would be outside [base, base+len)    |

- ## CINCi #imm14, CRt

| operation                                | µop               | isa               |
|------------------------------------------|-------------------|-------------------|
| CRt.cursor += sign_extend(imm14)         | CINCi #imm14, CRt | cap_inc imm14, ct |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0101  |
| [19-16]   | subop       | 0011  |
| [15-14]   | CRt         |       |
| [13- 0]   | imm14       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## CINCiv #imm14, CRt (trap on bounds)

| operation                                | µop                | isa                         |
|------------------------------------------|--------------------|-----------------------------|
| CRt.cursor += sign_extend(imm14)         | CINCiv #imm14, CRt | cap_inc.v imm14, ct         |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0101  |
| [19-16]   | subop       | 0014  |
| [15-14]   | CRt         |       |
| [13- 0]   | imm14       |       |

| z | n | c | v | trap condition                                           |
|---|---|---|---|----------------------------------------------------------|
| - | - | - | - | if resulting cursor would be outside [base, base+len)    |

- ## CSETB DRs, CRt

| operation                           | µop               | isa                 |
|-------------------------------------|-------------------|---------------------|
| CRt.length = zero_extend(DRs)       | CSETB DRs, CRt    | cap_setbounds ds, ct |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0101       |
| [19-16]   | subop       | 0100       |
| [15-14]   | CRt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## CSETBv DRs, CRt (trap on invalid bounds)

| operation                           | µop               | isa                           |
|-------------------------------------|-------------------|-------------------------------|
| CRt.length = zero_extend(DRs)       | CSETBv DRs, CRt   | cap_setbounds.v ds, ct        |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0101       |
| [19-16]   | subop       | 0102       |
| [15-14]   | CRt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v | trap condition                                                   |
|---|---|---|---|------------------------------------------------------------------|
| - | - | - | - | zero length, or base+length overflow beyond 48-bit, or sealed   |

- ## CSETBi #imm14, CRt

| operation                     | µop                 | isa                  |
|-------------------------------|---------------------|----------------------|
| CRt.length = sign_extend(imm14) | CSETBi #imm14, CRt | cap_setbounds imm14  |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0101  |
| [19-16]   | subop       | 0101  |
| [15-14]   | CRt         |       |
| [13- 0]   | imm14       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## CSETBiv #imm14, CRt (trap on invalid bounds)

| operation                     | µop                 | isa                            |
|-------------------------------|---------------------|--------------------------------|
| CRt.length = sign_extend(imm14) | CSETBiv #imm14, CRt | cap_setbounds.v imm14, ct      |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0101  |
| [19-16]   | subop       | 0103  |
| [15-14]   | CRt         |       |
| [13- 0]   | imm14       |       |

| z | n | c | v | trap condition                                                   |
|---|---|---|---|------------------------------------------------------------------|
| - | - | - | - | zero length, or base+length overflow beyond 48-bit, or sealed   |

- ## CGETP CRs, DRt

| operation                  | µop               | isa           |
|----------------------------|-------------------|---------------|
| DRt = perms_mask(CRs)      | CGETP CRs, DRt    | cap_getperm   |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0101     |
| [19-16]   | subop       | 0110     |
| [15-12]   | DRt         |          |
| [11-10]   | CRs         |          |
| [ 9- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## CANDP DRs, CRt

| operation                  | µop              | isa             |
|----------------------------|------------------|-----------------|
| CRt.perms &= DRs           | CANDP DRs, CRt   | cap_andperm     |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0101       |
| [19-16]   | subop       | 0111       |
| [15-14]   | CRt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## CGETT CRs, DRt

| operation             | µop               | isa          |
|-----------------------|-------------------|--------------|
| DRt = tag(CRs) ? 1:0  | CGETT CRs, DRt    | cap_gettag   |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0101     |
| [19-16]   | subop       | 1000     |
| [15-12]   | DRt         |          |
| [11-10]   | CRs         |          |
| [ 9- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## CCLRT CRt

| operation      | µop          | isa            |
|----------------|--------------|----------------|
| clear tag CRt  | CCLRT CRt    | cap_cleartag   |

| bit range | description | value          |
|-----------|-------------|----------------|
| [23-20]   | opclass     | 0101           |
| [19-16]   | subop       | 1001           |
| [15-14]   | CRt         |                |
| [13- 0]   | reserved    | 00000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |
