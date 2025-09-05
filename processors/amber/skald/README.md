Skald Language (skeleton)

Skald is a tiny, typed language that compiles to Amber assembly. This initial
drop provides a parser/AST/type skeleton and a simple code generator that emits
Amber assembly text. The goal is to iterate quickly while keeping the surface
area small and readable.

Status: skeleton only
- Types: `u24`, `s24`, `addr` (48-bit pointer/address).
- Variables: global `let` and local `let` declarations (locals are register
  backed for now).
- Functions: `fn name(params) -> ret_ty { ... }` with a minimal calling
  convention: data params in `DR0..`, address params in `AR0..`.
- Declspec: parameters can be constrained to a specific register via `in DRx`
  or `in ARx`. Return can be constrained with `out DRx` or `out ARx`.
- Expressions: integer literals, identifiers, `+ - * /` (very limited, left to
  right, no precedence parsing yet; this is just enough to stand up the code
  paths).

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

Next steps
- Flesh out expression parsing with proper precedence and parentheses.
- Add statements: if/while, assignment, calls.
- Globals layout for `addr` (48-bit) using `.diad` and `MOVAur/MOVDur` helpers.
- Real register allocator and liveness; callee-saved register convention.
- Type checking and conversions (e.g., signed vs unsigned ops mapping).

