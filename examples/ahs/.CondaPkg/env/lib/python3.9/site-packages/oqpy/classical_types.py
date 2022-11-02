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
"""Classes representing oqpy variables with classical types."""

from __future__ import annotations

import functools
import random
import string
from typing import TYPE_CHECKING, Any, Callable, Iterable, Type, TypeVar, Union

from openpulse import ast

from oqpy.base import (
    AstConvertible,
    OQPyExpression,
    Var,
    map_to_ast,
    optional_ast,
    to_ast,
)
from oqpy.timing import make_duration

if TYPE_CHECKING:
    from oqpy.program import Program

__all__ = [
    "BoolVar",
    "IntVar",
    "UintVar",
    "FloatVar",
    "AngleVar",
    "BitVar",
    "ComplexVar",
    "DurationVar",
    "OQFunctionCall",
    "StretchVar",
    "_ClassicalVar",
    "duration",
    "stretch",
    "bool_",
    "bit_",
    "bit8",
    "convert_range",
    "int_",
    "int32",
    "int64",
    "uint_",
    "uint32",
    "uint64",
    "float_",
    "float32",
    "float64",
    "complex_",
    "complex64",
    "complex128",
    "angle_",
    "angle32",
]

# The following methods and constants are useful for creating signatures
# for openqasm function calls, as is required when specifying
# waveform generating methods.
# If you wish to create a variable with a particular type, please use the
# subclasses of ``_ClassicalVar`` instead.


def int_(size: int) -> ast.IntType:
    """Create a sized signed integer type."""
    return ast.IntType(ast.IntegerLiteral(size))


def uint_(size: int) -> ast.UintType:
    """Create a sized unsigned integer type."""
    return ast.UintType(ast.IntegerLiteral(size))


def float_(size: int) -> ast.FloatType:
    """Create a sized floating-point type."""
    return ast.FloatType(ast.IntegerLiteral(size))


def angle_(size: int) -> ast.AngleType:
    """Create a sized angle type."""
    return ast.AngleType(ast.IntegerLiteral(size))


