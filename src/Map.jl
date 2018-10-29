
struct Map{I, T, Indices, Values}
	values::Values
	indices::Indices
end

Base.keys(m::Map) = Indices(m.indices)

@propagate_inbounds function Base.getindex(m::Map{I}, i::I) where {I}
	index = findfirst(isequal(i), m)
	m.values[m.indices[i]]
end

# Construction
#function AbstractMap(g::Generator)
#	Map(collect(g), keys(g.iter))
#end