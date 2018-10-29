"""
    Indices(iter)

Construct an `Indices <: AbstractIndices` from an arbitrary Julia iterable.
"""
struct Indices{I, Inds} <: AbstractIndices{I}
	inds::Inds
end

Indices(iter) = Indices{eltype(iter), typeof{iter}}(inds)

@propagate_inbounds function Base.iterate(i::Indices{I}, state...) where {I}
    iterate(i.inds, state...)::Union{Nothing, Tuple{I, Any}}
end

function Base.length(i::Indices)
	return length(i.inds)
end
