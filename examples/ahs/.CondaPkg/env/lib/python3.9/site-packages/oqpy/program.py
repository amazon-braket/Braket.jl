############################################################################
#  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License").
#  You may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
############################################################################
"""Module containing Program and related classes.

This module contains the oqpy.Program class, which is the primary user interface
for constructing openqasm/openpulse. The class follows the builder pattern in that
it contains a representation of the state of a program (internally represented as
AST components), and the class has methods which add to the current state.
"""

from __future__ import annotations

from copy import deepcopy
from typing import Any, Iterable, Iterator, Optional

from openpulse import ast
from openpulse.printer import dumps
from openqasm3.visitor import QASMVisitor

from oqpy import classical_types, quantum_types
from oqpy.base import (
    AstConvertible,
    Var,
    expr_matches,
    map_to_ast,
    optional_ast,
    to_ast,
)
from oqpy.pulse import FrameVar, PortVar, WaveformVar
from oqpy.timing import make_duration

__all__ = ["Program"]


class ProgramState:
    """Represents the current program state at a particular context level.

    A new ProgramState is created every time a context (such as the control
    flow constructs If/Else/ForIn/While) is created. A program will retain a
    stack of ProgramState objects for all currently open contexts.
    """

    def __init__(self) -> None:
        self.body: list[ast.Statement] = []
        self.if_clause: Optional[ast.BranchingStatement] = None

    def add_if_clause(self, condition: ast.Expression, if_clause: list[ast.Statement]) -> None:
        self.finalize_if_clause()
        self.if_clause = ast.BranchingStatement(condition, if_clause, [])

    def add_else_clause(self, else_clause: list[ast.Statement]) -> None:
        if self.if_clause is None:
            raise RuntimeError("Else without If.")
        self.if_clause.else_block = else_clause
        self.finalize_if_clause()

    def finalize_if_clause(self) -> None:
        if self.if_clause is not None:
            if_clause, self.if_clause = self.if_clause, None
            self.add_statement(if_clause)

    def add_statement(self, stmt: ast.Statement) -> None:
        self.finalize_if_clause()
        self.body.append(stmt)


