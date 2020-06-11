"""
    ArrayIndices(iter)

Construct an `ArrayIndices <: AbstractIndices` from an arbitrary Julia iterable with unique
elements. Lookup uses naive iteration.

ArrayIndices make simple and flexible indices using naive search that may be optimal for
small collections. Larger collections are better handled by containers like `Indices`.
"""
struct ArrayIndices{I, Inds <: AbstractArray{I}} <: AbstractIndices{I}
    inds::Inds
    
    @inline function ArrayIndices{I, Inds}(a::Inds) where {I, Inds <: AbstractArray{I}}
        @boundscheck for i in LinearIndices(a)
            @inbounds x = a[i]
            for j in i+1:last(LinearIndices(a))
                if isequal(x, @inbounds(a[j]))
                    throw(IndexError("Indices are not unique"))
                end
            end
        end
        return new(a)
    end
end

@propagate_inbounds ArrayIndices() = ArrayIndices{Any}([])
@propagate_inbounds ArrayIndices{I}() where {I} = ArrayIndices{I, Vector{I}}(I[])
@propagate_inbounds ArrayIndices{I, Inds}() where {I, Inds} = ArrayIndices{I}(Inds())

@propagate_inbounds ArrayIndices(iter) = ArrayIndices(collect(iter))
@propagate_inbounds ArrayIndices{I}(iter) where {I} = ArrayIndices{I}(collect(I, iter))

@propagate_inbounds ArrayIndices(a::AbstractArray{I}) where {I} = ArrayIndices{I}(a)
@propagate_inbounds ArrayIndices{I}(a::AbstractArray{I}) where {I} = ArrayIndices{I, typeof(a)}(a)

Base.parent(inds::ArrayIndices) = getfield(inds, :inds)

# Basic interface
@propagate_inbounds function Base.iterate(i::ArrayIndices{I}, state...) where {I}
    iterate(parent(i), state...)
end

Base.in(i::I, inds::ArrayIndices{I}) where {I} = in(i, parent(inds))
Base.IteratorSize(::ArrayIndices) = Base.HasLength()
Base.length(inds::ArrayIndices) = length(parent(inds))

istokenizable(i::ArrayIndices) = true
tokentype(::ArrayIndices) = Int
@inline iteratetoken(inds::ArrayIndices, s...) = iterate(LinearIndices(parent(inds)), s...)
@inline function gettoken(inds::ArrayIndices{I}, i::I) where {I}
    a = parent(inds)
    @inbounds for x in LinearIndices(a)
        if isequal(i, a[x])
            return (true, convert(Int, x))
        end
    end
    return (false, 0)
end
@propagate_inbounds gettokenvalue(inds::ArrayIndices, x::Int) = parent(inds)[x]

isinsertable(i::ArrayIndices) = true # Need an array trait here...
@inline function gettoken!(inds::ArrayIndices{I}, i::I) where {I}
    a = parent(inds)
    @inbounds for x in LinearIndices(a)
        if isequal(i, a[x])
            return (true, convert(Int, x))
        end
    end
    push!(a, i)
    return (false, last(LinearIndices(a)))
end

@inline function deletetoken!(inds::ArrayIndices, x::Int)
    deleteat!(parent(inds), x)
    return inds
end

function Base.empty!(inds::ArrayIndices)
    empty!(parent(inds))
    return inds
end

Base.empty(inds::ArrayIndices, ::Type{I}) where {I} = ArrayIndices{I}(empty(parent(inds), I))

function Base.copy(inds::ArrayIndices, ::Type{I}) where {I}
    if I === eltype(inds)
        ArrayIndices{I}(copy(parent(inds)))
    else
        ArrayIndices{I}(convert(AbstractArray{I}, parent(inds)))
    end
end

function Base.filter!(pred, inds::ArrayIndices)
    filter!(pred, parent(inds))
    return inds
end
