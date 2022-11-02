from typing import Any, Dict, Iterable, List, Optional, Tuple, Type, Union

import numpy as np
from braket.ir.jaqcd.program_v1 import Results

from braket.default_simulator.gate_operations import BRAKET_GATES, GPhase, U, Unitary

from ..noise_operations import KrausOperation
from ._helpers.arrays import (
    convert_discrete_set_to_list,
    convert_range_def_to_slice,
    flatten_indices,
    get_elements,
    get_type_width,
    update_value,
)
from ._helpers.casting import LiteralType, get_identifier_name, is_none_like
from ._helpers.utils import singledispatchmethod
from .circuit import Circuit
from .parser.braket_pragmas import parse_braket_pragma
from .parser.openqasm_ast import (
    ClassicalType,
    FloatLiteral,
    GateModifierName,
    Identifier,
    IndexedIdentifier,
    IndexElement,
    IntegerLiteral,
    QuantumGateDefinition,
    QuantumGateModifier,
    RangeDefinition,
    SubroutineDefinition,
)


class Table:
    """
    Utility class for storing and displaying items.
    """

    def __init__(self, title: str):
        self._title = title
        self._dict = {}

    def __getitem__(self, item: str):
        return self._dict[item]

    def __contains__(self, item: str):
        return item in self._dict

    def __setitem__(self, key: str, value: Any):
        self._dict[key] = value

    def items(self) -> Iterable[Tuple[str, Any]]:
        return self._dict.items()

    def _longest_key_length(self) -> int:
        items = self.items()
        return max(len(key) for key, value in items) if items else None

    def __repr__(self):
        rows = [self._title]
        longest_key_length = self._longest_key_length()
        for item, value in self.items():
            rows.append(f"{item:<{longest_key_length}}\t{value}")
        return "\n".join(rows)


class QubitTable(Table):
    def __init__(self):
        super().__init__("Qubits")

    @singledispatchmethod
    def get_by_identifier(self, identifier: Union[Identifier, IndexedIdentifier]) -> Tuple[int]:
        """
        Convenience method to get an element with a possibly indexed identifier.
        """
        return self[identifier.name]

    @get_by_identifier.register
    def _(self, identifier: IndexedIdentifier) -> Tuple[int]:
        """
        When identifier is an IndexedIdentifier, function returns a tuple
        corresponding to the elements referenced by the indexed identifier.
        """
        name = identifier.name.name
        primary_index = identifier.indices[0]
        if isinstance(primary_index, list):
            if len(primary_index) != 1:
                raise IndexError("Cannot index multiple dimensions for qubits.")
            primary_index = primary_index[0]
        if isinstance(primary_index, IntegerLiteral):
            target = (self[name][primary_index.value],)
        elif isinstance(primary_index, RangeDefinition):
            target = tuple(np.array(self[name])[convert_range_def_to_slice(primary_index)])
        # Discrete set
        else:
            target = tuple(np.array(self[name])[convert_discrete_set_to_list(primary_index)])

        if len(identifier.indices) == 1:
            return target
        elif len(identifier.indices) == 2:
            # used for gate calls on registers, index will be IntegerLiteral
            secondary_index = identifier.indices[1][0].value
            return (target[secondary_index],)
        else:
            raise IndexError("Cannot index multiple dimensions for qubits.")

    def get_qubit_size(self, identifier: Union[Identifier, IndexedIdentifier]) -> int:
        return len(self.get_by_identifier(identifier))


