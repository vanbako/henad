from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass(frozen=True)
class Type:
    name: str
    bits: int
    is_signed: bool = False
    is_addr: bool = False

    def __str__(self) -> str:
        return self.name


# Built-in types
U24 = Type("u24", 24, is_signed=False, is_addr=False)
S24 = Type("s24", 24, is_signed=True, is_addr=False)
ADDR = Type("addr", 48, is_signed=False, is_addr=True)


def type_from_name(name: str) -> Optional[Type]:
    t = name.strip().lower()
    if t == "u24":
        return U24
    if t == "s24":
        return S24
    if t in ("addr", "ptr", "pointer"):
        return ADDR
    return None

