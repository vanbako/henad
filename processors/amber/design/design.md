# amber design

## About

The diad-amber 8-stage microarchitecture core.
The main goal is to keep the pipeline as simple as possible and to avoid stalls where possible.  
Toolchain is currently iverilog.

## Details

- **Board:** Board with Arora-V
- **Instruction, Memories, and GP Registers:** diad (24 bit) in size
- **Special Registers (SSP, LR, PC):** tetrad (48 bit) in size
- **Memory Properties:**
  - Memories are 24 bit word (not byte) with a 48-bit address space
  - Integer & floating point math are not needed
- **Execution:**
  - No branch prediction (keep spectres away)
  - No out-of-order or speculative execution (no meltdown)
  - Interrupts, i-cache, d-cache are for future implementation
- **Pipeline Implementation:**
  - Use handshake signals between stages to indicate when new data can be accepted.
  - ISA instructions can be multi micro-ops (but no multi-cycle micro-ops).
  - Each stage has its own local hazard or control logic that communicates with adjacent stages.
  - Built-in synchronous Block RAM (BRAM) is used for both instruction and data memories (will be caches later) with a one-clock delay (fetch & mem stages).
- **Memory Initialization:** Bootloader at runtime (currently initialized with a memory file for testing)
- **Branching:** JCC/BCC/BAL resolve in XT; IF/ID are squashed on taken.

## Instruction Format

- 24 bit (diad) total; only necessary bits for the instruction are coded, the rest are RESERVED (should be all zeros, not checked yet)
- **Condition Code (CC):**
  - Field is 4-bit with: 0 = AL, 1 = EQ, 2 = NE, 3 = LT, 4 = GT, 5 = LE, 6 = GE, 7 = BT, 8 = AT, 9 = BE, A = AE
- **Immediates:**
  - 12 bit when used together with the uimm
  - Other immediates vary in size to maximize relative jumps and others

## Condition Code Table

- **AL:** Always – no flags consulted.
- **EQ:** Equal – true when Zero flag (Z) is set.
- **NE:** Not Equal – true when Z is clear.
- **LT:** Less Than (signed) – true when (N ⊕ V) = 1.
- **GT:** Greater Than (signed) – true when Z is clear and (N ⊕ V) = 0.
- **LE:** Less or Equal (signed) – true when Z is set or (N ⊕ V) = 1.
- **GE:** Greater or Equal (signed) – true when (N ⊕ V) = 0.
- **BT:** Below (unsigned) – true when the Carry flag (C) is set.
- **AT:** Above (unsigned, strict) – true when C is clear and Z is clear.
- **BE:** Below or Equal (unsigned) – true when C is set or Z is set.
- **AE:** Above or Equal (unsigned) – true when C is clear.

_**Flags Consulted:**_  

- Signed comparisons: Negative (N), Overflow (V), and Zero (Z) flags  
- Unsigned comparisons: Carry (C) flag (with Z for strict comparisons)

## Instruction Suffixes

- **ur:** unsigned register operation
- **ui:** unsigned immediate value (upper from uimm and lower from immxx)
- **sr:** signed register operation
- **si:** signed immediate operation (sign extended immxx)
- **so:** signed immediate operation (sign extended immxx offset)

_*Note:*_ In assembly, the last operand is the target; if there are two operands, the previous is source.

- Move instructions set/clear the Z flag (except for address instructions).
- Address instructions (including LD/ST) do not modify flags, except for MOVD, compare, and test.
- All 48-bit memory operations are little endian (2 x 24 bit).

## TODOS

- µop mov A <-> SR → ISA SETSSP, ...
- BTP (branch target pad) for control flow integrity

## Order of Future Implementation

1. Control flow integrity (BTP, check LR, SSP RAM)
2. CSR
3. Interrupts
4. i-cache & d-cache
5. Atomic operations

## Pipeline Stages

1. IA: Instruction Address
2. IF: Instruction Fetch
3. ID: Instruction Decode
4. XT: Translate
5. EX: Execute
6. MA: Memory Address
7. MO: Memory Operation
8. WB: Register Write Back

## Registers

- **Data Registers:** 0-7 Dx : data (24 bit)
- **Address Registers:** 0-3 Ax : address (48 bit)
- **Special Registers:** 0-3 Sx : address (48 bit)
  - 0: L: link register
  - 1: SSP: shadow stack pointer
  - 2: T: temporary register
  - 3: PC: program counter
- **Flags:**
  - FL:
    - 0: Z (zero)
    - 1: N (negative)
    - 2: C (carry)
    - 3: V (overflow)

## Memory

- **Data Memory:**  
  - 36-bit address space
  - Read-write (BRAM)

## Modules

- testbench
- amber
- regdr
- regar
- regsr
- mem (instruction and data)
- stage_ia
- stage_if
- stage_xt
- stage_id
- stage_ex
- stage_ma
- stage_mo
- stage_wb
