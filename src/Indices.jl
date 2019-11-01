"""
    Indices(iter)

Construct an `Indices <: AbstractIndices` from an arbitrary Julia iterable.
"""
struct Indices{I, Inds} <: AbstractIndices{I}
	inds::Inds
end

Indices() = Indices(())
Indices{I}() where {I} = Indices{I}(())
Indices{I, Inds}() where {I, Inds} = Indices{I}(Inds())

Indices(iter) = Indices{eltype(iter), typeof{iter}}(iter) # EltypeUnknown...
Indices{I}(iter) where {I} = Indices{I, typeof{iter}}(iter) # There is a corner case where the elements of `iter` might not be of type `I`

@propagate_inbounds function Base.iterate(i::Indices{I}, state...) where {I}
    # We haven't enforced uniqueness anywhere...
    iterate(i.inds, state...)::Union{Nothing, Tuple{I, Any}}
end

Base.in(i::I, inds::Indices{I}) where {I} = in(i, inds.inds)
Base.length(i::Indices) = length(i.inds)

Base.empty(d::AbstractIndices) = empty(d, eltype(d))
