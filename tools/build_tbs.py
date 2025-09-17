#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
AMBER_DIR = REPO_ROOT / "processors" / "amber"
SRC_DIR = AMBER_DIR / "src"
TB_DIR = AMBER_DIR / "tb"
OUT_DIR = REPO_ROOT / "build" / "vvp" / "amber"


def which_or_error(name: str) -> str:
    exe = shutil.which(name)
    if exe:
        return exe
    print(f"error: '{name}' not found in PATH. Please install Icarus Verilog.", file=sys.stderr)
    print("- Windows: choco install icarus-verilog (or portable binaries)", file=sys.stderr)
    print("- Linux:   apt install iverilog   (or your package manager)", file=sys.stderr)
    print("- macOS:   brew install icarus-verilog", file=sys.stderr)
    raise SystemExit(127)


def find_testbenches(pattern: str | None) -> list[Path]:
    benches = sorted(TB_DIR.glob("*_tb.v"))
    # Exclude legacy benches that target pre-CHERI/AR opcodes
    exclude = {
        "ex_ar_alu_tb.v",   # legacy AR ALU ops (removed)
    }
    benches = [p for p in benches if p.name not in exclude]
    if pattern:
        benches = [p for p in benches if pattern in p.name]
    return benches


def build_design_filelist() -> list[str]:
    # Take all .v files in src/ except the legacy top-level testbench
    files = []
    for p in sorted(SRC_DIR.glob("*.v")):
        if p.name.endswith("_tb.v") or p.name == "testbench.v":
            continue
        files.append(str(p))
    return files


def compile_tb(iverilog: str, tb: Path) -> Path:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_vvp = OUT_DIR / (tb.stem + ".vvp")

    cmd = [
        iverilog,
        "-g2012",
        # Includes support both styles: `include "src/xxx.vh"` and local includes
        "-I",
        str(AMBER_DIR),
        "-I",
        str(SRC_DIR),
        "-o",
        str(out_vvp),
        *build_design_filelist(),
        str(tb),
    ]
    subprocess.check_call(cmd, cwd=str(REPO_ROOT))
    return out_vvp


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Build Amber *_tb.v testbenches to build/vvp/amber/")
    ap.add_argument("--pattern", help="Substring filter for tb filenames", default=None)
    ap.add_argument("--iverilog", default="iverilog")
    args = ap.parse_args(argv)

    iverilog = which_or_error(args.iverilog)

    benches = find_testbenches(args.pattern)
    if not benches:
        print("No testbenches found in processors/amber/tb/", file=sys.stderr)
        return 1

    print(f"[build-tbs] Found {len(benches)} benches")
    built = []
    for tb in benches:
        print(f"[build-tbs] Compiling {tb.name} ...")
        out = compile_tb(iverilog, tb)
        built.append(out)
    print("[build-tbs] Outputs:")
    for out in built:
        print(f" - {out.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