class ScopedTable(Table):
    """
    Scoped version of Table
    """

    def __init__(self, title):
        super().__init__(title)
        self._scopes = [{}]

    def push_scope(self) -> None:
        self._scopes.append({})

    def pop_scope(self) -> None:
        self._scopes.pop()

    @property
    def in_global_scope(self):
        return len(self._scopes) == 1

    @property
    def current_scope(self) -> Dict[str, Any]:
        return self._scopes[-1]

    def __getitem__(self, item: str):
        """
        Resolve scope of item and return its value.
        """
        for scope in reversed(self._scopes):
            if item in scope:
                return scope[item]
        raise KeyError(f"Undefined key: {item}")

    def __setitem__(self, key: str, value: Any):
        """
        Set value of item in current scope.
        """
        try:
            self.get_scope(key)[key] = value
        except KeyError:
            self.current_scope[key] = value

    def __delitem__(self, key: str):
        """
        Delete item from first scope in which it exists.
        """
        for scope in reversed(self._scopes):
            if key in scope:
                del scope[key]
                return
        raise KeyError(f"Undefined key: {key}")

    def get_scope(self, key: str) -> Dict[str, Any]:
        """Get the smallest scope containing the given key"""
        for scope in reversed(self._scopes):
            if key in scope:
                return scope
        raise KeyError(f"Undefined key: {key}")

    def items(self) -> Iterable[Tuple[str, Any]]:
        items = {}
        for scope in reversed(self._scopes):
            for key, value in scope.items():
                if key not in items:
                    items[key] = value
        return items.items()

    def __repr__(self):
        rows = [self._title]
        longest_key_length = self._longest_key_length()
        for level, scope in enumerate(self._scopes):
            rows.append(f"SCOPE LEVEL {level}")
            for item, value in scope.items():
                rows.append(f"{item:<{longest_key_length}}\t{value}")
        return "\n".join(rows)


class SymbolTable(ScopedTable):
    """
    Scoped table used to map names to types.
    """

    class Symbol:
        def __init__(
            self,
            symbol_type: Union[ClassicalType, LiteralType],
            const: bool = False,
        ):
            self.type = symbol_type
            self.const = const

        def __repr__(self):
            return f"Symbol<{self.type}, const={self.const}>"

    def __init__(self):
        super().__init__("Symbols")

    def add_symbol(
        self,
        name: str,
        symbol_type: Union[ClassicalType, LiteralType, Type[Identifier]],
        const: bool = False,
    ) -> None:
        """
        Add a symbol to the symbol table.

        Args:
            name (str): Name of the symbol.
            symbol_type (Union[ClassicalType, LiteralType]): Type of the symbol. Symbols can
                have a literal type when they are a numeric argument to a gate or an integer
                literal loop variable.
            const (bool): Whether the variable is immutable.
        """
        self.current_scope[name] = SymbolTable.Symbol(symbol_type, const)

    def get_symbol(self, name: str) -> Symbol:
        """
        Get a symbol from the symbol table by name.

        Args:
            name (str): Name of the symbol.

        Returns:
            Symbol: The symbol object.
        """
        return self[name]

    def get_type(self, name: str) -> Union[ClassicalType, Type[LiteralType]]:
        """
        Get the type of a symbol by name.

        Args:
            name (str): Name of the symbol.

        Returns:
            Union[ClassicalType, LiteralType]: The type of the symbol.
        """
        return self.get_symbol(name).type

    def get_const(self, name: str) -> bool:
        """
        Get const status of a symbol by name.

        Args:
            name (str): Name of the symbol.

        Returns:
            bool: Whether the symbol is a const symbol.
        """
        return self.get_symbol(name).const


class VariableTable(ScopedTable):
    """
    Scoped table used store values for symbols. This implements the classical memory for
    the Interpreter.
    """

    def __init__(self):
        super().__init__("Data")

    def add_variable(self, name: str, value: Any) -> None:
        self.current_scope[name] = value

    def get_value(self, name: str) -> LiteralType:
        return self[name]

    @singledispatchmethod
    def get_value_by_identifier(
        self, identifier: Identifier, type_width: Optional[IntegerLiteral] = None
    ) -> LiteralType:
        """
        Convenience method to get value with a possibly indexed identifier.
        """
        return self[identifier.name]

    @get_value_by_identifier.register
    def _(
        self, identifier: IndexedIdentifier, type_width: Optional[IntegerLiteral] = None
    ) -> LiteralType:
        """
        When identifier is an IndexedIdentifier, function returns an ArrayLiteral
        corresponding to the elements referenced by the indexed identifier.
        """
        name = identifier.name.name
        value = self[name]
        indices = flatten_indices(identifier.indices)
        return get_elements(value, indices, type_width)

    def update_value(
        self,
        name: str,
        value: Any,
        var_type: ClassicalType,
        indices: Optional[List[IndexElement]] = None,
    ) -> None:
        """Update value of a variable, optionally providing an index"""
        current_value = self[name]
        if indices:
            value = update_value(current_value, value, flatten_indices(indices), var_type)
        self[name] = value

    def is_initalized(self, name: str) -> bool:
        """Determine whether a declared variable is initialized"""
        return not is_none_like(self[name])


