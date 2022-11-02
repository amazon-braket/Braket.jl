"""
Evaluating expressions
"""
import math
from typing import Type

import numpy as np

from ..parser.openqasm_ast import (
    ArrayLiteral,
    AssignmentOperator,
    BinaryOperator,
    BooleanLiteral,
    FloatLiteral,
    IntegerLiteral,
    UintType,
    UnaryOperator,
)
from .casting import LiteralType, cast_to, convert_bool_array_to_string

operator_maps = {
    IntegerLiteral: {
        # returns int
        getattr(BinaryOperator, "+"): lambda x, y: IntegerLiteral(x.value + y.value),
        getattr(BinaryOperator, "-"): lambda x, y: IntegerLiteral(x.value - y.value),
        getattr(BinaryOperator, "*"): lambda x, y: IntegerLiteral(x.value * y.value),
        getattr(BinaryOperator, "/"): lambda x, y: IntegerLiteral(x.value / y.value),
        getattr(BinaryOperator, "%"): lambda x, y: IntegerLiteral(x.value % y.value),
        getattr(BinaryOperator, "**"): lambda x, y: IntegerLiteral(x.value**y.value),
        getattr(UnaryOperator, "-"): lambda x: IntegerLiteral(-x.value),
        # returns bool
        getattr(BinaryOperator, ">"): lambda x, y: BooleanLiteral(x.value > y.value),
        getattr(BinaryOperator, "<"): lambda x, y: BooleanLiteral(x.value < y.value),
        getattr(BinaryOperator, ">="): lambda x, y: BooleanLiteral(x.value >= y.value),
        getattr(BinaryOperator, "<="): lambda x, y: BooleanLiteral(x.value <= y.value),
        getattr(BinaryOperator, "=="): lambda x, y: BooleanLiteral(x.value == y.value),
        getattr(BinaryOperator, "!="): lambda x, y: BooleanLiteral(x.value != y.value),
    },
    FloatLiteral: {
        # returns real
        getattr(BinaryOperator, "+"): lambda x, y: FloatLiteral(x.value + y.value),
        getattr(BinaryOperator, "-"): lambda x, y: FloatLiteral(x.value - y.value),
        getattr(BinaryOperator, "*"): lambda x, y: FloatLiteral(x.value * y.value),
        getattr(BinaryOperator, "/"): lambda x, y: FloatLiteral(x.value / y.value),
        getattr(BinaryOperator, "**"): lambda x, y: FloatLiteral(x.value**y.value),
        getattr(UnaryOperator, "-"): lambda x: FloatLiteral(-x.value),
        # returns bool
        getattr(BinaryOperator, ">"): lambda x, y: BooleanLiteral(x.value > y.value),
        getattr(BinaryOperator, "<"): lambda x, y: BooleanLiteral(x.value < y.value),
        getattr(BinaryOperator, ">="): lambda x, y: BooleanLiteral(x.value >= y.value),
        getattr(BinaryOperator, "<="): lambda x, y: BooleanLiteral(x.value <= y.value),
        getattr(BinaryOperator, "=="): lambda x, y: BooleanLiteral(x.value == y.value),
        getattr(BinaryOperator, "!="): lambda x, y: BooleanLiteral(x.value != y.value),
    },
    BooleanLiteral: {
        # returns bool
        getattr(BinaryOperator, "&"): lambda x, y: BooleanLiteral(x.value and y.value),
        getattr(BinaryOperator, "|"): lambda x, y: BooleanLiteral(x.value or y.value),
        getattr(BinaryOperator, "^"): lambda x, y: BooleanLiteral(x.value ^ y.value),
        getattr(BinaryOperator, "&&"): lambda x, y: BooleanLiteral(x.value and y.value),
        getattr(BinaryOperator, "||"): lambda x, y: BooleanLiteral(x.value or y.value),
        getattr(BinaryOperator, ">"): lambda x, y: BooleanLiteral(x.value > y.value),
        getattr(BinaryOperator, "<"): lambda x, y: BooleanLiteral(x.value < y.value),
        getattr(BinaryOperator, ">="): lambda x, y: BooleanLiteral(x.value >= y.value),
        getattr(BinaryOperator, "<="): lambda x, y: BooleanLiteral(x.value <= y.value),
        getattr(BinaryOperator, "=="): lambda x, y: BooleanLiteral(x.value == y.value),
        getattr(BinaryOperator, "!="): lambda x, y: BooleanLiteral(x.value != y.value),
        getattr(UnaryOperator, "!"): lambda x: BooleanLiteral(not x.value),
    },
    # Array literals are only used to store bit registers
    ArrayLiteral: {
        # returns array
        getattr(BinaryOperator, "&"): lambda x, y: ArrayLiteral(
            [BooleanLiteral(xv.value and yv.value) for xv, yv in zip(x.values, y.values)]
        ),
        getattr(BinaryOperator, "|"): lambda x, y: ArrayLiteral(
            [BooleanLiteral(xv.value or yv.value) for xv, yv in zip(x.values, y.values)]
        ),
        getattr(BinaryOperator, "^"): lambda x, y: ArrayLiteral(
            [BooleanLiteral(xv.value ^ yv.value) for xv, yv in zip(x.values, y.values)]
        ),
        getattr(BinaryOperator, "<<"): lambda x, y: ArrayLiteral(
            x.values[y.value :] + [BooleanLiteral(False) for _ in range(y.value)]
        ),
        getattr(BinaryOperator, ">>"): lambda x, y: ArrayLiteral(
            [BooleanLiteral(False) for _ in range(y.value)] + x.values[: len(x.values) - y.value]
        ),
        getattr(UnaryOperator, "~"): lambda x: ArrayLiteral(
            [BooleanLiteral(not v.value) for v in x.values]
        ),
        # returns bool
        getattr(BinaryOperator, ">"): lambda x, y: BooleanLiteral(
            convert_bool_array_to_string(x) > convert_bool_array_to_string(y)
        ),
        getattr(BinaryOperator, "<"): lambda x, y: BooleanLiteral(
            convert_bool_array_to_string(x) < convert_bool_array_to_string(y)
        ),
        getattr(BinaryOperator, ">="): lambda x, y: BooleanLiteral(
            convert_bool_array_to_string(x) >= convert_bool_array_to_string(y)
        ),
        getattr(BinaryOperator, "<="): lambda x, y: BooleanLiteral(
            convert_bool_array_to_string(x) <= convert_bool_array_to_string(y)
        ),
        getattr(BinaryOperator, "=="): lambda x, y: BooleanLiteral(
            convert_bool_array_to_string(x) == convert_bool_array_to_string(y)
        ),
        getattr(BinaryOperator, "!="): lambda x, y: BooleanLiteral(
            convert_bool_array_to_string(x) != convert_bool_array_to_string(y)
        ),
        getattr(UnaryOperator, "!"): lambda x: BooleanLiteral(not any(v.value for v in x.values)),
    },
}

