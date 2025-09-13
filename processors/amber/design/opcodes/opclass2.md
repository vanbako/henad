# opclass 0010 Core ALU (reg–reg, signed flags)

- ## ADDsr DRs, DRt

| operation         | µop            | isa          |
|-------------------|----------------|--------------|
| signed DRt += DRs | ADDsr DRs, DRt | add.s ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0010     |
| [19-16]   | subop       | 0011     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | x | - | x |

- ## ADDsv DRs, DRt (trap on overflow)

| operation                           | µop            | isa                  |
|-------------------------------------|----------------|----------------------|
| signed DRt += DRs; if V→1 then trap | ADDsv DRs, DRt | add.sv ds, dt (trap) |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0010     |
| [19-16]   | subop       | 0111     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v | trap condition                |
|---|---|---|---|-------------------------------|
| x | x | - | x | if V=1, raise ARITH_OVF (SWI) |

- ## SUBsr DRs, DRt

| operation         | µop            | isa          |
|-------------------|----------------|--------------|
| signed DRt -= DRs | SUBsr DRs, DRt | sub.s ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0010     |
| [19-16]   | subop       | 0100     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | x | - | x |

- ## SUBsv DRs, DRt (trap on overflow)

| operation                           | µop            | isa                  |
|-------------------------------------|----------------|----------------------|
| signed DRt -= DRs; if V→1 then trap | SUBsv DRs, DRt | sub.sv ds, dt (trap) |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0010     |
| [19-16]   | subop       | 1000     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v | trap condition                |
|---|---|---|---|-------------------------------|
| x | x | - | x | if V=1, raise ARITH_OVF (SWI) |

- ## NEGsr DRt

| operation         | µop       | isa    |
|-------------------|-----------|--------|
| signed DRt = -DRt | NEGsr DRt | neg dt |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0010         |
| [19-16]   | subop       | 0101         |
| [15-12]   | DRt         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| x | x | - | x |

- ## NEGsv DRt (trap on overflow)

| operation                                | µop        | isa             |
|------------------------------------------|------------|-----------------|
| signed DRt = -DRt; if overflow then trap | NEGsv DRt  | neg.v dt (trap) |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0010         |
| [19-16]   | subop       | 0110         |
| [15-12]   | DRt         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v | trap condition                                  |
|---|---|---|---|-------------------------------------------------|
| x | x | - | x | if DRt was INT24_MIN then V=1 → ARITH_OVF (SWI) |

- ## SHRsr DRs, DRt

| operation               | µop            | isa                       |
|-------------------------|----------------|---------------------------|
| signed DRt >>= DRs[4:0] | SHRsr DRs, DRt | arithm_shift_right ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0010     |
| [19-16]   | subop       | 1011     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | x | - | x |

- ## SHRsrv DRs, DRt (trap on range)

| operation               | µop             | isa                         |
|-------------------------|-----------------|-----------------------------|
| signed DRt >>= DRs[4:0] | SHRsrv DRs, DRt | arithm_shift_right.v ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0010     |
| [19-16]   | subop       | 1010     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v | trap condition                                  |
|---|---|---|---|-------------------------------------------------|
| x | x | - | x | if DRs[4:0] >= 24 → ARITH_RANGE (SWI), no write |

- ## CMPsr DRs, DRt

| operation               | µop            | isa           |
|-------------------------|----------------|---------------|
| signed compare DRs, DRt | CMPsr DRs, DRt | comp.s ds, dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0010     |
| [19-16]   | subop       | 1101     |
| [15-12]   | DRt         |          |
| [11- 8]   | DRs         |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| x | x | - | x |

- ## TSTsr DRt

| operation       | µop       | isa       |
|-----------------|-----------|-----------|
| signed DRt test | TSTsr DRt | test.s dt |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0010         |
| [19-16]   | subop       | 1110         |
| [15-12]   | DRt         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| x | x | - | - |
