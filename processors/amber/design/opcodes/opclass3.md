# opclass 0011 Core ALU (imm, signed flags / PC-rel)

- ## MOVsi #imm12, DRt

| operation                | µop               | isa              |
|--------------------------|-------------------|------------------|
| DRt = sign_extend(imm12) | MOVsi #imm12, DRt | copy.s imm12, dt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0011  |
| [19-16]   | subop       | 0001  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | x | - | - |

- ## MCCsi CC, #imm8, DRt

| operation                       | µop                  | isa                       |
|---------------------------------|----------------------|---------------------------|
| if (CC) DRt = sign_extend(imm8) | MCCsi CC, #imm8, DRt | cond_copy.s.[cc] imm8, dt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0011  |
| [19-16]   | subop       | 0010  |
| [15-12]   | DRt         |       |
| [11- 8]   | CC          |       |
| [ 7- 0]   | imm8        |       |

| z | n | c | v | comment              |
|---|---|---|---|----------------------|
| x | - | - | - | only if move happens |

- ## ADDsi #imm12, DRt

| operation                        | µop               | isa             |
|----------------------------------|-------------------|-----------------|
| signed DRt += sign_extend(imm12) | ADDsi #imm12, DRt | add.s imm12, dt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0011  |
| [19-16]   | subop       | 0011  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | x | - | x |

- ## ADDsiv #imm12, DRt (trap on overflow)

| operation                                     | µop                 | isa                     |
|-----------------------------------------------|---------------------|-------------------------|
| signed DRt += sign_extend(imm12); if V→1 trap | ADDsiv #imm12, DRt  | add.sv imm12, dt (trap) |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0011  |
| [19-16]   | subop       | 0110  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v | trap condition                |
|---|---|---|---|-------------------------------|
| x | x | - | x | if V=1, raise ARITH_OVF (SWI) |

- ## SUBsi #imm12, DRt

| operation                        | µop               | isa             |
|----------------------------------|-------------------|-----------------|
| signed DRt -= sign_extend(imm12) | SUBsi #imm12, DRt | sub.s imm12, dt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0011  |
| [19-16]   | subop       | 0100  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | x | - | x |

- ## SUBsiv #imm12, DRt (trap on overflow)

| operation                                     | µop                | isa                     |
|-----------------------------------------------|--------------------|-------------------------|
| signed DRt -= sign_extend(imm12); if V→1 trap | SUBsiv #imm12, DRt | sub.sv imm12, dt (trap) |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0011  |
| [19-16]   | subop       | 0111  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v | trap condition                |
|---|---|---|---|-------------------------------|
| x | x | - | x | if V=1, raise ARITH_OVF (SWI) |

- ## SHRsi #imm5, DRt

| operation           | µop              | isa                         |
|---------------------|------------------|-----------------------------|
| signed DRt >>= imm5 | SHRsi #imm5, DRt | arithm_shift_right imm5, dt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0011    |
| [19-16]   | subop       | 1011    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v | comment                                       |
|---|---|---|---|-----------------------------------------------|
| x | x | - | x | only if imm5 is non-zero, otherwise unchanged |

- ## SHRsiv #imm5, DRt (trap on range)

| operation           | µop               | isa                           |
|---------------------|-------------------|-------------------------------|
| signed DRt >>= imm5 | SHRsiv #imm5, DRt | arithm_shift_right.v imm5, dt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0011    |
| [19-16]   | subop       | 1100    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v | trap condition                              |
|---|---|---|---|---------------------------------------------|
| x | x | - | x | if imm5 >= 24 → ARITH_RANGE (SWI), no write |

- ## CMPsi #imm12, DRt

| operation                              | µop               | isa              |
|----------------------------------------|-------------------|------------------|
| signed compare sign_extend(imm12), DRt | CMPsi #imm12, DRt | comp.s imm12, dt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0011  |
| [19-16]   | subop       | 1101  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | x | - | x |
