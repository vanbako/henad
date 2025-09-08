# opclass 0110 Address-register ALU & moves

- ## MOVAur DRs, ARt, H|L

| operation               | µop                   | isa                |
|-------------------------|-----------------------|--------------------|
| if (L) ARt[23: 0] = DRs | MOVAur DRs, ARt, H\|L | copy.[h\|l] ds, at |
| if (H) ARt[47:24] = DRs |                       |                    |

| bit range | description | value     | comment  |
|-----------|-------------|-----------|----------|
| [23-20]   | opclass     | 0110      |          |
| [19-16]   | subop       | 0001      |          |
| [15-14]   | ARt         |           |          |
| [13-10]   | DRs         |           |          |
| [ 9   ]   | H\|L        |           | H=1, L=0 |
| [ 8- 0]   | reserved    | 000000000 |          |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ## MOVDur ARs, DRt, H|L

| operation               | µop                   | isa                |
|-------------------------|-----------------------|--------------------|
| if (L) DRt = ARs[23: 0] | MOVDur ARs, DRt, H\|L | copy.[h\|l] as, dt |
| if (H) DRt = ARs[47:24] |                       |                    |

| bit range | description | value     | comment  |
|-----------|-------------|-----------|----------|
| [23-20]   | opclass     | 0110      |          |
| [19-16]   | subop       | 0010      |          |
| [15-12]   | DRt         |           |          |
| [11-10]   | ARs         |           |          |
| [ 9   ]   | H\|L        |           | H=1, L=0 |
| [ 8- 0]   | reserved    | 000000000 |          |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

ADDAur      DRs, ARt           ; unsigned ARt += zext(DRs);
    µop
    isa                add.u ds, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0011
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
SUBAur      DRs, ARt           ; unsigned ARt -= zext(DRs);
    µop
    isa                sub.u ds, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0100
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
ADDAsr      DRs, ARt           ; signed ARt += sext(DRs);
    µop
    isa                add.s ds, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0101
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
SUBAsr      DRs, ARt           ; signed ARt -= sext(DRs);
    µop
    isa                sub.s ds, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0110
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
ADDAsi      #imm12, ARt        ; signed ARt += sext(imm12);
    µop
    isa                add.s imm12, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 0111
    [15-14] ARt
    [11- 0] imm12
    {}
SUBAsi      #imm12, ARt        ; signed ARt -= sext(imm12);
    µop
    isa                sub.s imm12, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 1000
    [15-14] ARt
    [11- 0] imm12
    {}
LEAso       ARs+#imm12, ARt    ; ARt = ARs + sext(imm12); (signed + operation)
    µop
    isa                copy_offset imm12, as, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 1001
    [15-14] ARt
    [13-12] ARs
    [11- 0] imm12
    {}
ADRAso      PC+#imm14, ARt     ; ARt = PC + sext(imm14); (signed + operation)
    µop
    isa                copy_from_pc_offset imm14, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 1010
    [15-14] ARt
    [13- 0] imm14
    {}
; TODO: MOVAui (#imm48[47-36]; LUIui #1, #imm48[35-24]; LUIui #0, #imm48[23-12]; MOVAui #imm48[11-0], ARt)
CMPAur      ARs, ARt           ; unsigned compare ARs, ARt;
    µop
    isa                comp.u as, at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 1101
    [15-14] ARt
    [13-12] ARs
    [11- 0] RESERVED
    {Z, C}
TSTAur      ARt                ; unsigned ARt == 0;
    µop
    isa                test.u at
    [23-20] opclass            ; 0110
    [19-16] subop              ; 1110
    [15-14] ARt
    [13- 0] RESERVED
    {Z}
