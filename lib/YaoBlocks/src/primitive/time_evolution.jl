using ExponentialUtilities, YaoArrayRegister

export TimeEvolution, time_evolve

"""
    TimeEvolution{D, TT, GT} <: PrimitiveBlock{D}

TimeEvolution, where GT is block type. input matrix should be hermitian.

!!!note:
    `TimeEvolution` contructor check hermicity of the input block by default, but sometimes it can be slow. Turn off the check manually by specifying optional parameter `check_hermicity = false`.
"""
mutable struct TimeEvolution{D,Tt,HT<:AbstractBlock{D}} <: PrimitiveBlock{D}
    H::HT
    dt::Tt
    tol::Float64

    function TimeEvolution(
        H::TH,
        dt::Tt;
        tol::Real = 1e-7,
        check_hermicity::Bool = true,
    ) where {D,Tt,TH<:AbstractBlock{D}}
        (check_hermicity && !ishermitian(H)) &&
            error("Time evolution Hamiltonian has to be a Hermitian")
        return new{D,Tt,TH}(H, dt, Float64(tol))
    end
end
nqudits(te::TimeEvolution) = nqudits(te.H)

"""
    TimeEvolution(H, dt[; tol::Real=1e-7])

Create a [`TimeEvolution`](@ref) block with Hamiltonian `H` and time step `dt`. The
`TimeEvolution` block will use Krylove based `expv` to calculate time propagation.

Optional keywords are tolerance `tol` (default is `1e-7`)
`TimeEvolution` block can also be used for
[imaginary time evolution](http://large.stanford.edu/courses/2008/ph372/behroozi2/) if dt is complex.
"""
time_evolve(M::AbstractBlock, dt; kwargs...) = TimeEvolution(M, dt; kwargs...)
time_evolve(dt; kwargs...) = @λ(M -> time_evolve(M, dt; kwargs...))

content(te::TimeEvolution) = te.H
chcontent(te::TimeEvolution, blk::AbstractBlock) = time_evolve(blk, te.dt; tol = te.tol)

function mat(::Type{T}, te::TimeEvolution) where {T}
    return exp(-im * T(te.dt) * Matrix(mat(T, te.H)))
end

struct BlockMap{T,GT<:AbstractBlock} <: AbstractArray{T,2}
    block::GT
    BlockMap(::Type{T}, block::GT) where {T,GT<:AbstractBlock} = new{T,GT}(block)
end

Base.size(bm::BlockMap{T,GT}, i::Int) where {T,D,GT<:AbstractBlock{D}} =
    0 < i <= 2 ? D^nqudits(bm.block) : DimensionMismatch("")
Base.size(bm::BlockMap{T,GT}) where {T,D,GT<:AbstractBlock{D}} = (L = D^nqudits(bm.block); (L, L))
LinearAlgebra.ishermitian(bm::BlockMap) = ishermitian(bm.block)

function LinearAlgebra.mul!(y::AbstractVector, A::BlockMap{T,GT}, x::AbstractVector) where {T,D,GT<:AbstractBlock{D}}
    copyto!(y, x)
    apply!(ArrayReg{D}(y), A.block)
    return y
end

function _apply!(reg::AbstractArrayReg{D,T}, te::TimeEvolution) where {D,T}
    st = state(reg)
    dt = real(te.dt) == 0 ? imag(te.dt) : -im * te.dt
    A = BlockMap(T, te.H)
    @inbounds for j = 1:size(st, 2)
        v = view(st, :, j)
        Ks = arnoldi(A, v; tol = te.tol, ishermitian = true, opnorm = 1.0)
        expv!(v, dt, Ks)
    end
    return reg
end

cache_key(te::TimeEvolution) = (te.dt, cache_key(te.H))

# parametric interface
niparams(::Type{<:TimeEvolution}) = 1
getiparams(x::TimeEvolution) = x.dt
setiparams!(r::TimeEvolution, param::Number) = (r.dt = param; r)
setiparams(r::TimeEvolution, param::Number) =
    TimeEvolution(r.H, param; tol = r.tol, check_hermicity = false)

function Base.:(==)(lhs::TimeEvolution, rhs::TimeEvolution)
    return lhs.H == rhs.H && lhs.dt == rhs.dt
end

function Base.adjoint(te::TimeEvolution)
    return TimeEvolution(te.H, -adjoint(te.dt); tol = te.tol)
end
Base.copy(te::TimeEvolution) = TimeEvolution(te.H, te.dt, tol = te.tol)

function YaoBase.isunitary(te::TimeEvolution)
    iszero(imag(te.dt)) || return false
    return true
end

iparams_range(::TimeEvolution{D,T}) where {D,T} = ((typemin(T), typemax(T)),)