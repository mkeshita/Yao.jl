using LinearAlgebra

export Scale, factor

"""
    Scale{S <: Union{Number, Val}, D, BT <: AbstractBlock{D}} <: TagBlock{BT, D}

`Scale` a block with scalar. it can be either a `Number` or a compile time `Val`.

# Example

```jldoctest; setup=:(using YaoBlocks)
julia> 2 * X
[scale: 2] X

julia> im * Z
[+im] Z

julia> -im * Z
[-im] Z

julia> -Z
[-] Z
```
"""
mutable struct Scale{S<:Union{Number,Val},D,BT<:AbstractBlock{D}} <: TagBlock{BT,D}
    alpha::S
    content::BT
end

content(x::Scale) = x.content
factor(x::Scale{<:Number}) = x.alpha
factor(x::Scale{Val{X}}) where {X} = X

# parameter interface
getiparams(s::Scale{<:Number}) = (factor(s),)
setiparams(s::Scale{<:Number}, alpha::Number) = Scale(alpha, s.content)
setiparams!(s::Scale{T1}, alpha::T2) where {T1<:Number, T2<:Number} = (s.alpha = T1(alpha); s)

Base.copy(x::Scale) = Scale(x.alpha, copy(x.content))
Base.adjoint(x::Scale{<:Number}) = Scale(adjoint(x.alpha), adjoint(content(x)))
Base.adjoint(x::Scale{Val{X}}) where {X} = Scale(Val(adjoint(X)), adjoint(content(x)))

YaoBase.ishermitian(s::Scale) =
    (ishermitian(s |> content) && ishermitian(s |> factor)) || ishermitian(mat(s))
YaoBase.isunitary(s::Scale) =
    (isunitary(s |> content) && isunitary(s |> factor)) || isunitary(mat(s))
YaoBase.isreflexive(s::Scale) =
    (isreflexive(s |> content) && isreflexive(s |> factor)) || isreflexive(mat(s))
YaoBase.iscommute(x::Scale, y::Scale) = iscommute(x |> content, y |> content)
YaoBase.iscommute(x::AbstractBlock, y::Scale) = iscommute(x, y |> content)
YaoBase.iscommute(x::Scale, y::AbstractBlock) = iscommute(x |> content, y)

Base.:(==)(x::Scale, y::Scale) = (factor(x) == factor(y)) && (content(x) == content(y))

chsubblocks(x::Scale, blk::AbstractBlock) = Scale(x.alpha, blk)
cache_key(x::Scale) = (factor(x), cache_key(content(x)))

mat(::Type{T}, x::Scale) where {T} = T(x.alpha) * mat(T, content(x))
mat(::Type{T}, x::Scale{Val{S}}) where {T,S} = T(S) * mat(T, content(x))

function _apply!(r::AbstractArrayReg, x::Scale{S}) where {S}
    _apply!(r, content(x))
    regscale!(r, factor(x))
    return r
end
