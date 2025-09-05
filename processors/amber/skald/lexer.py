from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional


KEYWORDS = {
    "let",
    "fn",
    "return",
    "u24",
    "s24",
    "addr",
    "in",
    "out",
}


@dataclass
class Token:
    kind: str
    text: str
    line: int
    col: int


class LexError(Exception):
    pass


class Lexer:
    def __init__(self, src: str) -> None:
        # Tolerate a UTF-8 BOM at the start of the source
        if src.startswith('\ufeff'):
            src = src.lstrip('\ufeff')
        self.src = src
        self.i = 0
        self.line = 1
        self.col = 1

    def _peek(self) -> str:
        return self.src[self.i] if self.i < len(self.src) else "\0"

    def _get(self) -> str:
        if self.i >= len(self.src):
            return "\0"
        ch = self.src[self.i]
        self.i += 1
        if ch == "\n":
            self.line += 1
            self.col = 1
        else:
            self.col += 1
        return ch

    def _match(self, s: str) -> bool:
        if self.src.startswith(s, self.i):
            for _ in s:
                self._get()
            return True
        return False

    def tokens(self) -> List[Token]:
        toks: List[Token] = []
        while True:
            self._skip_ws_and_comments()
            start_line, start_col = self.line, self.col
            ch = self._peek()
            if ch == "\0":
                toks.append(Token("EOF", "", start_line, start_col))
                break
            if ch.isalpha() or ch == "_":
                ident = self._read_ident()
                kind = ident if ident in KEYWORDS else "IDENT"
                toks.append(Token(kind, ident, start_line, start_col))
                continue
            if ch.isdigit():
                num = self._read_number()
                toks.append(Token("NUMBER", num, start_line, start_col))
                continue
            # punctuators
            if self._match("->"):
                toks.append(Token("ARROW", "->", start_line, start_col))
                continue
            # compound assignment (check longer tokens first)
            if self._match("<<="):
                toks.append(Token("SHLEQ", "<<=", start_line, start_col))
                continue
            if self._match(">>="):
                toks.append(Token("SHREQ", ">>=", start_line, start_col))
                continue
            if self._match("+="):
                toks.append(Token("PLUSEQ", "+=", start_line, start_col))
                continue
            if self._match("-="):
                toks.append(Token("MINUSEQ", "-=", start_line, start_col))
                continue
            if self._match("&="):
                toks.append(Token("ANDEQ", "&=", start_line, start_col))
                continue
            if self._match("|="):
                toks.append(Token("OREQ", "|=", start_line, start_col))
                continue
            if self._match("^="):
                toks.append(Token("XOREQ", "^=", start_line, start_col))
                continue
            single = {
                "(": "LPAREN",
                ")": "RPAREN",
                "{": "LBRACE",
                "}": "RBRACE",
                ":": "COLON",
                ",": "COMMA",
                ";": "SEMI",
                "=": "EQ",
                "+": "PLUS",
                "-": "MINUS",
                "*": "STAR",
                "/": "SLASH",
                "&": "AMP",
                "|": "BAR",
                "^": "CARET",
                "~": "TILDE",
                "<": "LT",
                ">": "GT",
            }
            if ch in single:
                self._get()
                toks.append(Token(single[ch], ch, start_line, start_col))
                continue
            raise LexError(f"Unexpected character '{ch}' at {start_line}:{start_col}")
        return toks

    def _skip_ws_and_comments(self) -> None:
        while True:
            ch = self._peek()
            if ch in (" ", "\t", "\r", "\n"):
                self._get()
                continue
            # line comment: // ... EOL
            if self._match("//"):
                while self._peek() not in ("\0", "\n"):
                    self._get()
                continue
            # block comment: /* ... */
            if self._match("/*"):
                while not self._match("*/"):
                    if self._peek() == "\0":
                        raise LexError("Unterminated block comment")
                    self._get()
                continue
            break

    def _read_ident(self) -> str:
        s = []
        while True:
            ch = self._peek()
            if ch.isalnum() or ch == "_":
                s.append(self._get())
            else:
                break
        return "".join(s)

    def _read_number(self) -> str:
        # Accept 0x..., 0b..., 0o..., or decimal
        start = self._peek()
        s = []
        if start == "0" and self.src.startswith(("0x", "0X", "0b", "0B", "0o", "0O"), self.i):
            s.append(self._get())  # 0
            s.append(self._get())  # x/b/o
            while True:
                ch = self._peek()
                if ch.isalnum():
                    s.append(self._get())
                else:
                    break
            return "".join(s)
        # decimal
        while self._peek().isdigit():
            s.append(self._get())
        return "".join(s)
