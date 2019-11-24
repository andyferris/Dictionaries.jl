"""
    AbstractDictionary{I, T}

Abstract type for a dictionary between unique indices of type `I` to elements of type `T`.

At minimum, an `AbstractDictionary` must implement:

 * `getindex(::AbstractDictionary{I, T}, ::I) --> T`
 * `isassigned(::AbstractDictionary{I}, ::I) --> Bool`
 * `keys(::AbstractDictionary{I, T}) --> AbstractIndices{I}`
 * A constructor `MyDictionary(values, indices)` returning a dictionary with the
   given `indices` and values set to `values`, matched by iteration. Alternatively, `values`
   may be a scalar in the broadcasting sense, where all elements are set to the same value.

If values can be set/mutated, then an `AbstractDictionary` should implement:

 * `issettable(::AbstractDictionary)` (returning `true`)
 * `setindex!(dict::AbstractDictionary{I, T}, ::T, ::I}` (returning `dict`)
 * `isassigned(dict::AbstractDictionary{I}, ::I) --> Bool`
 * A constructor `MyDictionary(undef, indices)` returning a dictionary with the
   given `indices` and unitialized values.

If arbitrary indices can be added to or removed from the dictionary, implement:

 * `isinsertable(::AbstractDictionary)` (returning `true`)
 * `insert!(dict::AbstractDictionary{I, T}, ::I, ::T}` (returning `dict`)
 * `delete!(dict::AbstractDictionary{I, T}, ::I}` (returning `dict`)
 * A zero-argument constructor `MyDictionary()` returning an empty `MyDictionary`.
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

"""
    issettable(dict::AbstractDictionary)

Return `true` if the dictionary `dict` obeys the settable interface, or `false` otherwise.

A mutable dictionary is one where the *values* can be modified (but not necessarily the
indices). The mutable interface requires the dictionary to implement:

* `setindex!(dict, value, index)`
* `isassigned(dict, index)`
* A constructor `MyDictionary(undef, indices)` returning a dictionary with the
  given `indices` and unitialized values.

