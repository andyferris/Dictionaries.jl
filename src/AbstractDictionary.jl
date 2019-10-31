"""
    AbstractDictionary{I, T}

Abstract type for a dictionary between unique indices of type `I` to elements of type `T`.

At minimum, an `AbstractDictionary` should implement:

 * `getindex(::AbstractDictionary{I, T}, ::I) --> T`
 * `keys(::AbstractDictionary{I, T}) --> AbstractIndices{I}`

If values can be mutated, then an `AbstractDictionary` should implement:

 * `ismutable(::AbstractDictionary)` (returning `true`)
 * `setindex!(dict::AbstractDictionary{I, T}, ::T, ::I}` (returning `dict`)

If arbitrary indices can be added to or removed from the dictionary, implement:

 * `isinsertable(::AbstractDictionary)` (returning `true`)
 * `insert!(dict::AbstractDictionary{I, T}, ::T, ::I}` (returning `dict`)
 * `delete!(dict::AbstractDictionary{I, T}, ::I}` (returning `dict`)
"""
abstract type AbstractDictionary{I, T}; end

Base.eltype(d::AbstractDictionary) = eltype(typeof(d))
Base.eltype(::Type{<:AbstractDictionary{I, T}}) where {I, T} = T
Base.keytype(d::AbstractDictionary) = keytype(typeof(d))
Base.keytype(::Type{<:AbstractDictionary{I, T}}) where {I, T} = I

function Base.keys(d::AbstractDictionary)
    error("Every AbstractDictionary type must define a method for `keys`: $(typeof(d))")
end

function Base.getindex(d::AbstractDictionary{I}, i::I) where {I}
    error("Every AbstractDictionary type must define a method for `getindex`: $(typeof(d))")
end

ismutable(::AbstractDictionary) = false

function Base.setindex!(d::AbstractDictionary{I, T}, ::T, ::I) where {I, T}
    if ismutable(d)
        error("setindex! needs to be defined for mutable dictionary: $(typeof(d))")
    else
        error("Dictionary is not mutable: $(typeof(d))")
    end
end

Base.length(d::AbstractDictionary) = length(keys(d))

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

"""
    AbstractIndices{I} <: AbstractDictionary{I, I}

Abstract type for the unique keys of an `AbstractDictionary`. It is itself an `AbstractDictionary` for
which `getindex` is idempotent, such that `indices[i] = i`. (This is a generalization of
`Base.Slice`).

At minimum, an `AbstractIndices{I}` should implement:

 * The `iterate` protocol, returning unique values of type `I`.
 * `in`, such that `in(i, indices)` implies there is an element of `indices` which `isequal` to `i`.

While an `AbstractIndices` object is a dictionary, the value corresponding to each index is
fixed, so `ismutable(::AbstractIndices) = false` and `setindex!` is never defined.

If arbitrary indices can be added or removed from the set, implement:

 * `insert!`
 * `delete!`
 * `isinsertable`
"""
abstract type AbstractIndices{I} <: AbstractDictionary{I, I}; end

@inline function Base.getindex(indices::AbstractIndices{I}, i::I) where {I}
    @boundscheck checkindex(indices, i)
    return i
end

function Base.setindex!(i::AbstractIndices{I}, ::I, ::I) where {I}
    error("Indices are not mutable: $(typeof(i))")
end

Base.keys(i::AbstractIndices) = i

function Base.iterate(i::AbstractIndices, s...)
    error("All AbstractIndices must define `iterate`: $(typeof(i))")
end

# Fallback definition would be rediculously slow. There shouldn't be many
# AbstractIndex types that rely on iteration for this.
function Base.in(i::I, indices::AbstractIndices{I}) where I
    error("All AbstractIndices must define `in`: $(typeof(i))")
end

function Base.in(i, indices::AbstractIndices{I}) where I
    return convert(I, i) in indices
end

Base.unique(i::AbstractIndices) = i

struct IndexError <: Exception
	msg::String
end


function checkindex(indices::AbstractIndices{I}, i::I) where {I}
	if i ∉ indices
		throw(IndexError("Index $i not found in indices $indices"))
	end
end
checkindex(indices::AbstractIndices{I}, i) where {I} = convert(I, i)

function checkindices(indices::AbstractIndices, inds)
    if !(inds ⊆ indices)
        throw(IndexError("Indices $inds are not a subset of $indices"))
    end
end

function Base.show(io::IO, d::AbstractDictionary)
    print(io, "$(length(d))-element $(typeof(d))")
    for (k, v) in pairs(d)
    	print(io, "\n  ", k, " => ", v)
    	# TODO * aligment of keys and values
    	#      * fit on single terminal screen
    end
end

function Base.show(io::IO, i::AbstractIndices)
    print(io, "$(length(i))-element $(typeof(i))")
    for k in i
        print(io, "\n  ", k)
        # TODO * aligment of keys and values
        #      * fit on single terminal screen
    end
end

# Indices are isequal if they iterate in the same order
function Base.isequal(i1::AbstractIndices, i2::AbstractIndices)
    if i1 === i2
        return true
    end

    if length(i1) != length(i2)
        return false
    end

    # TODO can we tokenize this?
    for (j1, j2) in zip(i1, i2)
        if !isequal(j1, j2)
            return false
        end
    end

    return true
end

# For now, indices are == if they are isequal or issetequal
function Base.:(==)(i1::AbstractIndices, i2::AbstractIndices)
    error("The semantic for ``==` is not yet fixed in Dictionaries.jl (regarding dictionaries with the same elements but different orderings). If you have an opinion, please contact the package maintainers.")
    #=if i1 === i2
        return true
    end

    if length(i1) != length(i2)
        return false
    end

    for i in i1
        if !(i in i2)
            return false
        end
    end

    return true=#
end

# TODO hash and isless for indices and dictionaries.


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

Base.empty(d::AbstractIndices) = empty(d, eltype(d))

Base.empty(d::AbstractDictionary) = empty(d, keytype(d), eltype(d))
Base.empty(d::AbstractDictionary, ::Type{T}) where {T} = empty(d, keytype(d), T)