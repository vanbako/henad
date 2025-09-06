from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

from . import ast as A
from .typesys import U24, S24, ADDR, Type, StructType, AddressType, addr_of


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
        # loop stack: list of (begin_label, end_label)
        self._loop_stack: List[Tuple[str, str]] = []
        # struct frame management
        self._frame_words: int = 0
        # name -> (offset_words, areg)
        self._frame_locals: Dict[str, Tuple[int, Reg]] = {}

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
            if isinstance(d, A.StructDecl):
                # no code emission for type decls
                continue
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
        # MVP: no global struct variables yet
        if isinstance(v.ty, StructType):
            raise CodegenError("global struct variables are not supported yet")
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
        self._frame_words = 0
        self._frame_locals.clear()

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

        # Pre-scan for struct locals anywhere in the function body; allocate
        for v in self._collect_struct_locals(f.body):
            if not isinstance(v.ty, StructType):
                continue
            # Allocate address register for the local's base pointer
            r = self.alloc_reg(v.ty)
            self.sym_regs[v.name] = r
            self.sym_types[v.name] = v.ty
            # Assign frame offset
            off = self._frame_words
            self._frame_words += v.ty.size_words
            self._frame_locals[v.name] = (off, r)
            self.comment(f"alloc frame for {v.name}:{v.ty} size {v.ty.size_words}w -> {r.name} at +{off}")

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
            elif isinstance(s, A.While):
                self.gen_while(s)
            elif isinstance(s, A.Break):
                self.gen_break(s)
            elif isinstance(s, A.Continue):
                self.gen_continue(s)
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

    def _collect_struct_locals(self, body: List[A.Stmt]) -> List[A.VarDecl]:
        out: List[A.VarDecl] = []
        def visit_stmt(s: A.Stmt) -> None:
            if isinstance(s, A.VarDecl):
                if isinstance(s.ty, StructType) and not s.is_global:
                    out.append(s)
            elif isinstance(s, A.If):
                for x in s.then_body:
                    visit_stmt(x)
                if s.else_body:
                    for x in s.else_body:
                        visit_stmt(x)
            elif isinstance(s, A.While):
                for x in s.body:
                    visit_stmt(x)
            # other stmts don't declare locals
        for s in body:
            visit_stmt(s)
        return out

    def gen_local_let(self, v: A.VarDecl) -> None:
        # Struct locals are pre-allocated in prologue with a base pointer in an AR
        if isinstance(v.ty, StructType):
            r = self.sym_regs.get(v.name)
            if r is None:
                # Fallback (shouldn't happen): allocate now
                r = self.alloc_reg(v.ty)
                self.sym_regs[v.name] = r
                self.sym_types[v.name] = v.ty
            self.comment(f"let {v.name}:{v.ty} -> {r.name} (frame)")
            if v.init is not None:
                raise CodegenError("struct initializer not supported; assign fields individually")
            return
        # Scalar local in register
        r = self.alloc_reg(v.ty)
        self.sym_regs[v.name] = r
        self.sym_types[v.name] = v.ty
        self.comment(f"let {v.name}:{v.ty} -> {r.name}")
        if v.init is not None:
            self.gen_store_expr_into(v.init, v.ty, r)

    def gen_assign(self, a: A.Assign) -> None:
        # LHS can be a variable or a field access
        if isinstance(a.target, A.NameRef):
            tname = a.target.ident
            if tname not in self.sym_regs:
                raise CodegenError(f"assignment to unknown variable '{tname}'")
            dst = self.sym_regs[tname]
            if tname not in self.sym_types:
                raise CodegenError(f"internal: missing type for '{tname}'")
            ty = self.sym_types[tname]
            op = a.op
            if op == "=":
                self.gen_store_expr_into(a.value, ty, dst)
                return
            # Address arithmetic: only for addr<T>, with DR rhs (u24/s24)
            if ty.is_addr:
                if isinstance(ty, StructType):
                    raise CodegenError("cannot perform arithmetic on struct value; use addr<T> variable")
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
            return
        elif isinstance(a.target, A.FieldAccess):
            # Resolve base variable and struct layout
            base = a.target.base
            if not isinstance(base, A.NameRef):
                raise CodegenError("complex field bases not supported yet")
            bname = base.ident
            if bname not in self.sym_types or bname not in self.sym_regs:
                raise CodegenError(f"unknown struct variable '{bname}'")
            bty = self.sym_types[bname]
            if not isinstance(bty, StructType):
                raise CodegenError("field access on non-struct variable")
            areg = self.sym_regs[bname]
            # Lookup field
            field_ty: Optional[Type] = None
            field_off = 0
            for fname, fty, off in bty.fields:
                if fname == a.target.field:
                    field_ty = fty
                    field_off = off
                    break
            if field_ty is None:
                raise CodegenError(f"unknown field '{a.target.field}' on '{bname}'")
            op = a.op
            if op == "=":
                src = self.gen_eval_expr(a.value, field_ty)
                if field_ty.is_addr:
                    # store AR src -> #off(AREG)
                    self.emit(f"    STASO {src.name}, #{field_off}, {areg.name}")
                else:
                    self.emit(f"    STSO {src.name}, #{field_off}, {areg.name}")
                return
            # Compound assignment: load field, apply, store back
            if field_ty.is_addr:
                if op not in ("+=", "-="):
                    raise CodegenError("only '+=' and '-=' supported for addr fields")
                # Load current field value into AR temp
                tmp = self.alloc_reg(ADDR)
                self.emit(f"    LDASO #{field_off}, {areg.name}, {tmp.name}")
                # Determine rhs type
                rhs_ty: Optional[Type] = None
                if isinstance(a.value, A.NameRef):
                    nm = a.value.ident
                    if nm not in self.sym_types:
                        raise CodegenError(f"unknown identifier '{nm}' in addr field assignment")
                    st = self.sym_types[nm]
                    if st.is_addr:
                        raise CodegenError("cannot use 'addr' value as rhs for addr +=/-=")
                    rhs_ty = st
                elif isinstance(a.value, A.IntLiteral):
                    rhs_ty = U24
                else:
                    raise CodegenError("addr field +=/-= requires u24/s24 variable or literal")
                rhs_reg = self.gen_eval_expr(a.value, rhs_ty)
                if op == "+=":
                    m = "ADDASR" if rhs_ty.is_signed else "ADDAUR"
                else:
                    m = "SUBASR" if rhs_ty.is_signed else "SUBAUR"
                self.emit(f"    {m} {rhs_reg.name}, {tmp.name}")
                self.emit(f"    STASO {tmp.name}, #{field_off}, {areg.name}")
                return
            # Data field compound ops
            # Load field into DR temp (signedness of load doesn't matter for raw value)
            cur = self.alloc_reg(field_ty)
            self.emit(f"    LDSO #{field_off}, {areg.name}, {cur.name}")
            if op == "+=":
                rhs = self.gen_eval_expr(a.value, field_ty)
                m = "ADDSR" if field_ty.is_signed else "ADDUR"
                self.emit(f"    {m} {rhs.name}, {cur.name}")
            elif op == "-=":
                rhs = self.gen_eval_expr(a.value, field_ty)
                m = "SUBSR" if field_ty.is_signed else "SUBUR"
                self.emit(f"    {m} {rhs.name}, {cur.name}")
            elif op == "&=":
                rhs = self.gen_eval_expr(a.value, field_ty)
                self.emit(f"    ANDUR {rhs.name}, {cur.name}")
            elif op == "|=":
                rhs = self.gen_eval_expr(a.value, field_ty)
                self.emit(f"    ORUR {rhs.name}, {cur.name}")
            elif op == "^=":
                rhs = self.gen_eval_expr(a.value, field_ty)
                self.emit(f"    XORUR {rhs.name}, {cur.name}")
            elif op == "<<=":
                rhs = self.gen_eval_data_any(a.value)
                self.emit(f"    SHLUR {rhs.name}, {cur.name}")
            elif op == ">>=":
                rhs = self.gen_eval_data_any(a.value)
                m = "SHRSR" if field_ty.is_signed else "SHRUR"
                self.emit(f"    {m} {rhs.name}, {cur.name}")
            elif op == "<<<=":
                rhs = self.gen_eval_data_any(a.value)
                self.emit(f"    ROLUR {rhs.name}, {cur.name}")
            elif op == ">>>=":
                rhs = self.gen_eval_data_any(a.value)
                self.emit(f"    RORUR {rhs.name}, {cur.name}")
            else:
                raise CodegenError(f"unsupported compound operator '{op}' for field")
            # Store back updated value
            self.emit(f"    STSO {cur.name}, #{field_off}, {areg.name}")
            return
        else:
            raise CodegenError("unsupported assignment target kind")
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
            elif isinstance(s, A.While):
                self.gen_while(s)
            elif isinstance(s, A.Break):
                self.gen_break(s)
            elif isinstance(s, A.Continue):
                self.gen_continue(s)
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
                elif isinstance(s, A.While):
                    self.gen_while(s)
                elif isinstance(s, A.Break):
                    self.gen_break(s)
                elif isinstance(s, A.Continue):
                    self.gen_continue(s)
                else:
                    raise CodegenError("unsupported statement in else-body")
        # end label
        self.emit(f"{lbl_end}:")

    def gen_while(self, node: A.While) -> None:
        # while (cond) { body }
        lbl_begin = self._new_label("while")
        lbl_end = self._new_label("endwhile")
        # begin label
        self.emit(f"{lbl_begin}:")
        # push loop context
        self._loop_stack.append((lbl_begin, lbl_end))
        # Evaluate condition as data; zero => false => branch to end
        cond = self.gen_eval_data_any(node.cond)
        self.emit(f"    TSTUR {cond.name}")
        self.emit(f"    BCCso EQ, {lbl_end}")
        # body
        for s in node.body:
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
            elif isinstance(s, A.While):
                self.gen_while(s)
            elif isinstance(s, A.Break):
                self.gen_break(s)
            elif isinstance(s, A.Continue):
                self.gen_continue(s)
            else:
                raise CodegenError("unsupported statement in while-body")
        # jump back to begin
        self.emit(f"    BALso {lbl_begin}")
        # end label
        self.emit(f"{lbl_end}:")
        # pop loop context
        self._loop_stack.pop()

    def gen_break(self, node: A.Break) -> None:
        if not self._loop_stack:
            raise CodegenError("'break' used outside of loop")
        _, end_label = self._loop_stack[-1]
        self.emit(f"    BALso {end_label}")

    def gen_continue(self, node: A.Continue) -> None:
        if not self._loop_stack:
            raise CodegenError("'continue' used outside of loop")
        begin_label, _ = self._loop_stack[-1]
        self.emit(f"    BALso {begin_label}")

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
                self.emit(f"    MOVAur {tmp.name}, {ret_reg.name}, L")
            elif (not ret_reg.is_addr) and tmp.is_addr:
                self.emit(f"    MOVDur {tmp.name}, {ret_reg.name}, L")
            elif ret_reg.is_addr and tmp.is_addr:
                self.emit(f"    LEASO {tmp.name}, #0, {ret_reg.name}")
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
        if dst.is_addr and src.is_addr:
            self.emit(f"    LEASO {src.name}, #0, {dst.name}")
        else:
            self.emit(f"    MOVur {src.name}, {dst.name}")
        return dst

    def gen_eval_expr(self, e: A.Expr, ty: Type) -> Reg:
        if isinstance(e, A.IntLiteral):
            # Materialize into a DR of the expected data type (strict typing)
            if ty.is_addr:
                raise CodegenError("integer literal not allowed in address context")
            dr = self.alloc_reg(S24 if ty.is_signed else U24)
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
            if ty.is_addr:
                # Enforce typed address match (addr<T>), not just class
                if isinstance(ty, AddressType):
                    if isinstance(src_ty, AddressType):
                        if ty.pointee != src_ty.pointee:
                            raise CodegenError(
                                f"type mismatch: expected {ty}, found {src_ty} for '{e.ident}'"
                            )
                    else:
                        # Using a struct value where an addr<T> is expected
                        raise CodegenError(
                            f"type mismatch: expected {ty}, found {src_ty}; use get_addr(...)"
                        )
                # For non-parameterized address-like types (e.g., StructType), fall through only
                # when the expected type is also non-parameterized (not allowed here).
            # Strict typing: require exact data type match (no implicit u24<->s24)
            if (not ty.is_addr) and (not src_ty.is_addr):
                if src_ty != ty:
                    raise CodegenError(
                        f"type mismatch: expected {ty}, found {src_ty} for '{e.ident}'"
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
                comp_ty = self._unify_compare_type(e.lhs, e.rhs)
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
        if isinstance(e, A.AddressOf):
            # Expected type must be 'addr'
            if not ty.is_addr:
                raise CodegenError("get_addr used in non-address context")
            # Only allow address-of field of a local struct variable (strongly typed)
            targ = e.target
            if isinstance(targ, A.FieldAccess):
                base = targ.base
                if not isinstance(base, A.NameRef):
                    raise CodegenError("complex field bases not supported for get_addr")
                bname = base.ident
                if bname not in self.sym_types or bname not in self.sym_regs:
                    raise CodegenError(f"unknown struct variable '{bname}' in get_addr")
                bty = self.sym_types[bname]
                if not isinstance(bty, StructType):
                    raise CodegenError("get_addr only supports fields on struct locals")
                areg = self.sym_regs[bname]
                # Lookup field offset
                field_ty: Optional[Type] = None
                field_off = 0
                for fname, fty, off in bty.fields:
                    if fname == targ.field:
                        field_ty = fty
                        field_off = off
                        break
                if field_ty is None:
                    raise CodegenError(f"unknown field '{targ.field}' on '{bname}'")
                # Type-check: expected addr<field_ty>
                if not isinstance(ty, AddressType) or ty.pointee != field_ty:
                    raise CodegenError("type mismatch: get_addr expected addr<field_type>")
                # Compute address: ARdst = ARbase + #off
                dst = self.alloc_reg(ty)
                self.emit(f"    LEASO {areg.name}, #{field_off}, {dst.name}")
                return dst
            elif isinstance(targ, A.NameRef):
                # Disallow taking address of scalar locals (register-backed)
                vname = targ.ident
                if vname in self.sym_types:
                    vty = self.sym_types[vname]
                    if isinstance(vty, StructType):
                        # Address of whole struct: return its base pointer
                        if not isinstance(ty, AddressType) or ty.pointee != vty:
                            raise CodegenError("type mismatch: get_addr expected addr<struct_type>")
                        areg = self.sym_regs[vname]
                        if not areg.is_addr:
                            raise CodegenError("internal: struct base is not an address register")
                        return areg
                    # Scalar locals are in registers — no addressable storage in MVP
                    raise CodegenError("cannot take address of register-backed local; use a struct field")
                # Global variables are not yet supported in expressions
                raise CodegenError("get_addr on globals not supported yet")
            else:
                raise CodegenError("get_addr argument must be a variable or field access")
        if isinstance(e, A.Deref):
            # Only allow deref of an AddressOf expression; ensures strong typing
            if not isinstance(e.addr_expr, A.AddressOf):
                raise CodegenError("get_content requires an addr<T> produced by get_addr(...) in this MVP")
            # Determine underlying element type and address register
            aof = e.addr_expr
            # Evaluate address value (must yield AR)
            # Expected address type is addr<ty>
            ar = self.gen_eval_expr(aof, addr_of(ty))
            # Determine element type from the AddressOf target
            elem_ty: Optional[Type] = None
            targ = aof.target
            if isinstance(targ, A.FieldAccess):
                base = targ.base
                if not isinstance(base, A.NameRef):
                    raise CodegenError("complex field bases not supported for get_content")
                bname = base.ident
                if bname not in self.sym_types:
                    raise CodegenError(f"unknown struct variable '{bname}' in get_content")
                bty = self.sym_types[bname]
                if not isinstance(bty, StructType):
                    raise CodegenError("get_content only supports fields on struct locals")
                for fname, fty, off in bty.fields:
                    if fname == targ.field:
                        elem_ty = fty
                        break
            elif isinstance(targ, A.NameRef):
                if targ.ident in self.sym_types and isinstance(self.sym_types[targ.ident], StructType):
                    raise CodegenError("cannot load entire struct with get_content; load individual fields")
            if elem_ty is None:
                raise CodegenError("internal: could not determine pointed-to type")
            # Now load from [ar] into reg of elem_ty
            dst = self.alloc_reg(elem_ty)
            if elem_ty.is_addr:
                self.emit(f"    LDASO #0, {ar.name}, {dst.name}")
            else:
                self.emit(f"    LDSO #0, {ar.name}, {dst.name}")
            # Enforce expected type compatibility
            if ty.is_addr != elem_ty.is_addr:
                raise CodegenError("type mismatch in get_content result")
            if (not ty.is_addr) and (ty.bits != elem_ty.bits):
                raise CodegenError("bit-width mismatch in get_content result")
            # For u24<->s24 reinterpret, allow
            return dst
        if isinstance(e, A.Call):
            if ty is None:
                raise CodegenError("internal: missing expected type for call")
            r = self.gen_call(e, expect_value=True)
            # Ensure the returned reg class matches expected
            if (ty.is_addr and not r.is_addr) or ((not ty.is_addr) and r.is_addr):
                raise CodegenError("call return type mismatch")
            return r
        if isinstance(e, A.FieldAccess):
            # Only support NameRef bases for now
            if not isinstance(e.base, A.NameRef):
                raise CodegenError("complex field bases not supported yet")
            bname = e.base.ident
            if bname not in self.sym_types or bname not in self.sym_regs:
                raise CodegenError(f"unknown struct variable '{bname}'")
            bty = self.sym_types[bname]
            if not isinstance(bty, StructType):
                raise CodegenError("field access on non-struct variable")
            areg = self.sym_regs[bname]
            # Lookup field
            field_ty: Optional[Type] = None
            field_off = 0
            for fname, fty, off in bty.fields:
                if fname == e.field:
                    field_ty = fty
                    field_off = off
                    break
            if field_ty is None:
                raise CodegenError(f"unknown field '{e.field}' on '{bname}'")
            # Load value into temp of the field's type
            dst = self.alloc_reg(field_ty)
            if field_ty.is_addr:
                self.emit(f"    LDASO #{field_off}, {areg.name}, {dst.name}")
            else:
                self.emit(f"    LDSO #{field_off}, {areg.name}, {dst.name}")
            return dst
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

    # --- Strict type helpers -----------------------------------------------
    def _expr_exact_type(self, e: A.Expr) -> Optional[Type]:
        """Best-effort exact type of an expression for strict checks.
        Returns None if not statically known (e.g., pure literal or complex arith).
        """
        if isinstance(e, A.NameRef):
            return self.sym_types.get(e.ident)
        if isinstance(e, A.FieldAccess):
            if isinstance(e.base, A.NameRef):
                bname = e.base.ident
                bty = self.sym_types.get(bname)
                if isinstance(bty, StructType):
                    for fname, fty, _ in bty.fields:
                        if fname == e.field:
                            return fty
            return None
        if isinstance(e, A.Cast):
            return e.target
        if isinstance(e, A.AddressOf):
            # Try derive addr<...> for known targets
            targ = e.target
            if isinstance(targ, A.FieldAccess) and isinstance(targ.base, A.NameRef):
                bname = targ.base.ident
                bty = self.sym_types.get(bname)
                if isinstance(bty, StructType):
                    for fname, fty, _ in bty.fields:
                        if fname == targ.field:
                            return addr_of(fty)
            if isinstance(targ, A.NameRef):
                vty = self.sym_types.get(targ.ident)
                if isinstance(vty, StructType):
                    return addr_of(vty)
            return ADDR
        if isinstance(e, A.Deref):
            # Only support Deref(AddressOf(field)) in MVP
            a = e.addr_expr
            if isinstance(a, A.AddressOf) and isinstance(a.target, A.FieldAccess):
                fa = a.target
                if isinstance(fa.base, A.NameRef):
                    bty = self.sym_types.get(fa.base.ident)
                    if isinstance(bty, StructType):
                        for fname, fty, _ in bty.fields:
                            if fname == fa.field:
                                return fty
            return None
        if isinstance(e, A.Call):
            sig = self.fn_sigs.get(e.callee)
            if sig is None:
                return None
            _, ret_ty, _ = sig
            return ret_ty
        if isinstance(e, (A.IntLiteral, A.Unary, A.Binary)):
            return None
        return None

    def _unify_compare_type(self, a: A.Expr, b: A.Expr) -> Type:
        """Unify types for comparison under strict rules:
        - Both operands must be data types (u24 or s24), not addresses.
        - If both sides have known types, they must be exactly equal.
        - If only one side has a known data type, use that.
        - If neither is known, default to u24.
        """
        ta = self._expr_exact_type(a)
        tb = self._expr_exact_type(b)
        if (ta is not None and ta.is_addr) or (tb is not None and tb.is_addr):
            raise CodegenError("address comparison is not supported")
        if ta is not None and tb is not None:
            if ta != tb:
                raise CodegenError("operands of comparison must have the same data type; use casts")
            return ta
        if ta is not None:
            return ta if not ta.is_addr else U24
        if tb is not None:
            return tb if not tb.is_addr else U24
        return U24

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
            if isinstance(x, A.FieldAccess):
                if isinstance(x.base, A.NameRef):
                    bname = x.base.ident
                    if bname in self.sym_types:
                        bty = self.sym_types[bname]
                        if isinstance(bty, StructType):
                            for fname, fty, _ in bty.fields:
                                if fname == x.field:
                                    return S24 if fty.is_signed and not fty.is_addr else (ADDR if fty.is_addr else U24)
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
            if isinstance(x, A.AddressOf):
                return ADDR
            if isinstance(x, A.Deref):
                a = x.addr_expr
                if isinstance(a, A.AddressOf) and isinstance(a.target, A.FieldAccess):
                    fa = a.target
                    if isinstance(fa.base, A.NameRef):
                        bname = fa.base.ident
                        if bname in self.sym_types:
                            bty = self.sym_types[bname]
                            if isinstance(bty, StructType):
                                for fname, fty, _ in bty.fields:
                                    if fname == fa.field:
                                        if fty.is_addr:
                                            return ADDR
                                        return S24 if fty.is_signed else U24
                return None
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
            elif treg.is_addr and src.is_addr and src.name != treg.name:
                self.emit(f"    LEASO {src.name}, #0, {treg.name}")
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
        # Allocate stack frame for struct locals, then compute each base pointer
        if self._frame_words > 0:
            pro.append(f"    SUBASI #{self._frame_words}, AR0")
            # Initialize base pointers
            for name, (off, reg) in self._frame_locals.items():
                pro.append(f"    LEASO AR0, #{off}, {reg.name}")
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
        # Free stack frame for struct locals (before popping saved regs)
        if self._frame_words > 0:
            epi.append(f"    ADDASI #{self._frame_words}, AR0")
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
