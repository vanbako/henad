# Instructions

## Preface

Bit-field annotations indicate bit positions in the 24-bit instruction word.
For example, [23-20] marks the high 4 bits, with the left number the most
significant bit and the right number the least significant.
Registers use the following naming:
  DRx - data registers, ARx - address registers, SRx - special registers.
Suffixes such as t and s denote target and source respectively.
Braces list flags affected by the instruction, e.g. {Z, C} updates the Zero
and Carry flags.

## opclass 0000 Core ALU (reg–reg, unsigned flags)

- ### NOP

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

- ### MOVur DRs, DRt

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

- ### MCCur CC, DRs, DRt

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

- ### ADDur DRs, DRt

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

- ### SUBur DRs, DRt

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

- ### NOTur DRt

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

- ### ANDur DRs, DRt

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

- ### ORur DRs, DRt

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

- ### XORur DRs, DRt

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

- ### SHLur DRs, DRt

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

- ### ROLur DRs, DRt

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

- ### SHRur DRs, DRt

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

- ### RORur DRs, DRt

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

- ### CMPur DRs, DRt

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

- ### TSTur DRt

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

## opclass 0001 Core ALU (imm/uimm, unsigned flags)

"LUIui ; [OPC]ui" sequences must be made atomic  
A "[OPC]ui" without previous LUIui is undefined behaviour for now (I should implement an exception for this)

- ### LUIui #x, #imm12

| operation                | µop              | isa                     |
|--------------------------|------------------|-------------------------|
| case (x)                 | LUIui #x, #imm12 | load_upper_imm x, imm12 |
|   0: uimm[11- 0] = imm12 |                  |                         |
|   1: uimm[23-12] = imm12 |                  |                         |
|   2: uimm[35-24] = imm12 |                  |                         |
| endcase                  |                  |                         |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0000  |
| [15-14]   | x           |       |
| [13-12]   | reserved    | 00    |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ### MOVui #imm12, DRt

| operation                 | µop               | isa                       |
|---------------------------|-------------------|---------------------------|
| DRt = {uimm[11-0], imm12} | MOVui #imm12, DRt | copy.u imm24, dt          |
|                           |                   | macro                     |
|                           |                   |   LUIui #0, #imm24[23-12] |
|                           |                   |   MOVui #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0001  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ### ADDui #imm12, DRt

| operation                           | µop               | isa                       |
|-------------------------------------|-------------------|---------------------------|
| unsigned DRt += {uimm[11-0], imm12} | ADDui #imm12, DRt | add.u imm24, dt           |
|                                     |                   | macro                     |
|                                     |                   |   LUIui #0, #imm24[23-12] |
|                                     |                   |   ADDui #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0011  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ### SUBui #imm12, DRt

| operation                           | µop               | isa                       |
|-------------------------------------|-------------------|---------------------------|
| unsigned DRt -= {uimm[11-0], imm12} | SUBui #imm12, DRt | sub.u imm24, dt           |
|                                     |                   | macro                     |
|                                     |                   |   LUIui #0, #imm24[23-12] |
|                                     |                   |   SUBui #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0100  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ### ANDui #imm12, DRt

| operation                  | µop               | isa                       |
|----------------------------|-------------------|---------------------------|
| DRt &= {uimm[11-0], imm12} | ANDui #imm12, DRt | and imm24, dt             |
|                            |                   | macro                     |
|                            |                   |   LUIui #0, #imm24[23-12] |
|                            |                   |   ANDui #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0110  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ### ORui #imm12, DRt

| operation                   | µop              | isa                       |
|-----------------------------|------------------|---------------------------|
| DRt \|= {uimm[11-0], imm12} | ORui #imm12, DRt | or imm24, dt              |
|                             |                  | macro                     |
|                             |                  |   LUIui #0, #imm24[23-12] |
|                             |                  |   ORui  #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 0111  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ### XORui #imm12, DRt

| operation                  | µop               | isa                       |
|----------------------------|-------------------|---------------------------|
| DRt ^= {uimm[11-0], imm12} | XORui #imm12, DRt | xor imm24, dt             |
|                            |                   | macro                     |
|                            |                   |   LUIui #0, #imm24[23-12] |
|                            |                   |   XORui #imm24[11-0], DRt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0001  |
| [19-16]   | subop       | 1000  |
| [15-12]   | DRt         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| x | - | - | - |

- ### SHLui #imm5, DRt

| operation    | µop              | isa                 |
|--------------|------------------|---------------------|
| DRt <<= imm5 | SHLui #imm5, DRt | shift_left imm5, dt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1001    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ### ROLui #imm5, DRt

