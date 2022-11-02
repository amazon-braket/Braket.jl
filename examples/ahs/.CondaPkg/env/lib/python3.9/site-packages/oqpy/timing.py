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
"""Constructs for manipulating sequence timing."""

from __future__ import annotations

import contextlib
from typing import TYPE_CHECKING, Iterator, cast

from openpulse import ast

from oqpy.base import ExpressionConvertible, HasToAst, OQPyExpression, optional_ast
from oqpy.classical_types import AstConvertible

if TYPE_CHECKING:
    from oqpy.program import Program


__all__ = ["Box", "make_duration"]


@contextlib.contextmanager
def Box(program: Program, duration: AstConvertible | None = None) -> Iterator[None]:
    """Creates a section of the program with a specified duration."""
    if duration is not None:
        duration = make_duration(duration)
    program._push()
    yield
    state = program._pop()
    program._add_statement(ast.Box(optional_ast(program, duration), state.body))


def make_duration(time: AstConvertible) -> HasToAst:
    """Make value into an expression representing a duration."""
    if isinstance(time, (float, int)):
        return OQDurationLiteral(time)
    if hasattr(time, "to_ast"):
        return time  # type: ignore[return-value]
    if hasattr(time, "_to_oqpy_expression"):
        time = cast(ExpressionConvertible, time)
        return time._to_oqpy_expression()
    raise TypeError(
        f"Expected either float, int, HasToAst or ExpressionConverible: Got {type(time)}"
    )


class OQDurationLiteral(OQPyExpression):
    """An expression corresponding to a duration literal."""

    def __init__(self, duration: float) -> None:
        super().__init__()
        self.duration = duration

    def to_ast(self, program: Program) -> ast.DurationLiteral:
        # Todo (#53): make better units?
        return ast.DurationLiteral(1e9 * self.duration, ast.TimeUnit.ns)
