
struct Map{I, T, Indices, Values} <: AbstractMap{I, T}
	values::Values
	indices::Indices
end

function Base.keys(m::Map{I}) where {I}
    inds = m.indices
    return inds isa AbstractIndices{I} ? inds : Indices{I}(inds)
end

@propagate_inbounds function Base.getindex(m::Map{I, T}, i::I) where {I, T}
    ind = m.indices[i]
	return @inbounds m.values[ind]::T
end

tokens(m::Map{<:Any, <:Any, <:AbstractMap, <:AbstractMap}) = _tokens(tokens(m.indices), tokens(m.values))

tokenized(t::AbstractMap, m::Map{<:Any, <:Any, <:AbstractMap, <:AbstractMap}) = Map(tokenized(t, m.indices), tokenized(t, m.values))

# Construction
#function AbstractMap(g::Generator)
#	Map(collect(g), keys(g.iter))
#end