"""
    Indices(iter)

Construct an `Indices <: AbstractIndices` from an arbitrary Julia iterable.
"""
struct Indices{I, Inds} <: AbstractIndices{I}
	inds::Inds
end

Indices(iter) = Indices{eltype(iter), typeof{iter}}(iter)

@propagate_inbounds function Base.iterate(i::Indices{I}, state...) where {I}
    iterate(i.inds, state...)::Union{Nothing, Tuple{I, Any}}
end

Base.in(inds::Indices{I}, i::I) where {I} = in(inds.inds, i)

function Base.length(i::Indices)
	return length(i.inds)
end


isinsertable(i::Indices) = _isinsertable(i.inds)

_isinsertable(i::AbstractMap) = isinsertable(i)
_isinsertable(::Any) = false
_isinsertable(::Dict) = true
