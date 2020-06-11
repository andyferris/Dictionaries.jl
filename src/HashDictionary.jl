struct HashDictionary{I, T} <: AbstractDictionary{I, T}
    indices::HashIndices{I}
    values::Vector{T}

    function HashDictionary{I, T}(inds::HashIndices{I}, values::Vector{T}, ::Nothing) where {I, T}
       @assert length(values) == length(inds.values)
       return new{I,T}(inds, values)
    end
end

"""
    HashDictionary{I,T}(;sizehint = 8)

Construct an empty hash-based dictionary. `I` and `T` default to `Any` if not specified. A
`sizehint` may be specified to set the initial size of the hash table, which may speed up
subsequent `insert!` operations.

# Example

```julia
julia> d = HashDictionary{Int, Int}()
0-element HashDictionary{Int64,Int64}
```
"""
HashDictionary(; sizehint = 8) = HashDictionary{Any, Any}(; sizehint = sizehint)
HashDictionary{I}(; sizehint = 8) where {I} = HashDictionary{I, Any}(; sizehint = sizehint)

function HashDictionary{I, T}(; sizehint = 8) where {I, T}
    HashDictionary{I, T}(HashIndices{I}(; sizehint = sizehint), Vector{T}(), nothing)
end

"""
    HashDictionary(indexable)
    HashDictionary{I}(indexable)
    HashDictionary{I,T}(indexable)

Construct a hash-based dictionary from an indexable input `indexable`, equivalent to
`HashDictionary(keys(indexable), values(indexable))`. The input might not be copied.

Note: to construct a dictionary from `Pair`s use the `dictionary` function. See also the
`index` function.

# Examples

```julia
julia> HashDictionary(Dict(:a=>1, :b=>2))
2-element HashDictionary{Symbol,Int64}
 :a │ 1
 :b │ 2

julia> HashDictionary(3:-1:1)
3-element HashDictionary{Int64,Int64}
 1 │ 3
 2 │ 2
 3 │ 1 
```
"""
HashDictionary(indexable) = HashDictionary(keys(indexable), values(indexable))
HashDictionary{I}(indexable) where {I} = HashDictionary{I}(keys(indexable), values(indexable))
HashDictionary{I, T}(indexable) where {I, T} = HashDictionary{I, T}(keys(indexable), values(indexable))

"""
    HashDictionary(inds, values)
    HashDictionary{I}(inds, values)
    HashDictionary{I, T}(inds, values)

Construct a hash-based dictionary from two iterable inputs `inds` and `values`. The first
value of `inds` will be the index for the first value of `values`. The input might not be
copied.

Note: the values of `inds` must be distinct. Consider using `dictionary(zip(inds, values))`
if they are not. See also the `index` function.

# Example

julia> HashDictionary(["a", "b", "c"], [1, 2, 3])
3-element HashDictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3

julia> HashDictionary{String, Float64}(["a", "b", "c"], [1, 2, 3])
3-element HashDictionary{String,Float6464}
 "a" │ 1.0
 "b" │ 2.0
 "c" │ 3.0
"""
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
    if inds.holes != 0
        inds = copy(inds)
    end

    iter_size = Base.IteratorSize(values)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        vs = Vector{T}(undef, length(values))
        @inbounds for (i, v) in enumerate(values)
            vs[i] = v
        end
        return HashDictionary{I, T}(inds, vs, nothing)
    else
        vs = Vector{T}()
        for v in values
            push!(vs, v)
        end
        return HashDictionary{I, T}(inds, vs, nothing)
    end
end

"""
    dictionary(iter)

Construct a new `AbstractDictionary` from an iterable `iter` of key-value `Pair`s (or other
iterables of two elements, such as a two-tuples). The default container type is
`HashDictionary`. If duplicate keys are detected, the first encountered value is retained.

See also the `index` function.

# Examples

```julia
julia> dictionary(["a"=>1, "b"=>2, "c"=>3])
3-element HashDictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3

julia> dictionary(["a"=>1, "b"=>2, "c"=>3, "a"=>4])
3-element HashDictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3

julia> dictionary(zip(["a","b","c"], [1,2,3]))
3-element HashDictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3
```
"""
function dictionary(iter)
    return _dictionary(first, last, HashDictionary, iter)
end

# An auto-widening HashDictionary constructor
function _dictionary(key, value, ::Type{HashDictionary}, iter)
    tmp = iterate(iter)
    if tmp === nothing
        IT = Base.@default_eltype(iter)
        I = Core.Compiler.return_type(first, Tuple{IT})
        T = Core.Compiler.return_type(last, Tuple{IT})
        return HashDictionary{I, T}()
    end
    (x, s) = tmp
    i = key(x)
    v = value(x)
    dict = HashDictionary{typeof(i), typeof(v)}()
    insert!(dict, i, v)
    return __dictionary(key, value, dict, iter, s)
end

# An auto-widening AbstractDictionary constructor
function __dictionary(key, value, dict, iter, s)
    I = keytype(dict)
    T = eltype(dict)
    tmp = iterate(iter, s)
    while tmp !== nothing
        (x, s) = tmp
        i = key(x)
        v = value(x)
        if !(i isa I)
            new_inds = copy(keys(dict), promote_type(I, typeof(i)))
            new_dict = similar(new_inds, promote_type(T, typeof(v)))
            (hadtoken, token) = gettoken!(new_dict, i)
            if !hadtoken
                @inbounds settokenvalue!(new_dict, token, v)
            end
            return __dictionary(key, value, new_dict, iter, s)
        elseif !(v isa T)
            new_dict = copy(dict, promote_type(T, typeof(v)))
            (hadtoken, token) = gettoken!(new_dict, i)
            if !hadtoken
                @inbounds settokenvalue!(new_dict, token, v)
            end
            return __dictionary(key, value, new_dict, iter, s)
        end
        (hadtoken, token) = gettoken!(dict, i)
        if !hadtoken
            @inbounds settokenvalue!(dict, token, v)
        end
        tmp = iterate(iter, s)
    end
    return dict
end

"""
    index(f, iter)

Return a dictionary associating the values `x` of iterable collection `iter` with the key
`f(x)`. If keys are repeated, only the first is kept. Somewhat similar to `unique(f, iter)`

See also the `dictionary` function.

# Examples

```julia
julia> index(first, ["Alice", "Bob", "Charlie"])
3-element HashDictionary{Char,String}
 'A' │ "Alice"
 'B' │ "Bob"
 'C' │ "Charlie"

julia> index(iseven, 1:10)
2-element HashDictionary{Bool,Int64}
 false │ 1
  true │ 2
```
"""
function index(f, iter)
    _dictionary(f, identity, HashDictionary, iter)
end

# indicesi

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
    _filter!(i -> pred(@inbounds dict.values[i]), indices.values, indices.hashes, (dict.values,))
    indices.holes = 0
    newsize = Base._tablesz(3*length(indices.values) >> 0x01)
    rehash!(indices, newsize, (dict.values,))
    return dict
end

function Base.filter!(pred, dict::PairDictionary{<:Any, <:Any, <:HashDictionary})
    d = dict.d
    indices = keys(d)
    _filter!(i -> pred(@inbounds indices.values[i] => d.values[i]), indices.values, indices.hashes, (d.values,))
    indices.holes = 0
    newsize = Base._tablesz(3*length(indices.values) >> 0x01)
    rehash!(indices, newsize, (d.values,))
    return dict
end

# Factories

function Base.similar(indices::HashIndices{I}, ::Type{T}) where {I, T}
    return HashDictionary{I, T}(indices, Vector{T}(undef, length(indices.values)), nothing)
end

