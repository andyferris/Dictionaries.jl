"""
    ArrayDictionary(indices, values)

Construct an `ArrayDictionary <: AbstractDictionary` from two arbitrary Julia iterables, one
specifying the `indices` and one specifying the `values`. Lookup uses naive iteration.

If `indices` and `values` are `Vector`s, then the result is `isinsertable` and
`istokenizable`, making simple and flexible dictionaries using naive search that may be
optimal for small collections.
"""
struct ArrayDictionary{I, T, Inds <: ArrayIndices{I}, Vals <: AbstractArray{T}} <: AbstractDictionary{I, T}
    indices::Inds
    values::Vals
    
    @inline function ArrayDictionary{I, T, Indices, Values}(indices::Indices, values::Values) where {I, T, Indices <: ArrayIndices{I}, Values <: AbstractArray{T}}
        @boundscheck if LinearIndices(parent(indices)) != LinearIndices(values)
            error("Dictinary indices and values inputs do not match")
        end
        return new(indices, values)
    end
end

"""
    ArrayDictionary{I,T}()

Construct an `ArrayDictionary` from empty `Vector`s, with `I` and `T` default to `Any`.
"""
@propagate_inbounds ArrayDictionary() = ArrayDictionary{Any, Any}([], [])
@propagate_inbounds ArrayDictionary{I}() where {I} = ArrayDictionary{I, Any}(I[], [])
@propagate_inbounds ArrayDictionary{I, T}() where {I, T} = ArrayDictionary{I, T}(I[], T[])

@propagate_inbounds ArrayDictionary(inds, vals) = ArrayDictionary(ArrayIndices(inds), vals)
@propagate_inbounds ArrayDictionary{I}(inds, vals) where {I} = ArrayDictionary{I}(ArrayIndices{I}(inds), vals)
@propagate_inbounds ArrayDictionary{I, T}(inds, vals) where {I, T} = ArrayDictionary{I, T}(ArrayIndices{I}(inds), vals)

@propagate_inbounds ArrayDictionary(inds::ArrayIndices, vals) = ArrayDictionary(inds, collect(vals))
@propagate_inbounds ArrayDictionary{I}(inds::ArrayIndices{I}, vals) where {I} = ArrayDictionary{I}(inds, collect(vals))
@propagate_inbounds ArrayDictionary{I, T}(inds::ArrayIndices{I}, vals) where {I, T} = ArrayDictionary{I, T}(inds, collect(T, vals))

@propagate_inbounds ArrayDictionary(inds::ArrayIndices, vals::AbstractArray) = ArrayDictionary{eltype(inds), eltype(vals)}(inds, vals)
@propagate_inbounds ArrayDictionary{I}(inds::ArrayIndices{I}, vals::AbstractArray) where {I} = ArrayDictionary{I, eltype(vals)}(inds, vals)

@propagate_inbounds ArrayDictionary{I,T}(inds::ArrayIndices{I}, vals::AbstractArray) where {I,T} = ArrayDictionary{I,T}(inds, convert(AbstractArray{T}, vals))
@propagate_inbounds ArrayDictionary{I,T}(inds::ArrayIndices{I}, vals::AbstractArray{T}) where {I,T} = ArrayDictionary{I,T,typeof(inds),typeof(vals)}(inds, vals)

@propagate_inbounds ArrayDictionary{I,T,Inds,Vals}(inds::AbstractArray, vals::AbstractArray{T}) where {I,T,Inds,Vals} = ArrayDictionary{I,T,Inds,Vals}(Inds(inds), vals)

"""
    ArrayDictionary(indices, undef::UndefInitializer)

Construct a `ArrayDictionary` from an iterable of `indices`, where the values are
undefined/uninitialized.
"""
@propagate_inbounds ArrayDictionary{I, T}(inds, ::UndefInitializer) where {I, T} = ArrayDictionary{I, T}(ArrayIndices{I}(inds), undef)
@propagate_inbounds ArrayDictionary{I, T}(inds::ArrayIndices{I}, ::UndefInitializer) where {I, T} = ArrayDictionary{I, T}(inds, similar(parent(inds), T))

"""
    ArrayDictionary(indexable)

Construct a `ArrayDictionary` from an indexable container `indexable` with the same `keys` and
`values`, equivalent to `ArrayDictionary(keys(indexable), values(indexable))`. Note that
`indexable` may not be copied.
"""
ArrayDictionary(indexable) = ArrayDictionary(keys(indexable), values(indexable))
ArrayDictionary{I}(indexable) where {I} = ArrayDictionary{I}(keys(indexable), values(indexable))
ArrayDictionary{I, T}(indexable) where {I, T} = ArrayDictionary{I, T}(keys(indexable), values(indexable))

ArrayDictionary{I, T}(indexable::ArrayDictionary) where {I, T} = ArrayDictionary{I, T, ArrayIndices{I}, Vector{T}}(convert(ArrayIndices{I}, keys(indexable)), convert(Vector{T}, indexable.values))

Base.parent(d::ArrayDictionary) = getfield(d, :values)

function Base.keys(d::ArrayDictionary{I}) where {I}
    return getfield(d, :indices)
end

# token interface
istokenizable(::ArrayDictionary) = true
istokenassigned(d::ArrayDictionary, t::Int) = isassigned(parent(d), t)
@propagate_inbounds gettokenvalue(d::ArrayDictionary, t::Int) = parent(d)[t]

tokenized(dict::ArrayDictionary) = parent(dict)

# settable interface
issettable(::ArrayDictionary) = true # Need an array trait for this...

@propagate_inbounds function settokenvalue!(d::ArrayDictionary{<:Any, T}, t::Int, value::T) where {T}
    parent(d)[t] = value
    return d
end

function Base.similar(inds::ArrayIndices, ::Type{T}) where {T}
    return ArrayDictionary(inds, similar(parent(inds), T))
end

Base.copy(dict::ArrayDictionary) = ArrayDictionary(copy(dict.indices), copy(dict.values))

# insertable interface
isinsertable(::ArrayDictionary) = true # Need an array trait for this...

@propagate_inbounds function gettoken!(d::ArrayDictionary{I}, i::I) where {I}
    gettoken!(keys(d), i, (parent(d),))
end

@propagate_inbounds function deletetoken!(d::ArrayDictionary, t::Int)
    deletetoken!(keys(d), t)
    deleteat!(parent(d), t)
    return d
end

function Base.empty!(d::ArrayDictionary)
    empty!(keys(d), (parent(d),))
    return d
end

empty_type(::Type{<:ArrayDictionary}, ::Type{I}, ::Type{T}) where {I, T} = ArrayDictionary{I, T, ArrayIndices{I, Vector{I}}, Vector{T}}

function Base.sort!(dict::ArrayDictionary; kwargs...)
    perm = sortperm(dict.values; kwargs...)
    permute!(dict.values, perm)
    permute!(keys(dict).inds, perm)
    return dict
end

function sortkeys!(dict::ArrayDictionary; kwargs...)
    perm = sortperm(keys(dict).inds; kwargs...)
    permute!(dict.values, perm)
    permute!(keys(dict).inds, perm)
    return dict
end

function sortpairs!(dict::ArrayDictionary; by = identity, kwargs...)
    inds = keys(dict).inds
    vals = dict.values
    perm = sortperm(keys(dict.values); by = i -> by(@inbounds(inds[i]) => @inbounds(vals[i])), kwargs...)
    permute!(dict.values, perm)
    permute!(inds, perm)
    return dict
end
