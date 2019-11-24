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


## get helper function
@propagate_inbounds function Base.get(d::AbstractDictionary{I, T}, i, default) where {I, T}
    get(d, convert(I, i), default)
end

@propagate_inbounds function Base.get(d::AbstractDictionary{I, T}, i::I, default) where {I, T}
    get(d, i, convert(T, default))
end

@propagate_inbounds function Base.get(d::AbstractDictionary{I, T}, i::I, default::T) where {I, T}
    (hasindex, t) = gettoken(d, i)
    if hasindex
        return gettokenvalue(d, t)
    else
        return default
    end
end

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
    return inds2 # TODO should this be a `copy`, perhaps?
end

## Views

struct DictionaryView{I, V, Inds <: AbstractDictionary{I}, Vals <: AbstractDictionary{<:Any, V}} <: AbstractDictionary{I, V}
    inds::Inds
    vals::Vals
end

Base.parent(d::DictionaryView) = d.vals

Base.keys(d::DictionaryView) = keys(d.inds)

function Base.isassigned(d::DictionaryView{I}, i::I) where {I}
    i2 = @inbounds d.inds[i]
    return isassigned(d.vals, i2)
end

@propagate_inbounds function Base.getindex(d::DictionaryView{I}, i::I) where {I}
    i2 = @inbounds d.inds[i]
    return d.vals[i2]
end

@propagate_inbounds function Base.setindex!(d::DictionaryView{I, T}, value::T, i::I) where {I, T}
    i2 = @inbounds d.inds[i]
    return d.vals[i2] = value
end

# `DictionaryView` shares tokens with it's `keys` (and can co-iterate quickly with other dictionaries with those keys)
@propagate_inbounds function gettoken(d::DictionaryView{I}, i::I) where {I}
    return gettoken(d.inds, i)
end

@propagate_inbounds function istokenassigned(d::DictionaryView, t)
    i2 = gettokenvalue(d.inds, t)
    return isassigned(d.vals, i2)
end

@propagate_inbounds function gettokenvalue(d::DictionaryView, t)
    i2 = gettokenvalue(d.inds, t)
    return d.vals[i2]
end

@propagate_inbounds function settokenvalue!(d::DictionaryView{<:Any, T}, t, value::T) where {T}
    i2 = gettokenvalue(d.inds, t)
    return d.vals[i2] = value
end


@inline function Base.view(vals::AbstractDictionary, inds::AbstractDictionary)
    @boundscheck checkindices(keys(vals), inds)

    return DictionaryView{keytype(inds), eltype(vals), typeof(inds), typeof(vals)}(inds, vals)
end

@inline function Base.view(inds1::AbstractIndices, inds2::AbstractIndices)
    @boundscheck checkindices(inds1, inds2)
    return inds2
end
