using YaoBase, YaoArrayRegister
import StaticArrays: SMatrix
export RotationGate, Rx, Ry, Rz, rot

"""
    RotationGate{D,T,GT<:AbstractBlock{D}} <: PrimitiveBlock{D}

RotationGate, with GT both hermitian and isreflexive.

# Definition

```math
\\mathbf{I} cos(θ / 2) - im sin(θ / 2) * mat(U)
```
"""
mutable struct RotationGate{D,T,GT<:AbstractBlock{D}} <: PrimitiveBlock{D}
    block::GT
    theta::T
    function RotationGate{D,T,GT}(block::GT, theta) where {D,T,GT<:AbstractBlock{D}}
        ishermitian(block) && isreflexive(block) ||
            throw(ArgumentError("Gate type $GT is not hermitian or not isreflexive."))
        new{D,T,GT}(block, T(theta))
    end
end

RotationGate(block::GT, theta::T) where {D,T,GT<:AbstractBlock{D}} =
    RotationGate{D,T,GT}(block, theta)
RotationGate(block::GT, theta::Integer) where {D,GT<:AbstractBlock{D}} =
    RotationGate{D,Float64,GT}(block, Float64(theta))
nqudits(rg::RotationGate) = nqudits(rg.block)

# bindings
"""
    Rx(theta)

Return a [`RotationGate`](@ref) on X axis.

# Example

```jldoctest; setup=:(using YaoBlocks)
julia> Rx(0.1)
rot(X, 0.1)
```
"""
Rx(theta) = RotationGate(X, theta)

"""
    Ry(theta)

Return a [`RotationGate`](@ref) on Y axis.

# Example

```jldoctest; setup=:(using YaoBlocks)
julia> Ry(0.1)
rot(Y, 0.1)
```
"""
Ry(theta) = RotationGate(Y, theta)

"""
    Rz(theta)

Return a [`RotationGate`](@ref) on Z axis.

# Example

```jldoctest; setup=:(using YaoBlocks)
julia> Rz(0.1)
rot(Z, 0.1)
```
"""
Rz(theta) = RotationGate(Z, theta)

"""
    rot(U, theta)

Return a [`RotationGate`](@ref) on U axis.
"""
rot(axis::AbstractBlock, theta) = RotationGate(axis, theta)

content(x::RotationGate) = x.block
chcontent(x::RotationGate, gen::AbstractBlock) = RotationGate(gen, x.theta)
# General definition
function mat(::Type{T}, R::RotationGate{D}) where {D,T}
    I = IMatrix{D^nqudits(R),T}()
    return I * cos(T(R.theta) / 2) - im * sin(T(R.theta) / 2) * mat(T, R.block)
end

# Specialized
mat(::Type{T}, R::RotationGate{1,<:Any,<:XGate}) where {T} =
    T[cos(R.theta / 2) -im*sin(R.theta / 2); -im*sin(R.theta / 2) cos(R.theta / 2)]
mat(::Type{T}, R::RotationGate{1,<:Any,<:YGate}) where {T} =
    T[cos(R.theta / 2) -sin(R.theta / 2); sin(R.theta / 2) cos(R.theta / 2)]
# mat(R::RotationGate{1, T, ZGate{Complex{T}}}) where T =
#     SMatrix{2, 2, Complex{T}}(cos(R.theta/2)-im*sin(R.theta/2), 0, 0, cos(R.theta/2)+im*sin(R.theta/2))

function _apply!(r::ArrayReg, rb::RotationGate)
    v0 = copy(r.state)
    _apply!(r, rb.block)
    # NOTE: we should not change register's memory address,
    # or batch operations may fail
    r.state .= -im * sin(rb.theta / 2) * r.state + cos(rb.theta / 2) * v0
    return r
end

# parametric interface
niparams(::Type{<:RotationGate}) = 1
getiparams(x::RotationGate) = x.theta
# no need to specify the type of param, Julia will try to do the conversion
setiparams!(r::RotationGate, param::Number) = (r.theta = param; r)
setiparams(r::RotationGate, param::Number) = RotationGate(r.block, param)

# fallback to matrix methods if it is not real
YaoBase.isunitary(r::RotationGate{D,<:Real}) where {D} = true

function YaoBase.isunitary(r::RotationGate)
    isreal(r.theta) && return true
    @warn "θ in RotationGate is not real, got θ=$(r.theta), fallback to matrix-based method"
    return isunitary(mat(r))
end

Base.adjoint(blk::RotationGate) = RotationGate(blk.block, -blk.theta)
Base.copy(R::RotationGate) = RotationGate(R.block, R.theta)
Base.:(==)(lhs::RotationGate{TA,GTA}, rhs::RotationGate{TB,GTB}) where {TA,TB,GTA,GTB} =
    false
Base.:(==)(lhs::RotationGate{TA,GT}, rhs::RotationGate{TB,GT}) where {TA,TB,GT} =
    lhs.theta == rhs.theta

cache_key(R::RotationGate) = R.theta

iparams_range(::RotationGate{D,T,GT}) where {D,T,GT} = ((zero(T), T(2 * pi)),)

occupied_locs(g::RotationGate) = occupied_locs(g.block)
