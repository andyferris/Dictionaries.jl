mutable struct HashMap{I,T} <: AbstractMap{I, T}
    values::Vector{T}
    indices::HashIndices{I}
end

HashMap{I, T}(; sizehint::Int = 16) where {I, T} = HashMap{I, T}(Vector{T}(undef, sizehint), HashIndices{I}(; sizehint=16))
HashMap{I}() where {I} = HashMap{I, Any}()
HashMap() = HashMap{Any}()

HashMap{I, T}(::UndefInitializer, h::HashIndices{I}) where {I, T} = HashMap{I, T}(Vector{T}(undef, length(h.slots)), h)
HashMap{I}(::UndefInitializer, h::HashIndices{I}) where {I} = HashMap{I, Any}(undef, h)
HashMap(::UndefInitializer, h::HashIndices{I}) where {I} = HashMap{I}(undef, h)

Base.keys(m::HashMap) = m.indices
insertable(m::HashMap) = true

@inline function Base.getindex(m::HashMap{I}, key::I) where {I}
    token = indextoken(m.indices, key)
    @boundscheck if token < 0
        throw(IndexError("HashMap has no key: $key"))
    end

    return @inbounds m.values[token]
end

@inline function Base.setindex!(m::HashMap{I, T}, value::T, key::I) where {I, T}
    token = indextoken(m.indices, key)
    @boundscheck if token < 0
        throw(IndexError("HashMap has no key: $key"))
    end

    @inbounds m.values[token] = value
    return m
end

# Default for `similar` is `HashMap`, since it is most flexible
function Base.similar(::AbstractMap, ::Type{T}, h::HashIndices{I}) where {I, T}
    return HashMap{I, T}(undef, h)
end

function Base.empty(::HashMap, ::Type{I}, ::Type{T}) where {I, T}
    return HashMap{I, T}()
end

tokens(m::HashMap{I}) where {I} = HashTokens{I}(m.indices)
tokenized(::HashTokens, m::HashMap) = m.values

@propagate_inbounds _iterate(m::HashMap{T}, i::Int) where {T} = i > length(m.indices.inds) ? nothing : (m.values[i], i + 1)
function Base.iterate(m::HashMap)
    _iterate(m, skip_deleted_floor!(m.indices))
end
@propagate_inbounds Base.iterate(m::HashMap, i::Int) = _iterate(m, skip_deleted(m.indices, i))

function Base.insert!(m::HashMap{I, T}, value::T, i::I) where {I, T}
    token = -indextoken!(m, i)

    if token < 0
        throw(IndexError("HashMap already contains index: $i"))
    else
        @inbounds _insert!(m.indices, m.values, i, -token)
        @inbounds m.values[-token] = value
    end

    return m
end

function Base.empty!(m::HashMap)
    empty!(m.values)
    empty!(m.indices)
    return m
end

function Base.delete!(m::HashMap{I, T}, i::I) where {I, T}
    token = indextoken(m.indices, i)
    if token > 0
        _delete!(m.indices, token)
        isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), m.values, token-1)
    else
        throw(IndexError("HashIndices does not contain index: $i"))
    end
    return m
end

function Base.sizehint!(m::HashMap, sz::Int)
    _sizehint!(m.indices, m.values, sz)
    return m
end

function Base.rehash!(m::HashMap, newsz::Int = length(m.inds))
    _rehash!(m.indices, m.values, newsz)
    return m
end
