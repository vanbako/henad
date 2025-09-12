# opclass 1111 µop

- ## SRMOVur SRs, SRt

| operation | µop              | isa |
|-----------|------------------|-----|
| SRt = SRs | SRMOVur SRs, SRt |     |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 1111         |
| [19-16]   | subop       | 0000         |
| [15-14]   | SRt         |              |
| [13-12]   | SRs         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## SRMOVAur ARs, SRt

| operation | µop               | isa  |
|-----------|-------------------|------|
| SRt = ARs | SRMOVAur ARs, SRt |      |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 1111         |
| [19-16]   | subop       | 0001         |
| [15-14]   | SRt         |              |
| [13-12]   | ARs         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## SRJCCso CC, SRt+#imm10

| operation                             | µop                    | isa |
|---------------------------------------|------------------------|-----|
| if (CC) goto SRt + sign_extend(imm10) | SRJCCso CC, SRt+#imm10 |     |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 1111  |
| [19-16]   | subop       | 0010  |
| [15-14]   | SRt         |       |
| [13-10]   | CC          |       |
| [ 9- 0]   | imm10       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## SRADDsi #imm14, SRt

| operation                        | µop                 | isa |
|----------------------------------|---------------------|-----|
| signed SRt += sign_extend(imm14) | SRADDsi #imm14, SRt |     |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 1111  |
| [19-16]   | subop       | 0011  |
| [15-14]   | SRt         |       |
| [13- 0]   | imm14       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## SRSUBsi #imm14, SRt

| operation                        | µop                 | isa |
|----------------------------------|---------------------|-----|
| signed SRt -= sign_extend(imm14) | SRSUBsi #imm14, SRt |     |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 1111  |
| [19-16]   | subop       | 0100  |
| [15-14]   | SRt         |       |
| [13- 0]   | imm14       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## SRSTso SRs, #imm12(SRt)

| operation                        | µop                     | isa |
|----------------------------------|-------------------------|-----|
| (SRt + sign_extend(imm12)) = SRs | SRSTso SRs, #imm12(SRt) |     |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 1111  |
| [19-16]   | subop       | 0101  |
| [15-14]   | SRt         |       |
| [13-12]   | SRs         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## SRLDso #imm12(SRs), SRt

| operation                        | µop                     | isa |
|----------------------------------|-------------------------|-----|
| SRt = (SRs + sign_extend(imm12)) | SRLDso #imm12(SRs), SRt |     |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 1111  |
| [19-16]   | subop       | 0110  |
| [15-14]   | SRt         |       |
| [13-12]   | SRs         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |
