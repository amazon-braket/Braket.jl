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
"""Base classes and conversion methods for OQpy.

This class establishes how expressions are represented in oqpy and how
they are converted to AST nodes.
"""

from __future__ import annotations

import sys
from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, Any, Iterable, Union

import numpy as np
from openpulse import ast

if sys.version_info >= (3, 8):
    from typing import Protocol, runtime_checkable
else:
    from typing_extensions import Protocol, runtime_checkable

if TYPE_CHECKING:
    from oqpy import Program


class OQPyExpression:
    """Base class for OQPy expressions.

    Subclasses must implement ``to_ast`` method and supply the ``type`` attribute

    Expressions can be composed via overloaded arithmetic and boolean comparison operators
    to create new expressions. Note this means you cannot evaluate expression equality via
    ``==`` which produces a new expression instead of producing a python boolean.
    """

    type: ast.ClassicalType

    def to_ast(self, program: Program) -> ast.Expression:
        """Converts the oqpy expression into an ast node."""
        raise NotImplementedError  # pragma: no cover

    @staticmethod
    def _to_binary(
        op_name: str, first: AstConvertible, second: AstConvertible
    ) -> OQPyBinaryExpression:
        """Helper method to produce a binary expression."""
        return OQPyBinaryExpression(ast.BinaryOperator[op_name], first, second)

    def __add__(self, other: AstConvertible) -> OQPyBinaryExpression:
        return self._to_binary("+", self, other)

    def __radd__(self, other: AstConvertible) -> OQPyBinaryExpression:
        return self._to_binary("+", other, self)

    def __mod__(self, other: AstConvertible) -> OQPyBinaryExpression:
        return self._to_binary("%", self, other)

    def __rmod__(self, other: AstConvertible) -> OQPyBinaryExpression:
        return self._to_binary("%", other, self)

    def __mul__(self, other: AstConvertible) -> OQPyBinaryExpression:
        return self._to_binary("*", self, other)

    def __rmul__(self, other: AstConvertible) -> OQPyBinaryExpression:
        return self._to_binary("*", other, self)

    def __eq__(self, other: AstConvertible) -> OQPyBinaryExpression:  # type: ignore[override]
        return self._to_binary("==", self, other)

    def __ne__(self, other: AstConvertible) -> OQPyBinaryExpression:  # type: ignore[override]
        return self._to_binary("!=", self, other)

    def __gt__(self, other: AstConvertible) -> OQPyBinaryExpression:
        return self._to_binary(">", self, other)

    def __lt__(self, other: AstConvertible) -> OQPyBinaryExpression:
        return self._to_binary("<", self, other)

    def __ge__(self, other: AstConvertible) -> OQPyBinaryExpression:
        return self._to_binary(">=", self, other)

    def __le__(self, other: AstConvertible) -> OQPyBinaryExpression:
        return self._to_binary("<=", self, other)

    def __bool__(self) -> bool:
        raise RuntimeError(
            "OQPy expressions cannot be converted to bool. This can occur if you try to check "
            "the equality of expressions using == instead of expr_matches."
        )


def expr_matches(a: Any, b: Any) -> bool:
    """Check equality of the given objects.

    This bypasses calling ``__eq__`` on expr objects.
    """
    if type(a) is not type(b):
        return False
    if isinstance(a, (list, np.ndarray)):
        if len(a) != len(b):
            return False
        return all(expr_matches(ai, bi) for ai, bi in zip(a, b))
    elif isinstance(a, dict):
        if a.keys() != b.keys():
            return False
        return all(expr_matches(va, b[k]) for k, va in a.items())
    if hasattr(a, "__dict__"):
        return expr_matches(a.__dict__, b.__dict__)
    else:
        return a == b


@runtime_checkable
class ExpressionConvertible(Protocol):
    """This is the protocol an object can implement in order to be usable as an expression."""

    def _to_oqpy_expression(self) -> HasToAst:
        ...