See also `isinsertable`.
"""
issettable(::AbstractDictionary) = false

function Base.isassigned(indices::AbstractIndices{I}, i::I) where {I}
    return i in indices
end

function Base.isassigned(dict::AbstractDictionary{I}, i::I) where {I}
    (hasindex, token) = gettoken(dict, i)
    return istokenassigned(dict, token)
end

function Base.setindex!(d::AbstractDictionary{I, T}, value::T, i::I) where {I, T}
    (hastoken, token) = gettoken(d, i)
    @boundscheck if !hastoken
        throw(IndexError("Dictionary does not contain index: $i"))
    end
    settokenvalue!(d, token, value)
    return d
end

# dictionaries are isequal if they iterate in the same order
function Base.isequal(d1::AbstractDictionary, d2::AbstractDictionary)
    if d1 === d2
        return true
    end

    if length(d1) != length(d2)
        return false
    end

    # TODO can we tokenize this?
    for (i1, i2) in zip(keys(d1), keys(d2))
        if !isequal(i1, i2) || !isequal(d1[i1], d2[i2])
            return false
        end
    end

    return true
end

function Base.:(==)(i1::AbstractDictionary, i2::AbstractDictionary)
    error("The semantic for ``==` is not yet fixed in Dictionaries.jl (regarding dictionaries with the same elements but different orderings). If you have an opinion, please contact the package maintainers.")
end

function Base.show(io::IO, d::AbstractDictionary)
    print(io, "$(length(d))-element $(typeof(d))")
    n_lines = displaysize(io)[1] - 5
    lines = 1
    for k in keys(d)
        if isassigned(d, k)
            valstring = string(d[k])
        else
            valstring = "#undef"
        end
        #print(io, "\n ", k, " │ ", valstring)
        print(io, "\n ", k, " => ", valstring)
        lines += 1
        if lines > n_lines
            print(io, "\n ⋮ => ⋮")
            break
        end
    end
end

# Traits
# ------
#
# It would be nice to know some things about the interface supported by a given AbstractDictionary
#
#  * Can you mutate the values using `setindex!`?
#  * Can you mutate the keys? How? Is it like a dictionary (`delete!`, and `setindex!` doing update/insert), or a list (push, pop, insertat / deleteat)?
#
# For Indices, you are mutating both keys and values in-sync, but you can't use `setindex!`

# Factories
# ---------
# Base provides these factories:
#  * `similar` - construct dictionary with given eltype and indices, and `undef` values
#  * `empty` - construct container with given eltype and no indices.
#
# StaticArrays seems to indicate that you might want to work at the type level: 
#  * `similar_type`,
#  * `empty_type`, etc..
#
# In reality, for immutable containers you need a way of constructing containers. There are
# a couple of patterns
#  * The `ntuple` / comprehension pattern - a closure is called with the key to get the
#    value, and it is constructed all-at-once (in "parallel", each element independently).
#  * The mutate + publish pattern. Let the user construct a mutable dictionary, then "publish" it
#    to become immutable. More flexible for user (they can fill the container in a loop,
#    so that the element calculations don't have to be independent).
#
# Some considerations
#  * Arrays benefit from small, immutable indices. Being able to reuse the index of e.g. a
#    hash dictionary would be an enormous saving! To do that safely, we'd want to know that the
#    keys won't change. (Possibly a copy-on-write technique could work well here).

Base.similar(d::AbstractDictionary) = similar(d, eltype(d), keys(d))
Base.similar(d::AbstractDictionary, ::Type{T}) where {T} = similar(d, T, keys(d))
Base.similar(d::AbstractDictionary, i::AbstractIndices) = similar(d, eltype(d), i)

Base.empty(d::AbstractDictionary) = empty(d, eltype(d))
Base.empty(d::AbstractDictionary, ::Type{T}) where {T} = empty(d, keytype(d), T)

# zeros
Base.zeros(d::AbstractDictionary) = zeros(d, Float64, keys(d))
Base.zeros(::Type{T}, i::AbstractIndices) where {T} = zeros(i, T, i)
Base.zeros(d::AbstractDictionary, ::Type{T}) where {T} = zeros(d, T, keys(d))
Base.zeros(d::AbstractDictionary, i::AbstractIndices) = zeros(d, i, Float64)
function Base.zeros(d::AbstractDictionary, ::Type{T}, i::AbstractIndices) where {T}
    out = similar(d, T, i)
    fill!(out, convert(T, 0))
    return out
end

# ones
Base.ones(d::AbstractDictionary) = ones(d, Float64, keys(d))
Base.ones(::Type{T}, i::AbstractIndices) where {T} = ones(i, T, i)
Base.ones(d::AbstractDictionary, ::Type{T}) where {T} = ones(d, T, keys(d))
Base.ones(d::AbstractDictionary, i::AbstractIndices) = ones(d, i, Float64)
function Base.ones(d::AbstractDictionary, ::Type{T}, i::AbstractIndices) where {T}
    out = similar(d, T, i)
    fill!(out, convert(T, 1))
    return out
end

# falses
Base.falses(d::AbstractDictionary) = falses(d, keys(d))
function Base.falses(d::AbstractDictionary, i::AbstractIndices)
    out = similar(d, Bool, i)
    fill!(out, false)
    return out
end

# trues?

# fill! and fill

function Base.fill!(d::AbstractDictionary, value)
    for t in tokens(d)
        settokenvalue!(d, t, value)
    end
    return d
end

Base.fill(value, indices::AbstractIndices) = fill(value, typeof(value), indices)

function Base.fill(value, ::Type{T}, indices::AbstractIndices) where {T}
    out = similar(indices, T, indices)
    fill!(out, value)
    return out    
end

# Conversion to-and-from AbstractDicts
function (::Type{T})(d::AbstractDict) where {T <: AbstractDictionary}
    return T(values(d), keys(d))
end

#function (::Type{T})(d::AbstractDictionary) where {T <: Dict}
#    return T(pairs(d))
#end

# Copying
function Base.copy(d::AbstractDictionary)
    out = similar(d)
    copyto!(out, d)
    return out
end

function Base.copyto!(out::AbstractDictionary, d::AbstractDictionary)
    map!(identity, out, d)
end
