export @const_gate,
    ConstantGate,
    ConstGate,
    X,
    Y,
    Z,
    H,
    I2,
    SWAP,
    T,
    XGate,
    YGate,
    ZGate,
    HGate,
    I2Gate,
    SWAPGate,
    TGate

"""
    ConstGate

A module contains all constant gate definitions.
"""
module ConstGate
import ..YaoBlocks
export ConstantGate, PauliGate

"""
    ConstantGate{N, D} <: PrimitiveBlock{N, D}

Abstract type for constant gates. Constant gates are
quantum gates with constant value, e.g Pauli gates,
T gate, Hadmard gates, etc. Type parameter `N` is the number of qubits.
"""
abstract type ConstantGate{N,D} <: YaoBlocks.PrimitiveBlock{D} end

include("const_gate_tools.jl")
include("const_gate_gen.jl")

const PauliGate = Union{I2Gate,XGate,YGate,ZGate}

YaoBlocks.cache_key(x::ConstantGate) = 0x1

struct IGate{N} <: ConstantGate{N,2} end
YaoBlocks.mat(::Type{T}, ::IGate{N}) where {T,N} = IMatrix{1 << N,T}()

YaoBase.ishermitian(::IGate) = true
YaoBase.isunitary(::IGate) = true
end

# import some frequently-used objects
import .ConstGate:
    XGate,
    YGate,
    ZGate,
    HGate,
    I2Gate,
    SWAPGate,
    TGate,
    X,
    Y,
    Z,
    H,
    I2,
    SWAP,
    T,
    @const_gate,
    ConstantGate,
    PauliGate

occupied_locs(::I2Gate) = ()
nqudits(::ConstantGate{N}) where N = N
