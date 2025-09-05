import argparse
from pathlib import Path

from .compiler import compile_file


def main() -> None:
    p = argparse.ArgumentParser(description="Skald compiler -> Amber assembly")
    p.add_argument("input", type=Path, help="Input Skald file (.skald)")
    p.add_argument("-o", "--output", type=Path, help="Output assembly file path (.asm)")
    p.add_argument("--assemble", action="store_true", help="Assemble with Amber assembler after codegen")
    p.add_argument("--format", choices=["bin", "hex"], default="bin", help="Assembler output format when --assemble is used")
    p.add_argument("--origin", type=int, default=0, help="Assembler origin (word address)")
    p.add_argument("--out-bin", type=Path, help="Assembled output file path (.bin/.hex)")

    args = p.parse_args()

    res = compile_file(
        args.input,
        out_asm=args.output,
        assemble=args.assemble,
        fmt=args.format,
        origin=args.origin,
        out_bin=args.out_bin,
    )

    if args.assemble and res.bin_path is not None:
        print(f"Compiled {args.input} -> {res.asm_path}; Assembled -> {res.bin_path}")
    else:
        print(f"Compiled {args.input} -> {res.asm_path}")


if __name__ == "__main__":
    main()

