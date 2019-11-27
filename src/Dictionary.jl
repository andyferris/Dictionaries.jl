"""
    Dictionary(indices, values)

Construct a `Dictionary <: AbstractDictionary` from two arbitrary Julia iterables, one
specifying the `indices` and one specifying the `values`. Lookup uses naive iteration.

If `indices` and `values` are `Vector`s, then the result is `isinsertable` and
`istokenizable`, making simple and flexible dictionaries using naive search that may be
optimal for small collections.
"""
struct Dictionary{I, T, Indices, Values} <: AbstractDictionary{I, T}
	indices::Indices
    values::Values
    
    @inline function Dictionary{I, T, Indices, Values}(indices, values) where {I, T, Indices, Values}
        @boundscheck if length(indices) != length(values)
            error("Dictinary indices and values inputs have different lengths")
        end
        return new(indices, values)
    end
end

Dictionary() = Dictionary{Any, Any}()
Dictionary{I}() where {I} = Dictionary{I, Any}()
Dictionary{I, T}() where {I, T} = Dictionary{I, T}(I[], T[])

Dictionary(inds, vals) = Dictionary{eltype(inds), eltype(vals), typeof(inds), typeof(vals)}(inds, vals)
Dictionary{I}(inds, vals) where {I} = Dictionary{I, eltype(vals), typeof(inds), typeof(vals)}(inds, vals)
Dictionary{I, T}(inds, vals) where {I, T} = Dictionary{I, T, typeof(inds), typeof(vals)}(inds, vals)


"""
    Dictionary(indices, undef::UndefInitializer)

Construct a `Dictionary` from an iterable of `indices`, where the values are
undefined/unitialized.
"""
Dictionary{I, T}(inds, ::UndefInitializer) where {I, T} = Dictionary{I, T}(inds, Vector{T}(undef, length(inds)))

"""
    Dictionary(dict::AbstractDictionary)

Construct a `Dictionary` copy of `dict` with the same keys and values.
"""
Dictionary(dict::AbstractDictionary) = Dictionary(keys(dict), dict)
Dictionary{I}(dict::AbstractDictionary) where {I} = Dictionary{I}(keys(dict), dict)
Dictionary{I, T}(dict::AbstractDictionary) where {I, T} = Dictionary{I, T}(keys(dict), dict)


function Base.keys(d::Dictionary{I}) where {I}
    return Indices{I}(d.indices)
end

@propagate_inbounds function Base.getindex(d::Dictionary{I, T}, i::I) where {I, T}
    for (k, v) in zip(d.indices, d.values)
        if isequal(k, i)
            return v::T
        end
    end
    throw(IndexError("Dictionary does not contain index: $i"))
end

## With Vectors they become settable, insertable and tokenizable
const VectorDictionary{I, T} = Dictionary{I, T, Vector{I}, Vector{T}}

# token interface
istokenizable(::VectorDictionary) = true

istokenassigned(d::VectorDictionary, t::Int) = isassigned(d.values, t)
@propagate_inbounds gettokenvalue(d::VectorDictionary{<:Any, T}, t::Int) where {T} = d.values[t]::T

# settable interface
issettable(::VectorDictionary) = true

@propagate_inbounds function settokenvalue!(d::VectorDictionary{<:Any, T}, t::Int, value::T) where {T}
    d.values[t] = value
    return d
end

Base.copy(d::VectorDictionary) = Dictionary(copy(d.indices), copy(d.values))

function Base.similar(inds::VectorIndices, ::Type{T}) where {T}
    return Dictionary(inds.inds, Vector{T}(undef, length(inds)))
end

# insertable interface
isinsertable(::VectorDictionary) = true

@propagate_inbounds function gettoken!(d::VectorDictionary{I}, i::I) where {I}
    (hadtoken, token) = gettoken!(Indices(d.indices), i)
    if !hadtoken
        resize!(d.values, length(d.values) + 1)
    end
    return (hadtoken, token)
end

@propagate_inbounds function deletetoken!(d::VectorDictionary, t::Int)
    deleteat!(d.indices, t)
    deleteat!(d.values, t)
    return d
end

function Base.empty!(d::VectorDictionary)
    empty!(d.indices)
    empty!(d.values)
    return d
end

function Base.empty(::VectorDictionary, ::Type{I}, ::Type{T}) where {I, T}
    return Dictionary(Vector{I}(), Vector{T}())
end

function Base.empty(::VectorDictionary, ::Type{I}) where {I}
    return Indices(Vector{I}())
end
