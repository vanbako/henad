# opclass 0000 Core ALU (reg–reg, unsigned flags)

- ## NOP

| operation    | µop | isa     |
|--------------|-----|---------|
| no operation | NOP | no_oper |

| bit range | description | value            |
|-----------|-------------|------------------|
| [23-20]   | opclass     | 0000             |
| [19-16]   | subop       | 0000             |
| [15- 0]   | reserved    | 0000000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## MOVur DRs, DRt

| operation | µop            | isa         |
|-----------|----------------|-------------|
| DRt = DRs | MOVur DRs, DRt | copy ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 0001     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## MCCur CC, DRs, DRt

| operation         | µop                | isa                   |
|-------------------|--------------------|-----------------------|
| if (CC) DRt = DRs | MCCur CC, DRs, DRt | cond_copy.[cc] ds, dt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0000  |
| [19-16]   | subop       | 0010  |
| [15-12]   | DRt         |       |
| [11- 8]   | DRs         |       |
| [ 7- 4]   | CC          |       |
| [ 3- 0]   | reserved    | 0000  |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## ADDur DRs, DRt

| operation           | µop            | isa          |
|---------------------|----------------|--------------|
| unsigned DRt += DRs | ADDur DRs, DRt | add.u ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 0011     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## SUBur DRs, DRt

| operation           | µop            | isa          |
|---------------------|----------------|--------------|
| unsigned DRt -= DRs | SUBur DRs, DRt | sub.u ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 0100     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## NOTur DRt

| operation  | µop       | isa    |
|------------|-----------|--------|
| DRt ~= DRt | NOTur DRt | not dt |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0000         |
| [19-16]   | subop       | 0101         |
| [15-12]   | DRt         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## ANDur DRs, DRt

| operation  | µop            | isa        |
|------------|----------------|------------|
| DRt &= DRs | ANDur DRs, DRt | and ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 0110     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## ORur DRs, DRt

| operation   | µop           | isa       |
|-------------|---------------|-----------|
| DRt \|= DRs | ORur DRs, DRt | or ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 0111     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## XORur DRs, DRt

| operation  | µop            | isa        |
|------------|----------------|------------|
| DRt ^= DRs | XORur DRs, DRt | xor ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 1000     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## SHLur DRs, DRt

| operation        | µop            | isa               |
|------------------|----------------|-------------------|
| DRt <<= DRs[4:0] | SHLur DRs, DRt | shift_left ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 1001     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

Trap note

- To avoid undefined behaviour from out-of-range shifts, when `DRs[4:0] >= 24` a software interrupt with cause `ARITH_RANGE` is raised and the shift is not performed.

- ## ROLur DRs, DRt

| operation         | µop            | isa             |
|-------------------|----------------|-----------------|
| DRt <<<= DRs[4:0] | ROLur DRs, DRt | rot_left ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 1010     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## SHRur DRs, DRt

| operation        | µop            | isa                |
|------------------|----------------|--------------------|
| DRt >>= DRs[4:0] | SHRur DRs, DRt | shift_right ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 1011     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

Trap note

- To avoid undefined behaviour from out-of-range shifts, when `DRs[4:0] >= 24` a software interrupt with cause `ARITH_RANGE` is raised and the shift is not performed.

- ## RORur DRs, DRt

| operation         | µop            | isa              |
|-------------------|----------------|------------------|
| DRt >>>= DRs[4:0] | RORur DRs, DRt | rot_right ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 1100     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## CMPur DRs, DRt

| operation                 | µop            | isa           |
|---------------------------|----------------|---------------|
| unsigned compare DRs, DRt | CMPur DRs, DRt | comp.u ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0000     |
| [19-16]   | subop       | 1101     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ## TSTur DRt

| operation         | µop       | isa       |
|-------------------|-----------|-----------|
| unsigned DRt == 0 | TSTur DRt | test.u dt |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0000         |
| [19-16]   | subop       | 1110         |
| [15-12]   | DRt         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |
