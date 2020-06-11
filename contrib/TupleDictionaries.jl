module TupleDictionaries

using Dictionaries
using Base: @propagate_inbounds

export TupleIndices, TupleDictionary

"""
    TupleIndices(iter)

Construct a `TupleIndices <: AbstractIndices` from an arbitrary Julia iterable. Lookup of
elements uses naive iteration.

If `iter` is a `Vector` then the result is `isinsertable` and `istokenizable`, making simple
and flexible indices using naive search that may be optimal for small collections.
"""
struct TupleIndices{I, Inds<:Tuple{Vararg{I}}} <: AbstractIndices{I}
	inds::Inds
end

TupleIndices() = TupleIndices{Union{},Tuple{}}(())
TupleIndices{I}() where {I} = TupleIndices{I,Tuple{}}({})

TupleIndices(t::Tuple{Vararg{I}}) = TupleIndices{eltype(t), typeof(t)}(t) # EltypeUnknown...
TupleIndices{I}(t::Tuple{Vararg{I}}) where {I} = TupleIndices{I, typeof(t)}(t) # There is a corner case where the elements of `iter` might not be of type `I`



# Basic interface
@propagate_inbounds function Base.iterate(i::TupleIndices{I}, state...) where {I}
    # We haven't enforced uniqueness anywhere...
    iterate(i.inds, state...)::Union{Nothing, Tuple{I, Any}}
end

Base.in(i::I, inds::TupleIndices{I}) where {I} = in(i, inds.inds)
function Base.IteratorSize(i::TupleIndices)
    out = Base.IteratorSize(i.inds)
    if out isa Base.HasShape
        return Base.HasLength()
    end
    return out
end
Base.length(i::TupleIndices) = length(i.inds)

end # module