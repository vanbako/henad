Amber Toolchain
===============

Quick commands to assemble Amber assembly and run it on the Verilog core.

Requirements
- Python 3.9+
- Icarus Verilog (`iverilog`, `vvp`) available in PATH
  - On systems where `python` is not available, use `python3`.

Assemble
- `python tools/amber_asm.py processors/amber/asm/examples/hello.asm -o build/hello.hex`
  - Or `python3` depending on your environment.

Run (simulate)
- `python tools/amber_run.py build/hello.hex --ticks 200`
  - By default the compiled vvp is written to `build/vvp/amber/amber_sim.vvp`.

Shortcut (assemble + run)
- `python tools/amber_run.py processors/amber/asm/examples/hello.asm --ticks 200`

Notes
- Output format `hex` is preferred for simulation; it is directly loaded into instruction memory via `$readmemh`.
- You can adjust cycles with `--ticks`.
- The testbench prints pipeline trace and a final register dump.

Testbenches
- Amber unit-level testbenches now live in `processors/amber/tb/` (files named `*_tb.v`).
- Build all benches into `build/vvp/amber/`:
  - `python tools/build_tbs.py`
  - Filter a single bench: `python tools/build_tbs.py --pattern sr_ops`
  - Run all built benches: `make benches-run` (prints PASS/FAIL)

Makefile workflow
- Build benches: `make benches` (optional: `PATTERN=sr_ops`)
- Build+run benches: `make benches-run`
- Run Amber with a program: `make run INPUT=processors/amber/asm/examples/hello.asm TICKS=200`
- Clean outputs: `make clean`

Notes
- The Makefile auto-detects `python3` and falls back to `python`. Override with `make PY=python3 ...` if needed.
