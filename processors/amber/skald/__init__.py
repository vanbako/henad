"""Skald: a tiny language that compiles to Amber assembly.

This package currently contains a minimal skeleton: lexer, parser, AST, a very
simple code generator, and a CLI that can emit Amber assembly or optionally run
the Amber assembler to produce binaries.
"""

__all__ = [
    "compile_file",
]

from .compiler import compile_file  # re-export primary API

