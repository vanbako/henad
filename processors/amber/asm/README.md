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
- `.align N`: aligns PC to next multiple of N (in words).
