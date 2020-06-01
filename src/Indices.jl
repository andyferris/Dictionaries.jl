"""
    Indices(iter)

Construct an `Indices <: AbstractIndices` from an arbitrary Julia iterable. Lookup of
elements uses naive iteration.

If `iter` is a `Vector` then the result is `isinsertable` and `istokenizable`, making simple
and flexible indices using naive search that may be optimal for small collections.
"""
struct Indices{I, Inds} <: AbstractIndices{I}
	inds::Inds
end

Indices() = Indices([])
Indices{I}() where {I} = Indices{I}(I[])
Indices{I, Inds}() where {I, Inds} = Indices{I}(Inds())

Indices(iter) = Indices{eltype(iter), typeof(iter)}(iter) # EltypeUnknown...
Indices{I}(iter) where {I} = Indices{I, typeof(iter)}(iter) # There is a corner case where the elements of `iter` might not be of type `I`


# Basic interface
@propagate_inbounds function Base.iterate(i::Indices{I}, state...) where {I}
    # We haven't enforced uniqueness anywhere...
    iterate(i.inds, state...)::Union{Nothing, Tuple{I, Any}}
end

Base.in(i::I, inds::Indices{I}) where {I} = in(i, inds.inds)
Base.IteratorSize(i::Indices) = Base.IteratorSize(i.inds)
Base.length(i::Indices) = length(i.inds)

# Specialize for `Vector` elements. Satisfy the tokenization and insertion interface
const VectorIndices{I} = Indices{I, Vector{I}}

istokenizable(i::VectorIndices) = true
tokentype(::VectorIndices) = Int
@inline iteratetoken(inds::VectorIndices, s...) = iterate(keys(inds.inds), s...)
@inline function gettoken(inds::VectorIndices{I}, i::I) where {I}
    @inbounds for x in keys(inds.inds)
        if isequal(i, inds.inds[x])
            return (true, x)
        end
    end
    return (false, 0)
end
@propagate_inbounds gettokenvalue(inds::VectorIndices, x::Int) = inds.inds[x]

isinsertable(i::VectorIndices) = true
@inline function gettoken!(inds::VectorIndices{I}, i::I) where {I}
    @inbounds for x in keys(inds.inds)
        if isequal(i, inds.inds[x])
            return (true, x)
        end
    end
    push!(inds.inds, i)
    return (false, length(inds.inds))
end

@inline function deletetoken!(inds::VectorIndices, x::Int)
    deleteat!(inds.inds, x)
    return inds
end

function Base.empty!(inds::VectorIndices)
    empty!(inds.inds)
    return inds
end

Base.empty(inds::VectorIndices, ::Type{I}) where {I} = Indices{I, Vector{I}}(Vector{I}())

Base.copy(inds::VectorIndices) = Indices(copy(inds.inds))

function Base.filter!(pred, inds::VectorIndices)
    filter!(pred, inds.inds)
    return inds
end