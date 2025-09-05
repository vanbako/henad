Amber Toolchain
===============

Quick commands to assemble Amber assembly and run it on the Verilog core.

Requirements
- Python 3.9+
- Icarus Verilog (`iverilog`, `vvp`) available in PATH

Assemble
- `python tools/amber_asm.py processors/amber/asm/examples/hello.asm -o build/hello.hex`

Run (simulate)
- `python tools/amber_run.py build/hello.hex --ticks 200`

Shortcut (assemble + run)
- `python tools/amber_run.py processors/amber/asm/examples/hello.asm --ticks 200`

Notes
- Output format `hex` is preferred for simulation; it is directly loaded into instruction memory via `$readmemh`.
- You can adjust cycles with `--ticks`.
- The testbench prints pipeline trace and a final register dump.

