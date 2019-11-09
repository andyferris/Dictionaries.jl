struct MappedDictionary{I, T, F, Maps <: Tuple{AbstractDictionary{<:I}, Vararg{AbstractDictionary{<:I}}}} <: AbstractDictionary{I, T}
    f::F
    maps::Maps
end

function SplitApplyCombine.mapview(f, d::AbstractDictionary)
    I = keytype(d)
    T = Core.Compiler.return_type(f, Tuple{eltype(d)})
    
    return MappedDictionary{I, T, typeof(f), Tuple{typeof(d)}}(f, (d,))
end

function SplitApplyCombine.mapview(f, d::AbstractDictionary, ds::AbstractDictionary...)
    I = typejoin(keytype(d), keytype.(ds)...)
    T = Core.Compiler.return_type(f, Tuple{eltype(d), eltype.(ds)...})

    # Check the things have the same keys...
    
    return MappedDictionary{I, T, typeof(f), typeof((d, ds))}(f, (d, ds...))
end

Base.keys(d::MappedDictionary{I}) where {I} = keys(d.maps[1])::AbstractIndices{I}

@propagate_inbounds function Base.getindex(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, i::I) where {I, T}
    return d.f(d.maps[1][i])::T
end

@inline function Base.getindex(d::MappedDictionary{I, T}, i::I) where {I, T}
    @boundscheck checkindex(d.maps[1], i)
    return d.f(map(x -> @inbounds(x[i]), d.maps)...)::T
end

Base.similar(dict::PairDictionary, ::Type{T}, indices) where {T} = similar(parent(dict), T, indices)
Base.empty(dict::PairDictionary, ::Type{I}, ::Type{T}) where {I, T} = similar(parent(dict), I, T)
