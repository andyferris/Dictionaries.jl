struct Dictionary{I, T} <: AbstractDictionary{I, T}
    indices::Indices{I}
    values::Vector{T}

    function Dictionary{I, T}(inds::Indices{I}, values::Vector{T}, ::Nothing) where {I, T}
       @assert length(values) == length(_values(inds))
       return new{I,T}(inds, values)
    end
end

"""
    Dictionary{I,T}(;sizehint = 8)

Construct an empty hash-based dictionary. `I` and `T` default to `Any` if not specified. A
`sizehint` may be specified to set the initial size of the hash table, which may speed up
subsequent `insert!` operations.

# Example

```julia
julia> d = Dictionary{Int, Int}()
0-element Dictionary{Int64,Int64}
```
"""
Dictionary(; sizehint = 8) = Dictionary{Any, Any}(; sizehint = sizehint)
Dictionary{I}(; sizehint = 8) where {I} = Dictionary{I, Any}(; sizehint = sizehint)

function Dictionary{I, T}(; sizehint = 8) where {I, T}
    values = Vector{T}()
    sizehint!(values, sizehint)
    Dictionary{I, T}(Indices{I}(; sizehint = sizehint), values, nothing)
end

"""
    Dictionary(indexable)
    Dictionary{I}(indexable)
    Dictionary{I,T}(indexable)

Construct a hash-based dictionary from an indexable input `indexable`, equivalent to
`Dictionary(keys(indexable), values(indexable))`. The input might not be copied.

Note: to construct a dictionary from `Pair`s use the `dictionary` function. See also the
`index` function.

# Examples

```julia
julia> Dictionary(Dict(:a=>1, :b=>2))
2-element Dictionary{Symbol,Int64}
 :a │ 1
 :b │ 2

julia> Dictionary(3:-1:1)
3-element Dictionary{Int64,Int64}
 1 │ 3
 2 │ 2
 3 │ 1 
```
"""
Dictionary(indexable) = Dictionary(keys(indexable), values(indexable))
Dictionary{I}(indexable) where {I} = Dictionary{I}(keys(indexable), values(indexable))
Dictionary{I, T}(indexable) where {I, T} = Dictionary{I, T}(keys(indexable), values(indexable))

"""
    Dictionary(inds, values)
    Dictionary{I}(inds, values)
    Dictionary{I, T}(inds, values)

Construct a hash-based dictionary from two iterable inputs `inds` and `values`. The first
value of `inds` will be the index for the first value of `values`. The input might not be
copied.

Note: the values of `inds` must be distinct. Consider using `dictionary(zip(inds, values))`
if they are not. See also the `index` function.

# Example

julia> Dictionary(["a", "b", "c"], [1, 2, 3])
3-element Dictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3

julia> Dictionary{String, Float64}(["a", "b", "c"], [1, 2, 3])
3-element Dictionary{String,Float6464}
 "a" │ 1.0
 "b" │ 2.0
 "c" │ 3.0
"""
function Dictionary(inds, values)
    return Dictionary(Indices(inds), values)
end

function Dictionary(inds::Indices{I}, values) where {I}
    return Dictionary{I}(inds, values)
end

function Dictionary{I}(inds, values) where {I}
    return Dictionary{I}(Indices{I}(inds), values)
end

function Dictionary{I}(inds::Indices{I}, values) where {I}
    if Base.IteratorEltype(values) === Base.EltypeUnknown()
        values = collect(values)
    end
    
    return Dictionary{I, eltype(values)}(inds, values)
end

function Dictionary{I, T}(inds, values) where {I, T}
    return Dictionary{I, T}(Indices{I}(inds), values)
end

function Dictionary{I, T}(inds::Indices{I}, values) where {I, T}
    if _holes(inds) != 0
        # TODO instead constructor a vector with holes in it...
        inds = copy(inds)
    end

    iter_size = Base.IteratorSize(values)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        vs = Vector{T}(undef, length(values))
        @inbounds for (i, v) in enumerate(values)
            vs[i] = v
        end
        return Dictionary{I, T}(inds, vs, nothing)
    else
        vs = Vector{T}()
        for v in values
            push!(vs, v)
        end
        return Dictionary{I, T}(inds, vs, nothing)
    end
