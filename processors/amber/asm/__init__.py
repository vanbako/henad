"""
Amber Assembler (2-pass) - package entry

This package provides a minimal two-pass assembler skeleton for the Amber ISA.
Extend `spec.py` to add instructions and encodings.
"""

from .assembler import Assembler, assemble_file

__all__ = [
    "Assembler",
    "assemble_file",
]

