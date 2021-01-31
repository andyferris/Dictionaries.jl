struct FillDictionary{I, T, Inds <: AbstractIndices{I}} <: AbstractDictionary{I, T}
    inds::Inds
    value::T
end

FillDictionary(inds, value) = FillDictionary(Indices(inds), value)

Base.keys(d::FillDictionary) = getfield(d, :inds)

@inline function Base.getindex(d::FillDictionary{I}, i::I) where I
    @boundscheck checkindex(keys(d), i)
    return getfield(d, :value)
end

Base.isassigned(d::FillDictionary{I}, i::I) where {I} = Base.isassigned(keys(d), i)

gettokenvalue(d::FillDictionary, t) = getfield(d, :value)

istokenassigned(d::FillDictionary, t) = true
