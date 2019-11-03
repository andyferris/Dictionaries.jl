# TODO docstring
struct PairDictionary{I, T, D <: AbstractDictionary{I, T}} <: AbstractDictionary{I, Pair{I, T}}
    d::D
    # TODO single argument constructor isn't an `AbstractDictionary` copy-constructor!
end

# TODO docstring
Base.pairs(d::AbstractDictionary) = PairDictionary(d)

Base.parent(d::PairDictionary) = d.d
Base.keys(d::PairDictionary) = keys(parent(d))
@propagate_inbounds Base.getindex(d::PairDictionary{I}, i::I) where {I} = i => parent(d)[i]

# TODO make iteration fast in a generic way (tokens)
