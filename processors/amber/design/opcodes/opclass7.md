# opclass 0111 Stack helpers (via CR)

- ## PUSHur DRs, (CRt)

| operation       | µop                  | isa            |
|-----------------|----------------------|----------------|
| --1(CRt) = DRs  | SUBAsi #1, CRt       | push ds, (ct)  |
|                 | STcso  DRs, #0(CRt)  |                |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0111       |
| [19-16]   | subop       | 0000       |
| [15-14]   | CRt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## PUSHAur CRs, (CRt)

| operation       | µop                   | isa            |
|-----------------|-----------------------|----------------|
| --2(CRt) = CRs  | SUBAsi #2, CRt        | push cs, (ct)  |
|                 | CSTcso CRs, #0(CRt)   |                |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0111         |
| [19-16]   | subop       | 0001         |
| [15-14]   | CRt         |              |
| [13-12]   | CRs         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## POPur (CRs), DRt

| operation       | µop                   | isa          |
|-----------------|-----------------------|--------------|
| DRt = (CRs)1++  | ADDAsi #1, CRs        | pop (cs), dt |
|                 | LDcso  #-1(CRs), DRt  |              |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0111       |
| [19-16]   | subop       | 0010       |
| [15-12]   | DRt         |            |
| [11-10]   | CRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## POPAur (CRs), CRt

| operation       | µop                    | isa          |
|-----------------|------------------------|--------------|
| CRt = (CRs)2++  | ADDAsi #2, CRs         | pop (cs), ct |
|                 | CLDcso #-2(CRs), CRt   |              |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0111         |
| [19-16]   | subop       | 0011         |
| [15-14]   | CRt         |              |
| [13-12]   | CRs         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |
