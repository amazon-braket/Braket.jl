export CompilerDirective, StartVerbatimBox, EndVerbatimBox

"""
    CompilerDirective <: Operator

Abstract type representing a directive to a device-specific compiler.
"""
abstract type CompilerDirective <: Operator end

"""
    StartVerbatimBox <: CompilerDirective

Directive to begin a region of "verbatim" instructions, which
will not be modified by any further compilation steps.
"""
struct StartVerbatimBox <: CompilerDirective end
"""
    EndVerbatimBox <: CompilerDirective

Directive to end a region of "verbatim" instructions, which
will not be modified by any further compilation steps.
"""
struct EndVerbatimBox <: CompilerDirective end
counterpart(s::StartVerbatimBox) = EndVerbatimBox()
counterpart(e::EndVerbatimBox)   = StartVerbatimBox()
ir(s::StartVerbatimBox, ::Val{:JAQCD}; kwargs...)    = IR.StartVerbatimBox("StartVerbatimBox", "start_verbatim_box")
ir(s::EndVerbatimBox,   ::Val{:JAQCD}; kwargs...)    = IR.EndVerbatimBox("EndVerbatimBox", "end_verbatim_box")
ir(s::StartVerbatimBox, ::Val{:OpenQASM}; kwargs...) = "#pragma braket verbatim\nbox{"
ir(s::EndVerbatimBox,   ::Val{:OpenQASM}; kwargs...) = "}"
ir(c::CompilerDirective; kwargs...)                  = ir(c, Val(IRType[]); kwargs...)
chars(s::StartVerbatimBox) = ("StartVerbatim","StartVerbatim")
chars(s::EndVerbatimBox)   = ("EndVerbatim","EndVerbatim")

StructTypes.subtypes(::Type{CompilerDirective}) = (start_verbatim_box=StartVerbatimBox, end_verbatim_box=EndVerbatimBox)
