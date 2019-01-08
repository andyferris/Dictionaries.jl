struct MappedMap{I, T, F, Maps <: Tuple{AbstractMap{<:I}, Vararg{AbstractMap{<:I}}}} <: AbstractMap{I, T}
    f::F
    maps::Maps
end

function SplitApplyCombine.mapview(f, m::AbstractMap)
    I = keytype(m)
    T = Core.Compiler.return_type(f, Tuple{eltype(m)})
    
    return MappedMap{I, T, typeof(f), Tuple{typeof(m)}}(f, (m,))
end

function SplitApplyCombine.mapview(f, m::AbstractMap, ms::AbstractMap...)
    I = typejoin(keytype(m), keytype.(ms)...)
    T = Core.Compiler.return_type(f, Tuple{eltype(m), eltype.(ms)...})

    # Check the things have the same keys...
    
    return MappedMap{I, T, typeof(f), typeof((m, ms))}(f, (m, ms...))
end

Base.keys(m::MappedMap{I}) where {I} = keys(m.maps[1])::AbstractIndices{I}

@propagate_inbounds function Base.getindex(m::MappedMap{I, T, <:Any, <:Tuple{AbstractMap{<:I}}}, i::I) where {I, T}
    return m.f(m.maps[1][i])::T
end

@inline function Base.getindex(m::MappedMap{I, T}, i::I) where {I, T}
    @boundscheck checkindex(m.maps[1], i)
    return f(map(x -> @inbounds(x[i]), m.maps)...)::T
end