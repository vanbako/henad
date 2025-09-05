from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional

from .lexer import Lexer, Token, LexError
from . import ast as A
from .typesys import type_from_name, Type


class ParseError(Exception):
    pass


class Parser:
    def __init__(self, src: str) -> None:
        self.tokens = Lexer(src).tokens()
        self.i = 0

    def _peek(self) -> Token:
        return self.tokens[self.i]

    def _eat(self, kind: str) -> Token:
        t = self._peek()
        if t.kind != kind:
            raise ParseError(f"Expected {kind}, got {t.kind} at {t.line}:{t.col}")
        self.i += 1
        return t

    def _match(self, kind: str) -> Optional[Token]:
        t = self._peek()
        if t.kind == kind:
            self.i += 1
            return t
        return None

    def parse(self) -> A.Program:
        prog = A.Program(line=1, col=1)
        while self._peek().kind != "EOF":
            if self._peek().kind == "let":
                prog.decls.append(self.parse_global_let())
            elif self._peek().kind == "fn":
                prog.decls.append(self.parse_fn())
            else:
                t = self._peek()
                raise ParseError(f"Unexpected token {t.kind} at {t.line}:{t.col}")
        return prog

    def parse_global_let(self) -> A.VarDecl:
        kw = self._eat("let")
        name = self._eat("IDENT")
        self._eat("COLON")
        ty = self.parse_type()
        init = None
        if self._match("EQ"):
            init = self.parse_expr()
        self._eat("SEMI")
        return A.VarDecl(kw.line, kw.col, name.text, ty, init, is_global=True)

    def parse_type(self) -> Type:
        t = self._peek()
        if t.kind in ("u24", "s24", "addr"):
            self.i += 1
            ty = type_from_name(t.kind)
            assert ty is not None
            return ty
        raise ParseError(f"Expected type, got {t.kind} at {t.line}:{t.col}")

    def parse_fn(self) -> A.FuncDecl:
        kw = self._eat("fn")
        name = self._eat("IDENT")
        self._eat("LPAREN")
        params: List[A.Param] = []
        if self._peek().kind != "RPAREN":
            while True:
                params.append(self.parse_param())
                if not self._match("COMMA"):
                    break
        self._eat("RPAREN")
        ret_ty: Optional[Type] = None
        ret_reg_hint: Optional[str] = None
        if self._match("ARROW"):
            ret_ty = self.parse_type()
            # optional: out DRx/ARx
            if self._match("out"):
                regtok = self._eat("IDENT")
                ret_reg_hint = regtok.text.upper()
        self._eat("LBRACE")
        body: List[A.Stmt] = []
        while self._peek().kind != "RBRACE":
            body.append(self.parse_stmt())
        rbrace = self._eat("RBRACE")
        return A.FuncDecl(kw.line, kw.col, name.text, params, ret_ty, ret_reg_hint, body)

    def parse_param(self) -> A.Param:
        name = self._eat("IDENT")
        self._eat("COLON")
        ty = self.parse_type()
        reg_hint: Optional[str] = None
        if self._match("in"):
            regtok = self._eat("IDENT")
            reg_hint = regtok.text.upper()
        return A.Param(name.line, name.col, name.text, ty, reg_hint)

    # Statements (skeleton): let and return only
    def parse_stmt(self) -> A.Stmt:
        t = self._peek()
        if t.kind == "let":
            return self.parse_local_let()
        if t.kind == "return":
            return self.parse_return()
        raise ParseError(f"Unexpected token in function body: {t.kind} at {t.line}:{t.col}")

    def parse_local_let(self) -> A.VarDecl:
        kw = self._eat("let")
        name = self._eat("IDENT")
        self._eat("COLON")
        ty = self.parse_type()
        init = None
        if self._match("EQ"):
            init = self.parse_expr()
        self._eat("SEMI")
        return A.VarDecl(kw.line, kw.col, name.text, ty, init, is_global=False)

    def parse_return(self) -> A.Return:
        kw = self._eat("return")
        val: Optional[A.Expr] = None
        if self._peek().kind != "SEMI":
            val = self.parse_expr()
        self._eat("SEMI")
        return A.Return(kw.line, kw.col, val)

    # Very simple expressions: NUMBER | IDENT | lhs (+|-) rhs | lhs (*|/) rhs
    # Left-to-right, no precedence (skeleton)
    def parse_expr(self) -> A.Expr:
        lhs = self.parse_primary()
        while self._peek().kind in ("PLUS", "MINUS", "STAR", "SLASH"):
            op = self._eat(self._peek().kind)
            rhs = self.parse_primary()
            lhs = A.Binary(op.text, lhs, rhs, line=op.line, col=op.col)  # type: ignore[arg-type]
        return lhs

    def parse_primary(self) -> A.Expr:
        t = self._peek()
        if t.kind == "NUMBER":
            tok = self._eat("NUMBER")
            return A.IntLiteral(tok.line, tok.col, self._parse_int(tok.text))
        if t.kind == "IDENT":
            tok = self._eat("IDENT")
            return A.NameRef(tok.line, tok.col, tok.text)
        raise ParseError(f"Expected expression at {t.line}:{t.col}")

    @staticmethod
    def _parse_int(text: str) -> int:
        s = text
        base = 10
        if s.startswith(("0x", "0X")):
            base = 16
        elif s.startswith(("0b", "0B")):
            base = 2
        elif s.startswith(("0o", "0O")):
            base = 8
        return int(s, base)


def parse(src: str) -> A.Program:
    return Parser(src).parse()

