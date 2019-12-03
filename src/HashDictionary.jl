mutable struct HashDictionary{I,T} <: AbstractDictionary{I, T}
    indices::HashIndices{I}
    values::Vector{T}

    HashDictionary{I, T}(indices::HashIndices{I}, values::Vector{T}, ::Nothing) where {I, T} = new(indices, values)
end

"""
    HashDictionary{I, T}()

Construct an empty `HashDictionary` with index type `I` and element type `T`. This type of
dictionary uses hashes for fast lookup and insertion, and is both mutable and insertable.
(See `issettable` and `isinsertable`).
"""
function HashDictionary{I, T}(; sizehint::Int = 16) where {I, T}
    indices = HashIndices{I}(; sizehint=sizehint)
    HashDictionary{I, T}(indices, Vector{T}(undef, length(indices.slots)), nothing)
end
HashDictionary{I}() where {I} = HashDictionary{I, Any}()
HashDictionary() = HashDictionary{Any}()

"""
    HashDictionary{I, T}(indices, undef::UndefInitializer)

Construct a `HashDictionary` with index type `I` and element type `T`. The container is
initialized with `keys` that match the values of `indices`, but the values are unintialized.
"""
function HashDictionary{I, T}(indices, ::UndefInitializer) where {I, T} 
    return HashDictionary{I, T}(HashIndices{I}(indices), undef)
end

function HashDictionary{I, T}(h::HashIndices{I}, ::UndefInitializer) where {I, T}
    return HashDictionary{I, T}(h, Vector{T}(undef, length(h.slots)), nothing)
end

function HashDictionary{I, T}(indices::HashIndices{I}, values) where {I, T}
    vals = Vector{T}(undef, length(indices.slots))
    d = HashDictionary{I, T}(indices, vals, nothing)

    @inbounds for (i, v) in zip(tokens(indices), values)
        vals[i] = v
    end

    return d
end

"""
    HashDictionary(indices, values)
    HashDictionary{I}(indices, values)
    HashDictionary{I, T}(indices, values)

Construct a `HashDictionary` with indices from `indices` and values from `values`, matched
in iteration order.
"""
function HashDictionary{I, T}(indices, values) where {I, T}
    iter_size = Base.IteratorSize(indices)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        d = HashDictionary{I, T}(; sizehint = length(indices)*2)
    else
        d = HashDictionary{I, T}()
    end

    for (i, v) in zip(indices, values)
        insert!(d, i, v)
    end

    return d
end
function HashDictionary{I}(indices, values) where {I}
    if Base.IteratorEltype(values) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnkown
        values = collect(values)
    end

    return HashDictionary{I, eltype(values)}(indices, values)
end

function HashDictionary(indices, values)
    if Base.IteratorEltype(indices) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnkown
        indices = collect(indices)
    end

    return HashDictionary{eltype(indices)}(indices, values)
end

"""
    HashDictionary(dict::AbstractDictionary)
    HashDictionary{I}(dict::AbstractDictionary)
    HashDictionary{I, T}(dict::AbstractDictionary)

Construct a copy of `dict` with the same keys and values.

(For copying an `AbstractDict` or other iterable of `Pair`s, see `dictionary`).
"""
HashDictionary(dict::AbstractDictionary) = HashDictionary(keys(dict), dict)
HashDictionary{I}(dict::AbstractDictionary) where {I} = HashDictionary{I}(keys(dict), dict)
HashDictionary{I, T}(dict::AbstractDictionary) where {I, T} = HashDictionary{I, T}(keys(dict), dict)

"""
    dictionary(iter)

Construct a new `AbstractDictionary` from an iterable `iter` of key-value `Pair`s. The
default container type is `HashDictionary`.
"""
function dictionary(iter)
    if Base.IteratorEltype(iter) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnkown
        iter = collect(iter)
    end
    _dictionary(eltype(iter), iter)
end

dictionary(p1::Pair, p2::Pair...) = dictionary((p1, p2...))

function _dictionary(::Type{Pair{I, T}}, iter) where {I, T}
    iter_size = Base.IteratorSize(iter)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        d = HashDictionary{I, T}(; sizehint = length(iter)*2)
    else
        d = HashDictionary{I, T}()
    end

    for (i, v) in iter
        insert!(d, i, v)
    end

    return d
end

## Implementation

Base.keys(d::HashDictionary) = d.indices
isinsertable(d::HashDictionary) = true
issettable(d::HashDictionary) = true

@propagate_inbounds function gettoken(d::HashDictionary{I}, i::I) where {I}
    return gettoken(keys(d), i)
end

@inline function gettokenvalue(d::HashDictionary, token)
    return @inbounds d.values[token]
end

function istokenassigned(d::HashDictionary, token)
    return isassigned(d.values, token)
end

@inline function settokenvalue!(d::HashDictionary{I, T}, token, value::T) where {I, T}
    @inbounds d.values[token] = value
    return d
end

function gettoken!(d::HashDictionary{T}, key::T) where {T}
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

function Base.copy(d::HashDictionary{I, T}) where {I, T}
    return HashDictionary{I, T}(d.indices, copy(d.values), nothing)
end

tokenized(d::HashDictionary) = d.values

function Base.empty!(d::HashDictionary)
    empty!(d.indices)
    empty!(d.values)
    resize!(d.values, length(keys(d).slots))
    return d
end

function deletetoken!(d::HashDictionary{I, T}, token) where {I, T}
    deletetoken!(keys(d), token)
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), d.values, token-1)
    return d
end

function Base.sizehint!(d::HashDictionary, sz::Int)
    _sizehint!(d.indices, d.values, sz)
    return d
end

function Base.rehash!(d::HashDictionary, newsz::Int = length(d.inds))
    _rehash!(d.indices, d.values, newsz)
    return d
end

Base.filter!(pred, d::HashDictionary) = Base.unsafe_filter!(pred, d)

# `HashDictionary` is the default mutable AbstractDictionary
# If given some other index type, create a new `HashIndices` copy of the indices
function Base.similar(indices::AbstractIndices{I}, ::Type{T}) where {I, T}
    return similar(HashIndices{I}(indices), T)
end

# For `HashIndices` we don't copy the indices, we allow the `keys` to remain identical (`===`)
function Base.similar(indices::HashIndices{I}, ::Type{T}) where {I, T}
    return HashDictionary{I, T}(indices, undef)
end

# `HashDictionary` is the default insertable AbstractDictionary
function Base.empty(::AbstractDictionary, ::Type{I}, ::Type{T}) where {I, T}
    return HashDictionary{I, T}()
end