| operation     | µop              | isa               |
|---------------|------------------|-------------------|
| DRt <<<= imm5 | ROLui #imm5, DRt | rot_left imm5, dt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1010    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ### SHRui #imm5, DRt

| operation    | µop              | isa                  |
|--------------|------------------|----------------------|
| DRt >>= imm5 | SHRui #imm5, DRt | shift_right imm5, dt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1011    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ### RORui #imm5, DRt

| operation     | µop              | isa                |
|---------------|------------------|--------------------|
| DRt >>>= imm5 | RORui #imm5, DRt | rot_right imm5, dt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1100    |
| [15-12]   | DRt         |         |
| [11- 5]   | reserved    | 0000000 |
| [ 4- 0]   | imm5        |         |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

- ### CMPui #imm12, DRt

| operation                                 | µop               | isa                       |
|-------------------------------------------|-------------------|---------------------------|
| unsigned compare {uimm[11-0], imm12}, DRt | CMPui #imm12, DRt | comp.u imm24, dt          |
|                                           |                   | macro                     |
|                                           |                   |   LUIui #0, #imm24[23-12] |
|                                           |                   |   CMPui #imm24[11-0], DRt |

| bit range | description | value   |
|-----------|-------------|---------|
| [23-20]   | opclass     | 0001    |
| [19-16]   | subop       | 1101    |
| [15-12]   | DRt         |         |
| [11- 0]   | imm12       |         |

| z | n | c | v |
|---|---|---|---|
| x | - | x | - |

## opclass 0010 Core ALU (reg–reg, signed flags)

- ### ADDsr DRs, DRt

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

- ### SUBsr DRs, DRt

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

- ### NEGsr DRt

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

- ### SHRsr DRs, DRt

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

- ### CMPsr DRs, DRt

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

- ### TSTsr DRt

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

## opclass 0011 Core ALU (imm, signed flags / PC-rel)

- ### MOVsi #imm12, DRt

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

- ### MCCsi CC, #imm8, DRt

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

- ### ADDsi #imm12, DRt

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

- ### SUBsi #imm12, DRt

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

- ### SHRsi #imm5, DRt

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

- ### CMPsi #imm12, DRt

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

## opclass 0100 Loads/Stores

offsets are always signed

- ### LDso #imm10(ARs), DRt

| operation                        | µop                   | isa                |
|----------------------------------|-----------------------|--------------------|
| DRt = (ARs + sign_extend(imm10)) | LDso #imm10(ARs), DRt | load imm10(as), dt |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0000  |
| [15-12]   | DRt         |       |
| [11-10]   | ARs         |       |
| [ 9- 0]   | imm10       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ### STso DRs, #imm10(ARt)

| operation                        | µop                   | isa                 |
|----------------------------------|-----------------------|---------------------|
| (ARt + sign_extend(imm10)) = DRs | STso DRs, #imm10(ARt) | store ds, imm10(at) |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0001  |
| [15-14]   | ARt         |       |
| [13-10]   | DRs         |       |
| [ 9- 0]   | imm10       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ### STui #imm12, (ARt)

| operation                   | µop                | isa                         |
|-----------------------------|--------------------|-----------------------------|
| (ARt) = {uimm[11-0], imm12} | STui #imm12, (ARt) | store imm24, (at)           |
|                             |                    | macro                       |
|                             |                    |   LUIui #0, #imm24[23-12]   |
|                             |                    |   STui  #imm24[11-0], (ARt) |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0010  |
| [15-14]   | ARt         |       |
| [13-12]   | reserved    | 00    |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ### STsi #imm12, (ARt)

| operation                  | µop                | isa                 |
|----------------------------|--------------------|---------------------|
| (ARt) = sign_extend(imm12) | STsi #imm12, (ARt) | store.s imm12, (at) |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0011  |
| [15-14]   | ARt         |       |
| [13-12]   | reserved    | 00    |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ### LDAso #imm12(ARs), ARt

| operation                        | µop                    | isa                |
|----------------------------------|------------------------|--------------------|
| ARt = (ARs + sign_extend(imm12)) | LDAso #imm12(ARs), ARt | load imm12(as), at |
| comment: signed + operation      |                        |                    |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0100  |
| [15-14]   | ARt         |       |
| [13-12]   | ARs         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

- ### STAso ARs, #imm12(ARt)

| operation                        | µop                    | isa                 |
|----------------------------------|------------------------|---------------------|
| (ARt + sign_extend(imm12)) = ARs | STAso ARs, #imm12(ARt) | store as, imm12(at) |
| comment: signed + operation      |                        |                     |

| bit range | description | value |
|-----------|-------------|-------|
| [23-20]   | opclass     | 0100  |
| [19-16]   | subop       | 0101  |
| [15-14]   | ARt         |       |
| [13-12]   | ARs         |       |
| [11- 0]   | imm12       |       |

| z | n | c | v |
|---|---|---|---|
| - | - | - | - |

## opclass 0101 reserved

## opclass 0110 Address-register ALU & moves (reg)

- ### MOVAur DRs, ARt, H|L

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

- ### MOVDur ARs, DRt, H|L

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

; opclass 0111 Control flow (absolute via AR / long immediates) & linkage

BTP                            ; branch target pad
    isa                branch_target_pad
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0000
    [15- 0] RESERVED
    {}
JCCur    CC, ARt               ; if (CC) goto ARt;
    µop
    isa                jump.[cc] at
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0001
    [15-14] ARt
    [13-10] CC
    [ 9- 0] RESERVED
    {}
JCCui    CC, #imm12            ; if (CC) goto {uimm[35-0], imm12};
    µop
    isa                jump.[cc] imm48 (macro: LUIui #2, #imm48[47-36]; LUIui #1, #imm48[35-24]; LUIui #0, #imm48[23-12]; JCCui CC, #imm48[11-0])
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0010
    [15-12] CC
    [11- 0] imm12
    {}
BCCsr    CC, PC+DRt            ; if (CC) goto PC+signed(DRt);
    µop
    isa               branch.[cc] dt
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0011
    [15-12] DRt
    [11- 8] CC
    [ 7- 0] RESERVED
    {}
BCCso    CC, PC+#imm12         ; if (CC) goto PC+sext(imm12);
    µop
    isa                branch.[cc] imm12
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0100
    [15-12] CC
    [11- 0] imm12
    {}
BALso    PC+#imm16             ; goto PC+sext(imm16);
    µop
    isa                branch.always imm16
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0101
    [15- 0] imm16
    {}
JSRur       ARt                ; call ARt;
    isa                jump_sub at
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0110
    [15-14] ARt
    [13- 0] RESERVED
    {}
    µops
        SRSUBsi     #2, SSP
        SRSTso      LR, #0(SSP)
        SRMOVur     PC, LR
        JCCur       AL, ARt
JSRui       #imm12             ; call {uimm[35-0], imm12};
    isa                jump_sub imm48 (macro: LUIui #2, #imm48[47-36]; LUIui #1, #imm48[35-24]; LUIui #0, #imm48[23-12]; JSRui #imm48[11-0])
    [23-20] opclass            ; 0111
    [19-16] subop              ; 0111
    [15-12] RESERVED
    [11- 0] imm12
    {}
    µops
        SRSUBsi     #2, SSP
        SRSTso      LR, #0(SSP)
        SRMOVur     PC, LR
        JCCui       AL, #imm12
BSRsr       PC+DRt             ; call PC + sext(DRt);
    isa                branch_sub dt
    [23-20] opclass            ; 0111
    [19-16] subop              ; 1000
    [15-12] DRt
    [11- 0] RESERVED
    {}
    µops
        SRSUBsi     #2, SSP
        SRSTso      LR, #0(SSP)
        SRMOVur     PC, LR
        BCCsr       AL, PC+DRt
BSRso       PC+#imm16          ; call PC + sext(imm16); (signed + operation)
    isa                branch_sub imm16
    [23-20] opclass            ; 0111
    [19-16] subop              ; 1001
    [15- 0] imm16
    {}
    µops
        SRSUBsi     #2, SSP
        SRSTso      LR, #0(SSP)
        SRMOVur     PC, LR
        BALso       PC+#imm16
RET                            ; return
    isa                return
    [23-20] opclass            ; 0111
    [19-16] subop              ; 1010
    [15- 0] RESERVED
    {}
    µops
        SRADDsi     #2, SSP
        SRLDso      #-2(SSP), LR
        SRJCCso     AL, LR+#1

; opclass 1000 Stack helpers

PUSHur      DRs, (ARt)         ; --1(ARt) = DRs;
    isa                push ds, (at)
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0000
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
    µops
        SUBAsi      #1, ARt
        STso        DRs, #0(ARt)
PUSHAur     ARs, (ARt)         ; --2(ARt) = ARs;
    isa                push as, (at)
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0001
    [15-14] ARt
    [13-12] ARs
    [11- 0] RESERVED
    {}
    µops
        SUBAsi      #2, ARt
        STAso       ARs, #0(ARt)
POPur       (ARs), DRt         ; DRt = (ARs)1++
    isa                pop (as), dt
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0010
    [15-12] DRt
    [11-10] ARs
    [ 9- 0] RESERVED
    {}
    µops
        ADDAsi      #1, ARs
        LDso        #-1(ARs), DRt
POPAur      (ARs), ARt         ; ARt = (ARs)2++
    isa                pop (as), at
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0011
    [15-14] ARt
    [13-12] ARs
    [11- 0] RESERVED
    {}
    µops
        ADDAsi      #2, ARs
        LDAso       #-2(ARs), ARt

; opclass 1001 CSR access

CSRRD     #csr8, DRt          ; DRt = CSR[csr8] (24-bit)
    isa                csr_read csr8, dt
    [23-20] opclass            ; 1001
    [19-16] subop              ; 0000
    [15-12] DRt
    [11- 8] RESERVED
    [ 7- 0] csr8
    {Z}

CSRWR     DRs, #csr8          ; CSR[csr8] = DRs (24-bit)
    isa                csr_write ds, csr8
    [23-20] opclass            ; 1001
    [19-16] subop              ; 0001
    [15-14] RESERVED
    [13-10] DRs
    [ 9- 8] RESERVED
    [ 7- 0] csr8
    {}

; opclass 1010 privileged / kernel-only

SRHLT                          ; halt;
    µop
    isa                halt
    [23-20] opclass            ; 1010
    [19-16] subop              ; 0000
    [15- 0] RESERVED
    {}
SETSSP      ARs                ; SSP = ARs;
    isa                copy_to_ssp as
    [23-20] opclass            ; 1010
    [19-16] subop              ; 0001
    [15-14] ARs
    [13- 0] RESERVED
    {}
    µops
        SRMOVAur     ARs, SSP

SWI        #imm12             ; software interrupt to absolute handler
    isa                swi #imm12
    ; Semantics:
    ;   LR := PC + 1 (return address)
    ;   PC := {UIMM2[47:36], UIMM1[35:24], UIMM0[23:12], imm12[11:0]}
    ;   Mode: enter kernel mode
    ; Notes:
    ;   - The three upper immediate banks are loaded via prior LUIui #2/#1/#0 instructions.
    ;   - imm12 provides the low 12 bits of the absolute handler address.
    ;   - On a taken SWI, the branch flushes earlier in-flight instructions as usual.
    [23-20] opclass            ; 1010
    [19-16] subop              ; 0010
    [15-12] RESERVED
    [11- 0] imm12
    {}

SRET                          ; supervisor return
    isa                sret
    ; Semantics:
    ;   PC := LR (return to address saved by SWI/JSR sequence)
    ;   Mode: leave kernel mode and resume in user mode
    [23-20] opclass            ; 1010
    [19-16] subop              ; 0011
    [15- 0] RESERVED
    {}

; opclass 1011 MMU / TLB & Cache management

; opclass 1100 Atomics & SMP

; opclass 1101 24 bit integer math unit

; opclass 1110 24 bit float math unit

; opclass 1111 µop (future ISA can use the same opcodes)

SRMOVur     SRs, SRt           ; SRt = SRs;
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0000
    [15-14] SRt
    [13-12] SRs
    [11- 0] RESERVED
    {}
SRMOVAur    ARs, SRt           ; SRt = ARs;
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0001
    [15-14] SRt
    [13-12] ARs
    [11- 0] RESERVED
    {}
SRJCCso     CC, SRt+#imm10     ; if (CC) goto SRt + sext(imm10); (signed + operation)
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0010
    [15-14] SRt
    [13-10] CC
    [ 9- 0] imm10
    {}
SRADDsi     #imm14, SRt        ; signed SRt += sext(imm14);
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0011
    [15-14] SRt
    [13- 0] imm14
    {}
SRSUBsi     #imm14, SRt        ; signed SRt -= sext(imm14);
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0100
    [15-14] SRt
    [13- 0] imm14
    {}
SRSTso      SRs, #imm12(SRt)   ; (SRt + sext(imm12)) = SRs; (signed + operation)
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0101
    [15-14] SRt
    [13-12] SRs
    [11- 0] imm12
    {}
SRLDso      #imm12(SRs), SRt   ; SRt = (SRs + sext(imm12)); (signed + operation)
    µop
    [23-20] opclass            ; 1111
    [19-16] subop              ; 0110
    [15-14] SRt
    [13-12] SRs
    [11- 0] imm12
    {}
