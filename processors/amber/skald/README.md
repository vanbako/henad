Skald Language (skeleton)

Skald is a tiny, typed language that compiles to Amber assembly. This initial
drop provides a parser/AST/type skeleton and a simple code generator that emits
Amber assembly text. The goal is to iterate quickly while keeping the surface
area small and readable.

Status: skeleton only
- Types: `u24`, `s24`, `addr` (48-bit pointer/address).
- Variables: global `let` and local `let` declarations (locals are register
  backed for now).
- Functions: `fn name(params) -> ret_ty { ... }` with a small calling
  convention described below.
- Declspec: parameters can be constrained to a specific register via `in DRx`
  or `in ARx`. Return can be constrained with `out DRx` or `out ARx`.
- Statements: `let`, `return`, `if (expr) { ... } else { ... }`, `while (expr) { ... }`, `break;`, `continue;`.
- Expressions: integer literals, identifiers, arithmetic and bitwise ops with
  precedence; relational/equality operators (`==`, `!=`, `<`, `<=`, `>`, `>=`);
  assignment (including compound assignment) and calls.
  - Relational results are data values: `0` (false) or `1` (true).
  - Signed vs unsigned comparisons: if either operand is `s24`, signed
    comparisons are emitted; otherwise unsigned.
  - Explicit casts: use `cast_s24(x)` or `cast_u24(x)` to reinterpret the bits
    of `x` as signed/unsigned. These are compile-time pseudos, not real calls.
  - Implicit casts: variables of type `u24` and `s24` implicitly coerce to
    each other in expression contexts (same 24-bit width). No implicit casts to
    or from `addr` are performed.

CLI
- Compile to Amber assembly: `python -m processors.amber.skald input.skald -o out.asm`.
- Or compile and assemble: `python -m processors.amber.skald input.skald --assemble --format bin -o out.bin`.

Layout
- `lexer.py`: trivial tokenizer.
- `ast.py`: nodes and type representations.
- `parser.py`: hand-rolled recursive descent (skeleton-level coverage).
- `typesys.py`: basic types and helpers.
- `codegen.py`: emits Amber assembly; trivial register allocation.
- `compiler.py`: end-to-end pipeline and CLI helpers.
- `__main__.py`: command-line entry.

Calling Convention (skeleton)
- Stack pointer: `AR0` is reserved as the stack pointer (SP). Runtime/startup
  must initialize it before calling into Skald code.
- Parameter passing (defaults, unless `in DRx/ARx` is specified on the param):
  - Data params (`u24`/`s24`) are passed in `DR0`, `DR1`, `DR2`, ... (in order).
  - Address params (`addr`) are passed in `AR1`, `AR2`, `AR3`, ... (in order).
    `AR0` is not used for parameters to avoid clobbering SP.
- Return values (defaults, unless `out DRx/ARx` is specified on the function):
  - Data return in `DR0`.
  - Address return in `AR1` (not `AR0`, which is SP).
- Calls: direct calls compile to `BSRso callee_label`. Function pointers are
  not supported yet.
- Callee-saved behavior in this skeleton:
  - The callee preserves any locals/temporaries it allocates by pushing them on
    entry and popping them before every `RET`.
  - Concretely, the code generator emits:
    - Prologue: `PUSHAur ARn, AR0` for address registers `ARn >= AR1` it uses
      (locals/temps), then `PUSHur DRn, AR0` for data registers `DRn >= DR1` it
      uses (locals/temps). Parameter registers are not saved.
    - Epilogue(s): the corresponding `POPur`/`POPAur` in reverse order before
      each `RET`.
  - Volatile (caller-saved) by convention: `DR0` (return) and parameter
    registers used for argument passing.
  - Non-volatile (callee-saved): any additional `DRx (x>=1)` / `ARx (x>=1)` the
    callee chooses to use for locals/temporaries (the prologue/epilogue handles
    saving them).

Notes
- This is intentionally minimal. There is no spilling, real register allocator,
  or interprocedural analysis yet. The prologue/epilogue only saves registers
  that the function itself allocates for locals/temporaries; parameter registers
  are left intact unless you explicitly copy them.
- Global `addr` layout is two 24-bit words (`.dw24 lo; .dw24 hi`). Moves between
  `DRx` and `ARx` use `MOVAur/MOVDur` with `L` (low) lane only for now.

Next steps
- Flesh out expression parsing with proper precedence and parentheses.
- Add statements: if/while, assignment, calls.
- Globals layout for `addr` (48-bit) using `.diad` and `MOVAur/MOVDur` helpers.
- Real register allocator and liveness; callee-saved register convention.
- Type checking and conversions (e.g., signed vs unsigned ops mapping).
