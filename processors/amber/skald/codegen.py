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
        self.next_ar = 1  # AR0 reserved for stack pointer (callee-saved convention)
        # function signatures: name -> (params, ret_ty, ret_reg_hint)
        self.fn_sigs: Dict[str, Tuple[List[Tuple[Type, Optional[str]]], Optional[Type], Optional[str]]] = {}
        # tracking for current function
        self._ret_indices: List[int] = []
        self._func_start_idx: int = -1
        self._dr_base: int = 1
        self._ar_base: int = 1
        self._init_sp_in_prologue: bool = False
        self._label_counter: int = 0
        self._cur_ret_reg: Optional[Reg] = None
        self._cur_ret_ty: Optional[Type] = None

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
        self.fn_sigs.clear()

        self.emit("    .org 0")

        # Globals: emit storage as .dw24 (u24/s24) or two words for addr (placeholder)
        for d in prog.decls:
            if isinstance(d, A.VarDecl) and d.is_global:
                self.gen_global(d)

        # Collect function signatures (types and reg hints)
        for d in prog.decls:
            if isinstance(d, A.FuncDecl):
                params: List[Tuple[Type, Optional[str]]] = [(p.ty, p.reg_hint) for p in d.params]
                self.fn_sigs[d.name] = (params, d.ret_ty, d.ret_reg_hint)

        # Functions
        for d in prog.decls:
            if isinstance(d, A.FuncDecl):
                self.gen_func(d)

        # Emit a small zeroed stack region for examples and initialize SP to its top in 'main'
        self.emit("    ; --- Skald demo stack region ---")
        self.emit("__skald_stack_area:")
        for _ in range(64):  # 64 words (~192 bytes)
            self.emit("    .dw24 #0")
        self.emit("__skald_stack_top:")

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
        self.next_ar = 1  # AR0 is stack pointer
        self._ret_indices = []

        self.emit(f"{f.name}:")
        # Record insertion point for prologue and bases
        self._func_start_idx = len(self.lines)
        self.comment("prologue (callee-saved)")
        # Initialize SP in 'main' before any pushes
        self._init_sp_in_prologue = (f.name == "main")

        # Assign registers to params (by hint or by type class)
        used_dr: List[int] = []
        used_ar: List[int] = []
        for p in f.params:
            r = self.alloc_reg(p.ty, p.reg_hint)
            self.sym_regs[p.name] = r
            self.sym_types[p.name] = p.ty
            self.comment(f"param {p.name}:{p.ty} in {r.name}")
            # Track used param registers to avoid reuse for locals/temps
            if r.name.startswith("DR"):
                try:
                    used_dr.append(int(r.name[2:]))
                except ValueError:
                    pass
            elif r.name.startswith("AR"):
                try:
                    used_ar.append(int(r.name[2:]))
                except ValueError:
                    pass

        # Bump next allocators past any used param registers
        if used_dr:
            self.next_dr = max(self.next_dr, max(used_dr) + 1)
        if used_ar:
            self.next_ar = max(self.next_ar, max(used_ar) + 1)

        ret_reg = None
        if f.ret_ty is not None:
            # Default return regs
            if f.ret_reg_hint:
                ret_reg = Reg(f.ret_reg_hint.upper(), f.ret_reg_hint.upper().startswith("AR"))
            else:
                # AR0 is reserved for stack pointer; use AR1 for address returns
                ret_reg = Reg("AR1", True) if f.ret_ty.is_addr else Reg("DR0", False)

        # Remember bases for locals/temps (after params)
        self._dr_base = self.next_dr
        self._ar_base = self.next_ar

        # Body
        # Capture return signature for nested returns
        prev_ret_reg, prev_ret_ty = self._cur_ret_reg, self._cur_ret_ty
        self._cur_ret_reg, self._cur_ret_ty = ret_reg, f.ret_ty
        for s in f.body:
            if isinstance(s, A.VarDecl):
                self.gen_local_let(s)
            elif isinstance(s, A.Return):
                self.gen_return(s, ret_reg, f.ret_ty)
            elif isinstance(s, A.Assign):
                self.gen_assign(s)
            elif isinstance(s, A.ExprStmt):
                self.gen_expr_stmt(s)
            elif isinstance(s, A.If):
                self.gen_if(s)
            else:
                raise CodegenError("unsupported statement kind")

        # If no explicit return and function returns nothing, fall-through
        if f.ret_ty is None:
            self.emit("    RET")
            self._ret_indices.append(len(self.lines) - 1)

        # Restore previous return context
        self._cur_ret_reg, self._cur_ret_ty = prev_ret_reg, prev_ret_ty
        # Insert prologue and epilogues at recorded points
        self._insert_prologue()
        self._insert_all_epilogues()

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
        # Address arithmetic: only += and -= with DR rhs (u24/s24)
        if ty.is_addr:
            if op not in ("+=", "-="):
                raise CodegenError("only '+=' and '-=' supported for 'addr'")
            # Determine rhs type: name ref or literal only for now
            rhs_ty: Optional[Type] = None
            if isinstance(a.value, A.NameRef):
                nm = a.value.ident
                if nm not in self.sym_types:
                    raise CodegenError(f"unknown identifier '{nm}' in addr assignment")
                st = self.sym_types[nm]
                if st.is_addr:
                    raise CodegenError("cannot use 'addr' value as rhs for addr +=/-=")
                rhs_ty = st
            elif isinstance(a.value, A.IntLiteral):
                rhs_ty = U24
            else:
                raise CodegenError("addr +=/-= requires u24/s24 variable or literal (skeleton)")
            # Evaluate rhs in that type
            rhs_reg = self.gen_eval_expr(a.value, rhs_ty)
            if op == "+=":
                m = "ADDASR" if rhs_ty.is_signed else "ADDAUR"
            else:
                m = "SUBASR" if rhs_ty.is_signed else "SUBAUR"
            self.emit(f"    {m} {rhs_reg.name}, {dst.name}")
            return
        # Evaluate RHS with appropriate expected type
        if op in ("<<=", ">>=", "<<<=", ">>>="):
            rhs = self.gen_eval_data_any(a.value)
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
        elif op == "<<<=":
            # rotate left
            self.emit(f"    ROLUR {rhs.name}, {dst.name}")
        elif op == ">>>=":
            # rotate right
            self.emit(f"    RORUR {rhs.name}, {dst.name}")
        else:
            raise CodegenError(f"unsupported compound operator '{op}'")

    def gen_expr_stmt(self, s: A.ExprStmt) -> None:
        # Only calls have side effects today
        if isinstance(s.expr, A.Call):
            self.gen_call(s.expr, expect_value=False)
        else:
            raise CodegenError("only function calls permitted as expression statements")

    def _new_label(self, prefix: str) -> str:
        self._label_counter += 1
        return f"__sk_{prefix}_{self._label_counter}"

    def gen_if(self, node: A.If) -> None:
        # Evaluate condition as data (u24). 'addr' not allowed.
        cond = self.gen_eval_data_any(node.cond)
        # Test condition (updates flags). Zero => EQ
        self.emit(f"    TSTUR {cond.name}")
        has_else = node.else_body is not None and len(node.else_body) > 0
        lbl_else = self._new_label("else") if has_else else None
        lbl_end = self._new_label("endif")
        # If zero, branch to else (or end if no else)
        target = lbl_else if has_else else lbl_end
        self.emit(f"    BCCso EQ, {target}")
        # then block
        for s in node.then_body:
            if isinstance(s, A.VarDecl):
                self.gen_local_let(s)
            elif isinstance(s, A.Return):
                self.gen_return(s, self._cur_ret_reg, self._cur_ret_ty)
            elif isinstance(s, A.Assign):
                self.gen_assign(s)
            elif isinstance(s, A.ExprStmt):
                self.gen_expr_stmt(s)
            elif isinstance(s, A.If):
                self.gen_if(s)
            else:
                raise CodegenError("unsupported statement in if-body")
        # after then, jump to end if we have else
        if has_else:
            self.emit(f"    BALso {lbl_end}")
        # else label/body
        if has_else and lbl_else is not None:
            self.emit(f"{lbl_else}:")
            for s in node.else_body or []:
                if isinstance(s, A.VarDecl):
                    self.gen_local_let(s)
                elif isinstance(s, A.Return):
                    self.gen_return(s, self._cur_ret_reg, self._cur_ret_ty)
                elif isinstance(s, A.Assign):
                    self.gen_assign(s)
                elif isinstance(s, A.ExprStmt):
                    self.gen_expr_stmt(s)
                elif isinstance(s, A.If):
                    self.gen_if(s)
                else:
                    raise CodegenError("unsupported statement in else-body")
        # end label
        self.emit(f"{lbl_end}:")

    def gen_return(self, r: A.Return, ret_reg: Optional[Reg], ret_ty: Optional[Type]) -> None:
        if ret_ty is None:
            self.emit("    RET")
            self._ret_indices.append(len(self.lines) - 1)
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
        # RET; epilogue will be inserted later
        self.emit("    RET")
        self._ret_indices.append(len(self.lines) - 1)

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
            # Allow implicit reinterpret between u24 <-> s24 (same width, data regs)
            if (not ty.is_addr) and (not src_ty.is_addr):
                if src_ty.bits != ty.bits:
                    raise CodegenError(
                        f"type width mismatch: expected {ty.bits}, found {src_ty.bits} for '{e.ident}'"
                    )
                return self.sym_regs[e.ident]
            return self.sym_regs[e.ident]
        if isinstance(e, A.Unary):
            if e.op != "~":
                raise CodegenError("unsupported unary operator")
            # Evaluate inner; apply NOTur
            inner = self.gen_eval_expr(e.expr, ty)
            # If inner is not a fresh temp, clone to a new dest before in-place NOT to avoid clobbering
            dst = self.alloc_reg(ty)
            if inner.name != dst.name:
                self.emit(f"    MOVur {inner.name}, {dst.name}")
            self.emit(f"    NOTUR {dst.name}")
            return dst
        if isinstance(e, A.Binary):
            # Relational/equality
            if e.op in ("==", "!=", "<", "<=", ">", ">="):
                if ty.is_addr:
                    raise CodegenError("comparison result cannot be 'addr'")
                comp_ty = self._infer_data_type(e.lhs, e.rhs) or U24
                if comp_ty.is_addr:
                    raise CodegenError("address comparison not supported yet")
                lhsr = self.gen_eval_expr(e.lhs, comp_ty)
                rhsr = self.gen_eval_expr(e.rhs, comp_ty)
                cmpm = "CMPSR" if comp_ty.is_signed else "CMPUR"
                # Compare lhs ? rhs (flags reflect lhs - rhs)
                self.emit(f"    {cmpm} {rhsr.name}, {lhsr.name}")
                # dst := 0; if cond then dst := 1
                dst = self.alloc_reg(ty)
                self.emit(f"    MOVui #0, {dst.name}")
                if e.op == "==":
                    cc = "EQ"
                elif e.op == "!=":
                    cc = "NE"
                elif e.op == "<":
                    cc = "LT" if comp_ty.is_signed else "BT"
                elif e.op == "<=":
                    cc = "LE" if comp_ty.is_signed else "BE"
                elif e.op == ">":
                    cc = "GT" if comp_ty.is_signed else "AT"
                elif e.op == ">=":
                    cc = "GE" if comp_ty.is_signed else "AE"
                else:
                    cc = "EQ"
                self.emit(f"    MCCsi {cc}, #1, {dst.name}")
                return dst
            lhs = self.gen_eval_expr(e.lhs, ty)
            dst = self.alloc_reg(ty)
            if lhs.name != dst.name:
                self.emit(f"    MOVur {lhs.name}, {dst.name}")
            # Determine opcode by operator and type
            if e.op in ("+", "-"):
                rhs = self.gen_eval_expr(e.rhs, ty)
                if ty.is_signed:
                    op = "ADDSR" if e.op == "+" else "SUBSR"
                else:
                    op = "ADDUR" if e.op == "+" else "SUBUR"
                self.emit(f"    {op} {rhs.name}, {dst.name}")
                return dst
            if e.op in ("&", "|", "^"):
                rhs = self.gen_eval_expr(e.rhs, ty)
                opm = {"&": "ANDUR", "|": "ORUR", "^": "XORUR"}
                self.emit(f"    {opm[e.op]} {rhs.name}, {dst.name}")
                return dst
            if e.op in ("<<", ">>"):
                # shift amount is data (u24/s24 ok); destination’s signedness controls SHR vs SHRs
                rhs = self.gen_eval_data_any(e.rhs)
                if e.op == "<<":
                    self.emit(f"    SHLUR {rhs.name}, {dst.name}")
                else:
                    m = "SHRSR" if ty.is_signed else "SHRUR"
                    self.emit(f"    {m} {rhs.name}, {dst.name}")
                return dst
            raise CodegenError("unsupported binary operator")
        if isinstance(e, A.Cast):
            # Only data casts supported (u24 <-> s24). Reinterpretation only.
            if e.target.is_addr:
                raise CodegenError("cast to 'addr' not supported")
            # Evaluate inner with the cast target type, then return it
            return self.gen_eval_expr(e.expr, e.target)
        if isinstance(e, A.Call):
            if ty is None:
                raise CodegenError("internal: missing expected type for call")
            r = self.gen_call(e, expect_value=True)
            # Ensure the returned reg class matches expected
            if (ty.is_addr and not r.is_addr) or ((not ty.is_addr) and r.is_addr):
                raise CodegenError("call return type mismatch")
            return r
        raise CodegenError("unsupported expression form")

    def gen_eval_data_any(self, e: A.Expr) -> Reg:
        """Evaluate expression as a data value (u24 or s24), without enforcing signedness.
        Rejects 'addr'. Uses u24 for immediates and arithmetic temporaries.
        """
        if isinstance(e, A.NameRef):
            if e.ident not in self.sym_types or e.ident not in self.sym_regs:
                raise CodegenError(f"unknown identifier '{e.ident}'")
            ty = self.sym_types[e.ident]
            if ty.is_addr:
                raise CodegenError("expected data value, found 'addr'")
            return self.sym_regs[e.ident]
        if isinstance(e, A.IntLiteral):
            dr = self.alloc_reg(U24)
            imm = e.value & 0xFFF
            self.emit(f"    MOVui #{imm}, {dr.name}")
            return dr
        # Fallback: evaluate as u24 using existing arithmetic (+/- only for now)
        return self.gen_eval_expr(e, U24)

    # --- Type inference helper for comparisons ------------------------------
    def _infer_data_type(self, a: A.Expr, b: A.Expr) -> Optional[Type]:
        def infer_one(x: A.Expr) -> Optional[Type]:
            if isinstance(x, A.NameRef):
                if x.ident in self.sym_types:
                    t = self.sym_types[x.ident]
                    if t.is_addr:
                        return ADDR
                    return S24 if t.is_signed else U24
                return None
            if isinstance(x, A.IntLiteral):
                return U24
            if isinstance(x, A.Unary):
                return infer_one(x.expr) or U24
            if isinstance(x, A.Binary):
                lt = infer_one(x.lhs)
                rt = infer_one(x.rhs)
                if lt is not None and lt.is_addr:
                    return ADDR
                if rt is not None and rt.is_addr:
                    return ADDR
                if (lt is not None and lt.is_signed) or (rt is not None and rt.is_signed):
                    return S24
                if lt is not None or rt is not None:
                    return U24
                return None
            if isinstance(x, A.Cast):
                if x.target.is_addr:
                    return ADDR
                return S24 if x.target.is_signed else U24
            if isinstance(x, A.Call):
                sig = self.fn_sigs.get(x.callee)
                if sig is None:
                    return None
                _, ret_ty, _ = sig
                if ret_ty is None:
                    return None
                if ret_ty.is_addr:
                    return ADDR
                return S24 if ret_ty.is_signed else U24
            return None

        t1 = infer_one(a)
        t2 = infer_one(b)
        if t1 is None and t2 is None:
            return None
        if (t1 is not None and t1.is_addr) or (t2 is not None and t2.is_addr):
            return ADDR
        if (t1 is not None and t1.is_signed) or (t2 is not None and t2.is_signed):
            return S24
        return U24

    def gen_call(self, c: A.Call, *, expect_value: bool) -> Reg:
        # Lookup signature
        if c.callee not in self.fn_sigs:
            raise CodegenError(f"unknown function '{c.callee}'")
        params, ret_ty, ret_hint = self.fn_sigs[c.callee]
        if len(c.args) != len(params):
            raise CodegenError(
                f"function '{c.callee}' expects {len(params)} args, got {len(c.args)}"
            )
        # Evaluate and move args into their designated registers
        # Default sequence indices
        next_dr = 0
        next_ar = 1  # AR0 is stack pointer; start args at AR1
        for (arg_expr, (pty, hint)) in zip(c.args, params):
            # Evaluate argument to the expected type
            src = self.gen_eval_expr(arg_expr, pty)
            # Determine target register
            if hint is not None:
                treg = Reg(hint.upper(), hint.upper().startswith("AR"))
            elif pty.is_addr:
                treg = Reg(f"AR{next_ar}", True)
                next_ar += 1
            else:
                treg = Reg(f"DR{next_dr}", False)
                next_dr += 1
            # Move if needed with proper move op
            if treg.is_addr and not src.is_addr:
                self.emit(f"    MOVAur {src.name}, {treg.name}, L")
            elif (not treg.is_addr) and src.is_addr:
                self.emit(f"    MOVDur {src.name}, {treg.name}, L")
            elif src.name != treg.name:
                self.emit(f"    MOVur {src.name}, {treg.name}")
        # Emit call (PC-relative to label)
        self.emit(f"    BSRso {c.callee}")
        # Handle return value
        if ret_ty is None:
            if expect_value:
                raise CodegenError("void function used in expression context")
            # Return a dummy register (not used)
            return Reg("DR0", False)
        # Determine return register
        if ret_hint:
            rreg = Reg(ret_hint.upper(), ret_hint.upper().startswith("AR"))
        else:
            # AR0 is stack pointer; address returns default to AR1
            rreg = Reg("AR1", True) if ret_ty.is_addr else Reg("DR0", False)
        return rreg

    # --- Prologue/Epilogue insertion ---------------------------------------
    def _insert_prologue(self) -> None:
        # Build prologue push sequence for locals/temps
        pro: List[str] = []
        if self._init_sp_in_prologue:
            pro.append("    ADRAso #__skald_stack_top, AR0")
        # Save address registers (AR1..)
        for idx in range(self._ar_base, self.next_ar):
            pro.append(f"    PUSHAur AR{idx}, AR0")
        # Save data registers (DR1..), but only those allocated for locals/temps
        for idx in range(self._dr_base, self.next_dr):
            pro.append(f"    PUSHur DR{idx}, AR0")
        # Insert after the prologue comment line (at _func_start_idx)
        insert_at = self._func_start_idx
        # Replace the comment with itself plus prologue lines for clarity
        self.lines = self.lines[: insert_at + 1] + pro + self.lines[insert_at + 1 :]
        # Adjust recorded RET indices due to insertion
        added = len(pro)
        if added > 0:
            self._ret_indices = [i + added if i >= insert_at + 1 else i for i in self._ret_indices]

    def _insert_all_epilogues(self) -> None:
        # Build epilogue pop sequence based on final allocation
        epi: List[str] = []
        for idx in range(self.next_dr - 1, self._dr_base - 1, -1):
            epi.append(f"    POPur AR0, DR{idx}")
        for idx in range(self.next_ar - 1, self._ar_base - 1, -1):
            epi.append(f"    POPAur AR0, AR{idx}")
        if not epi:
            return
        # Insert before each RET, from last to first to keep indices valid
        for pos in sorted(self._ret_indices, reverse=True):
            self.lines = self.lines[:pos] + epi + self.lines[pos:]
        # No need to track adjustments after finalization
