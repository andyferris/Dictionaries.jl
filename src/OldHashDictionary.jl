mutable struct OldHashDictionary{I,T} <: AbstractDictionary{I, T}
    indices::OldHashIndices{I}
    values::Vector{T}

    OldHashDictionary{I, T}(indices::OldHashIndices{I}, values::Vector{T}, ::Nothing) where {I, T} = new(indices, values)
end

"""
    OldHashDictionary{I, T}()

Construct an empty `OldHashDictionary` with index type `I` and element type `T`. This type of
dictionary uses hashes for fast lookup and insertion, and is both mutable and insertable.
(See `issettable` and `isinsertable`).
"""
function OldHashDictionary{I, T}(; sizehint::Int = 16) where {I, T}
    indices = OldHashIndices{I}(; sizehint=sizehint)
    OldHashDictionary{I, T}(indices, Vector{T}(undef, length(indices.slots)), nothing)
end
OldHashDictionary{I}() where {I} = OldHashDictionary{I, Any}()
OldHashDictionary() = OldHashDictionary{Any}()

"""
    OldHashDictionary{I, T}(indices, undef::UndefInitializer)

Construct a `OldHashDictionary` with index type `I` and element type `T`. The container is
initialized with `keys` that match the values of `indices`, but the values are unintialized.
"""
function OldHashDictionary{I, T}(indices, ::UndefInitializer) where {I, T} 
    return OldHashDictionary{I, T}(OldHashIndices{I}(indices), undef)
end

function OldHashDictionary{I, T}(h::OldHashIndices{I}, ::UndefInitializer) where {I, T}
    return OldHashDictionary{I, T}(h, Vector{T}(undef, length(h.slots)), nothing)
end

function OldHashDictionary{I, T}(indices::OldHashIndices{I}, values) where {I, T}
    vals = Vector{T}(undef, length(indices.slots))
    d = OldHashDictionary{I, T}(indices, vals, nothing)

    @inbounds for (i, v) in zip(tokens(indices), values)
        vals[i] = v
    end

    return d
end

"""
    OldHashDictionary(indices, values)
    OldHashDictionary{I}(indices, values)
    OldHashDictionary{I, T}(indices, values)

Construct a `OldHashDictionary` with indices from `indices` and values from `values`, matched
in iteration order.
"""
function OldHashDictionary{I, T}(indices, values) where {I, T}
    iter_size = Base.IteratorSize(indices)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        d = OldHashDictionary{I, T}(; sizehint = length(indices)*2)
    else
        d = OldHashDictionary{I, T}()
    end

    for (i, v) in zip(indices, values)
        insert!(d, i, v)
    end

    return d
end
function OldHashDictionary{I}(indices, values) where {I}
    if Base.IteratorEltype(values) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnkown
        values = collect(values)
    end

    return OldHashDictionary{I, eltype(values)}(indices, values)
end

function OldHashDictionary(indices, values)
    if Base.IteratorEltype(indices) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnkown
        indices = collect(indices)
    end

    return OldHashDictionary{eltype(indices)}(indices, values)
end

"""
    OldHashDictionary(dict::AbstractDictionary)
    OldHashDictionary{I}(dict::AbstractDictionary)
    OldHashDictionary{I, T}(dict::AbstractDictionary)

Construct a copy of `dict` with the same keys and values.
(For copying an `AbstractDict` or other iterable of `Pair`s, see `dictionary`).
"""
OldHashDictionary(dict::AbstractDictionary) = OldHashDictionary(keys(dict), dict)
OldHashDictionary{I}(dict::AbstractDictionary) where {I} = OldHashDictionary{I}(keys(dict), dict)
OldHashDictionary{I, T}(dict::AbstractDictionary) where {I, T} = OldHashDictionary{I, T}(keys(dict), dict)

## Implementation

Base.keys(d::OldHashDictionary) = d.indices
isinsertable(d::OldHashDictionary) = true
issettable(d::OldHashDictionary) = true

@propagate_inbounds function gettoken(d::OldHashDictionary{I}, i::I) where {I}
    return gettoken(keys(d), i)
end

@inline function gettokenvalue(d::OldHashDictionary, token)
    return @inbounds d.values[token]
end

function istokenassigned(d::OldHashDictionary, token)
    return isassigned(d.values, token)
end

@inline function settokenvalue!(d::OldHashDictionary{I, T}, token, value::T) where {I, T}
    @inbounds d.values[token] = value
    return d
end

function gettoken!(d::OldHashDictionary{T}, key::T) where {T}
    indices = keys(d)
    (token, values) = _gettoken!(indices, d.values, key)
    if token < 0
        (token, values) = _insert!(indices, values, key, -token)
        d.values = values
        return (false, token)
    else
        d.values = values
        return (true, token)
    end 
end

function Base.copy(d::OldHashDictionary{I, T}, ::Type{I}, ::Type{T}) where {I, T}
    return OldHashDictionary{I, T}(d.indices, copy(d.values), nothing)
end

tokenized(d::OldHashDictionary) = d.values

function Base.empty!(d::OldHashDictionary)
    empty!(d.indices)
    empty!(d.values)
    resize!(d.values, length(keys(d).slots))
    return d
end

function deletetoken!(d::OldHashDictionary{I, T}, token) where {I, T}
    deletetoken!(keys(d), token)
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), d.values, token-1)
    return d
end

function Base.sizehint!(d::OldHashDictionary, sz::Int)
    d.values = _sizehint!(d.indices, d.values, sz)
    return d
end

function Base.rehash!(d::OldHashDictionary, newsz::Int = length(d.inds))
    _rehash!(d.indices, d.values, newsz)
    return d
end

Base.filter!(pred, d::OldHashDictionary) = Base.unsafe_filter!(pred, d)

# For `OldHashIndices` we don't copy the indices, we allow the `keys` to remain identical (`===`)
function Base.similar(indices::OldHashIndices{I}, ::Type{T}) where {I, T}
    return OldHashDictionary{I, T}(indices, undef)
end

function Base.empty(indices::OldHashIndices, ::Type{I}, ::Type{T}) where {I, T}
    return OldHashDictionary{I, T}()
end