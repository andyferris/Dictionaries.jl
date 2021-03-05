## Scalar indexing (and related) conversion helpers

# getting
@propagate_inbounds function Base.getindex(d::AbstractDictionary{I}, i) where {I}
	return d[convert(I, i)]
end

@propagate_inbounds function Base.setindex!(d::AbstractDictionary{I}, v, i) where {I}
    # Should we do a `isequal` check here?
    return setindex!(d, v, convert(I, i))
end

# setting
@propagate_inbounds function Base.setindex!(d::AbstractDictionary{I, T}, v, i::I) where {I, T}
    return setindex!(d, convert(T, v), i)
end

## `get` helper function
@propagate_inbounds function Base.get(d::AbstractDictionary{I, T}, i, default) where {I, T}
    get(d, convert(I, i), default)
end

@propagate_inbounds function Base.get(d::AbstractDictionary{I}, i::I, default) where {I}
    (hasindex, t) = gettoken(d, i)
    if hasindex
        return gettokenvalue(d, t)
    else
        return default
    end
end

@propagate_inbounds function Base.get(f::Base.Callable, d::AbstractDictionary{I}, i) where {I}
    get(f, d, convert(I, i))
end

@propagate_inbounds function Base.get(f::Base.Callable, d::AbstractDictionary{I, T}, i::I) where {I, T}
    (hasindex, t) = gettoken(d, i)
    if hasindex
        return gettokenvalue(d, t)
    else
        return f()
    end
end

## getproperty is equivalent to indexing with a `Symbol`

# @propagate_inbounds Base.getproperty(d::AbstractDictionary, s::Symbol) = d[s]
# @propagate_inbounds function Base.setproperty!(d::AbstractDictionary, s::Symbol, x)
#     d[s] = x
#     return x
# end

## Non-scalar indexing

# Basically, getindices maps the indices over the indexee
@inline function Indexing.getindices(d, inds::AbstractDictionary)
    @boundscheck checkindices(keys(d), inds)
    return map(i -> @inbounds(d[i]), inds)
end

@inline function Indexing.setindices!(d, value, inds::AbstractDictionary)
    @boundscheck checkindices(keys(d), inds)
    foreach(i -> @inbounds(d[i] = value), inds)
    return d
end

@inline function Indexing.getindices(inds1::AbstractIndices, inds2::AbstractIndices)
    @boundscheck checkindices(inds1, inds2)
    return inds2 # TODO should this be a `copy`, perhaps? The output shouldn't alias inds1, but what about inds2?
end

## Views

struct DictionaryView{I, V, Inds <: AbstractDictionary{I}, Vals <: AbstractDictionary{<:Any, V}} <: AbstractDictionary{I, V}
    inds::Inds
    vals::Vals
end

Base.parent(d::DictionaryView) = getfield(d, :vals)
_inds(d::DictionaryView) = getfield(d, :inds)

Base.keys(d::DictionaryView) = keys(_inds(d))

function Base.isassigned(d::DictionaryView{I}, i::I) where {I}
    i2 = @inbounds _inds(d)[i]
    return isassigned(parent(d), i2)
end

@propagate_inbounds function Base.getindex(d::DictionaryView{I}, i::I) where {I}
    i2 = _inds(d)[i]
    return @inbounds parent(d)[i2]
end

@propagate_inbounds function Base.setindex!(d::DictionaryView{I, T}, value::T, i::I) where {I, T}
    i2 = _inds(d)[i]
    return @inbounds parent(d)[i2] = value
end

# `DictionaryView` shares tokens with it's `keys` (and can co-iterate quickly with other dictionaries with those keys)
@propagate_inbounds function gettoken(d::DictionaryView{I}, i::I) where {I}
    return gettoken(_inds(d), i)
end

@propagate_inbounds function istokenassigned(d::DictionaryView, t)
    i2 = gettokenvalue(_inds(d), t)
    return isassigned(parent(d), i2)
end

@propagate_inbounds function gettokenvalue(d::DictionaryView, t)
    i2 = gettokenvalue(_inds(d), t)
    return @inbounds parent(d)[i2]
end

@propagate_inbounds function settokenvalue!(d::DictionaryView{<:Any, T}, t, value::T) where {T}
    i2 = gettokenvalue(_inds(d), t)
    return @inbounds parent(d)[i2] = value
end

@inline function Base.view(vals::AbstractDictionary, inds::AbstractDictionary)
    @boundscheck checkindices(keys(vals), inds)

    return DictionaryView{keytype(inds), eltype(vals), typeof(inds), typeof(vals)}(inds, vals)
end

@inline function Base.view(inds1::AbstractIndices, inds2::AbstractIndices)
    @boundscheck checkindices(inds1, inds2)
    return inds2
end

# TODO accelerate view(::Union{Dictionary, Indices}, ::Indices) to fetch not compute the intermediate `hash`
# (similary a sort-based index could take advantage of sort-merge algorithms on iteration?)