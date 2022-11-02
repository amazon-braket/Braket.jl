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
"""Context manager objects used for creating control flow contexts."""

from __future__ import annotations

import contextlib
from typing import TYPE_CHECKING, Iterable, Iterator, Optional

from openpulse import ast

from oqpy.base import OQPyExpression, to_ast
from oqpy.classical_types import AstConvertible, IntVar, _ClassicalVar, convert_range

if TYPE_CHECKING:
    from oqpy.program import Program


__all__ = ["If", "Else", "ForIn", "While"]


@contextlib.contextmanager
def If(program: Program, condition: OQPyExpression) -> Iterator[None]:
    """Context manager for doing conditional evaluation.

    .. code-block:: python

        i = IntVar(1)
        with If(program, i == 1):
            program.increment(i)

    """
    program._push()
    yield
    state = program._pop()
    program._state.add_if_clause(to_ast(program, condition), state.body)


@contextlib.contextmanager
def Else(program: Program) -> Iterator[None]:
    """Context manager for conditional evaluation. Must come after an "If" context block.

    .. code-block:: python

        i = IntVar(1)
        with If(program, i == 1):
            program.increment(i, 1)
        with Else(program):
            program.increment(i, 2)

    """
    program._push()
    yield
    state = program._pop()
    program._state.add_else_clause(state.body)


@contextlib.contextmanager
def ForIn(
    program: Program,
    iterator: Iterable[AstConvertible] | range | AstConvertible,
    identifier_name: Optional[str] = None,
) -> Iterator[IntVar]:
    """Context manager for looping a particular portion of a program.

    .. code-block:: python

        i = IntVar(1)
        with ForIn(program, range(1, 10)) as index:
            program.increment(i, index)

    """
    program._push()
    var = IntVar(name=identifier_name, needs_declaration=False)
    yield var
    state = program._pop()

    if isinstance(iterator, range):
        iterator = convert_range(program, iterator)
    elif isinstance(iterator, Iterable):
        iterator = ast.DiscreteSet([to_ast(program, i) for i in iterator])
    elif isinstance(iterator, _ClassicalVar):
        iterator = to_ast(program, iterator)
    else:
        raise TypeError(f"'{type(iterator)}' object is not iterable")

    stmt = ast.ForInLoop(ast.IntType(size=None), var.to_ast(program), iterator, state.body)
    program._add_statement(stmt)


@contextlib.contextmanager
def While(program: Program, condition: OQPyExpression) -> Iterator[None]:
    """Context manager for looping a repeating a portion of a program while a condition is True.

    .. code-block:: python

        i = IntVar(1)
        with While(program, i < 5) as index:
            program.increment(i, 1)

    """
    program._push()
    yield
    state = program._pop()
    program._add_statement(ast.WhileLoop(to_ast(program, condition), state.body))
