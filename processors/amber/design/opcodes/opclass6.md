# opclass 0110 Control flow (immediates, PC-relative) & linkage

- ## BTP

| operation         | µop | isa               |
|-------------------|-----|-------------------|
| branch target pad | BTP | branch_target_pad |

| bit range | description | value            |
|-----------|-------------|------------------|
| [23-20]   | opclass     | 0110             |
| [19-16]   | subop       | 0000             |
| [15- 0]   | reserved    | 0000000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

Note: Absolute jumps via address/capability registers are removed in the CHERI revision. Use PC-relative or immediate absolute jumps (which are checked against `PCC`).

- ## JCCui CC, #imm12

| operation                        | µop              | isa                       |
|----------------------------------|------------------|---------------------------|
| if (CC) goto {uimm[35-0], imm12} | JCCui CC, #imm12 | jump.[cc] imm48           |
|                                  |                  | macro                     |
|                                  |                  |   LUIui #2, #imm48[47-36] |
|                                  |                  |   LUIui #1, #imm48[35-24] |
|                                  |                  |   LUIui #0, #imm48[23-12] |
|                                  |                  |   JCCui CC, #imm48[11- 0] |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0110  |
| [19-16]   | subop       | 0010  |
| [15-12]   | CC          |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## BCCsr CC, PC+DRt

| operation                   | µop              | isa            |
|-----------------------------|------------------|----------------|
| if (CC) goto PC+signed(DRt) | BCCsr CC, PC+DRt | branch.[cc] dt |

| bit range | description | value    |
|-----------|-------------|----------|
| [23-20]   | opclass     | 0110     |
| [19-16]   | subop       | 0011     |
| [15-12]   | DRt         |          |
| [11- 8]   | CC          |          |
| [ 7- 0]   | reserved    | 00000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## BCCso CC, PC+#imm12

| operation                          | µop                 | isa               |
|------------------------------------|---------------------|-------------------|
| if (CC) goto PC+sign_extend(imm12) | BCCso CC, PC+#imm12 | branch.[cc] imm12 |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0110  |
| [19-16]   | subop       | 0100  |
| [15-12]   | CC          |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## BALso PC+#imm16

| operation                  | µop             | isa                 |
|----------------------------|-----------------|---------------------|
| goto PC+sign_extend(imm16) | BALso PC+#imm16 | branch.always imm16 |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0110  |
| [19-16]   | subop       | 0101  |
| [15- 0]   | imm16       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

 

- ## JSRui #imm12

| operation                | µop                 | isa                       |
|--------------------------|---------------------|---------------------------|
| call {uimm[35-0], imm12} | SRSUBsi #2, SSP     | jump_sub imm48            |
|                          | SRSTso  LR, #0(SSP) | macro                     |
|                          | SRMOVur PC, LR      |   LUIui #2, #imm48[47-36] |
|                          | JCCui   AL, #imm12  |   LUIui #1, #imm48[35-24] |
|                          |                     |   LUIui #0, #imm48[23-12] |
|                          |                     |   JSRui #imm48[11-0]      |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0110  |
| [19-16]   | subop       | 0111  |
| [15-12]   | reserved    | 0000  |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## BSRsr PC+DRt

| operation                  | µop                 | isa           |
|----------------------------|---------------------|---------------|
| call PC + sign_extend(DRt) | SRSUBsi #2, SSP     | branch_sub dt |
|                            | SRSTso  LR, #0(SSP) |               |
|                            | SRMOVur PC, LR      |               |
|                            | BCCsr   AL, PC+DRt  |               |

| bit range | description | value        |
|-----------|-------------|--------------|
| [23-20]   | opclass     | 0110         |
| [19-16]   | subop       | 1000         |
| [15-12]   | DRt         |              |
| [11- 0]   | reserved    | 000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## BSRso PC+#imm16

| operation                    | µop                 | isa              |
|------------------------------|---------------------|------------------|
| call PC + sign_extend(imm16) | SRSUBsi #2, SSP     | branch_sub imm16 |
|                              | SRSTso  LR, #0(SSP) |                  |
|                              | SRMOVur PC, LR      |                  |
|                              | BALso   PC+#imm16   |                  |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0110  |
| [19-16]   | subop       | 1001  |
| [15- 0]   | imm16       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## RET

| operation        | µop                  | isa    |
|------------------|----------------------|--------|
| return from call | SRADDsi #2, SSP      | return |
|                  | SRLDso  #-2(SSP), LR |        |
|                  | SRJCCso AL, LR+#1    |        |

| bit range | description | value            |
|-----------|-------------|------------------|
| [23-20]   | opclass     | 0110             |
| [19-16]   | subop       | 1010             |
| [15- 0]   | reserved    | 0000000000000000 |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

 
