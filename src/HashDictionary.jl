struct HashDictionary{I, T} <: AbstractDictionary{I, T}
    indices::HashIndices{I}
    values::Vector{T}

    function HashDictionary{I, T}(inds::HashIndices{I}, values::Vector{T}) where {I, T}
        # TODO make sure sizes match, deal with the fact that inds.holes might be nonzero
        return new(inds, values)
    end
end

HashDictionary(; sizehint = 8) = HashDictionary{Any, Any}(; sizehint = sizehint)
HashDictionary{I}(; sizehint = 8) where {I} = HashDictionary{I, Any}(; sizehint = sizehint)

function HashDictionary{I, T}(; sizehint = 8) where {I, T}
    HashDictionary{I, T}(HashIndices{I}(; sizehint = sizehint), Vector{T}())
end

function HashDictionary(inds, values)
    return HashDictionary(HashIndices(inds), values)
end

function HashDictionary(inds::HashIndices{I}, values) where {I}
    return HashDictionary{I}(inds, values)
end

function HashDictionary{I}(inds, values) where {I}
    return HashDictionary{I}(HashIndices{I}(inds), values)
end

function HashDictionary{I}(inds::HashIndices{I}, values) where {I}
    if Base.IteratorEltype(values) === Base.EltypeUnknown()
        values = collect(values)
    end
    
    return HashDictionary{I, eltype(values)}(inds, values)
end

function HashDictionary{I, T}(inds, values) where {I, T}
    return HashDictionary{I, T}(HashIndices{I}(inds), values)
end

function HashDictionary{I, T}(inds::HashIndices{I}, values) where {I, T}
    iter_size = Base.IteratorSize(values)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        vs = Vector{T}(undef, length(values))
        @inbounds for (i, v) in enumerate(values)
            vs[i] = v
        end
        return HashDictionary{I, T}(inds, vs)
    else
        vs = Vector{T}()
        for v in values
            push!(vs, v)
        end
        return HashDictionary{I, T}(inds, vs)
    end
end

"""
    dictionary(iter)

Construct a new `AbstractDictionary` from an iterable `iter` of key-value `Pair`s. The
default container type is `HashDictionary`.
"""
function dictionary(iter)
    if Base.IteratorEltype(iter) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnkown
        iter = collect(iter)
    end
    _dictionary(eltype(iter), iter)
end

dictionary(p1::Pair, p2::Pair...) = dictionary((p1, p2...))

function _dictionary(::Type{Pair{I, T}}, iter) where {I, T}
    iter_size = Base.IteratorSize(iter)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        n = length(iter)
        inds = Vector{I}(undef, n)
        vals = Vector{T}(undef, n)
        j = 1
        @inbounds for (i, v) in iter
            inds[j] = i
            vals[j] = v
            j += 1
        end
        return HashDictionary{I, T}(inds, vals)
    else
        inds = Vector{I}()
        vals = Vector{T}()
        @inbounds for (i, v) in iter
            push!(inds, i)
            push!(vals, v)
        end        
        return HashDictionary{I, T}(inds, vals)
    end
end

# indices

Base.keys(dict::HashDictionary) = dict.indices

# tokens

tokenized(dict::HashDictionary) = dict.values

# values

function istokenassigned(dict::HashDictionary, (_slot, index))
    return isassigned(dict.values, index)
end

@propagate_inbounds function gettokenvalue(dict::HashDictionary, (_slot, index))
    return dict.values[index]
end

issettable(::HashDictionary) = true

@propagate_inbounds function settokenvalue!(dict::HashDictionary{<:Any, T}, (_slot, index), value::T) where {T}
    dict.values[index] = value
    return dict
end

# insertion

isinsertable(::HashDictionary) = true

function gettoken!(dict::HashDictionary{I}, i::I) where {I}
    (hadtoken, (slot, index)) = gettoken!(keys(dict), i, (dict.values,))
    return (hadtoken, (slot, index))
end

function deletetoken!(dict::HashDictionary{I, T}, (slot, index)) where {I, T}
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), dict.values, index-1)
    deletetoken!(dict.indices, (slot, index), (dict.values,))
    return dict
end


function Base.empty!(dict::HashDictionary{I, T}) where {I, T}
    empty!(dict.values)
    empty!(dict.indices)

    return dict
end

function Base.filter!(pred, dict::HashDictionary)
    indices = keys(dict)
    _filter!(i -> pred(@inbounds dict.values[i]), keys(indices.values), indices.values, indices.hashes, (dict.values,))
    indices.deleted = 0
    newsize = Base._tablesz(3*length(indices.values) >> 0x01)
    rehash!(indices, newsize, (dict.values,))
    return dict
end

function Base.filter!(pred, dict::PairDictionary{<:Any, <:Any, <:HashDictionary})
    d = dict.d
    indices = keys(d)
    _filter!(i -> pred(@inbounds indices.values[i] => d.values[i]), keys(indices.values), indices.values, indices.hashes, (d.values,))
    indices.deleted = 0
    newsize = Base._tablesz(3*length(indices.values) >> 0x01)
    rehash!(indices, newsize, (d.values,))
    return dict
end

# Factories

function Base.similar(indices::HashIndices{I}, ::Type{T}) where {I, T}
    return HashDictionary(indices, Vector{T}(undef, length(indices.values)))
end

function _distinct(f, ::Type{HashDictionary}, itr)
    tmp = iterate(itr)
    if tmp === nothing
        T = Base.@default_eltype(itr)
        I = Core.Compiler.return_type(f, Tuple{T})
        return HashDictionary{I, T}()
    end
    (x, s) = tmp
    i = f(x)
    dict = HashDictionary{typeof(i), typeof(x)}()
    insert!(dict, i, x)
    return __distinct(f, dict, itr, s)
end
