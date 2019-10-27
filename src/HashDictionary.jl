mutable struct HashDictionary{I,T} <: AbstractDictionary{I, T}
    values::Vector{T}
    indices::HashIndices{I}
end

HashDictionary{I, T}(; sizehint::Int = 16) where {I, T} = HashDictionary{I, T}(Vector{T}(undef, sizehint), HashIndices{I}(; sizehint=16))
HashDictionary{I}() where {I} = HashDictionary{I, Any}()
HashDictionary() = HashDictionary{Any}()

HashDictionary{I, T}(::UndefInitializer, h::HashIndices{I}) where {I, T} = HashDictionary{I, T}(Vector{T}(undef, length(h.slots)), h)
HashDictionary{I}(::UndefInitializer, h::HashIndices{I}) where {I} = HashDictionary{I, Any}(undef, h)
HashDictionary(::UndefInitializer, h::HashIndices{I}) where {I} = HashDictionary{I}(undef, h)

Base.keys(d::HashDictionary) = d.indices
insertable(d::HashDictionary) = true

@inline function Base.getindex(d::HashDictionary{I}, key::I) where {I}
    token = indextoken(d.indices, key)
    @boundscheck if token < 0
        throw(IndexError("HashDictionary has no index: $key"))
    end

    return @inbounds d.values[token]
end

@inline function Base.setindex!(d::HashDictionary{I, T}, value::T, key::I) where {I, T}
    token = indextoken(d.indices, key)
    @boundscheck if token < 0
        throw(IndexError("HashDictionary has no index: $key"))
    end

    @inbounds d.values[token] = value
    return d
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
    token = -indextoken!(d, i)

    if token < 0
        throw(IndexError("HashDictionary already contains index: $i"))
    else
        @inbounds _insert!(d.indices, d.values, i, -token)
        @inbounds d.values[-token] = value
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