class Program:
    """A builder class for OpenQASM/OpenPulse programs."""

    def __init__(self, version: Optional[str] = "3.0") -> None:
        self.stack: list[ProgramState] = [ProgramState()]
        self.defcals: dict[tuple[str, str], ast.CalibrationDefinition] = {}
        self.subroutines: dict[str, ast.SubroutineDefinition] = {}
        self.externs: dict[str, ast.ExternDeclaration] = {}
        self.declared_vars: dict[str, Var] = {}
        self.undeclared_vars: dict[str, Var] = {}

        if version is None or (
            len(version.split(".")) in [1, 2]
            and all([item.isnumeric() for item in version.split(".")])
        ):
            self.version = version
        else:
            raise RuntimeError("Version number does not match the X[.y] format.")

    def __iadd__(self, other: Program) -> Program:
        """In-place concatenation of programs."""
        if len(other.stack) > 1:
            raise RuntimeError("Cannot add subprogram with unclosed contextmanagers.")
        self._state.finalize_if_clause()
        self._state.body.extend(other._state.body)
        self._state.if_clause = other._state.if_clause
        self._state.finalize_if_clause()
        self.defcals.update(other.defcals)
        self.subroutines.update(other.subroutines)
        self.externs.update(other.externs)
        for var in other.declared_vars.values():
            self._mark_var_declared(var)
        for var in other.undeclared_vars.values():
            self._add_var(var)
        return self

    def __add__(self, other: Program) -> Program:
        """Return concatenation of two programs."""
        assert isinstance(other, Program)
        self_copy = deepcopy(self)
        self_copy += other
        return self_copy

    @property
    def _state(self) -> ProgramState:
        """The current program state is found on the top of the stack."""
        return self.stack[-1]

    @property
    def frame_vars(self) -> Iterator[FrameVar]:
        """Returns an Iterator of any declared/undeclared FrameVar used in the program."""
        for v in {**self.declared_vars, **self.undeclared_vars}.values():
            if isinstance(v, FrameVar):
                yield v

    @property
    def waveform_vars(self) -> Iterator[WaveformVar]:
        """Returns an Iterator of any declared/undeclared WaveformVar used in the program."""
        for v in {**self.declared_vars, **self.undeclared_vars}.values():
            if isinstance(v, WaveformVar):
                yield v

    def _push(self) -> None:
        """Open a new context by pushing a new program state on the stack."""
        self.stack.append(ProgramState())

    def _pop(self) -> ProgramState:
        """Close a context by removing the program state from the top stack, and return it."""
        state = self.stack.pop()
        state.finalize_if_clause()
        return state

    def _add_var(self, var: Var) -> None:
        """Register a variable with the program.

        If the variable is not declared (and is specified to need declaration),
        the variable will be automatically declared at the top of the program
        upon conversion to ast.

        This method is safe to call on the same variable multiple times.
        """
        name = var.name
        existing_var = self.declared_vars.get(name)
        if existing_var is None:
            existing_var = self.undeclared_vars.get(name)
        if existing_var is not None and not expr_matches(var, existing_var):
            raise RuntimeError(f"Program has conflicting variables with name {name}")
        if name not in self.declared_vars:
            self.undeclared_vars[name] = var

    def _mark_var_declared(self, var: Var) -> None:
        """Indicate that a variable has been declared."""
        self._add_var(var)
        name = var.name
        new_var = self.undeclared_vars.pop(name, None)
        if new_var is not None:
            self.declared_vars[name] = new_var

    def autodeclare(self, encal: bool = False) -> None:
        """Declare any currently undeclared variables at the beginning of the program."""
        while any(v._needs_declaration for v in self.undeclared_vars.values()):
            self.declare(
                [var for var in self.undeclared_vars.values() if var._needs_declaration],
                to_beginning=True,
                encal=encal,
            )

    def _add_statement(self, stmt: ast.Statement) -> None:
        """Add a statment to the current context's program state."""
        self._state.add_statement(stmt)

    def _add_subroutine(self, name: str, stmt: ast.SubroutineDefinition) -> None:
        """Register a subroutine which has been used.

        Subroutines are added to the top of the program upon conversion to ast.
        """
        self.subroutines[name] = stmt

    def _add_defcal(self, qubit_name: str, name: str, stmt: ast.CalibrationDefinition) -> None:
        """Register a defcal which has been used.

        Defcals are added to the top of the program upon conversion to ast.
        """
        self.defcals[(qubit_name, name)] = stmt

    def _make_externs_statements(self, auto_encal: bool = False) -> list[ast.ExternDeclaration]:
        """Return a list of extern statements for inclusion at beginning of program.

        if auto_encal is True, any externs using openpulse types will be wrapped in a Cal block.
        """
        if not auto_encal:
            return list(self.externs.values())
        openqasm_externs, openpulse_externs = [], []
        openpulse_types = ast.PortType, ast.FrameType, ast.WaveformType
        for extern_statement in self.externs.values():
            for arg in extern_statement.arguments:
                if isinstance(arg.type, openpulse_types):
                    openpulse_externs.append(extern_statement)
                    break
            else:
                if isinstance(extern_statement.return_type.type, openpulse_types):
                    openpulse_externs.append(extern_statement)
                else:
                    openqasm_externs.append(extern_statement)
        if openpulse_externs:
            openqasm_externs.append(ast.CalibrationStatement(body=openpulse_externs))
        return openqasm_externs

    def to_ast(
        self,
        encal: bool = False,
        include_externs: bool = True,
        ignore_needs_declaration: bool = False,
        encal_declarations: bool = False,
    ) -> ast.Program:
        """Convert to an AST program.

        Args:
            encal: If true, wrap all statements in a "Cal" block, ensuring
                that all openpulse statements are contained within a Cal block.
            include_externs: If true, for all used extern statements, include
                an extern declaration at the top of the program.
            ignore_needs_declaration: If true, the field `_needs_declaration` of
                undeclared variables is ignored and their declaration will not
                be added to the AST
            encal_declarations: If true, when declaring undeclared variables,
                if the variables have openpulse types, automatically wrap the
                declarations in cal blocks.
        """
        if not ignore_needs_declaration and self.undeclared_vars:
            self.autodeclare(encal=encal_declarations)

        assert len(self.stack) == 1
        self._state.finalize_if_clause()
        statements = []
        if include_externs:
            statements += self._make_externs_statements(encal_declarations)
        statements += list(self.subroutines.values()) + self._state.body
        if encal:
            statements = [ast.CalibrationStatement(statements)]
        if encal_declarations:
            statements = [ast.CalibrationGrammarDeclaration("openpulse")] + statements
        prog = ast.Program(statements=statements, version=self.version)
        if encal_declarations:
            MergeCalStatementsPass().visit(prog)
        return prog

    def to_qasm(
        self,
        encal: bool = False,
        include_externs: bool = True,
        ignore_needs_declaration: bool = False,
        encal_declarations: bool = False,
    ) -> str:
        """Convert to QASM text.

        See to_ast for option documentation.
        """
        return dumps(
            self.to_ast(
                encal=encal,
                include_externs=include_externs,
                ignore_needs_declaration=ignore_needs_declaration,
                encal_declarations=encal_declarations,
            ),
            indent="    ",
        ).strip()

    def declare(
        self,
        variables: list[Var] | Var,
        to_beginning: bool = False,
        encal: bool = False,
    ) -> Program:
        """Declare a variable.

        Args:
            variables: A list of variables to declare, or a single variable to declare.
            to_beginning: If true, insert the declaration at the beginning of the program,
                instead of at the current point.
            encal: If true, wrap any declarations of undeclared variables with openpulse
                types in a cal block.
        """
        if isinstance(variables, (classical_types._ClassicalVar, quantum_types.Qubit)):
            variables = [variables]

        assert isinstance(variables, list)

        openpulse_vars, openqasm_vars = [], []
        for var in variables:
            if encal and isinstance(var, (PortVar, FrameVar, WaveformVar)):
                openpulse_vars.append(var)
            else:
                openqasm_vars.append(var)

        if to_beginning:
            openqasm_vars.reverse()

        for var in openqasm_vars:
            stmt = var.make_declaration_statement(self)
            if to_beginning:
                self._state.body.insert(0, stmt)
            else:
                self._add_statement(stmt)
            self._mark_var_declared(var)
        if openpulse_vars:
            cal_stmt = ast.CalibrationStatement([])
            for var in openpulse_vars:
                stmt = var.make_declaration_statement(self)
                cal_stmt.body.append(stmt)
                self._mark_var_declared(var)
            if to_beginning:
                self._state.body.insert(0, cal_stmt)
            else:
                self._add_statement(cal_stmt)
        return self

    def delay(
        self, time: AstConvertible, qubits_or_frames: AstConvertible | Iterable[AstConvertible] = ()
    ) -> Program:
        """Apply a delay to a set of qubits or frames."""
        if not isinstance(qubits_or_frames, Iterable):
            qubits_or_frames = [qubits_or_frames]
        ast_duration = to_ast(self, make_duration(time))
        ast_qubits_or_frames = map_to_ast(self, qubits_or_frames)
        self._add_statement(ast.DelayInstruction(ast_duration, ast_qubits_or_frames))
        return self

    def barrier(self, qubits_or_frames: Iterable[AstConvertible]) -> Program:
        """Apply a barrier to a set of qubits or frames."""
        ast_qubits_or_frames = map_to_ast(self, qubits_or_frames)
        self._add_statement(ast.QuantumBarrier(ast_qubits_or_frames))
        return self

    def function_call(self, name: str, args: Iterable[AstConvertible]) -> None:
        """Add a function call."""
        self._add_statement(
            ast.ExpressionStatement(ast.FunctionCall(ast.Identifier(name), map_to_ast(self, args)))
        )

    def play(self, frame: AstConvertible, waveform: AstConvertible) -> Program:
        """Play a waveform on a particular frame."""
        self.function_call("play", [frame, waveform])
        return self

    def capture(self, frame: AstConvertible, kernel: AstConvertible) -> Program:
        """Capture signal integrated against a kernel on a particular frame."""
        self.function_call("capture", [frame, kernel])
        return self

    def set_phase(self, frame: AstConvertible, phase: AstConvertible) -> Program:
        """Set the phase of a particular frame."""
        self.function_call("set_phase", [frame, phase])
        return self

    def shift_phase(self, frame: AstConvertible, phase: AstConvertible) -> Program:
        """Shift the phase of a particular frame."""
        self.function_call("shift_phase", [frame, phase])
        return self

    def set_frequency(self, frame: AstConvertible, freq: AstConvertible) -> Program:
        """Set the frequency of a particular frame."""
        self.function_call("set_frequency", [frame, freq])
        return self

    def shift_frequency(self, frame: AstConvertible, freq: AstConvertible) -> Program:
        """Shift the frequency of a particular frame."""
        self.function_call("shift_frequency", [frame, freq])
        return self

    def set_scale(self, frame: AstConvertible, scale: AstConvertible) -> Program:
        """Set the amplitude scaling of a particular frame."""
        self.function_call("set_scale", [frame, scale])
        return self

    def shift_scale(self, frame: AstConvertible, scale: AstConvertible) -> Program:
        """Shift the amplitude scaling of a particular frame."""
        self.function_call("shift_scale", [frame, scale])
        return self

    def gate(
        self, qubits: AstConvertible | Iterable[AstConvertible], name: str, *args: Any
    ) -> Program:
        """Apply a gate to a qubit or set of qubits."""
        if isinstance(qubits, quantum_types.Qubit):
            qubits = [qubits]
        assert isinstance(qubits, Iterable)
        self._add_statement(
            ast.QuantumGate(
                [],
                ast.Identifier(name),
                map_to_ast(self, args),
                map_to_ast(self, qubits),
            )
        )
        return self

    def reset(self, qubit: quantum_types.Qubit) -> Program:
        """Reset a particular qubit."""
        self._add_statement(ast.QuantumReset(qubits=qubit.to_ast(self)))
        return self

    def measure(
        self, qubit: quantum_types.Qubit, output_location: classical_types.BitVar | None = None
    ) -> Program:
        """Measure a particular qubit.

        If provided, store the result in the given output location.
        """
        self._add_statement(
            ast.QuantumMeasurementStatement(
                measure=ast.QuantumMeasurement(ast.Identifier(qubit.name)),
                target=optional_ast(self, output_location),
            )
        )
        return self

    def _do_assignment(self, var: AstConvertible, op: str, value: AstConvertible) -> None:
        """Helper function for variable assignment operations."""
        if isinstance(var, classical_types.DurationVar):
            value = make_duration(value)
        self._add_statement(
            ast.ClassicalAssignment(
                to_ast(self, var),
                ast.AssignmentOperator[op],
                to_ast(self, value),
            )
        )

    def set(self, var: classical_types._ClassicalVar, value: AstConvertible) -> Program:
        """Set a variable value."""
        self._do_assignment(var, "=", value)
        return self

    def increment(self, var: classical_types._ClassicalVar, value: AstConvertible) -> Program:
        """Increment a variable value."""
        self._do_assignment(var, "+=", value)
        return self

    def decrement(self, var: classical_types._ClassicalVar, value: AstConvertible) -> Program:
        """Decrement a variable value."""
        self._do_assignment(var, "-=", value)
        return self

    def mod_equals(self, var: classical_types.IntVar, value: AstConvertible) -> Program:
        """In-place update of a variable to be itself modulo value."""
        assert isinstance(var, classical_types.IntVar)
        self._do_assignment(var, "%=", value)
        return self