end

"""
    Dictionary(indices, undef::UndefInitializer)

Construct a `Dictionary` from an iterable of `indices`, where the values are
undefined/uninitialized.

# Example

```julia
julia> Dictionary{Int, Float64}([1,2,3], undef)
3-element Dictionary{Int64,Float64}
 1 │ 6.9220016379355e-310
 2 │ 6.9220016379426e-310
 3 │ 6.92200163794736e-310
```
"""
function Dictionary{I, T}(inds::Indices{I}, ::UndefInitializer) where {I, T}
    vs = Vector{T}(undef, length(_values(inds)))
    return Dictionary{I, T}(inds, vs, nothing)
end

function Base.convert(::Type{Dictionary{I, T}}, dict::Dictionary) where {I, T}
    return Dictionary{I, T}(convert(Indices{I}, dict.indices), convert(Vector{T}, dict.values))
end

"""
    dictionary(iter)

Construct a new `AbstractDictionary` from an iterable `iter` of key-value `Pair`s (or other
iterables of two elements, such as a two-tuples). The default container type is
`Dictionary`. If duplicate keys are detected, the first encountered value is retained.

See also the `index` function.

# Examples

```julia
julia> dictionary(["a"=>1, "b"=>2, "c"=>3])
3-element Dictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3

julia> dictionary(["a"=>1, "b"=>2, "c"=>3, "a"=>4])
3-element Dictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3

julia> dictionary(zip(["a","b","c"], [1,2,3]))
3-element Dictionary{String,Int64}
 "a" │ 1
 "b" │ 2
 "c" │ 3
```
"""
function dictionary(iter)
    return _dictionary(first, last, Dictionary, iter)
end

# An auto-widening Dictionary constructor
function _dictionary(key, value, ::Type{Dictionary}, iter)
    tmp = iterate(iter)
    if tmp === nothing
        IT = Base.@default_eltype(iter)
        I = Core.Compiler.return_type(first, Tuple{IT})
        T = Core.Compiler.return_type(last, Tuple{IT})
        return Dictionary{I, T}()
    end
    (x, s) = tmp
    i = key(x)
    v = value(x)
    dict = Dictionary{typeof(i), typeof(v)}()
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
        if !(i isa I) && promote_type(typeof(i), I) != I
            new_inds = copy(keys(dict), promote_type(I, typeof(i)))
            new_dict = similar(new_inds, promote_type(T, typeof(v)))
            (hadtoken, token) = gettoken!(new_dict, i)
            if !hadtoken
                @inbounds settokenvalue!(new_dict, token, v)
            end
            return __dictionary(key, value, new_dict, iter, s)
        elseif !(v isa T) && promote_type(typeof(v), T) != T
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
3-element Dictionary{Char,String}
 'A' │ "Alice"
 'B' │ "Bob"
 'C' │ "Charlie"

julia> index(iseven, 1:10)
2-element Dictionary{Bool,Int64}
 false │ 1
  true │ 2