class GateTable(ScopedTable):
    """
    Scoped table to implement gates.
    """

    def __init__(self):
        super().__init__("Gates")

    def add_gate(self, name: str, definition: QuantumGateDefinition) -> None:
        self[name] = definition

    def get_gate_definition(self, name: str) -> QuantumGateDefinition:
        return self[name]


class SubroutineTable(ScopedTable):
    """
    Scoped table to implement subroutines.
    """

    def __init__(self):
        super().__init__("Subroutines")

    def add_subroutine(self, name: str, definition: SubroutineDefinition) -> None:
        self[name] = definition

    def get_subroutine_definition(self, name: str) -> SubroutineDefinition:
        return self[name]


class ScopeManager:
    """
    Allows ProgramContext to manage scope with `with` keyword.
    """

    def __init__(self, context: "ProgramContext"):
        self.context = context

    def __enter__(self):
        self.context.push_scope()

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.context.pop_scope()


class ProgramContext:
    """
    Interpreter state.

    Symbol table - symbols in scope
    Variable table - variable values
    Gate table - gate definitions
    Subroutine table - subroutine definitions
    Qubit mapping - mapping from logical qubits to qubit indices

    Circuit - IR build to hand off to the simulator

    """

    def __init__(self):
        self.symbol_table = SymbolTable()
        self.variable_table = VariableTable()
        self.gate_table = GateTable()
        self.subroutine_table = SubroutineTable()
        self.qubit_mapping = QubitTable()
        self.scope_manager = ScopeManager(self)
        self.inputs = {}
        self.num_qubits = 0
        self.circuit = Circuit()

    def __repr__(self):
        return "\n\n".join(
            repr(x)
            for x in (self.symbol_table, self.variable_table, self.gate_table, self.qubit_mapping)
        )

    def load_inputs(self, inputs: Dict[str, Any]) -> None:
        """Load inputs for the program"""
        for key, value in inputs.items():
            self.inputs[key] = value

    def parse_pragma(self, pragma_body: str):
        """Parse pragma"""
        return parse_braket_pragma(pragma_body, self.qubit_mapping)

    def declare_variable(
        self,
        name: str,
        symbol_type: Union[ClassicalType, Type[LiteralType], Type[Identifier]],
        value: Optional[Any] = None,
        const: bool = False,
    ) -> None:
        """Declare variable in current scope"""
        self.symbol_table.add_symbol(name, symbol_type, const)
        self.variable_table.add_variable(name, value)

    def declare_qubit_alias(
        self,
        name: str,
        value: Identifier,
    ) -> None:
        """Declare qubit alias in current scope"""
        self.symbol_table.add_symbol(name, Identifier)
        self.variable_table.add_variable(name, value)

    def enter_scope(self) -> ScopeManager:
        """
        Allows pushing/popping scope with indentation and the `with` keyword.

        Usage:
        # inside the original scope
        ...
        with program_context.enter_scope():
            # inside a new scope
            ...
        # exited new scope, back in the original scope
        """
        return self.scope_manager

    def push_scope(self) -> None:
        """Enter a new scope"""
        self.symbol_table.push_scope()
        self.variable_table.push_scope()
        self.gate_table.push_scope()

    def pop_scope(self) -> None:
        """Exit current scope"""
        self.symbol_table.pop_scope()
        self.variable_table.pop_scope()
        self.gate_table.pop_scope()

    @property
    def in_global_scope(self):
        return self.symbol_table.in_global_scope

    def get_type(self, name: str) -> Union[ClassicalType, Type[LiteralType]]:
        """Get symbol type by name"""
        return self.symbol_table.get_type(name)

    def get_const(self, name: str) -> bool:
        """Get whether a symbol is const by name"""
        return self.symbol_table.get_const(name)

    def get_value(self, name: str) -> LiteralType:
        """Get value of a variable by name"""
        return self.variable_table.get_value(name)

    def get_value_by_identifier(
        self, identifier: Union[Identifier, IndexedIdentifier]
    ) -> LiteralType:
        """Get value of a variable by identifier"""
        # find type width for the purpose of bitwise operations
        var_type = self.get_type(get_identifier_name(identifier))
        type_width = get_type_width(var_type)
        return self.variable_table.get_value_by_identifier(identifier, type_width)

    def is_initialized(self, name: str) -> bool:
        """Check whether variable is initialized by name"""
        return self.variable_table.is_initalized(name)

    def update_value(self, variable: Union[Identifier, IndexedIdentifier], value: Any) -> None:
        """Update value by identifier, possible only a sub-index of a variable"""
        name = get_identifier_name(variable)
        var_type = self.get_type(name)
        indices = variable.indices if isinstance(variable, IndexedIdentifier) else None
        self.variable_table.update_value(name, value, var_type, indices)

    def add_qubits(self, name: str, num_qubits: Optional[int] = 1) -> None:
        """Allocate additional qubits for the program"""
        self.qubit_mapping[name] = tuple(range(self.num_qubits, self.num_qubits + num_qubits))
        self.num_qubits += num_qubits
        self.declare_qubit_alias(name, Identifier(name))

    def get_qubits(self, qubits: Union[Identifier, IndexedIdentifier]) -> Tuple[int]:
        """
        Get qubit indices from a qubit identifier, possibly referring to a sub-index of
        a qubit register
        """
        return self.qubit_mapping.get_by_identifier(qubits)

    def add_gate(self, name: str, definition: QuantumGateDefinition) -> None:
        """Add a gate definition"""
        self.gate_table.add_gate(name, definition)

    def get_gate_definition(self, name: str) -> QuantumGateDefinition:
        """Get a gate definition by name"""
        try:
            return self.gate_table.get_gate_definition(name)
        except KeyError:
            raise ValueError(f"Gate {name} is not defined.")

    def is_builtin_gate(self, name: str) -> bool:
        """Whether the gate is currently in scope as a built in Braket gate"""
        try:
            self.get_gate_definition(name)
            user_defined_gate = True
        except ValueError:
            user_defined_gate = False
        return name in BRAKET_GATES and not user_defined_gate

    def add_subroutine(self, name: str, definition: SubroutineDefinition) -> None:
        """Add a subroutine definition"""
        self.subroutine_table.add_subroutine(name, definition)

    def get_subroutine_definition(self, name: str) -> SubroutineDefinition:
        """Get a subroutine definition by name"""
        try:
            return self.subroutine_table.get_subroutine_definition(name)
        except KeyError:
            raise NameError(f"Subroutine {name} is not defined.")

    def add_result(self, result: Results) -> None:
        """Add a result type to the circuit"""
        self.circuit.add_result(result)

    def add_phase(
        self,
        phase: FloatLiteral,
        qubits: Optional[List[Union[Identifier, IndexedIdentifier]]] = None,
    ) -> None:
        """Add quantum phase instruction to the circuit"""
        # if targets overlap, duplicates will be ignored
        if not qubits:
            target = range(self.num_qubits)
        else:
            target = set(sum((self.get_qubits(q) for q in qubits), ()))
        phase_instruction = GPhase(target, phase.value)
        self.circuit.add_instruction(phase_instruction)

    def add_builtin_gate(
        self,
        gate_name: str,
        parameters: List[FloatLiteral],
        qubits: List[Union[Identifier, IndexedIdentifier]],
        modifiers: Optional[List[QuantumGateModifier]] = None,
    ) -> None:
        """Add a builtin gate instruction to the circuit"""
        target = sum(((*self.get_qubits(qubit),) for qubit in qubits), ())
        params = np.array([param.value for param in parameters])
        num_inv_modifiers = modifiers.count(QuantumGateModifier(GateModifierName.inv, None))
        power = 1
        if num_inv_modifiers % 2:
            power *= -1  # todo: replace with adjoint

        ctrl_mod_map = {
            GateModifierName.ctrl: 0,
            GateModifierName.negctrl: 1,
        }
        ctrl_modifiers = []
        for mod in modifiers:
            ctrl_mod_ix = ctrl_mod_map.get(mod.modifier)
            if ctrl_mod_ix is not None:
                ctrl_modifiers += [ctrl_mod_ix] * mod.argument.value
            if mod.modifier == GateModifierName.pow:
                power *= mod.argument.value
        instruction = BRAKET_GATES[gate_name](
            target, *params, ctrl_modifiers=ctrl_modifiers, power=power
        )
        self.circuit.add_instruction(instruction)

    def add_custom_unitary(
        self,
        unitary: np.ndarray,
        target: Tuple[int],
    ) -> None:
        """Add a custom Unitary instruction to the circuit"""
        instruction = Unitary(target, unitary)
        self.circuit.add_instruction(instruction)

    def add_noise_instruction(self, noise: KrausOperation):
        """Add a noise instruction the circuit"""
        self.circuit.add_instruction(noise)
