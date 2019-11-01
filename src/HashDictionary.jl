mutable struct HashDictionary{I,T} <: AbstractDictionary{I, T}
    values::Vector{T}
    indices::HashIndices{I}

    HashDictionary{I, T}(values::Vector{T}, indices::HashIndices{I}, ::Nothing) where {I, T} = new(values, indices)
end

"""
    HashDictionary{I, T}()

Construct an empty `HashDictionary` with index type `I` and element type `T`. This type of
dictionary uses hashes for fast lookup and insertion, and is both mutable and insertable.
(See `ismutable` and `isinsertable`).
"""
function HashDictionary{I, T}(; sizehint::Int = 16) where {I, T}
    indices = HashIndices{I}(; sizehint=sizehint)
    HashDictionary{I, T}(Vector{T}(undef, length(indices.slots)), indices, nothing)
end
HashDictionary{I}() where {I} = HashDictionary{I, Any}()
HashDictionary() = HashDictionary{Any}()

"""
    HashDictionary{I, T}(undef::UndefInitializer, indices)

Construct a `HashDictionary` with index type `I` and element type `T`. The container is
initialized with `keys` that match the values of `indices`, but the values are unintialized.
"""
function HashDictionary{I, T}(::UndefInitializer, indices) where {I, T} 
    return HashDictionary{I, T}(undef, HashIndices{I}(indices))
end

function HashDictionary{I, T}(::UndefInitializer, h::HashIndices{I}) where {I, T}
    return HashDictionary{I, T}(Vector{T}(undef, length(h.slots)), h, nothing)
end

function HashDictionary{I, T}(values, indices::HashIndices{I}) where {I, T}
    vals = Vector{T}(undef, length(indices.slots))
    d = HashDictionary{I, T}(vals, indices, nothing)

    @inbounds for (v, i) in zip(values, tokens(indices))
        vals[i] = v
    end

    return d
end

"""
    HashDictionary(values, indices)
    HashDictionary{I}(values, indices)
    HashDictionary{I, T}(values, indices)

Construct a `HashDictionary` with indices from `indices` and values from `values`, matched
in iteration order.
"""
function HashDictionary{I, T}(values, indices) where {I, T}
    iter_size = Base.IteratorSize(indices)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        d = HashDictionary{I, T}(; sizehint = length(indices))
    else
        d = HashDictionary{I, T}()
    end

    for (v, i) in zip(values, indices)
        insert!(d, v, i)
    end

    return d
end
HashDictionary{I}(values, indices) where {I} = HashDictionary{I, eltype(values)}(values, indices)
HashDictionary(values, indices) = HashDictionary{eltype(indices)}(values, indices)

Base.keys(d::HashDictionary) = d.indices
isinsertable(d::HashDictionary) = true
ismutable(d::HashDictionary) = true

@inline function Base.getindex(d::HashDictionary{I}, key::I) where {I}
    token = indextoken(d.indices, key)
    @boundscheck if token < 0
        throw(IndexError("HashDictionary has no index: $key"))
    end

    return @inbounds d.values[token]
end

@inline function Base.isassigned(d::HashDictionary{I}, key::I) where {I}
    token = indextoken(d.indices, key)
    if token < 0
        return false
    end

    return isassigned(d.values, token)
end

@inline function Base.setindex!(d::HashDictionary{I, T}, value::T, key::I) where {I, T}
    token = indextoken(d.indices, key)
    @boundscheck if token < 0
        throw(IndexError("HashDictionary has no index: $key"))
    end

    @inbounds d.values[token] = value
    return d
end

function Base.copy(d::HashDictionary{I, T}) where {I, T}
    return HashDictionary{I, T}(copy(d.values), copy(d.indices), nothing)
end

# Default for `similar` is `HashDictionary`, since it is most flexible
function Base.similar(::AbstractDictionary, ::Type{T}, h::HashIndices{I}) where {I, T}
    return HashDictionary{I, T}(undef, h)
end

function Base.empty(::HashDictionary, ::Type{I}, ::Type{T}) where {I, T}
    return HashDictionary{I, T}()
end

tokens(d::HashDictionary{I}) where {I} = HashTokens{I}(d.indices)
tokenized(::HashTokens, d::HashDictionary) = d.values

@propagate_inbounds _iterate(d::HashDictionary{T}, i::Int) where {T} = i > length(d.indices.inds) ? nothing : (d.values[i], i + 1)
function Base.iterate(d::HashDictionary)
    _iterate(d, skip_deleted_floor!(d.indices))
end
@propagate_inbounds Base.iterate(d::HashDictionary, i::Int) = _iterate(d, skip_deleted(d.indices, i))

function Base.insert!(d::HashDictionary{I, T}, value::T, i::I) where {I, T}
    token = -indextoken!(d.indices, d.values, i)

    if token < 0
        throw(IndexError("HashDictionary already contains index: $i"))
    else
        d.values = @inbounds _insert!(d.indices, d.values, i, value, token)
    end

    return d
end

function Base.empty!(d::HashDictionary)
    empty!(d.values)
    empty!(d.indices)
    return d
end

function Base.delete!(d::HashDictionary{I, T}, i::I) where {I, T}
    token = indextoken(d.indices, i)
    if token > 0
        _delete!(d.indices, token)
        isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), d.values, token-1)
    else
        throw(IndexError("HashIndices does not contain index: $i"))
    end
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
