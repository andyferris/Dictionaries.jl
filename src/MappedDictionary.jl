struct MappedDictionary{I, T, F, Maps <: Tuple{AbstractDictionary{<:I}, Vararg{AbstractDictionary{<:I}}}} <: AbstractDictionary{I, T}
    f::F
    dicts::Maps
end

#=
function SplitApplyCombine.mapview(f, d::AbstractDictionary)
    I = keytype(d)
    T = Core.Compiler.return_type(f, Tuple{eltype(d)})
    
    return MappedDictionary{I, T, typeof(f), Tuple{typeof(d)}}(f, (d,))
end

function SplitApplyCombine.mapview(f, d::AbstractDictionary, ds::AbstractDictionary...)
    I = typejoin(keytype(d), keytype.(ds)...)
    T = Core.Compiler.return_type(f, Tuple{eltype(d), eltype.(ds)...})

    # Check the things have the same keys...
    
    return MappedDictionary{I, T, typeof(f), typeof((d, ds...))}(f, (d, ds...))
end
=#

Base.keys(d::MappedDictionary{I}) where {I} = keys(d.dicts[1])::AbstractIndices{I}

function Base.isassigned(d::MappedDictionary{I}, i::I) where {I}
    return all(Base.Fix2(isassigned, i), d.dicts)
end

function Base.isassigned(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, i::I) where {I, T}
    return isassigned(d.dicts[1], i)
end


@propagate_inbounds function Base.getindex(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, i::I) where {I, T}
    return d.f(d.dicts[1][i])::T
end

@inline function Base.getindex(d::MappedDictionary{I, T}, i::I) where {I, T}
    @boundscheck checkindex(d.dicts[1], i)
    return d.f(map(x -> @inbounds(x[i]), d.dicts)...)::T
end

# TODO FIXME what do about tokens when there is more than one mapped dictioanry? For now, we disable them...
istokenizable(d::MappedDictionary) = false
function istokenizable(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}) where {I, T}
    return istokenizable(d.maps[1])
end

@propagate_inbounds function gettokenvalue(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, t) where {I, T}
    return d.f(gettokenvalue(d.dicts[1], t))
end

function istokenassigned(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, t) where {I, T}
    return istokenassigned(d.dicts[1], t)
end


Base.similar(dict::MappedDictionary, ::Type{T}, indices) where {T} = similar(parent(dict), T, indices)
Base.empty(dict::MappedDictionary, ::Type{I}, ::Type{T}) where {I, T} = similar(parent(dict), I, T)
