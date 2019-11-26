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

## Comparisons

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


### Settable interface

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


# Copying
function Base.copy(d::AbstractDictionary)
    out = similar(d)
    copyto!(out, d)
    return out
end

function Base.copyto!(out::AbstractDictionary, d::AbstractDictionary)
    map!(identity, out, d)
end


# Conversion to-and-from AbstractDicts
# TODO rethink this

function (::Type{T})(d::AbstractDict) where {T <: AbstractDictionary}
    return T(values(d), keys(d))
end

#function (::Type{T})(d::AbstractDictionary) where {T <: Dict}
#    return T(pairs(d))
#end

# This should be considered part of the insertable interface...
Base.empty(d::AbstractDictionary) = empty(d, eltype(d))
Base.empty(d::AbstractDictionary, ::Type{T}) where {T} = empty(d, keytype(d), T)
