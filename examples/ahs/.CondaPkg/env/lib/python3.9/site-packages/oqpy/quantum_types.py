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
"""Classes representing variables containing quantum types (i.e. Qubits)."""

from __future__ import annotations

import contextlib
from typing import TYPE_CHECKING, Iterator, Union

from openpulse import ast

from oqpy.base import Var

if TYPE_CHECKING:
    from oqpy.program import Program


__all__ = ["Qubit", "QubitArray", "defcal", "PhysicalQubits", "Cal"]


class Qubit(Var):
    """OQpy variable representing a single qubit."""

    def __init__(self, name: str, needs_declaration: bool = True):
        super().__init__(name, needs_declaration=needs_declaration)
        self.name = name

    def to_ast(self, prog: Program) -> ast.Expression:
        """Converts the OQpy variable into an ast node."""
        prog._add_var(self)
        return ast.Identifier(self.name)

    def make_declaration_statement(self, program: Program) -> ast.Statement:
        """Make an ast statement that declares the OQpy variable."""
        return ast.QubitDeclaration(ast.Identifier(self.name), size=None)


class PhysicalQubits:
    """Provides a means of accessing qubit variables corresponding to physical qubits.

    For example, the openqasm qubit "$3" is accessed by ``PhysicalQubits[3]``.
    """

    def __class_getitem__(cls, item: int) -> Qubit:
        return Qubit(f"${item}", needs_declaration=False)


# Todo (#51): support QubitArray
class QubitArray:
    """Represents an array of qubits."""


@contextlib.contextmanager
def defcal(program: Program, qubits: Union[Qubit, list[Qubit]], name: str) -> Iterator[None]:
    """Context manager for creating a defcal.

    .. code-block:: python

        with defcal(program, q1, "X"):
            program.play(frame, waveform)
    """
    program._push()
    yield
    state = program._pop()

    if isinstance(qubits, Qubit):
        qubits = [qubits]

    stmt = ast.CalibrationDefinition(
        ast.Identifier(name),
        [],  # TODO (#52): support arguments
        [ast.Identifier(q.name) for q in qubits],
        None,  # TODO (#52): support return type,
        state.body,
    )
    program._add_statement(stmt)
    for qubit in qubits:
        program._add_defcal(qubit.name, name, stmt)


@contextlib.contextmanager
def Cal(program: Program) -> Iterator[None]:
    """Context manager that begins a cal block."""
    program._push()
    yield
    state = program._pop()
    program._add_statement(ast.CalibrationStatement(state.body))
