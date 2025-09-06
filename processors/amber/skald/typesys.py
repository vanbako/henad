from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple


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
ADDR = Type("addr", 48, is_signed=False, is_addr=True)  # internal/sentinel only


def type_from_name(name: str) -> Optional[Type]:
    # Builtins: case-insensitive
    t = name.strip()
    tl = t.lower()
    if tl == "u24":
        return U24
    if tl == "s24":
        return S24
    # Plain 'addr' is not a valid surface type (must be addr<T>)
    # Structs: case-sensitive lookup
    st = _STRUCTS.get(t) if '_STRUCTS' in globals() else None
    if st is not None:
        return st
    return None


@dataclass(frozen=True)
class StructType(Type):
    # List of (field_name, field_type, offset_words)
    fields: Tuple[Tuple[str, Type, int], ...] = ()
    size_words: int = 0


# Registry for user-defined struct types: exact (case-sensitive) names
_STRUCTS: Dict[str, StructType] = {}


def define_struct(name: str, fields: List[Tuple[str, Type]]) -> StructType:
    """Define a struct type with the given fields.

    Constraints:
      - Field types may be primitive data (`u24`, `s24`) or address (`addr<T>`).
      - Nested structs are NOT allowed.

    Field sizes:
      - u24/s24 occupy 1 word
      - addr<T> occupies 2 words (low then high)
    """
    if name in _STRUCTS:
        raise ValueError(f"struct '{name}' already defined")
    # Validate and compute layout
    offs = 0
    laid_out: List[Tuple[str, Type, int]] = []
    for fname, fty in fields:
        # Disallow nested structs; allow addr<T> as a primitive 48-bit field
        if isinstance(fty, StructType):
            raise ValueError("nested struct fields are not supported")
        laid_out.append((fname, fty, offs))
        offs += 2 if fty.is_addr else 1
    st = StructType(name=name, bits=48, is_signed=False, is_addr=True, fields=tuple(laid_out), size_words=offs)
    _STRUCTS[name] = st
    return st


def get_struct(name: str) -> Optional[StructType]:
    return _STRUCTS.get(name)


@dataclass(frozen=True)
class AddressType(Type):
    pointee: Type = U24


def addr_of(pointee: Type) -> AddressType:
    return AddressType(
        name=f"addr<{pointee.name}>", bits=48, is_signed=False, is_addr=True, pointee=pointee
    )


@dataclass(frozen=True)
class ArrayType(Type):
    elem: Type = U24
    length: int = 0
    elem_words: int = 1
    size_words: int = 0


def array_of(elem: Type, length: int) -> ArrayType:
    """Create a one-dimensional static array type.

    Constraints:
      - Only primitive data (u24/s24) and address types (addr<...>) are allowed as elements.
      - Struct element types and nested arrays are not supported in this MVP.

    Semantics:
      - Array variables are address-like: a local `let a: T[N];` allocates N*elem_words
        words on the stack and binds `a` to a base pointer in an AR register.
    """
    if length <= 0:
        raise ValueError("array length must be positive")
    if isinstance(elem, StructType):
        raise ValueError("arrays of struct are not supported")
    # Disallow nesting: if someone synthesizes ArrayType elem, reject
    if isinstance(elem, ArrayType):
        raise ValueError("nested arrays are not supported")
    elem_words = 2 if elem.is_addr else 1
    size_words = length * elem_words
    return ArrayType(
        name=f"{elem.name}[{length}]",
        bits=48,  # address-like; variable binds to AR base
        is_signed=False,
        is_addr=True,
        elem=elem,
        length=length,
        elem_words=elem_words,
        size_words=size_words,
    )
