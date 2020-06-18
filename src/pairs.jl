# TODO docstring
struct PairDictionary{I, T, D <: AbstractDictionary{I, T}} <: AbstractDictionary{I, Pair{I, T}}
    d::D
end

"""
    pairs(dict::AbstractDictionary)

Return a new dictionary, wrapping `dict`, that shares the same `keys` but containing
key-value pairs.

# Example

```julia
julia> dict = Dictionary(["a", "b", "c"], [1, 2, 3])
3-element Dictionary{String,Int64}
 "c" │ 3
 "b" │ 2
 "a" │ 1

julia> pairs(dict)
3-element Dictionaries.PairDictionary{String,Int64,Dictionary{String,Int64}}
 "c" │ "c" => 3
 "b" │ "b" => 2
 "a" │ "a" => 1
```
"""
Base.pairs(d::AbstractDictionary) = PairDictionary{keytype(d), eltype(d), typeof(d)}(d)

Base.parent(d::PairDictionary) = getfield(d, :d)
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
