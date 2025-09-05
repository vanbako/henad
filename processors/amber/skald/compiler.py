from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from .parser import parse, ParseError
from .codegen import CodeGen, CodegenError


@dataclass
class CompileResult:
    asm_text: str
    asm_path: Optional[Path]
    bin_path: Optional[Path]


def compile_text(src: str) -> str:
    prog = parse(src)
    cg = CodeGen()
    return cg.gen_program(prog)


def compile_file(path: Path, *, out_asm: Optional[Path] = None, assemble: bool = False, fmt: str = "bin", origin: int = 0, out_bin: Optional[Path] = None) -> CompileResult:
    src = path.read_text(encoding="utf-8")
    asm_text = compile_text(src)
    if out_asm is None:
        out_asm = path.with_suffix(".asm")
    out_asm.write_text(asm_text, encoding="utf-8")

    bin_path: Optional[Path] = None
    if assemble:
        from processors.amber.asm.assembler import Assembler

        asm = Assembler(origin=origin)
        words = asm.assemble(asm_text)
        if fmt == "bin":
            data = asm.pack_words_bin(words)
            suffix = ".bin"
        else:
            data = asm.pack_words_hex(words).encode("utf-8")
            suffix = ".hex"
        if out_bin is None:
            out_bin = path.with_suffix(suffix)
        out_bin.write_bytes(data)
        bin_path = out_bin
    return CompileResult(asm_text=asm_text, asm_path=out_asm, bin_path=bin_path)