type_hierarchy = (
    BooleanLiteral,
    IntegerLiteral,
    FloatLiteral,
    ArrayLiteral,
)

constant_map = {
    "pi": np.pi,
    "tau": 2 * np.pi,
    "euler": np.e,
}


builtin_constants = {
    "pi": FloatLiteral(np.pi),
    "π": FloatLiteral(np.pi),
    "tau": FloatLiteral(2 * np.pi),
    "τ": FloatLiteral(2 * np.pi),
    "euler": FloatLiteral(np.e),
    "ℇ": FloatLiteral(np.e),
}


builtin_functions = {
    "sizeof": lambda array, dim: (
        IntegerLiteral(len(array.values))
        if dim is None or dim.value == 0
        else builtin_functions["sizeof"](array.values[0], IntegerLiteral(dim.value - 1))
    ),
    "arccos": lambda x: FloatLiteral(np.arccos(x.value)),
    "arcsin": lambda x: FloatLiteral(np.arcsin(x.value)),
    "arctan": lambda x: FloatLiteral(np.arctan(x.value)),
    "ceiling": lambda x: IntegerLiteral(math.ceil(x.value)),
    "cos": lambda x: FloatLiteral(np.cos(x.value)),
    "exp": lambda x: FloatLiteral(np.exp(x.value)),
    "floor": lambda x: IntegerLiteral(math.floor(x.value)),
    "log": lambda x: FloatLiteral(np.log(x.value)),
    "mod": lambda x, y: (
        IntegerLiteral(x.value % y.value)
        if isinstance(x, IntegerLiteral) and isinstance(y, IntegerLiteral)
        else FloatLiteral(x.value % y.value)
    ),
    "popcount": lambda x: IntegerLiteral(np.binary_repr(cast_to(UintType(), x).value).count("1")),
    # parser gets confused by pow, mistaking for quantum modifier
    "pow": lambda x, y: (
        IntegerLiteral(x.value**y.value)
        if isinstance(x, IntegerLiteral) and isinstance(y, IntegerLiteral)
        else FloatLiteral(x.value**y.value)
    ),
    "rotl": lambda x: NotImplementedError(),
    "rotr": lambda x: NotImplementedError(),
    "sin": lambda x: FloatLiteral(np.sin(x.value)),
    "sqrt": lambda x: FloatLiteral(np.sqrt(x.value)),
    "tan": lambda x: FloatLiteral(np.tan(x.value)),
}


def resolve_type_hierarchy(x: LiteralType, y: LiteralType) -> Type[LiteralType]:
    """Determine output type of expression, for example: 1 + 1.0 == 2.0"""
    return max(type(x), type(y), key=type_hierarchy.index)


def evaluate_binary_expression(
    lhs: LiteralType, rhs: LiteralType, op: BinaryOperator
) -> LiteralType:
    """Evaluate a binary expression between two literals"""
    result_type = resolve_type_hierarchy(lhs, rhs)
    func = operator_maps[result_type].get(op)
    if not func:
        raise TypeError(f"Invalid operator {op.name} for {result_type.__name__}")
    return func(lhs, rhs)


def evaluate_unary_expression(expression: LiteralType, op: BinaryOperator) -> LiteralType:
    """Evaluate a unary expression on a literal"""
    expression_type = type(expression)
    func = operator_maps[expression_type].get(op)
    if not func:
        raise TypeError(f"Invalid operator {op.name} for {expression_type.__name__}")
    return func(expression)


def get_operator_of_assignment_operator(assignment_operator: AssignmentOperator) -> BinaryOperator:
    """Extract the binary operator related to an assignment operator, for example: += -> +"""
    return getattr(BinaryOperator, assignment_operator.name[:-1])