```
"""
function index(f, iter)
    _dictionary(f, identity, Dictionary, iter)
end

# indices

Base.keys(dict::Dictionary) = getfield(dict, :indices)
_values(dict::Dictionary) = getfield(dict, :values)

# tokens

tokenized(dict::Dictionary) = _values(dict)

# values

function istokenassigned(dict::Dictionary, (_slot, index))
    return isassigned(_values(dict), index)
end

function istokenassigned(dict::Dictionary, index::Int)
    return isassigned(_values(dict), index)
end

@propagate_inbounds function gettokenvalue(dict::Dictionary, (_slot, index))
    return _values(dict)[index]
end

@propagate_inbounds function gettokenvalue(dict::Dictionary, index::Int)
    return _values(dict)[index]
end

issettable(::Dictionary) = true

@propagate_inbounds function settokenvalue!(dict::Dictionary{<:Any, T}, (_slot, index), value::T) where {T}
    _values(dict)[index] = value
    return dict
end

@propagate_inbounds function settokenvalue!(dict::Dictionary{<:Any, T}, index::Int, value::T) where {T}
    _values(dict)[index] = value
    return dict
end

# insertion

isinsertable(::Dictionary) = true

function gettoken!(dict::Dictionary{I}, i::I) where {I}
    (hadtoken, (slot, index)) = gettoken!(keys(dict), i, (_values(dict),))
    return (hadtoken, (slot, index))
end

function deletetoken!(dict::Dictionary{I, T}, (slot, index)) where {I, T}
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), _values(dict), index-1)
    deletetoken!(keys(dict), (slot, index), (_values(dict),))
    return dict
end


function Base.empty!(dict::Dictionary{I, T}) where {I, T}
    empty!(_values(dict))
    empty!(keys(dict))

    return dict
end

function Base.filter!(pred, dict::Dictionary)
    indices = keys(dict)
    _filter!(token -> pred(@inbounds gettokenvalue(dict, token)), indices, (_values(dict),))
    return dict
end

function Base.filter!(pred, dict::PairDictionary{<:Any, <:Any, <:Dictionary})
    d = dict.d
    indices = keys(d)
    _filter!(token -> pred(@inbounds gettokenvalue(indices, token) => gettokenvalue(d, token)), indices, (_values(d),))
    return dict
end

# Factories

function Base.similar(indices::Indices{I}, ::Type{T}) where {I, T}
    return Dictionary{I, T}(indices, Vector{T}(undef, length(_values(indices))), nothing)
end

"""
    sort!(dict::AbstractDictionary; kwargs...)

Modify `dict` so that it is sorted by its values. The `kwargs` are the usual ordering
options supported by `sort`. Note that this only works on supported types.

See also `sort`, `sortkeys!` and `sortpairs!`.
"""
function Base.sort!(dict::Dictionary; kwargs...)
    inds = keys(dict)
    if inds.holes != 0
        rehash!(inds, length(inds.slots))
    end
    perm = sortperm(dict.values; kwargs...)
    inds.values = @inbounds inds.values[perm]
    inds.hashes = @inbounds inds.hashes[perm]
    @inbounds for i in keys(inds.slots)
        s = inds.slots[i]
        if s > 0
            inds.slots[i] = perm[s]
        end
    end
    permute!(dict.values, perm)
    return dict
end

"""
    sortkeys!(dict::AbstractDictionary; kwargs...)

Modify `dict` so that it is sorted by `keys(dict)`. The `kwargs` are the usual ordering
options supported by `sort`. Note that this only works on supported types.

See also `sortkeys`, `sort!` and `sortpairs!`.
"""
function sortkeys!(dict::Dictionary; kwargs...)
    inds = keys(dict)
    if inds.holes != 0
        rehash!(inds, length(inds.slots))
    end
    perm = sortperm(inds.values; kwargs...)
    inds.values = @inbounds inds.values[perm]
    inds.hashes = @inbounds inds.hashes[perm]
    @inbounds for i in keys(inds.slots)
        s = inds.slots[i]
        if s > 0
            inds.slots[i] = perm[s]
        end
    end
    permute!(dict.values, perm)
    return dict
end

"""
    sortpairs!(dict::AbstractDictionary; kwargs...)

Modify `dict` so that it is sorted by `pairs(dict)`. The `kwargs` are the usual ordering
options supported by `sort`.

See also `sortpairs`,`sort!` and `sortkeys!`.
"""
function sortpairs!(dict::Dictionary; by = identity, kwargs...)
    inds = keys(dict)
    if inds.holes != 0
        rehash!(inds, length(inds.slots))
    end
    vals = dict.values
    inds_vals = inds.values
    perm = sortperm(keys(dict.values); by = i -> by(@inbounds(inds_vals[i]) => @inbounds(vals[i])), kwargs...)
    inds.values = @inbounds inds.values[perm]
    inds.hashes = @inbounds inds.hashes[perm]
    @inbounds for i in keys(inds.slots)
        s = inds.slots[i]
        if s > 0
            inds.slots[i] = perm[s]
        end
    end
    permute!(dict.values, perm)
    return dict
end