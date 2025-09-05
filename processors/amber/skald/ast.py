from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional

from .typesys import Type


@dataclass
class Node:
    line: int
    col: int


@dataclass
class Program(Node):
    decls: List[Node] = field(default_factory=list)


@dataclass
class VarDecl(Node):
    name: str
    ty: Type
    init: Optional["Expr"] = None
    is_global: bool = False


@dataclass
class Param(Node):
    name: str
    ty: Type
    reg_hint: Optional[str] = None  # e.g., "DR1" or "AR0"


@dataclass
class FuncDecl(Node):
    name: str
    params: List[Param]
    ret_ty: Optional[Type]
    ret_reg_hint: Optional[str]
    body: List["Stmt"]


# Statements
class Stmt(Node):
    pass


@dataclass
class Return(Stmt):
    value: Optional["Expr"]


# Expressions
class Expr(Node):
    pass


@dataclass
class IntLiteral(Expr):
    value: int
    as_signed: bool = False


@dataclass
class NameRef(Expr):
    ident: str


@dataclass
class Binary(Expr):
    op: str
    lhs: Expr
    rhs: Expr