class OQPyBinaryExpression(OQPyExpression):
    """An expression consisting of two subexpressions joined by an operator."""

    def __init__(self, op: ast.BinaryOperator, lhs: AstConvertible, rhs: AstConvertible):
        super().__init__()
        self.op = op
        self.lhs = lhs
        self.rhs = rhs
        # TODO (#50): More robust type checking which considers both arguments
        #   types, as well as the operator.
        if isinstance(lhs, OQPyExpression):
            self.type = lhs.type
        elif isinstance(rhs, OQPyExpression):
            self.type = rhs.type
        else:
            raise TypeError("Neither lhs nor rhs is an expression?")

    def to_ast(self, program: Program) -> ast.BinaryExpression:
        """Converts the OQpy expression into an ast node."""
        return ast.BinaryExpression(self.op, to_ast(program, self.lhs), to_ast(program, self.rhs))


class Var(ABC):
    """Abstract base class for both classical and quantum variables."""

    def __init__(self, name: str, needs_declaration: bool = True):
        self.name = name
        self._needs_declaration = needs_declaration

    def _var_matches(self, other: Any) -> bool:
        """Return true if this object represents the same variable as other.

        Needed because we overload ``==`` for expressions.
        """
        if isinstance(self, OQPyExpression):
            return expr_matches(self, other)
        else:
            return self == other

    @abstractmethod
    def to_ast(self, program: Program) -> ast.Expression:
        """Converts the OQpy variable into an ast node."""
        ...

    @abstractmethod
    def make_declaration_statement(self, program: Program) -> ast.Statement:
        """Make an ast statement that declares the OQpy variable."""
        ...


@runtime_checkable
class HasToAst(Protocol):
    """Protocol for objects which can be converted into ast nodes."""

    def to_ast(self, program: Program) -> ast.Expression:
        """Converts the OQpy object into an ast node."""
        ...


AstConvertible = Union[
    HasToAst, bool, int, float, complex, Iterable, ExpressionConvertible, ast.Expression
]


def to_ast(program: Program, item: AstConvertible) -> ast.Expression:
    """Convert an object to an AST node."""
    if hasattr(item, "_to_oqpy_expression"):
        return item._to_oqpy_expression().to_ast(program)  # type: ignore[union-attr]
    if isinstance(item, (complex, np.complexfloating)):
        if item.imag == 0:
            return to_ast(program, item.real)
        if item.real == 0:
            if item.imag < 0:
                return ast.UnaryExpression(ast.UnaryOperator["-"], ast.ImaginaryLiteral(-item.imag))
            else:
                return ast.ImaginaryLiteral(item.imag)
        if item.imag < 0:
            return ast.BinaryExpression(
                ast.BinaryOperator["-"],
                ast.FloatLiteral(item.real),
                ast.ImaginaryLiteral(-item.imag),
            )
        return ast.BinaryExpression(
            ast.BinaryOperator["+"], ast.FloatLiteral(item.real), ast.ImaginaryLiteral(item.imag)
        )
    if isinstance(item, (bool, np.bool_)):
        return ast.BooleanLiteral(item)
    if isinstance(item, (int, np.integer)):
        if item < 0:
            return ast.UnaryExpression(ast.UnaryOperator["-"], ast.IntegerLiteral(-item))
        return ast.IntegerLiteral(item)
    if isinstance(item, (float, np.floating)):
        if item < 0:
            return ast.UnaryExpression(ast.UnaryOperator["-"], ast.FloatLiteral(-item))
        return ast.FloatLiteral(item)
    if isinstance(item, Iterable):
        return ast.ArrayLiteral([to_ast(program, i) for i in item])
    if isinstance(item, ast.Expression):
        return item
    if hasattr(item, "to_ast"):  # Using isinstance(HasToAst) slowish
        return item.to_ast(program)  # type: ignore[union-attr]
    raise TypeError(f"Cannot convert {item} of type {type(item)} to ast")


def optional_ast(program: Program, item: AstConvertible | None) -> ast.Expression | None:
    """Convert item to ast if it is not None."""
    if item is None:
        return None
    return to_ast(program, item)


def map_to_ast(program: Program, items: Iterable[AstConvertible]) -> list[ast.Expression]:
    """Convert a sequence of items into a sequence of ast nodes."""
    return [to_ast(program, item) for item in items]
