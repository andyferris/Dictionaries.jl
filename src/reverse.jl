# Reversed indices
struct ReverseIndices{I, Inds <: AbstractIndices{I}} <: AbstractIndices{I}
    inds::Inds
end

Base.parent(inds::ReverseIndices) = getfield(inds, :inds)
@propagate_inbounds Base.in(inds::ReverseIndices{I}, i::I) where {I} = in(parent(inds), i)
Base.length(inds::ReverseIndices) = length(parent(inds))
Base.IteratorSize(inds::ReverseIndices) = Base.IteratorSize(parent(inds))

istokenizable(inds::ReverseIndices) = istokenizable(parent(inds))
tokentype(inds::ReverseIndices) = tokentype(parent(inds))
@propagate_inbounds gettoken(inds::ReverseIndices{I}, i::I) where {I} = gettoken(parent(inds), i)
@propagate_inbounds gettokenvalue(inds::ReverseIndices, t) = gettokenvalue(parent(inds), t)

@propagate_inbounds iteratetoken(inds::ReverseIndices, s...) = iteratetoken_reverse(parent(inds), s...)
@propagate_inbounds iteratetoken_reverse(inds::ReverseIndices, s...) = iteratetoken(parent(inds), s...)

Iterators.reverse(inds::AbstractIndices) = ReverseIndices{eltype(inds), typeof(inds)}(inds)
Iterators.reverse(inds::ReverseIndices) = parent(inds)

Base.reverse(inds::AbstractIndices) = copy(Iterators.reverse(inds))

empty_type(::Type{<:ReverseIndices{<:Any, Inds}}, ::Type{I}) where {I, Inds} = empty_type(Inds, I)
empty_type(::Type{<:ReverseIndices{<:Any, Inds}}, ::Type{I}, ::Type{T}) where {I, T, Inds} = empty_type(Inds, I, T)

Base.similar(inds::ReverseIndices, ::Type{T}) where {T} = Iterators.reverse(similar(parent(inds), T))

# Reversed dictionary
struct ReverseDictionary{I, T, Dict <: AbstractDictionary{I, T}} <: AbstractDictionary{I, T}
    dict::Dict
end

Base.parent(dict::ReverseDictionary) = getfield(dict, :dict)

@inline function Base.keys(dict::ReverseDictionary)
    Iterators.reverse(keys(parent(dict)))
end

issetable(dict::ReverseDictionary) = issetable(parent(dict))

Base.isassigned(dict::ReverseDictionary{I}, i::I) where {I} = isassigned(parent(dict), i)
@propagate_inbounds Base.getindex(dict::ReverseDictionary{I}, i::I) where {I} = getindex(parent(dict), i)
@propagate_inbounds Base.setindex!(dict::ReverseDictionary{I, T}, i::I, v::T) where {I, T} = setindex!(parent(dict), v, i)

istokenassigned(dict::ReverseDictionary, t) = istokenassigned(parent(dict), t)
@propagate_inbounds gettokenvalue(dict::ReverseDictionary, t) = gettokenvalue(parent(dict), t)
@propagate_inbounds settokenvalue!(dict::ReverseDictionary{<:Any, T}, t, v::T) where {T} = settokenvalue!(parent(dict), t, v)

Iterators.reverse(dict::AbstractDictionary) = ReverseDictionary{keytype(dict), eltype(dict), typeof(dict)}(dict)
Iterators.reverse(dict::ReverseDictionary) = parent(dict)

function Base.reverse(dict::AbstractDictionary)
    out = similar(reverse(keys(dict)), eltype(dict))
    @inbounds copyto!(out, Iterators.reverse(dict))
    return out
end

empty_type(::Type{<:ReverseDictionary{<:Any, <:Any, D}}, ::Type{I}) where {I, D} = empty_type(D, I)
empty_type(::Type{<:ReverseDictionary{<:Any, <:Any, D}}, ::Type{I}, ::Type{T}) where {I, T, D} = empty_type(D, I, T)
