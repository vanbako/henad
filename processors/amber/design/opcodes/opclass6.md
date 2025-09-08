# opclass 0110 Address-register ALU & moves

- ## MOVAur DRs, ARt, H|L

| operation               | µop                   | isa                |
|-------------------------|-----------------------|--------------------|
| if (L) ARt[23: 0] = DRs | MOVAur DRs, ARt, H\|L | copy.[h\|l] ds, at |
| if (H) ARt[47:24] = DRs |                       |                    |

| bit range | description | value     | comment  |
|-----------|-------------|-----------|----------|
| [23-20]   | opclass     | 0110      |          |
| [19-16]   | subop       | 0001      |          |
| [15-14]   | ARt         |           |          |
| [13-10]   | DRs         |           |          |
| [ 9   ]   | H\|L        |           | H=1, L=0 |
| [ 8- 0]   | reserved    | 000000000 |          |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## MOVDur ARs, DRt, H|L

| operation               | µop                   | isa                |
|-------------------------|-----------------------|--------------------|
| if (L) DRt = ARs[23: 0] | MOVDur ARs, DRt, H\|L | copy.[h\|l] as, dt |
| if (H) DRt = ARs[47:24] |                       |                    |

| bit range | description | value     | comment  |
|-----------|-------------|-----------|----------|
| [23-20]   | opclass     | 0110      |          |
| [19-16]   | subop       | 0010      |          |
| [15-12]   | DRt         |           |          |
| [11-10]   | ARs         |           |          |
| [ 9   ]   | H\|L        |           | H=1, L=0 |
| [ 8- 0]   | reserved    | 000000000 |          |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## ADDAur DRs, ARt

| operation               | µop             | isa          |
|-------------------------|-----------------|--------------|
| ARt += zero_extend(DRs) | ADDAur DRs, ARt | add.u ds, at |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0110       |
| [19-16]   | subop       | 0011       |
| [15-14]   | ARt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## SUBAur DRs, ARt

| operation               | µop             | isa          |
|-------------------------|-----------------|--------------|
| ARt -= zero_extend(DRs) | SUBAur DRs, ARt | sub.u ds, at |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0110       |
| [19-16]   | subop       | 0100       |
| [15-14]   | ARt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## ADDAsr DRs, ARt

| operation               | µop             | isa          |
|-------------------------|-----------------|--------------|
| ARt += sign_extend(DRs) | ADDAsr DRs, ARt | add.s ds, at |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0110       |
| [19-16]   | subop       | 0101       |
| [15-14]   | ARt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## SUBAsr DRs, ARt

| operation               | µop             | isa          |
|-------------------------|-----------------|--------------|
| ARt -= sign_extend(DRs) | SUBAsr DRs, ARt | sub.s ds, at |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0110       |
| [19-16]   | subop       | 0110       |
| [15-14]   | ARt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## ADDAsi #imm14, ARt

| operation                 | µop                | isa             |
|---------------------------|--------------------|-----------------|
| ARt += sign_extend(imm14) | ADDAsi #imm14, ARt | add.s imm14, at |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0110  |
| [19-16]   | subop       | 0111  |
| [15-14]   | ARt         |       |
| [13- 0]   | imm14       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## SUBAsi #imm14, ARt

| operation                 | µop                | isa             |
|---------------------------|--------------------|-----------------|
| ARt -= sign_extend(imm14) | SUBAsi #imm14, ARt | sub.s imm14, at |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0110  |
| [19-16]   | subop       | 1000  |
| [15-14]   | ARt         |       |
| [13- 0]   | imm14       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## LEAso ARs+#imm12, ARt

| operation                      | µop                   | isa                       |
|--------------------------------|-----------------------|---------------------------|
| ARt = ARs + sign_extend(imm12) | LEAso ARs+#imm12, ARt | copy_offset imm12, as, at |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0110  |
| [19-16]   | subop       | 1001  |
| [15-14]   | ARt         |       |
| [13-12]   | ARs         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## ADRAso PC+#imm14, ARt

| operation                     | µop                   | isa                       |
|-------------------------------|-----------------------|---------------------------|
| ARt = PC + sign_extend(imm14) | ADRAso PC+#imm14, ARt | copy_offset imm14, pc, at |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0110  |
| [19-16]   | subop       | 1010  |
| [15-14]   | ARt         |       |
| [13- 0]   | imm14       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## MOVAui #imm12, ARt

| operation                                           | µop                | isa                        |
|-----------------------------------------------------|--------------------|----------------------------|
| ARt = {uimm[35-24], uimm[23-12], uimm[11-0], imm12} | MOVAui #imm12, ARt | copy.u imm48, at           |
|                                                     |                    | macro                      |
|                                                     |                    |   LUIui  #2, #imm48[47-36] |
|                                                     |                    |   LUIui  #1, #imm48[35-24] |
|                                                     |                    |   LUIui  #0, #imm48[23-12] |
|                                                     |                    |   MOVAui #imm48[11-0], ARt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0110  |
| [19-16]   | subop       | 1011  |
| [15-14]   | ARt         |       |
| [13-12]   | reserved    | 00    |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## CMPAur ARs, ARt

| operation                 | µop             | isa           |
|---------------------------|-----------------|---------------|
| unsigned compare ARs, ARt | CMPAur ARs, ARt | comp.u as, at |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0110         |
| [19-16]   | subop       | 1101         |
| [15-14]   | ARt         |              |
| [13-12]   | ARs         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## TSTAur ARt

| operation | µop        | isa       |
|-----------|------------|-----------|
| ARt == 0  | TSTAur ARt | test.u at |

| bit range | description | value          |
|-----------|-------------|----------------|
| [23-20]   | opclass     | 0110           |
| [19-16]   | subop       | 1110           |
| [15-14]   | ARt         |                |
| [13- 0]   | reserved    | 00000000000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |
