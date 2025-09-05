#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
AMBER_DIR = REPO_ROOT / "processors" / "amber"
SRC_DIR = AMBER_DIR / "src"


def which_or_error(name: str) -> str:
    exe = shutil.which(name)
    if exe:
        return exe
    print(f"error: '{name}' not found in PATH. Please install Icarus Verilog.", file=sys.stderr)
    if name == "iverilog":
        print("- Windows: choco install icarus-verilog (or grab binaries)", file=sys.stderr)
        print("- Linux:   apt install iverilog   (or your package manager)", file=sys.stderr)
        print("- macOS:   brew install icarus-verilog", file=sys.stderr)
    raise SystemExit(127)


def build_source_list() -> list[str]:
    # Explicit list to avoid pulling in *_tb.v files
    files = [
        "testbench.v",
        "amber.v",
        "mem.v",
        "regar.v",
        "regcsr.v",
        "reggp.v",
        "regsr.v",
        "hazard.v",
        "forward.v",
        "stg1ia.v",
        "stg1if.v",
        "stg2xt.v",
        "stg3id.v",
        "stg4ex.v",
        "stg5ma.v",
        "stg5mo.v",
        "stg6wb.v",
        "math24_async.v",
    ]
    return [str(SRC_DIR / f) for f in files]


def assemble_if_needed(inp: Path, workdir: Path) -> Path:
    # Pass-through if HEX/MEM file is provided
    if inp.suffix.lower() in {".hex", ".mem"}:
        return inp
    # Treat anything else as assembly source (single entry supported; use .include for composition)
    sys.path.insert(0, str(REPO_ROOT))
    from processors.amber.asm.assembler import Assembler

    asm = Assembler(origin=0)
    words = asm.assemble_path(inp)
    stem = inp.stem
    src_desc = f"{inp}"
    hex_text = asm.pack_words_hex(words)
    out_hex = workdir / (stem + ".hex")
    out_hex.write_text(hex_text, encoding="utf-8")
    print(f"Assembled {src_desc} -> {out_hex} ({len(words)} words)")
    return out_hex


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Run Amber core in Icarus with a program")
    p.add_argument("input", type=Path, help="Program file: .hex (preferred) or .asm/.s")
    p.add_argument("-o", "--out", type=Path, help="Output vvp file path (optional)")
    p.add_argument("--ticks", type=int, default=200, help="Simulation cycles (default: 200)")
    p.add_argument("--iverilog", type=str, default="iverilog", help="iverilog executable name/path")
    p.add_argument("--vvp", type=str, default="vvp", help="vvp executable name/path")
    args = p.parse_args(argv)

    iverilog = which_or_error(args.iverilog)
    vvp = which_or_error(args.vvp)

    with tempfile.TemporaryDirectory(prefix="amber_run_") as tmpdir:
        tmpdir = Path(tmpdir)
        prog_hex = assemble_if_needed(args.input, tmpdir)

        # Normalize path for Verilog `define string
        mem_path = prog_hex.resolve().as_posix()

        # Write compiled vvp to a stable build directory by default
        default_out = REPO_ROOT / "build" / "vvp" / "amber" / "amber_sim.vvp"
        out_vvp = args.out or default_out
        out_vvp.parent.mkdir(parents=True, exist_ok=True)

        cmd = [
            iverilog,
            "-g2012",
            # Includes support both styles: `include "src/xxx.vh"` and local includes
            "-I",
            str(AMBER_DIR),
            "-I",
            str(SRC_DIR),
            # Disable testbench's default ROM preload when external HEX provided
            "-DNO_ROM_INIT=1",
            f"-DTICKS={args.ticks}",
            "-o",
            str(out_vvp),
            *build_source_list(),
        ]
        print("[amber-run] Compiling testbench...")
        subprocess.check_call(cmd, cwd=str(REPO_ROOT))

        print("[amber-run] Running simulation...")
        # vvp will print the testbench output to stdout
        run = subprocess.run([vvp, str(out_vvp), f"+HEX={mem_path}"], cwd=str(REPO_ROOT))
        return run.returncode


if __name__ == "__main__":
    raise SystemExit(main())
