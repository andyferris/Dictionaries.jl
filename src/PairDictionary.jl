# TODO docstring
struct PairDictionary{I, T, D <: AbstractDictionary{I, T}} <: AbstractDictionary{I, Pair{I, T}}
    d::D
    # TODO single argument constructor isn't an `AbstractDictionary` copy-constructor!
end

# TODO docstring
Base.pairs(d::AbstractDictionary) = PairDictionary{keytype(d), eltype(d), typeof(d)}(d)

Base.parent(d::PairDictionary) = d.d
Base.keys(d::PairDictionary) = keys(parent(d))

# Length
Base.IteratorSize(d::PairDictionary) = Base.IteratorSize(parent(d))
Base.length(d::PairDictionary) = Base.length(parent(d))

# Standard interface
@propagate_inbounds Base.getindex(d::PairDictionary{I}, i::I) where {I} = i => parent(d)[i]
Base.isassigned(d::PairDictionary{I}, i::I) where {I} = isassigned(parent(d), i)

# Token interface
@propagate_inbounds gettoken(d::PairDictionary{I}, i::I) where {I} = gettoken(parent(d), i)

@propagate_inbounds function gettokenvalue(pd::PairDictionary, t)
    d = parent(pd)
    gettokenvalue(keys(d), t) => gettokenvalue(d, t)
end

istokenassigned(pd::PairDictionary, t) = istokenassigned(parent(pd), t)

iteratetoken(pd::PairDictionary, s...) = iteratetoken(parent(pd), s...)

# Factories
Base.similar(dict::PairDictionary, ::Type{T}, indices) where {T} = similar(parent(dict), T, indices)
Base.empty(dict::PairDictionary, ::Type{I}, ::Type{T}) where {I, T} = similar(parent(dict), I, T)
