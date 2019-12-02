"""
    AbstractDictionary{I, T}

Abstract type for a dictionary between unique indices of type `I` to elements of type `T`.

At minimum, an `AbstractDictionary` must implement:

 * `getindex(::AbstractDictionary{I, T}, ::I) --> T`
 * `isassigned(::AbstractDictionary{I}, ::I) --> Bool`
 * `keys(::AbstractDictionary{I, T}) --> AbstractIndices{I}`

If values can be set/mutated, then an `AbstractDictionary` should implement:

 * `issettable(::AbstractDictionary)` (returning `true`)
 * `setindex!(dict::AbstractDictionary{I, T}, ::T, ::I}` (returning `dict`)

If arbitrary indices can be added to or removed from the dictionary, implement:

 * `isinsertable(::AbstractDictionary)` (returning `true`)
 * `insert!(dict::AbstractDictionary{I, T}, ::I, ::T}` (returning `dict`)
 * `delete!(dict::AbstractDictionary{I, T}, ::I}` (returning `dict`)
"""
abstract type AbstractDictionary{I, T}; end
abstract type AbstractIndices{I} <: AbstractDictionary{I, I}; end

Base.eltype(d::AbstractDictionary) = eltype(typeof(d))
Base.eltype(::Type{<:AbstractDictionary{I, T}}) where {I, T} = T
Base.keytype(d::AbstractDictionary) = keytype(typeof(d))
Base.keytype(::Type{<:AbstractDictionary{I, T}}) where {I, T} = I

function Base.keys(dict::AbstractDictionary)
    error("Every AbstractDictionary type must define a method for `keys`: $(typeof(dict))")
end

@propagate_inbounds function Base.getindex(dict::AbstractDictionary{I}, i::I) where {I}
    if !(istokenizable(dict))
        error("Every AbstractDictionary type must define a method for `getindex`: $(typeof(dict))")
    end

    (hastoken, token) = gettoken(dict, i)
    @boundscheck if !hastoken
        throw(IndexError("Dictionary does not contain index: $i"))
    end
    return @inbounds gettokenvalue(dict, token)
end

@inline function Base.iterate(dict::AbstractDictionary{I, T}, s...) where {I, T}
    if istokenizable(dict)
        tmp = iteratetoken(keys(dict), s...)
        tmp === nothing && return nothing
        (t, s2) = tmp
        return (gettokenvalue(dict, t), s2)
    else
        tmp = iterate(keys(dict), s...)
        tmp === nothing && return nothing
        (i, s2) = tmp
        return (@inbounds dict[i], s2)
    end
end

Base.length(d::AbstractDictionary) = length(keys(d))
Base.IteratorSize(d::AbstractDictionary) = Base.IteratorSize(keys(d))

Base.checkindex(d::AbstractDictionary{I}, i) where {I} = checkindex(d, convert(I, i))
Base.checkindex(d::AbstractDictionary{I}, i::I) where {I} = checkindex(keys(d), i)

## Comparisons

# dictionaries are isequal if they iterate in the same order
function Base.isequal(d1::AbstractDictionary, d2::AbstractDictionary)
    if d1 === d2
        return true
    end

    if sharetokens(d1, d2)
        @inbounds for t in tokens(d1)
            if !isequal(gettokenvalue(d1, t), gettokenvalue(d2, t))
                return false
            end
        end
        return true
    end

    if length(d1) != length(d2)
        return false
    end

    for (p1, p2) in zip(pairs(d1), pairs(d2))
        if !isequal(p1, p2)
            return false
        end
    end

    return true
end

# `==` doesn't care about the iteration order. Keys must be `isequal` and values `==`
function Base.:(==)(d1::AbstractDictionary, d2::AbstractDictionary)
    if d1 === d2
        return true
    end

    if sharetokens(d1, d2)
        @inbounds for t in tokens(d1)
            if gettokenvalue(d1, t) != gettokenvalue(d2, t)
                return false
            end
        end
        return true
    end

    if length(d1) != length(d2)
        return false
    end

    if istokenizable(d2)
        for (i,v) in pairs(d1)
            (hastoken, token) = gettoken(d2, i)
            if !hastoken || v != gettokenvalue(d2, token)
                return false
            end
        end
    else
        for (i,v) in pairs(d1)
            if !haskey(d2, i) || v != d2[i]
                return false
            end
        end
    end

    return true
end

# Lexical ordering based on iteration (of pairs - lesser key takes priority over lesser value, as implmeneted in `cmp(::Pair)`)
function Base.isless(dict1::AbstractDictionary, dict2::AbstractDictionary)
    if sharetokens(dict1, dict2)
        @inbounds for t in tokens(dict1)
            c = cmp(gettokenvalue(dict1, t), gettokenvalue(dict2, t))
            if c == -1
                return true
            elseif c == 1
                return false
            end
        end
        return false # they are isequal
    end

    # We want to iterate... until one is longer than the other (no `zip`)
    pairdict1 = pairs(dict1)
    pairdict2 = pairs(dict2)
    tmp1 = iterate(pairdict1)
    tmp2 = iterate(pairdict2)
    while tmp1 !== nothing
        if tmp2 === nothing
            return false # shorter collections are isless in lexical ordering
        end
        (p1, s1) = tmp1
        (p2, s2) = tmp2
        c = cmp(p1, p2)
        
        if c == -1
            return true
        elseif c == 1
            return false
        end

        tmp1 = iterate(pairdict1, s1)
        tmp2 = iterate(pairdict2, s2)
    end
    return tmp2 !== nothing # shorter collections are isless in lexical ordering
end

function Base.cmp(dict1::AbstractDictionary, dict2::AbstractDictionary)
    if sharetokens(dict1, dict2)
        @inbounds for t in tokens(dict1)
            c = cmp(gettokenvalue(dict1, t), gettokenvalue(dict2, t))
            if c == -1
                return -1
            elseif c == 1
                return 1
            end
        end
        return 0
    end

    # We want to iterate... until one is longer than the other (no `zip`)
    pairdict1 = pairs(dict1)
    pairdict2 = pairs(dict2)
    tmp1 = iterate(pairdict1)
    tmp2 = iterate(pairdict2)
    while tmp1 !== nothing
        if tmp2 === nothing
            return 1 # shorter collections are isless in lexical ordering
        end
        (p1, s1) = tmp1
        (p2, s2) = tmp2
        c = cmp(p1, p2)
        
        if c == -1
            return -1
        elseif c == 1
            return 1
        end

        tmp1 = iterate(pairdict1, s1)
        tmp2 = iterate(pairdict2, s2)
    end
    if tmp2 === nothing # shorter collections are isless in lexical ordering
        return 0
    else
        return -1
    end
end

## Hashing

function Base.hash(dict::AbstractDictionary, h::UInt)
    h1 = h
    h2 = h
    for (i, v) in pairs(dict)
        h1 = hash(i, h1)
        h2 = hash(v, h2)
    end
    
    return hash(hash(UInt === UInt64 ? 0x8955a87bc313a509 : 0xa9cff5d1, h1), h2)
end

## unique returns an Indices

function Base.unique(d::AbstractDictionary)
    out = empty(d, eltype(d)) # an AbstractIndices
    for x in d
        set!(out, x)
    end
    return out
end

### Settable interface

"""
    issettable(dict::AbstractDictionary)

Return `true` if the dictionary `dict` obeys the settable interface, or `false` otherwise.

A mutable dictionary is one where the *values* can be modified (but not necessarily the
indices). The mutable interface requires the dictionary to implement:

 * `setindex!(dict::AbstractDictionary{I, T}, value::I, index::T)`

New settable dictionaries are primarily created through the `similar` function (for
unitialized values), as well as `fill`, `zeros`, `ones`, `trues` and `falses` (for
initialized values).

See also `isinsertable`.
"""
issettable(::AbstractDictionary) = false

function Base.isassigned(dict::AbstractDictionary{I}, i::I) where {I}
    if !(istokenizable(dict))
        error("Every settable AbstractDictionary type must define a method for `isassigned`: $(typeof(dict))")
    end

    (hasindex, token) = gettoken(dict, i)
    if hasindex
        return istokenassigned(dict, token)
    else
        return false
    end
end

function Base.setindex!(dict::AbstractDictionary{I, T}, value::T, i::I) where {I, T}
    if !(istokenizable(dict))
        error("Every settable AbstractDictionary type must define a method for `setindex!`: $(typeof(dict))")
    end

    (hastoken, token) = gettoken(dict, i)
    @boundscheck if !hastoken
        throw(IndexError("Dictionary does not contain index: $i"))
    end
    settokenvalue!(dict, token, value)
    return dict
end

# similar is the primary way to construct an `issettable` dictionary, and allows us to write
# generic "factories" like `fill`, `copy`, `zeros`...

"""
    similar(d::AbstractDictionary, [T=eltype(d)])

Construct a new `issettable` dictionary with identical `keys` as `d` and an element type of
`T`. The initial values are unitialized/undefined.
"""
Base.similar(d::AbstractDictionary) = similar(keys(d), eltype(d))
Base.similar(d::AbstractDictionary, ::Type{T}) where {T} = similar(keys(d), T)

# fill! and fill

function Base.fill!(d::AbstractDictionary, value)
    for t in tokens(d)
        settokenvalue!(d, t, value)
    end
    return d
end

"""
    fill(value, d::AbstractDictionary, [T = typeof(value)])

Construct a new `issettable` dictionary with identical `keys` as `d` and all elements
initialized to `value`.

An element type can optionally be provided, which can be useful for constructing containers
that accept different types of values, for example `fill(d, missing, Union{Missing, Bool})`.
"""
Base.fill(value, d::AbstractDictionary) = fill(value, d, typeof(value))
function Base.fill(value, indices::AbstractDictionary, ::Type{T}) where {T}
    out = similar(keys(indices), T)
    fill!(out, value)
    return out
end

# zeros, ones, falses, trues
Base.zeros(d::AbstractDictionary) = zeros(Float64, d)
Base.zeros(::Type{T}, d::AbstractDictionary) where {T} = fill(zero(T), d, T)

Base.ones(d::AbstractDictionary) = ones(Float64, d)
Base.ones(::Type{T}, d::AbstractDictionary) where {T} = fill(one(T), d, T)

Base.falses(d::AbstractDictionary) = falses(Bool, d)
Base.falses(::Type{T}, d::AbstractDictionary) where {T} = fill(false, d, T) # T could be `Union{Missing, Bool}`, for example

Base.trues(d::AbstractDictionary) = trues(Bool, d)
Base.trues(::Type{T}, d::AbstractDictionary) where {T} = fill(true, d, T) # T could be `Union{Missing, Bool}`, for example

# rand

# Drawing FROM a dictionary requires is to create a `Sampler(rng, dict, Val(1/Inf))` and overload `rand(rng, S)`
# We need to think about how this might happen efficiently. `randtoken`?
# This should resolve an ambiguity with another convenience method below...
Random.rand(rng::AbstractRNG, dict::AbstractDictionary) = error("Sampling from dictionaries is not yet implemented. You can create a random dictionary with `rand([rng], sampler, dict)`, e.g. `rand(1:10, dict)`")

# Creating a random dictionary

function Random.rand!(dict::AbstractDictionary; S = Random.Sampler(Random.GLOBAL_RNG, eltype(dict), Val(1)))
    map!(() -> rand(Random.GLOBAL_RNG, S), dict)
    return dict
end

function Random.rand!(rng::AbstractRNG, dict::AbstractDictionary; S = Random.Sampler(rng, eltype(dict), Val(1)))
    map!(() -> rand(rng, S), dict)
    return dict
end

sampletype(::Random.Sampler{T}) where {T} = T

Random.rand(S, dict::AbstractDictionary) = rand(Random.GLOBAL_RNG, S, dict)

function Random.rand(rng::AbstractRNG, S, dict::AbstractDictionary)
    sampler = Random.Sampler(rng, S, Val(Inf))
    out = similar(dict, sampletype(sampler))
    rand!(rng, out, S=sampler)
    return out
end

# randn
Random.randn!(dict::AbstractDictionary) = randn!(Random.GLOBAL_RNG, dict)

function Random.randn!(rng::AbstractRNG, dict::AbstractDictionary)
    map!(() -> randn(rng, eltype(dict)), dict)
    return dict
end

Random.randn(dict::AbstractDictionary) = randn(Random.GLOBAL_RNG, Float64, dict)
Random.randn(::Type{T}, dict::AbstractDictionary) where {T} = randn(Random.GLOBAL_RNG, T, dict)
Random.randn(rng::AbstractRNG, dict::AbstractDictionary) = randn(rng, Float64, dict)

function Random.randn(rng::AbstractRNG, ::Type{T}, dict::AbstractDictionary) where {T}
    out = similar(dict, T)
    randn!(rng, out)
    return out
end


# Copying - note that this doesn't necessarily copy the indices! (`copy(keys(dict))` can do that)
function Base.copy(d::AbstractDictionary)
    out = similar(d)
    copyto!(out, d)
    return out
end

function Base.copyto!(out::AbstractDictionary, d::AbstractDictionary)
    map!(identity, out, d)
end
