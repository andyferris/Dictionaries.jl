
mutable struct UnorderedDictionary{I,T} <: AbstractDictionary{I, T}
    indices::UnorderedIndices{I}
    values::Vector{T}

    UnorderedDictionary{I, T}(indices::UnorderedIndices{I}, values::Vector{T}, ::Nothing) where {I, T} = new(indices, values)
end

"""
    UnorderedDictionary{I, T}()

Construct an empty `UnorderedDictionary` with index type `I` and element type `T`. This type of
dictionary uses hashes for fast lookup and insertion, and is both mutable and insertable.
(See `issettable` and `isinsertable`). Unlike `Dictionary`, the order of elements
is undefined (depending on the implementation of `hash` and the history of the collection).
"""
function UnorderedDictionary{I, T}(; sizehint::Int = 16) where {I, T}
    indices = UnorderedIndices{I}(; sizehint=sizehint)
    UnorderedDictionary{I, T}(indices, Vector{T}(undef, length(indices.slots)), nothing)
end
UnorderedDictionary{I}() where {I} = UnorderedDictionary{I, Any}()
UnorderedDictionary() = UnorderedDictionary{Any}()

"""
    UnorderedDictionary{I, T}(indices, undef::UndefInitializer)

Construct a `UnorderedDictionary` with index type `I` and element type `T`. The container is
initialized with `keys` that match the values of `indices`, but the values are uninitialized.
"""
function UnorderedDictionary{I, T}(indices, ::UndefInitializer) where {I, T} 
    return UnorderedDictionary{I, T}(UnorderedIndices{I}(indices), undef)
end

function UnorderedDictionary{I, T}(h::UnorderedIndices{I}, ::UndefInitializer) where {I, T}
    return UnorderedDictionary{I, T}(h, Vector{T}(undef, length(h.slots)), nothing)
end

function UnorderedDictionary{I, T}(indices::UnorderedIndices{I}, values) where {I, T}
    vals = Vector{T}(undef, length(indices.slots))
    d = UnorderedDictionary{I, T}(indices, vals, nothing)

    @inbounds for (i, v) in zip(tokens(indices), values)
        vals[i] = v
    end

    return d
end

"""
    UnorderedDictionary(indices, values)
    UnorderedDictionary{I}(indices, values)
    UnorderedDictionary{I, T}(indices, values)

Construct a `UnorderedDictionary` with indices from `indices` and values from `values`, matched
in iteration order.
"""
function UnorderedDictionary{I, T}(indices, values) where {I, T}
    iter_size = Base.IteratorSize(indices)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        d = UnorderedDictionary{I, T}(; sizehint = length(indices)*2)
    else
        d = UnorderedDictionary{I, T}()
    end

    for (i, v) in zip(indices, values)
        insert!(d, i, v)
    end

    return d
end
function UnorderedDictionary{I}(indices, values) where {I}
    if Base.IteratorEltype(values) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnknown
        values = collect(values)
    end

    return UnorderedDictionary{I, eltype(values)}(indices, values)
end

function UnorderedDictionary(indices, values)
    if Base.IteratorEltype(indices) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnknown
        indices = collect(indices)
    end

    return UnorderedDictionary{eltype(indices)}(indices, values)
end

"""
UnorderedDictionary(indexable)

Construct a `UnorderedDictionary` from an indexable container `indexable` with the same `keys` and
`values`, equivalent to `UnorderedDictionary(keys(indexable), values(indexable))`. Note that
`indexable` may not be copied.
"""
UnorderedDictionary(indexable) = UnorderedDictionary(keys(indexable), values(indexable))
UnorderedDictionary{I}(indexable) where {I} = UnorderedDictionary{I}(keys(indexable), values(indexable))
UnorderedDictionary{I, T}(indexable) where {I, T} = UnorderedDictionary{I, T}(keys(indexable), values(indexable))

UnorderedDictionary{I, T}(indexable::UnorderedDictionary) where {I, T} = UnorderedDictionary{I, T,}(convert(UnorderedIndices{I}, keys(indexable)), convert(Vector{T}, indexable.values), nothing)

function Base.convert(::Type{UnorderedDictionary{I, T}}, dict::UnorderedDictionary) where {I, T}
    return UnorderedDictionary{I, T}(convert(UnorderedIndices{I}, dict.indices), convert(Vector{T}, dict.values), nothing)
end
Base.convert(::Type{T}, dict::T) where {T<:UnorderedDictionary} = dict

## Implementation

Base.keys(d::UnorderedDictionary) = d.indices
isinsertable(d::UnorderedDictionary) = true
issettable(d::UnorderedDictionary) = true

@propagate_inbounds function gettoken(d::UnorderedDictionary{I}, i::I) where {I}
    return gettoken(keys(d), i)
end

@inline function gettokenvalue(d::UnorderedDictionary, token)
    return @inbounds d.values[token]
end

function istokenassigned(d::UnorderedDictionary, token)
    return isassigned(d.values, token)
end

@inline function settokenvalue!(d::UnorderedDictionary{I, T}, token, value::T) where {I, T}
    @inbounds d.values[token] = value
    return d
end

function gettoken!(d::UnorderedDictionary{T}, key::T) where {T}
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

function Base.copy(d::UnorderedDictionary{I, T}) where {I, T}
    return UnorderedDictionary{I, T}(copy(d.indices), copy(d.values), nothing)
end

tokenized(d::UnorderedDictionary) = d.values

function Base.empty!(d::UnorderedDictionary)
    empty!(d.indices)
    empty!(d.values)
    resize!(d.values, length(keys(d).slots))
    return d
end

function deletetoken!(d::UnorderedDictionary{I, T}, token) where {I, T}
    deletetoken!(keys(d), token)
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), d.values, token-1)
    return d
end

function Base.sizehint!(d::UnorderedDictionary, sz::Int)
    d.values = _sizehint!(d.indices, d.values, sz)
    return d
end

function Base.rehash!(d::UnorderedDictionary, newsz::Int = length(d.indices))
    _rehash!(d.indices, d.values, newsz)
    return d
end

Base.filter!(pred, d::UnorderedDictionary) = Base.unsafe_filter!(pred, d)

function Base.similar(indices::UnorderedIndices{I}, ::Type{T}) where {I, T}
    return UnorderedDictionary{I, T}(indices, undef)
end

empty_type(::Type{<:UnorderedDictionary}, ::Type{I}, ::Type{T}) where {I, T} = UnorderedDictionary{I, T}
empty_type(::Type{<:UnorderedIndices}, ::Type{I}, ::Type{T}) where {I, T} = UnorderedDictionary{I, T}
