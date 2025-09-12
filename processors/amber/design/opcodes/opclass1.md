# opclass 0001 Core ALU (imm/uimm, unsigned flags)

UI/imm bank safety

- All `..ui` forms consume the current `uimm` banks set by `LUIui`. If the banks are invalid/stale (no prior `LUIui` in the atomic window), the core raises a software interrupt with cause `UIMM_STATE`. This removes the undefined behaviour previously noted and makes `[OPC]ui` checked by default.

- ## LUIui #x, #imm12

| operation                | µop              | isa                     |
|--------------------------|------------------|-------------------------|
| case (x)                 | LUIui #x, #imm12 | load_upper_imm x, imm12 |
|   0: uimm[11- 0] = imm12 |                  |                         |
|   1: uimm[23-12] = imm12 |                  |                         |
|   2: uimm[35-24] = imm12 |                  |                         |
| endcase                  |                  |                         |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0000  |
| [15-14]   | x           |       |
| [13-12]   | reserved    | 00    |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## MOVui #imm12, DRt

| operation                 | µop               | isa                       |
|---------------------------|-------------------|---------------------------|
| DRt = {uimm[11-0], imm12} | MOVui #imm12, DRt | copy.u imm24, dt          |
|                           |                   | macro                     |
|                           |                   |   LUIui #0, #imm24[23-12] |
|                           |                   |   MOVui #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0001  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## ADDui #imm12, DRt

| operation                           | µop               | isa                       |
|-------------------------------------|-------------------|---------------------------|
| unsigned DRt += {uimm[11-0], imm12} | ADDui #imm12, DRt | add.u imm24, dt           |
|                                     |                   | macro                     |
|                                     |                   |   LUIui #0, #imm24[23-12] |
|                                     |                   |   ADDui #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0011  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## SUBui #imm12, DRt

| operation                           | µop               | isa                       |
|-------------------------------------|-------------------|---------------------------|
| unsigned DRt -= {uimm[11-0], imm12} | SUBui #imm12, DRt | sub.u imm24, dt           |
|                                     |                   | macro                     |
|                                     |                   |   LUIui #0, #imm24[23-12] |
|                                     |                   |   SUBui #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0100  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## ANDui #imm12, DRt

| operation                  | µop               | isa                       |
|----------------------------|-------------------|---------------------------|
| DRt &= {uimm[11-0], imm12} | ANDui #imm12, DRt | and imm24, dt             |
|                            |                   | macro                     |
|                            |                   |   LUIui #0, #imm24[23-12] |
|                            |                   |   ANDui #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0110  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## ORui #imm12, DRt

| operation                   | µop              | isa                       |
|-----------------------------|------------------|---------------------------|
| DRt \|= {uimm[11-0], imm12} | ORui #imm12, DRt | or imm24, dt              |
|                             |                  | macro                     |
|                             |                  |   LUIui #0, #imm24[23-12] |
|                             |                  |   ORui  #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0111  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## XORui #imm12, DRt

| operation                  | µop               | isa                       |
|----------------------------|-------------------|---------------------------|
| DRt ^= {uimm[11-0], imm12} | XORui #imm12, DRt | xor imm24, dt             |
|                            |                   | macro                     |
|                            |                   |   LUIui #0, #imm24[23-12] |
|                            |                   |   XORui #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 1000  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## SHLui #imm5, DRt

| operation    | µop              | isa                 |
|--------------|------------------|---------------------|
| DRt <<= imm5 | SHLui #imm5, DRt | shift_left imm5, dt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1001    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## SHLuiv #imm5, DRt (trap on range)

| operation    | µop                | isa                      |
|--------------|--------------------|--------------------------|
| DRt <<= imm5 | SHLuiv #imm5, DRt  | shift_left.v imm5, dt    |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1110    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v | trap condition                             |
|---|---|---|---|--------------------------------------------|
| x | - | x | - | if imm5 >= 24 → ARITH_RANGE (SWI), no write |

- ## ROLui #imm5, DRt

| operation     | µop              | isa               |
|---------------|------------------|-------------------|
| DRt <<<= imm5 | ROLui #imm5, DRt | rot_left imm5, dt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1010    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## SHRui #imm5, DRt

| operation    | µop              | isa                  |
|--------------|------------------|----------------------|
| DRt >>= imm5 | SHRui #imm5, DRt | shift_right imm5, dt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1011    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## SHRuiv #imm5, DRt (trap on range)

| operation    | µop                | isa                      |
|--------------|--------------------|--------------------------|
| DRt >>= imm5 | SHRuiv #imm5, DRt  | shift_right.v imm5, dt   |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1111    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v | trap condition                             |
|---|---|---|---|--------------------------------------------|
| x | - | x | - | if imm5 >= 24 → ARITH_RANGE (SWI), no write |

- ## RORui #imm5, DRt

| operation     | µop              | isa                |
|---------------|------------------|--------------------|
| DRt >>>= imm5 | RORui #imm5, DRt | rot_right imm5, dt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1100    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## CMPui #imm12, DRt

| operation                                 | µop               | isa                       |
|-------------------------------------------|-------------------|---------------------------|
| unsigned compare {uimm[11-0], imm12}, DRt | CMPui #imm12, DRt | comp.u imm24, dt          |
|                                           |                   | macro                     |
|                                           |                   |   LUIui #0, #imm24[23-12] |
|                                           |                   |   CMPui #imm24[11-0], DRt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1101    |
| [15-12]   | DRt         |         |
| [11- 0]   | imm12       |         |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |
