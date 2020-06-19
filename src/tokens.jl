## A simple token-based interface

"""
    istokenizable(indices::AbstractIndices)

Return `true` if the indices `indices` obeys the token interface, or `false` otherwise.

A token is a more efficient way of refering to an element of `indices`. Using tokens may
help avoid multiple index lookups for a single operation.

A tokenizable indices must implement:

 * `tokentype(indices) --> T::Type`
 * `iteratetoken(indices, s...)` iterates the tokens of `indices`, like `iterate`
 * `gettoken(indices, i) --> (hasindex::Bool, token)`
 * `gettokenvalue(indices, token)` returning the value of the index at `token`

An `isinsertable` tokenizable indices must implement

 * `gettoken!(indices, i) --> (hadtoken::Bool, token)`
 * `deletetoken!(indices, token) --> indices`

    istokenizable(dict::AbstractDictionary)

Return `true` if the dictionary `dict` obeys the token interface, or `false` otherwise.

A token is a more efficient way of refering to an element of `dict`. Using tokens may
help avoid multiple index lookups for a single operation.

An tokenizable dictionary must implement:

 * `keys(dict)` must be `istokenizable` and share tokens with `dict`
 * `gettokenvalue(dict, token)` returning the dictionary value at `token`
 * `istokenassigned(dict, token) --> Bool` 

An `issettable` tokenizable dictionary must implement:

 * `settokenvalue!(dict, token)`

An `isinsertable` tokenizable dictionary must implement:

 * `gettoken!(dict, i) --> (hadtoken::Bool, token)`
 * `deletetoken!(dict, token) --> dict`
"""
istokenizable(d::AbstractIndices) = false
istokenizable(d::AbstractDictionary) = istokenizable(keys(d))

"""
    tokentype(dict)

Return the type of the tokens retrieved via `gettoken` for dictionary `dict`, for
dictionaries that are `istokenizable`.
"""
tokentype(d::AbstractDictionary) = tokentype(keys(d))

function tokentype(inds::AbstractIndices)
    if istokenizable(inds)
        error("`tokentype` needs to be defined for tokenizable indices: $(typeof(inds))")
    else
        error("Indices are not tokenizable: $(typeof(inds))")
    end
end

"""
    IndicesTokens(indices)

Return a dictionary mapping from `i ∈ indices` to a valid token.
""" 
struct IndicesTokens{I, T, Parent <: AbstractIndices{I}} <: AbstractDictionary{I, T}
    parent::Parent
end

IndicesTokens(indices::AbstractIndices{I}) where {I} = IndicesTokens{I}(indices)
IndicesTokens{I}(indices::AbstractIndices{I}) where {I} = IndicesTokens{I, tokentype(indices)}(indices)

Base.parent(ts::IndicesTokens) = getfield(ts, :parent)

Base.keys(ts::IndicesTokens) = parent(ts)

# These containers are obviously tokenizable (but never settable or insertable)
istokenizable(::IndicesTokens) = true
tokentype(::IndicesTokens{<:Any, T}) where {T} = T
tokens(ts::IndicesTokens) = ts
istokenassigned(ts::IndicesTokens, t) = istokenassigned(parent(ts), t)
@propagate_inbounds iteratetoken(ts::IndicesTokens, s...) = iteratetoken(parent(ts), s...)
@propagate_inbounds gettoken(ts::IndicesTokens{I}, i::I) where {I} = gettoken(parent(ts), i)
gettokenvalue(ts::IndicesTokens, t) = t

Base.IteratorSize(ts::IndicesTokens) = Base.IteratorSize(parent(ts))
Base.length(ts::IndicesTokens) = Base.length(parent(ts))

"""
    tokens(dict::AbstractDictionary)

Return a new dictionary mapping from the `keys` of `dict` to a "token". The token can be
used to fetch a value with `gettokenvalue`. For mutable containers, the token can be used to
overwrite a value with `settokenvalue!`.
"""
@inline tokens(d::AbstractDictionary) = tokens(keys(d))
@inline function tokens(i::AbstractIndices{I}) where {I}
    if istokenizable(i)
        return IndicesTokens{I, tokentype(i), typeof(i)}(i)
    else
        return i
    end
end


"""
    Tokenized(dict)

Return an indexable container mapping from the `token ∈ tokens(dict)` to the values of
`dict`. 
"""
struct Tokenized{Parent <: AbstractDictionary}
    parent::Parent
end

Base.parent(dict::Tokenized) = getfield(dict, :parent)

@propagate_inbounds function Base.getindex(d::Tokenized, t)
    return gettoken(parent(d), t)
end

function Base.isassigned(d::Tokenized, t)
    return istokenassigned(parent(d), t)
end

@propagate_inbounds function Base.setindex!(d::Tokenized, value, t)
    return settokenvalue!(parent(d), t, value)
end


"""
    tokenized(dict::AbstractDictionary)

For `istokenizable` dictionary `dict`, return a container that supports
`getindex(dict, token)` and `isassigned(dict, token)`, where `token ∈ tokens(dict)`.

If `issettable(dict)` then the result should also support `setindex!(dict, value, token)`.

Note: the output is not necessarily an `AbstractDictionary`.
"""
function tokenized(d::AbstractDictionary)
    if istokenizable(d)
        return Tokenized{tokentype(d), eltype(d), typeof(d)}(d)
    else
        return d
    end
end


"""
    gettoken(dict, i)

Return the tuple `(hasindex, token)`, where `hasindex` is `true` if `i` exists in `dict`.
The `token` can be used to retrieve a value using the `gettokenvalue` function. You can
check if a token is assigned to a valid Julia object (i.e. not `#undef`) via
`istokenassigned`.

Settable (i.e. mutable) dictionaries allow you to set a corresponding value via the
`settokenvalue!` function (see the `issettable` trait).

Insertable dictionaries provide the `gettoken!` function (see the `isinsertable` trait).
"""
@propagate_inbounds function gettoken(inds::AbstractIndices{I}, i::I) where I
    if istokenizable(inds)
        error("gettoken needs to be defined for tokenizable indices: $(typeof(inds))")
    end

    @boundscheck if i ∉ inds
        return (false, i)
    end
    return (true, i)
end

@propagate_inbounds function gettoken(d::AbstractDictionary{I}, i::I) where I
    return gettoken(keys(d), i)
end

@propagate_inbounds function gettoken(d::AbstractDictionary{I}, i) where I
    return gettoken(d, convert(I, i))
end

@propagate_inbounds function gettokenvalue(d::AbstractDictionary, token)
    if istokenizable(d)
        error("gettokenvalue needs to be defined for tokenizable $(d isa AbstractIndices ? "indices" : "dictionary"): $(typeof(d))")
    end

    return d[token]
end

@propagate_inbounds function istokenassigned(d::AbstractDictionary, token)
    if istokenizable(d)
        error("istokenassigned needs to be defined for tokenizable $(d isa AbstractIndices ? "indices" : "dictionary"): $(typeof(d))")
    end

    return isassigned(d, token)
end

@propagate_inbounds function settokenvalue!(d::AbstractDictionary{<:Any,T}, t, value) where {T}
    return settokenvalue!(d, t, convert(T, value))
end

@propagate_inbounds function settokenvalue!(d::AbstractDictionary{<:Any,T}, i, value::T) where {T}
    if !issettable(d)
        error("Cannot mutate values of dictionary: $(typeof(d))")
    end
    if istokenizable(d)
        error("settoken! needs to be defined for settable, tokenizable dictionary: $(typeof(d))")
    end

    return d[i] = value
end

## Check if we can do fast mutual iteration over multiple containers

# I guess someone could overload this method if they can check this faster than O(N),
# but more precise than ===

"""
    sharetokens(dict1, dict2)

Return `true` if `dict1` and `dict2` obviously share tokens, using a test which can be
performed quickly (e.g. O(1) rather than O(N)). Return `false` otherwise.

Note: the test may not be precise, this defaults to `tokens(dict1) === tokens(dict2)`.
"""
sharetokens(i1::AbstractIndices, i2::AbstractIndices) = istokenizable(i1) && i1 === i2
sharetokens(d1, d2) = sharetokens(keys(d1), keys(d2))
sharetokens(d1, d2, ds...) = sharetokens(d1, d2) && sharetokens(d1, ds...)
