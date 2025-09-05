from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

from . import ast as A
from .typesys import U24, S24, ADDR, Type


class CodegenError(Exception):
    pass


@dataclass
class Reg:
    name: str  # e.g., DR1 or AR0
    is_addr: bool


class CodeGen:
    def __init__(self) -> None:
        self.lines: List[str] = []
        self.globals: List[str] = []
        self.sym_regs: Dict[str, Reg] = {}
        self.sym_types: Dict[str, Type] = {}
        self.next_dr = 1  # DR0 reserved for return/scratch by convention
        self.next_ar = 0

    def emit(self, s: str) -> None:
        self.lines.append(s)

    def comment(self, s: str) -> None:
        self.lines.append(f"    ; {s}")

    def alloc_reg(self, ty: Type, hint: Optional[str] = None) -> Reg:
        if hint is not None:
            return Reg(hint.upper(), hint.upper().startswith("AR"))
        if ty.is_addr:
            n = self.next_ar
            self.next_ar += 1
            return Reg(f"AR{n}", True)
        n = self.next_dr
        self.next_dr += 1
        return Reg(f"DR{n}", False)

    def gen_program(self, prog: A.Program) -> str:
        self.lines.clear()
        self.globals.clear()

        self.emit("    .org 0")

        # Globals: emit storage as .dw24 (u24/s24) or two words for addr (placeholder)
        for d in prog.decls:
            if isinstance(d, A.VarDecl) and d.is_global:
                self.gen_global(d)

        # Functions
        for d in prog.decls:
            if isinstance(d, A.FuncDecl):
                self.gen_func(d)

        return "\n".join(self.lines) + "\n"

    def gen_global(self, v: A.VarDecl) -> None:
        label = v.name
        if v.ty.is_addr:
            # Reserve two 24-bit words for a 48-bit value (low then high)
            self.emit(f"{label}:")
            lo = 0
            hi = 0
            if isinstance(v.init, A.IntLiteral):
                val = v.init.value & ((1 << 48) - 1)
                lo = val & 0xFFFFFF
                hi = (val >> 24) & 0xFFFFFF
            self.emit(f"    .dw24 #{lo}")
            self.emit(f"    .dw24 #{hi}")
        else:
            val = 0
            if isinstance(v.init, A.IntLiteral):
                val = v.init.value & 0xFFFFFF
            self.emit(f"{label}:")
            self.emit(f"    .dw24 #{val}")

    def gen_func(self, f: A.FuncDecl) -> None:
        # Reset simple allocator per function
        self.sym_regs.clear()
        self.next_dr = 1
        self.next_ar = 0

        self.emit(f"{f.name}:")
        self.comment("prologue (skeleton, no saves)")

        # Assign registers to params (by hint or by type class)
        for p in f.params:
            r = self.alloc_reg(p.ty, p.reg_hint)
            self.sym_regs[p.name] = r
            self.sym_types[p.name] = p.ty
            self.comment(f"param {p.name}:{p.ty} in {r.name}")

        ret_reg = None
        if f.ret_ty is not None:
            # Default return regs
            if f.ret_reg_hint:
                ret_reg = Reg(f.ret_reg_hint.upper(), f.ret_reg_hint.upper().startswith("AR"))
            else:
                ret_reg = Reg("AR0", True) if f.ret_ty.is_addr else Reg("DR0", False)

        # Body
        for s in f.body:
            if isinstance(s, A.VarDecl):
                self.gen_local_let(s)
            elif isinstance(s, A.Return):
                self.gen_return(s, ret_reg, f.ret_ty)
            elif isinstance(s, A.Assign):
                self.gen_assign(s)
            else:
                raise CodegenError("unsupported statement kind")

        # If no explicit return and function returns nothing, fall-through
        if f.ret_ty is None:
            self.emit("    RET")

    def gen_local_let(self, v: A.VarDecl) -> None:
        r = self.alloc_reg(v.ty)
        self.sym_regs[v.name] = r
        self.sym_types[v.name] = v.ty
        self.comment(f"let {v.name}:{v.ty} -> {r.name}")
        if v.init is not None:
            self.gen_store_expr_into(v.init, v.ty, r)

    def gen_assign(self, a: A.Assign) -> None:
        if a.target not in self.sym_regs:
            raise CodegenError(f"assignment to unknown variable '{a.target}'")
        dst = self.sym_regs[a.target]
        if a.target not in self.sym_types:
            raise CodegenError(f"internal: missing type for '{a.target}'")
        ty = self.sym_types[a.target]
        op = a.op
        if op == "=":
            self.gen_store_expr_into(a.value, ty, dst)
            return
        # No compound ops on addr (for now)
        if ty.is_addr:
            raise CodegenError("compound assignment not supported for 'addr' type in skeleton")
        # Evaluate RHS with appropriate expected type
        if op in ("<<=", ">>="):
            rhs = self.gen_eval_expr(a.value, U24)
        else:
            rhs = self.gen_eval_expr(a.value, ty)
        # Apply op in-place to dst
        if op == "+=":
            m = "ADDSR" if ty.is_signed else "ADDUR"
            self.emit(f"    {m} {rhs.name}, {dst.name}")
        elif op == "-=":
            m = "SUBSR" if ty.is_signed else "SUBUR"
            self.emit(f"    {m} {rhs.name}, {dst.name}")
        elif op == "&=":
            self.emit(f"    ANDUR {rhs.name}, {dst.name}")
        elif op == "|=":
            self.emit(f"    ORUR {rhs.name}, {dst.name}")
        elif op == "^=":
            self.emit(f"    XORUR {rhs.name}, {dst.name}")
        elif op == "<<=":
            self.emit(f"    SHLUR {rhs.name}, {dst.name}")
        elif op == ">>=":
            m = "SHRSR" if ty.is_signed else "SHRUR"
            self.emit(f"    {m} {rhs.name}, {dst.name}")
        else:
            raise CodegenError(f"unsupported compound operator '{op}'")

    def gen_return(self, r: A.Return, ret_reg: Optional[Reg], ret_ty: Optional[Type]) -> None:
        if ret_ty is None:
            self.emit("    RET")
            return
        if r.value is None:
            raise CodegenError("return requires a value for non-void function")
        if ret_reg is None:
            raise CodegenError("internal: missing return register")
        tmp = self.gen_eval_expr(r.value, ret_ty)
        if tmp.name != ret_reg.name:
            if ret_reg.is_addr and not tmp.is_addr:
                # Move DRtmp -> ARret low (placeholder: only low part)
                self.emit(f"    MOVAur {tmp.name}, {ret_reg.name}, L")
            elif (not ret_reg.is_addr) and tmp.is_addr:
                self.emit(f"    MOVDur {tmp.name}, {ret_reg.name}, L")
            else:
                self.emit(f"    MOVur {tmp.name}, {ret_reg.name}")
        self.emit("    RET")

    # --- Expression helpers -------------------------------------------------
    def gen_store_expr_into(self, e: A.Expr, ty: Type, dst: Reg) -> Reg:
        src = self.gen_eval_expr(e, ty)
        if src.name == dst.name:
            return dst
        if dst.is_addr and not src.is_addr:
            self.emit(f"    MOVAur {src.name}, {dst.name}, L")
            return dst
        if (not dst.is_addr) and src.is_addr:
            self.emit(f"    MOVDur {src.name}, {dst.name}, L")
            return dst
        self.emit(f"    MOVur {src.name}, {dst.name}")
        return dst

    def gen_eval_expr(self, e: A.Expr, ty: Type) -> Reg:
        if isinstance(e, A.IntLiteral):
            # Materialize into a DR
            dr = self.alloc_reg(U24)
            imm = e.value & 0xFFF  # skeleton: 12-bit immediates only for now
            self.emit(f"    MOVui #{imm}, {dr.name}")
            return dr
        if isinstance(e, A.NameRef):
            if e.ident not in self.sym_regs:
                raise CodegenError(f"unknown identifier '{e.ident}'")
            # Enforce no implicit conversions: exact match for data types; addr must match
            if e.ident not in self.sym_types:
                raise CodegenError(f"internal: missing type for '{e.ident}'")
            src_ty = self.sym_types[e.ident]
            if src_ty.is_addr != ty.is_addr:
                raise CodegenError(
                    f"type mismatch: expected {ty}, found {src_ty} for '{e.ident}'"
                )
            if not ty.is_addr and src_ty.name != ty.name:
                raise CodegenError(
                    f"type mismatch: expected {ty}, found {src_ty} for '{e.ident}'"
                )
            return self.sym_regs[e.ident]
        if isinstance(e, A.Binary):
            if e.op not in ("+", "-"):
                raise CodegenError("only + and - supported in skeleton")
            lhs = self.gen_eval_expr(e.lhs, ty)
            rhs = self.gen_eval_expr(e.rhs, ty)
            dst = self.alloc_reg(ty)
            # Move lhs into dst
            self.emit(f"    MOVur {lhs.name}, {dst.name}")
            if ty.is_signed:
                op = "ADDSR" if e.op == "+" else "SUBSR"
            else:
                op = "ADDUR" if e.op == "+" else "SUBUR"
            self.emit(f"    {op} {rhs.name}, {dst.name}")
            return dst
        raise CodegenError("unsupported expression form")
