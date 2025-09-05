import argparse
from pathlib import Path
from .assembler import Assembler


def main():
    p = argparse.ArgumentParser(description="Amber assembler")
    p.add_argument("input", type=Path, help="Input assembly file (.asm/.s)")
    p.add_argument("-o", "--output", type=Path, help="Output file path")
    p.add_argument(
        "--format",
        choices=["bin", "hex"],
        default="bin",
        help="Output format: raw binary (bin) or simple hex (hex)",
    )
    p.add_argument(
        "--origin",
        type=int,
        default=0,
        help="Origin (word address, default 0). PC counts 24-bit words.",
    )
    args = p.parse_args()

    asm = Assembler(origin=args.origin)
    words = asm.assemble_path(args.input)

    if args.format == "bin":
        data = asm.pack_words_bin(words)
    else:
        data = asm.pack_words_hex(words).encode("utf-8")

    out = args.output
    if out is None:
        suffix = ".bin" if args.format == "bin" else ".hex"
        out = args.input.with_suffix(suffix)
    out.write_bytes(data)

    print(f"Assembled {args.input} -> {out} ({len(words)} words)")


if __name__ == "__main__":
    main()
