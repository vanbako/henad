from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional, Tuple

from .typesys import Type


@dataclass
class Node:
    line: int
    col: int


@dataclass
class Program(Node):
    decls: List[Node] = field(default_factory=list)


@dataclass
class StructDecl(Node):
    name: str
    fields: List[Tuple[str, Type]]  # (field_name, type)


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


@dataclass
class Assign(Stmt):
    # target may be a name or a field access expression
    target: "Expr"  # NameRef or FieldAccess
    value: "Expr"
    op: str = "="  # '=', '+=', '-=', '&=', '|=', '^=', '<<=', '>>='


@dataclass
class ExprStmt(Stmt):
    expr: "Expr"


@dataclass
class If(Stmt):
    cond: "Expr"
    then_body: List["Stmt"]
    else_body: Optional[List["Stmt"]] = None

@dataclass
class While(Stmt):
    cond: "Expr"
    body: List["Stmt"]

@dataclass
class Break(Stmt):
    pass

@dataclass
class Continue(Stmt):
    pass


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
class FieldAccess(Expr):
    base: Expr  # typically a NameRef
    field: str


@dataclass
class ArrayIndex(Expr):
    base: Expr  # typically a NameRef (array variable)
    index: Expr


@dataclass
class AddressOf(Expr):
    target: Expr  # NameRef or FieldAccess only


@dataclass
class Deref(Expr):
    addr_expr: Expr  # AddressOf only (strongly typed)


@dataclass
class Unary(Expr):
    op: str
    expr: Expr


@dataclass
class Binary(Expr):
    op: str
    lhs: Expr
    rhs: Expr


@dataclass
class Call(Expr):
    callee: str
    args: List[Expr]


@dataclass
class Cast(Expr):
    target: Type
    expr: Expr
