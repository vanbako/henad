# opclass 1000 CSR access

- See CSR map: `processors/amber/design/csr.md` for indices and field layouts (PSTATE, default capabilities, math unit, trap causes).

- ## CSRRD #csr12, DRt

| operation        | µop               | isa                |
|------------------|-------------------|--------------------|
| DRt = CSR[csr12] | CSRRD #csr12, DRt | csr_read csr12, dt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 1000  |
| [19-16]   | subop       | 0000  |
| [15-12]   | DRt         |       |
| [11- 0]   | csr12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ## CSRWR DRs, #csr12

| operation        | µop               | isa                 |
|------------------|-------------------|---------------------|
| CSR[csr12] = DRs | CSRWR DRs, #csr12 | csr_write ds, csr12 |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 1000  |
| [19-16]   | subop       | 0001  |
| [15-12]   | DRs         |       |
| [11- 0]   | csr12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |
