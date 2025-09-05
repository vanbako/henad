Amber Assembler (Skeleton)

This is a minimal, two-pass assembler skeleton for the Amber ISA.
It is intentionally incomplete but designed to be easy to extend.

Capabilities (initial):
- Two-pass assembly with a symbol table for labels.
- Basic parsing of labels, directives, and mnemonics.
- Output in raw 24-bit binary (3 bytes/word) or simple hex text (6 hex chars/line).
- Partial instruction spec expanded: core ALU (reg/reg and imm), basic loads/stores, branches, CSR access, and SWI.

Non-goals (yet):
- Full ISA coverage (many mnemonics are stubbed/TODO).
- Expressions beyond simple constants for directives.
- Macros and pseudo-instructions.

Usage:
- Module: `python -m processors.amber.asm -h`
- Example: `python -m processors.amber.asm processors/amber/asm/examples/hello.asm -o hello.bin --format bin`

Directives:
- `.org <const>`: set origin in words (instruction addresses).
- `.dw24 <const> [,<const> ...]` or `.diad <const>[, ...]`: emit one or more 24-bit diads (24-bit words).

Notes:
- The program counter (PC) counts 24-bit words. One instruction = 1 word.
- Labels capture the current word address at definition time.
- Extend `spec.py` with additional instruction definitions and field encoders.
- Special registers: accepts aliases `PC`, `LR`, `SSP`, `FL` for SR indices (also `SR0..SR3`).

Supported mnemonics (subset):
- OP0 (unsigned reg/reg): `NOP`, `MOVur`, `MCCur`, `ADDur`, `SUBur`, `NOTur`, `ANDur`, `ORur`, `XORur`, `SHLur`, `ROLur`, `SHRur`, `RORur`, `CMPur`, `TSTur`.
- OP1 (imm/uimm): `LUIui`, `MOVui`, `ADDui`, `SUBui`, `ANDui`, `ORui`, `XORui`, `SHLui`, `ROLui`, `SHRui`, `RORui`, `CMPui`.
- OP2 (signed reg/reg): `ADDsr`, `SUBsr`, `NEGsr`, `SHRsr`, `CMPsr`, `TSTsr`.
- OP3 (signed imm): `MOVsi`, `ADDsi`, `SUBsi`, `SHRsi`, `CMPsi`.
- OP4 (loads/stores base only): `LDur (ARs), DRt`, `STur DRs, (ARt)`.
- OP5 (base+offset): `LDso #imm10(ARs), DRt`, `STso DRs, #imm10(ARt)`, `LDAso #imm12(ARs), ARt`, `STAso ARs, #imm12(ARt)`.
- OP7 (branches subset): `JCCur CC, ARt`, `BCCso CC, label|expr`, `BALso label|expr`, `RET`.
  - Macros: `JCCui CC, abs_expr` and `JSRui abs_expr` expand into `LUIui #2/#1/#0` + `JCCui/JSRui`.
  - Also `BCCsr CC, PC+DRt` for register-relative branches.
- OP6 (address-register ops subset): `ADDaur`, `SUBaur`, `ADDAsr`, `SUBAsr`, `ADDAsi`, `SUBAsi`, `LEAso`, `ADRAso`, `CMPAur`, `TSTAur`, `MOVAur DRs, ARt, H|L`, `MOVDur ARs, DRt, H|L` (bit 9: H=1, L=0).
- OP9 (CSR): `CSRRD #csr8, DRt`, `CSRWR DRs, #csr8`.
  - Built-in CSR aliases include: `STATUS`, `CAUSE`, `EPC_LO`, `EPC_HI`, `CYCLE_L`, `CYCLE_H`, `INSTRET_L`, `INSTRET_H`.
  - Async Int24 Math CSR aliases: `MATH_CTRL`, `MATH_STATUS`, `MATH_OPA`, `MATH_OPB`, `MATH_OPC`, `MATH_RES0`, `MATH_RES1`.
  - Math control constants: `MATH_CTRL_START` and pre-shifted `MATH_OP_*` (e.g. `MATH_OP_DIVU`, `MATH_OP_MULS`, `MATH_OP_SQRTU`, `MATH_OP_CLAMP_S`).
  - Math status bits: `MATH_STATUS_READY`, `MATH_STATUS_BUSY`, `MATH_STATUS_DIV0`.
- OPA (privileged): `SRHLT`, `SETSSP ARs`, `SWI #imm12`.
  - Macro: `SWIui abs_expr` expands like `JSRui`: `LUIui #2,#expr[47:36]; LUIui #1,#expr[35:24]; LUIui #0,#expr[23:12]; SWI #expr[11:0]`.

Immediates and expressions:
- Numeric formats: `#123`, `#0x1F`, `#0b1010`, `#0o77` (leading `#` optional for immediates in expressions).
- Symbols: bare labels evaluate to their word address; `.` evaluates to current PC.
- Operators: `+` and `-` (left-to-right, no parentheses yet).
- PC-relative: for `BCCso` and `BALso`, bare label operands are treated as relative (auto: `label - .`). You can also write `label-.` explicitly.
  For `ADRAso`, labels are treated as `label - .` (PC-relative address materialization).

 Macros:
- `JCCui CC, expr48` expands to `LUIui #2,#expr[47:36]; LUIui #1,#expr[35:24]; LUIui #0,#expr[23:12]; JCCui CC,#expr[11:0]`.
- `JSRui expr48` expands similarly with `JSRui` final instruction.
- `SWIui expr48` expands similarly with `SWI` final instruction.

Directives:
- `.equ NAME, expr`: defines a symbol; supports forward references (resolved after pass 1). `.equ` can reference labels and earlier `.equ`s.

Async Int24 Math macros
- `MULU24 DRa, DRb, DRlo, DRhi, DRtmp`
- `MULS24 DRa, DRb, DRlo, DRhi, DRtmp`
- `DIVU24 DRa, DRb, DRq, DRr, DRtmp`
- `DIVS24 DRa, DRb, DRq, DRr, DRtmp`
- `MODU24 DRa, DRb, DRr, DRtmp`
- `MODS24 DRa, DRb, DRr, DRtmp`
- `SQRTU24 DRa, DRres, DRtmp`
- `ABS_S24 DRa, DRres, DRtmp`
- `MIN_U24 DRa, DRb, DRres, DRtmp`
- `MAX_U24 DRa, DRb, DRres, DRtmp`
- `MIN_S24 DRa, DRb, DRres, DRtmp`
- `MAX_S24 DRa, DRb, DRres, DRtmp`
- `CLAMP_U24 DRa, DRmin, DRmax, DRres, DRtmp`
- `CLAMP_S24 DRa, DRmin, DRmax, DRres, DRtmp`

Semantics:
- Macros issue CSR writes to `MATH_OP*`, kick the operation via `MATH_CTRL`, poll `MATH_STATUS` until `READY`, and read results (`RES0`, and `RES1` when applicable).
- `DRtmp` is a scratch register used to build control and poll status; it is clobbered.
- Destination registers receive: MUL -> `DRlo`=RES0, `DRhi`=RES1; DIV -> `DRq`=RES0, `DRr`=RES1; others -> `DRres`=RES0.

Examples:
- See `processors/amber/asm/examples/math_async.asm` for manual CSR usage.
- See `processors/amber/asm/examples/math_macros.asm` for macro-based usage.

Async Int24 Math usage
- Write operands: `CSRWR DRa, MATH_OPA` and `CSRWR DRb, MATH_OPB` (and `CSRWR DRc, MATH_OPC` for clamp min).
- Start operation: load control into a DR and write `CSRWR DRc, MATH_CTRL`, where `DRc = MATH_CTRL_START + MATH_OP_DIVU` (example for unsigned divide).
- Poll status: `CSRRD MATH_STATUS, DRt` and test `MATH_STATUS_READY`.
- Read results: `CSRRD MATH_RES0, DRx` (and `MATH_RES1` for MUL high or DIV remainder).

CSR syntax convenience
- `CSRWR` accepts either order: `CSRWR DRs, #idx` (canonical) or `CSRWR MATH_OPA, DRs` (assembler rewrites to canonical).
- `CSRRD` accepts either order: `CSRRD #idx, DRt` (canonical) or `CSRRD DRt, MATH_STATUS` (rewritten).
