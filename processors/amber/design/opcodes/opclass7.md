# opclass 0111 Stack helpers

- ## PUSHur DRs, (ARt)

| operation      | µop                 | isa           |
|----------------|---------------------|---------------|
| --1(ARt) = DRs | SUBAsi #1, ARt      | push ds, (at) |
|                | STso   DRs, #0(ARt) |               |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0111       |
| [19-16]   | subop       | 0000       |
| [15-14]   | ARt         |            |
| [13-10]   | DRs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## PUSHAur ARs, (ARt)

| operation      | µop                 | isa           |
|----------------|---------------------|---------------|
| --2(ARt) = ARs | SUBAsi #2, ARt      | push as, (at) |
|                | STAso  ARs, #0(ARt) |               |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0111         |
| [19-16]   | subop       | 0001         |
| [15-14]   | ARt         |              |
| [13-12]   | ARs         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## POPur (ARs), DRt

| operation      | µop                  | isa          |
|----------------|----------------------|--------------|
| DRt = (ARs)1++ | ADDAsi #1, ARs       | pop (as), dt |
|                | LDso   #-1(ARs), DRt |              |

| bit range | description | value      |
|-----------|-------------|------------|
| [23-20]   | opclass     | 0111       |
| [19-16]   | subop       | 0010       |
| [15-12]   | DRt         |            |
| [11-10]   | ARs         |            |
| [ 9- 0]   | reserved    | 0000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## POPAur (ARs), ARt

| operation      | µop                  | isa          |
|----------------|----------------------|--------------|
| ARt = (ARs)2++ | ADDAsi #2, ARs       | pop (as), at |
|                | LDAso  #-2(ARs), ARt |              |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0111         |
| [19-16]   | subop       | 0011         |
| [15-14]   | ARt         |              |
| [13-12]   | ARs         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |
