from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional, Tuple

from .lexer import Lexer, Token, LexError
from . import ast as A
from .typesys import type_from_name, Type, define_struct, addr_of, array_of


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

    def _peek_n(self, n: int) -> Token:
        idx = self.i + n
        if idx < 0:
            idx = 0
        if idx >= len(self.tokens):
            return self.tokens[-1]
        return self.tokens[idx]

    def parse(self) -> A.Program:
        prog = A.Program(line=1, col=1)
        while self._peek().kind != "EOF":
            if self._peek().kind == "let":
                prog.decls.append(self.parse_global_let())
            elif self._peek().kind == "fn":
                prog.decls.append(self.parse_fn())
            elif self._peek().kind == "struct":
                prog.decls.append(self.parse_struct())
            else:
                t = self._peek()
                raise ParseError(f"Unexpected token {t.kind} at {t.line}:{t.col}")
        return prog

    def parse_struct(self) -> A.StructDecl:
        kw = self._eat("struct")
        name_tok = self._eat("IDENT")
        self._eat("LBRACE")
        fields: List[Tuple[str, Type]] = []
        while self._peek().kind != "RBRACE":
            fname = self._eat("IDENT").text
            self._eat("COLON")
            fty = self.parse_type()
            self._eat("SEMI")
            fields.append((fname, fty))
        self._eat("RBRACE")
        # Register the struct type globally for later type lookups
        define_struct(name_tok.text, fields)
        return A.StructDecl(kw.line, kw.col, name_tok.text, fields)

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
        base: Optional[Type] = None
        if t.kind in ("u24", "s24"):
            self.i += 1
            base = type_from_name(t.kind)
            assert base is not None
        elif t.kind == "addr":
            # Require generic parameter: addr<type>
            self.i += 1
            if not self._match("LT"):
                raise ParseError(f"'addr' must be parameterized as addr<type> at {t.line}:{t.col}")
            inner = self.parse_type()
            self._eat("GT")
            base = addr_of(inner)
        elif t.kind == "IDENT":
            self.i += 1
            ty = type_from_name(t.text)
            if ty is None:
                raise ParseError(f"Unknown type '{t.text}' at {t.line}:{t.col}")
            base = ty
        else:
            raise ParseError(f"Expected type, got {t.kind} at {t.line}:{t.col}")
        # Optional one-dimensional array suffix: [NUMBER]
        if self._peek().kind == "LBRACK":
            self._eat("LBRACK")
            n_tok = self._eat("NUMBER")
            try:
                length = self._parse_int(n_tok.text)
            except Exception:
                raise ParseError(f"invalid array length at {n_tok.line}:{n_tok.col}")
            self._eat("RBRACK")
            # Disallow nested array suffixes in MVP
            if self._peek().kind == "LBRACK":
                raise ParseError("multi-dimensional arrays are not supported")
            return array_of(base, length)
        return base

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
        if t.kind == "if":
            return self.parse_if()
        if t.kind == "while":
            return self.parse_while()
        if t.kind == "break":
            return self.parse_break()
        if t.kind == "continue":
            return self.parse_continue()
        if t.kind == "return":
            return self.parse_return()
        if t.kind == "IDENT":
            # lookahead for call vs assignment
            nxt = self._peek_n(1)
            if nxt.kind == "LPAREN":
                e = self.parse_call_expr()
                self._eat("SEMI")
                return A.ExprStmt(e.line, e.col, e)
            # assignment? IDENT '=' expr ';'
            return self.parse_assign()
        raise ParseError(f"Unexpected token in function body: {t.kind} at {t.line}:{t.col}")

    def parse_block(self) -> List[A.Stmt]:
        self._eat("LBRACE")
        items: List[A.Stmt] = []
        while self._peek().kind != "RBRACE":
            items.append(self.parse_stmt())
        self._eat("RBRACE")
        return items

    def parse_if(self) -> A.If:
        kw = self._eat("if")
        self._eat("LPAREN")
        cond = self.parse_expr()
        self._eat("RPAREN")
        then_body = self.parse_block()
        else_body = None
        if self._match("else"):
            # Only support else { ... } for now
            else_body = self.parse_block()
        return A.If(kw.line, kw.col, cond, then_body, else_body)

    def parse_while(self) -> A.While:
        kw = self._eat("while")
        self._eat("LPAREN")
        cond = self.parse_expr()
        self._eat("RPAREN")
        body = self.parse_block()
        return A.While(kw.line, kw.col, cond, body)

    def parse_break(self) -> A.Break:
        kw = self._eat("break")
        self._eat("SEMI")
        return A.Break(kw.line, kw.col)

    def parse_continue(self) -> A.Continue:
        kw = self._eat("continue")
        self._eat("SEMI")
        return A.Continue(kw.line, kw.col)

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

    def parse_assign(self) -> A.Assign:
        # Parse lvalue: IDENT ('.' IDENT | '[' expr ']')*
        name = self._eat("IDENT")
        lhs: A.Expr = A.NameRef(name.line, name.col, name.text)
        while True:
            if self._match("DOT"):
                fld = self._eat("IDENT")
                lhs = A.FieldAccess(name.line, name.col, lhs, fld.text)
                continue
            if self._match("LBRACK"):
                idx = self.parse_expr()
                self._eat("RBRACK")
                lhs = A.ArrayIndex(name.line, name.col, lhs, idx)
                continue
            break
        # Check for compound assignment operators
        op_tok = None
        for kind in ("ROLEQ", "ROREQ", "PLUSEQ", "MINUSEQ", "ANDEQ", "OREQ", "XOREQ", "SHLEQ", "SHREQ", "EQ"):
            if self._match(kind):
                op_tok = kind
                break
        if op_tok is None:
            t = self._peek()
            raise ParseError(f"Expected assignment operator after lvalue at {t.line}:{t.col}")
        val = self.parse_expr()
        self._eat("SEMI")
        op_map = {
            "EQ": "=",
            "ROLEQ": "<<<=",
            "ROREQ": ">>>=",
            "PLUSEQ": "+=",
            "MINUSEQ": "-=",
            "ANDEQ": "&=",
            "OREQ": "|=",
            "XOREQ": "^=",
            "SHLEQ": "<<=",
            "SHREQ": ">>=",
        }
        op_str = op_map[op_tok]
        return A.Assign(name.line, name.col, lhs, val, op_str)

    # Expressions with precedence and parentheses
    # Grammar (skeleton):
    #   expr    := bitor
    #   bitor   := bitxor ( '|' bitxor )*
    #   bitxor  := bitand ( '^' bitand )*
    #   bitand  := equality ( '&' equality )*
    #   equality:= relational ( ('=='|'!=') relational )*
    #   relational := shift ( ('<'|'>'|'<='|'>=') shift )*
    #   shift   := add ( ('<<'|'>>') add )*
    #   add     := mul ( ('+'|'-') mul )*
    #   mul     := unary ( ('*'|'/') unary )*
    #   unary   := ('+'|'-'|'~') unary | primary
    #   primary := NUMBER | IDENT | '(' expr ')'
    def parse_expr(self) -> A.Expr:
        return self.parse_bitor()

    def parse_bitor(self) -> A.Expr:
        lhs = self.parse_bitxor()
        while self._peek().kind == "BAR":
            op = self._eat("BAR")
            rhs = self.parse_bitxor()
            lhs = A.Binary(line=op.line, col=op.col, op="|", lhs=lhs, rhs=rhs)
        return lhs

    def parse_bitxor(self) -> A.Expr:
        lhs = self.parse_bitand()
        while self._peek().kind == "CARET":
            op = self._eat("CARET")
            rhs = self.parse_bitand()
            lhs = A.Binary(line=op.line, col=op.col, op="^", lhs=lhs, rhs=rhs)
        return lhs

    def parse_bitand(self) -> A.Expr:
        lhs = self.parse_equality()
        while self._peek().kind == "AMP":
            op = self._eat("AMP")
            rhs = self.parse_equality()
            lhs = A.Binary(line=op.line, col=op.col, op="&", lhs=lhs, rhs=rhs)
        return lhs

    def parse_equality(self) -> A.Expr:
        lhs = self.parse_relational()
        while self._peek().kind in ("EQEQ", "NEQ"):
            t = self._peek()
            if t.kind == "EQEQ":
                op = self._eat("EQEQ")
                rhs = self.parse_relational()
                lhs = A.Binary(line=op.line, col=op.col, op="==", lhs=lhs, rhs=rhs)
            elif t.kind == "NEQ":
                op = self._eat("NEQ")
                rhs = self.parse_relational()
                lhs = A.Binary(line=op.line, col=op.col, op="!=", lhs=lhs, rhs=rhs)
        return lhs

    def parse_relational(self) -> A.Expr:
        lhs = self.parse_shift()
        while self._peek().kind in ("LT", "GT", "LTE", "GTE"):
            t = self._peek()
            if t.kind == "LT":
                op = self._eat("LT")
                rhs = self.parse_shift()
                lhs = A.Binary(line=op.line, col=op.col, op="<", lhs=lhs, rhs=rhs)
            elif t.kind == "GT":
                op = self._eat("GT")
                rhs = self.parse_shift()
                lhs = A.Binary(line=op.line, col=op.col, op=">", lhs=lhs, rhs=rhs)
            elif t.kind == "LTE":
                op = self._eat("LTE")
                rhs = self.parse_shift()
                lhs = A.Binary(line=op.line, col=op.col, op="<=", lhs=lhs, rhs=rhs)
            elif t.kind == "GTE":
                op = self._eat("GTE")
                rhs = self.parse_shift()
                lhs = A.Binary(line=op.line, col=op.col, op=">=", lhs=lhs, rhs=rhs)
        return lhs

    def parse_shift(self) -> A.Expr:
        lhs = self.parse_add()
        while self._peek().kind in ("SHL", "SHR"):
            t = self._peek()
            op = self._eat(t.kind)
            rhs = self.parse_add()
            sym = "<<" if t.kind == "SHL" else ">>"
            lhs = A.Binary(line=op.line, col=op.col, op=sym, lhs=lhs, rhs=rhs)
        return lhs

    def parse_add(self) -> A.Expr:
        lhs = self.parse_mul()
        while self._peek().kind in ("PLUS", "MINUS"):
            op = self._eat(self._peek().kind)
            rhs = self.parse_mul()
            lhs = A.Binary(line=op.line, col=op.col, op=op.text, lhs=lhs, rhs=rhs)
        return lhs

    def parse_mul(self) -> A.Expr:
        lhs = self.parse_unary()
        while self._peek().kind in ("STAR", "SLASH"):
            op = self._eat(self._peek().kind)
            rhs = self.parse_unary()
            lhs = A.Binary(line=op.line, col=op.col, op=op.text, lhs=lhs, rhs=rhs)
        return lhs

    def parse_unary(self) -> A.Expr:
        t = self._peek()
        if t.kind in ("PLUS", "MINUS"):
            op = self._eat(t.kind)
            # Represent unary +x as (0 + x) and -x as (0 - x)
            zero = A.IntLiteral(op.line, op.col, 0)
            rhs = self.parse_unary()
            return A.Binary(line=op.line, col=op.col, op=op.text, lhs=zero, rhs=rhs)
        if t.kind == "TILDE":
            op = self._eat("TILDE")
            rhs = self.parse_unary()
            return A.Unary(line=op.line, col=op.col, op="~", expr=rhs)
        return self.parse_primary()

    def parse_primary(self) -> A.Expr:
        t = self._peek()
        if t.kind == "NUMBER":
            tok = self._eat("NUMBER")
            return A.IntLiteral(tok.line, tok.col, self._parse_int(tok.text))
        if t.kind == "IDENT":
            # function call or name reference
            tok = self._eat("IDENT")
            # Handle call, field access, or bare name
            if self._peek().kind == "LPAREN":
                return self._finish_call(tok)
            # Field and/or index access chain: IDENT ('.' IDENT | '[' expr ']')*
            base: A.Expr = A.NameRef(tok.line, tok.col, tok.text)
            while True:
                if self._peek().kind == "DOT":
                    self._eat("DOT")
                    fld = self._eat("IDENT")
                    base = A.FieldAccess(tok.line, tok.col, base, fld.text)
                    continue
                if self._peek().kind == "LBRACK":
                    self._eat("LBRACK")
                    idx = self.parse_expr()
                    self._eat("RBRACK")
                    base = A.ArrayIndex(tok.line, tok.col, base, idx)
                    continue
                break
            return base
        if t.kind == "LPAREN":
            self._eat("LPAREN")
            e = self.parse_expr()
            self._eat("RPAREN")
            return e
        raise ParseError(f"Expected expression at {t.line}:{t.col}")

    def parse_call_expr(self) -> A.Call:
        # Expect IDENT '(' ... ')'
        name = self._eat("IDENT")
        if self._peek().kind != "LPAREN":
            raise ParseError(f"Expected '(' after function name at {name.line}:{name.col}")
        return self._finish_call(name)

    def _finish_call(self, name_tok: Token) -> A.Call:
        lpar = self._eat("LPAREN")
        args: List[A.Expr] = []
        if self._peek().kind != "RPAREN":
            while True:
                args.append(self.parse_expr())
                if not self._match("COMMA"):
                    break
        self._eat("RPAREN")
        # Recognize built-in cast pseudo-functions: cast_s24(x), cast_u24(x)
        if name_tok.text in ("cast_s24", "cast_u24"):
            if len(args) != 1:
                raise ParseError(f"{name_tok.text} expects exactly 1 argument at {name_tok.line}:{name_tok.col}")
            from .typesys import S24, U24  # local import to avoid cycles
            tgt = S24 if name_tok.text == "cast_s24" else U24
            return A.Cast(name_tok.line, name_tok.col, tgt, args[0])
        # Address-of and content built-ins (strongly typed)
        if name_tok.text == "get_addr":
            if len(args) != 1:
                raise ParseError(f"get_addr expects 1 argument at {name_tok.line}:{name_tok.col}")
            # Accept only NameRef or FieldAccess; reject others here to give better errors
            if not isinstance(args[0], (A.NameRef, A.FieldAccess)):
                raise ParseError("get_addr argument must be a variable or field access")
            return A.AddressOf(name_tok.line, name_tok.col, args[0])
        if name_tok.text == "get_content":
            if len(args) != 1:
                raise ParseError(f"get_content expects 1 argument at {name_tok.line}:{name_tok.col}")
            return A.Deref(name_tok.line, name_tok.col, args[0])
        return A.Call(name_tok.line, name_tok.col, name_tok.text, args)

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
