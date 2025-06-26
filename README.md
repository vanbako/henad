# Henad RISC Core

Henad is an experimental 12-bit RISC microarchitecture. It features a simple five-stage pipeline that now includes full instruction decode, execution and memory access. Earlier revisions merely passed the program counter through each stage; the current design adds a register file, branch handling and basic hazard detection so a small program can run end-to-end.

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

The repository includes a small test program in `instr_mem_init.hex`.
Simulation shows the pipeline executing this code, and debug output can be enabled by defining `DEBUGPC`, `DEBUGINSTR` or related macros when running Icarus Verilog.

## License

This project is distributed under the terms of the GNU General Public License version 3. See the `LICENSE` file for details.
