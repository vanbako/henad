#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path
import sys


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Assemble Amber asm into 24-bit words (hex or bin)"
    )
    parser.add_argument("input", type=Path, help="Input assembly file (.asm/.s)")
    parser.add_argument("-o", "--output", type=Path, help="Output file path")
    parser.add_argument(
        "--format",
        choices=["hex", "bin"],
        default="hex",
        help="Output format (default: hex for simulation)",
    )
    parser.add_argument(
        "--origin",
        type=int,
        default=0,
        help="Origin (word address, default 0). PC counts 24-bit words.",
    )
    args = parser.parse_args(argv)

    # Lazy import to avoid package path issues if tools/ is executed directly
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    from processors.amber.asm.assembler import Assembler

    if not args.input.exists():
        print(f"error: input not found: {args.input}", file=sys.stderr)
        return 2

    asm = Assembler(origin=args.origin)
    words = asm.assemble_path(args.input)
    if args.format == "hex":
        data = asm.pack_words_hex(words).encode("utf-8")
        suffix = ".hex"
    else:
        data = asm.pack_words_bin(words)
        suffix = ".bin"

    out = args.output or args.input.with_suffix(suffix)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    print(f"Assembled {args.input} -> {out} ({len(words)} words)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

