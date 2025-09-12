# opclass 1001 privileged / kernel-only

- ## HLT

| operation | µop | isa  |
|-----------|-----|------|
| halt      | HLT | halt |

| bit range | description | value            |
|-----------|-------------|------------------|
| [23-20]   | opclass     | 1001             |
| [19-16]   | subop       | 0000             |
| [15- 0]   | reserved    | 0000000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## SETSSP ARs

| operation | µop               | isa          |
|-----------|-------------------|--------------|
| SSP = ARs | SRMOVAur ARs, SSP | copy as, ssp |

| bit range | description | value          |
|-----------|-------------|----------------|
| [23-20]   | opclass     | 1001           |
| [19-16]   | subop       | 0001           |
| [15-14]   | ARs         |                |
| [13- 0]   | reserved    | 00000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## KRET

| operation               | µop                  | isa     |
|-------------------------|----------------------|---------|
| return from kernel mode | SRADDsi #2, SSP      | kreturn |
|                         | SRLDso  #-2(SSP), LR |         |
|                         | SRJCCso AL, LR+#1    |         |

| bit range | description | value            |
|-----------|-------------|------------------|
| [23-20]   | opclass     | 1001             |
| [19-16]   | subop       | 0001             |
| [15- 0]   | reserved    | 0000000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |
