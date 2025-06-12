# Henad RISC Core

Henad is an experimental 12‑bit RISC microarchitecture. The design implements a simple five‑stage pipeline with separate modules for each control and latch stage. At this point the project mainly provides a skeleton implementation that passes the program counter through each stage.

The overall architecture and instruction format are documented in `design.txt`.

## Repository layout

```
src/        Verilog source files for the core and its pipeline stages
LICENSE     GPLv3 license text
```

Key pipeline stages are defined in `src/henad.v`:

```
1. IA/IF – Instruction Address & Fetch
2. ID    – Instruction Decode
3. EX    – Execute
4. MA/MO – Memory Address & Operation
5. RA/RO – Register Address & Operation
```

A list of planned modules and memories can be found starting at line 120 of `design.txt`.

## Building and simulation

The project is written for Verilog-2001. A simple way to test the design is with Icarus Verilog:

```bash
iverilog -g2012 -o test.vvp src/*.v
vvp test.vvp
```

The repository currently provides only stub modules, so simulation will simply step the pipeline without executing real instructions.

## License

This project is distributed under the terms of the GNU General Public License version 3. See the `LICENSE` file for details.
