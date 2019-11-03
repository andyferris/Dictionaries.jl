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
    get(d, convert(T, default), i)
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
    map(i -> @inbounds(d[i]), inds)
end

@inline function Indexing.setindices!(d, value, inds::AbstractDictionary)
    @boundscheck checkindices(keys(d), inds)
    map(i -> @inbounds(d[i] = value), inds)
end

## Views
# TODO

#@inline function Base.view()

#function Base.checkindices(target_inds, inds::AbstractDictionary)
#    for i in inds
#        if !(i ∈ target_inds)
#            throw(IndexError("Index not found: $i"))
#        end
#    end
#end
