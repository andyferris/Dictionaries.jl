
struct Dictionary{I, T, Indices, Values} <: AbstractDictionary{I, T}
	values::Values
	indices::Indices
end

function Base.keys(d::Dictionary{I}) where {I}
    inds = d.indices
    return inds isa AbstractIndices{I} ? inds : Indices{I}(inds)
end

@propagate_inbounds function Base.getindex(d::Dictionary{I, T}, i::I) where {I, T}
    ind = d.indices[i]
	return @inbounds d.values[ind]::T
end

tokens(d::Dictionary{<:Any, <:Any, <:AbstractDictionary, <:AbstractDictionary}) = _tokens(tokens(d.indices), tokens(d.values))

tokenized(t::AbstractDictionary, d::Dictionary{<:Any, <:Any, <:AbstractDictionary, <:AbstractDictionary}) = Dictionary(tokenized(t, d.indices), tokenized(t, d.values))

# Construction
#function AbstractDictionary(g::Generator)
#	Dictionary(collect(g), keys(g.iter))
#end