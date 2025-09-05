"""
Amber Assembler (2-pass) - package entry

Two-pass assembler for the Amber ISA with includes, macros, and full ISA
coverage (excluding internal micro-ops). See `processors/amber/asm/README.md`.
"""

from .assembler import Assembler, assemble_file

__all__ = [
    "Assembler",
    "assemble_file",
]