def complex_(size: int) -> ast.ComplexType:
    """Create a sized complex type.

    Note the size represents the total size, and thus the components have
    half of the requested size.
    """
    return ast.ComplexType(ast.FloatType(ast.IntegerLiteral(size // 2)))


def bit_(size: int) -> ast.BitType:
    """Create a sized bit type."""
    return ast.BitType(ast.IntegerLiteral(size))


duration = ast.DurationType()
stretch = ast.StretchType()
bool_ = ast.BoolType()
bit8 = bit_(8)
int32 = int_(32)
int64 = int_(64)
uint32 = uint_(32)
uint64 = uint_(64)
float32 = float_(32)
float64 = float_(64)
complex64 = complex_(64)
complex128 = complex_(128)
angle32 = angle_(32)


def convert_range(program: Program, item: Union[slice, range]) -> ast.RangeDefinition:
    """Convert a slice or range into an ast node."""
    return ast.RangeDefinition(
        to_ast(program, item.start),
        to_ast(program, item.stop - 1),
        to_ast(program, item.step) if item.step != 1 else None,
    )


class _ClassicalVar(Var, OQPyExpression):
    """Base type for variables with classical type.

    Subclasses should supply the type_cls class variable.
    """

    type_cls: Type[ast.ClassicalType]

    def __init__(
        self,
        init_expression: AstConvertible | None = None,
        name: str | None = None,
        needs_declaration: bool = True,
        **type_kwargs: Any,
    ):
        name = name or "".join([random.choice(string.ascii_letters) for _ in range(10)])
        super().__init__(name, needs_declaration=needs_declaration)
        self.type = self.type_cls(**type_kwargs)
        self.init_expression = init_expression

    def to_ast(self, program: Program) -> ast.Identifier:
        """Converts the OQpy variable into an ast node."""
        program._add_var(self)
        return ast.Identifier(self.name)

    def make_declaration_statement(self, program: Program) -> ast.Statement:
        """Make an ast statement that declares the OQpy variable."""
        init_expression_ast = optional_ast(program, self.init_expression)
        return ast.ClassicalDeclaration(self.type, self.to_ast(program), init_expression_ast)


class BoolVar(_ClassicalVar):
    """An (unsized) oqpy variable with bool type."""

    type_cls = ast.BoolType


class _SizedVar(_ClassicalVar):
    """Base class for variables with a specified size."""

    default_size: int | None = None
    size: int | None

    def __class_getitem__(cls: Type[_SizedVarT], item: int) -> Callable[..., _SizedVarT]:
        # Allows IntVar[64]() notation
        return functools.partial(cls, size=item)

    def __init__(self, *args: Any, size: int | None = None, **kwargs: Any):
        if size is None:
            self.size = self.default_size
        else:
            if not isinstance(size, int) or size <= 0:
                raise ValueError(
                    f"The size of '{self.type_cls}' objects must be an positive integer."
                )
            self.size = size
        super().__init__(*args, **kwargs, size=ast.IntegerLiteral(self.size) if self.size else None)


_SizedVarT = TypeVar("_SizedVarT", bound=_SizedVar)


class IntVar(_SizedVar):
    """An oqpy variable with integer type."""

    type_cls = ast.IntType
    default_size = 32


class UintVar(_SizedVar):
    """An oqpy variable with unsigned integer type."""

    type_cls = ast.UintType
    default_size = 32


class FloatVar(_SizedVar):
    """An oqpy variable with floating type."""

    type_cls = ast.FloatType
    default_size = 64


class AngleVar(_SizedVar):
    """An oqpy variable with angle type."""

    type_cls = ast.AngleType
    default_size = 32


class BitVar(_SizedVar):
    """An oqpy variable with bit type."""

    type_cls = ast.BitType

    def __getitem__(self, idx: Union[int, slice, Iterable[int]]) -> BitVar:
        if self.size is None:
            raise TypeError(f"'{self.type_cls}' object is not subscriptable")
        if isinstance(idx, int):
            if 0 <= idx < self.size:
                return BitVar(
                    init_expression=ast.IndexExpression(
                        ast.Identifier(self.name), [ast.IntegerLiteral(idx)]
                    ),
                    name=f"{self.name}[{idx}]",
                    needs_declaration=False,
                )
            else:
                raise IndexError("list index out of range.")
        else:
            raise IndexError("The list index must be an integer.")


class ComplexVar(_ClassicalVar):
    """An oqpy variable with bit type."""

    type_cls = ast.ComplexType

    def __class_getitem__(cls, item: Type[ast.FloatType]) -> Callable[..., ComplexVar]:
        return functools.partial(cls, base_type=item)

    def __init__(
        self,
        init_expression: AstConvertible | None = None,
        *args: Any,
        base_type: Type[ast.FloatType] = float64,
        **kwargs: Any,
    ) -> None:
        assert isinstance(base_type, ast.FloatType)

        if not isinstance(init_expression, (complex, type(None), OQPyExpression)):
            init_expression = complex(init_expression)  # type: ignore[arg-type]
        super().__init__(init_expression, *args, **kwargs, base_type=base_type)


class DurationVar(_ClassicalVar):
    """An oqpy variable with duration type."""

    type_cls = ast.DurationType

    def __init__(
        self,
        init_expression: AstConvertible | None = None,
        name: str | None = None,
        *args: Any,
        **type_kwargs: Any,
    ) -> None:
        if init_expression is not None:
            init_expression = make_duration(init_expression)
        super().__init__(init_expression, name, *args, **type_kwargs)


class StretchVar(_ClassicalVar):
    """An oqpy variable with stretch type."""

    type_cls = ast.StretchType


class OQFunctionCall(OQPyExpression):
    """An oqpy expression corresponding to a function call."""

    def __init__(
        self,
        identifier: Union[str, ast.Identifier],
        args: Iterable[AstConvertible],
        return_type: ast.ClassicalType,
        extern_decl: ast.ExternDeclaration | None = None,
        subroutine_decl: ast.SubroutineDefinition | None = None,
    ):
        """Create a new OQFunctionCall instance.

        Args:
            identifier: The function name.
            args: The function arguments.
            return_type: The type returned by the function call.
            extern_decl: An optional extern declaration ast node. If present,
                this extern declaration will be added to the top of the program
                whenever this is converted to ast.
            subroutine_decl: An optional subroutine definition ast node. If present,
                this subroutine definition will be added to the top of the program
                whenever this expression is converted to ast.
        """
        super().__init__()
        if isinstance(identifier, str):
            identifier = ast.Identifier(identifier)
        self.identifier = identifier
        self.args = args
        self.type = return_type
        self.extern_decl = extern_decl
        self.subroutine_decl = subroutine_decl

    def to_ast(self, program: Program) -> ast.Expression:
        """Converts the OQpy expression into an ast node."""
        if self.extern_decl is not None:
            program.externs[self.identifier.name] = self.extern_decl
        if self.subroutine_decl is not None:
            program._add_subroutine(self.identifier.name, self.subroutine_decl)
        return ast.FunctionCall(self.identifier, map_to_ast(program, self.args))
