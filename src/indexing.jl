# Scalar indexing (and related) conversion helpers

@propagate_inbounds function Base.getindex(m::AbstractMap{I}, i) where {I}
	return m[convert(I, i)]
end

@propagate_inbounds function Base.setindex!(m::AbstractMap{I}, v, i) where {I}
    return setindex!(m, v, convert(I, i))
end

@propagate_inbounds function Base.setindex!(m::AbstractMap{I, T}, v, i::I) where {I, T}
    return setindex!(m, convert(v, T), i)
end

# Non-scalar indexing

# Basically, one maps the indices over the indexee
@inline function Indexing.getindices(m, inds::AbstractMap)
    @boundscheck checkindices(keys(m), inds)
    map(i -> @inbounds(m[i]), inds)
end

@inline function Indexing.setindices!(m, value, inds::AbstractMap)
    @boundscheck checkindices(keys(m), inds)
    map(i -> @inbounds(m[i] = value), inds)
end

#@inline function Base.view()

#function Base.checkindices(target_inds, inds::AbstractMap)
#    for i in inds
#        if !(i ∈ target_inds)
#            throw(IndexError("Index not found: $i"))
#        end
#    end
#end