class MergeCalStatementsPass(QASMVisitor[None]):
    """Merge adjacent CalibrationStatement ast nodes."""

    def visit_Program(self, node: ast.Program, context: None = None) -> None:
        node.statements = self.process_statement_list(node.statements)
        self.generic_visit(node, context)

    def visit_ForInLoop(self, node: ast.ForInLoop, context: None = None) -> None:
        node.block = self.process_statement_list(node.block)
        self.generic_visit(node, context)

    def visit_WhileLoop(self, node: ast.WhileLoop, context: None = None) -> None:
        node.block = self.process_statement_list(node.block)
        self.generic_visit(node, context)

    def visit_BranchingStatement(self, node: ast.BranchingStatement, context: None = None) -> None:
        node.if_block = self.process_statement_list(node.if_block)
        node.else_block = self.process_statement_list(node.else_block)
        self.generic_visit(node, context)

    def visit_CalibrationStatement(
        self, node: ast.CalibrationStatement, context: None = None
    ) -> None:
        node.body = self.process_statement_list(node.body)
        self.generic_visit(node, context)

    def visit_SubroutineDefinition(
        self, node: ast.SubroutineDefinition, context: None = None
    ) -> None:
        node.body = self.process_statement_list(node.body)
        self.generic_visit(node, context)

    def process_statement_list(self, statements: list[ast.Statement]) -> list[ast.Statement]:
        new_list = []
        cal_stmts = []
        for stmt in statements:
            if isinstance(stmt, ast.CalibrationStatement):
                cal_stmts.extend(stmt.body)
            else:
                if cal_stmts:
                    new_list.append(ast.CalibrationStatement(body=cal_stmts))
                    cal_stmts = []
                new_list.append(stmt)

        if cal_stmts:
            new_list.append(ast.CalibrationStatement(body=cal_stmts))

        return new_list
