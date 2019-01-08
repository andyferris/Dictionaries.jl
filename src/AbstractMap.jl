"""
    AbstractMap{I, T}

Abstract type for a mapping between unique indices of type `I` to elements of type `T`.

At minimum, an `AbstractMap` should implement:

 * `getindex(::AbstractMap{I, T}, ::I) --> I`
 * `keys(::AbstractMap{I, T}) --> AbstractIndices{I}`

If arbitrary indices can be added to or removed from the map, implement:

 * `insert!`
 * `delete!`
 * `isinsertable`

If the map can operate as a list (with keys forming a unit range), implement:

 * `push!`
 * `pop!`
 * `islist`
"""
abstract type AbstractMap{I, T}; end

Base.eltype(m::AbstractMap) = eltype(typeof(m))
Base.eltype(::Type{<:AbstractMap{I, T}}) where {I, T} = T
Base.keytype(m::AbstractMap) = keytype(typeof(m))
Base.keytype(::Type{<:AbstractMap{I, T}}) where {I, T} = I

function Base.keys(m::AbstractMap)
    error("All AbstractMaps must define `keys`: $(typeof(m))")
end

function Base.getindex(m::AbstractMap{I}, i::I) where {I}
    error("All AbstractMaps must define `getindex`: $(typeof(m))")
end

Base.length(m::AbstractMap) = length(keys(m))

"""
    AbstractIndices{I} <: AbstractMap{I, I}

Abstract type for the unique keys of an `AbstractMap`. It is itself an `AbstractMap` for
which `getindex` is idempotent, such that `indices[i] = i`. This is a generalization of
`Base.Slice`.

At minimum, an `AbstractIndices` should implement:

 * The `iterate` protocol, returning unique values of type `I`.

If arbitrary indices can be added or removed from the set, implement:

 * `insert!`
 * `delete!`
 * `isinsertable`
"""
abstract type AbstractIndices{I} <: AbstractMap{I, I}; end

@inline function Base.getindex(indices::AbstractIndices{I}, i::I) where {I}
    @boundscheck checkindex(indices, i)
    return i
end

Base.keys(i::AbstractIndices) = i

function Base.iterate(m::AbstractIndices, s...)
    error("All AbstractIndices must define `iterate`: $(typeof(m))")
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

function Base.show(io::IO, m::AbstractMap)
    print(io, "$(length(m))-element $(typeof(m))")
    for (k, v) in pairs(m)
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

# Indices are isequal if they iterate in the same order (TODO optimize?)
Base.isequal(i1::AbstractIndices, i2::AbstractIndices) = all(x -> isequal(x[1], x[2]), zip(i1, i2))

# TODO decide if indices are == if they are isequal or issetequal


# Traits
# ------
#
# It would be nice to know some things about the interface supported by a given AbstractMap
#
#  * Can you mutate the values using `setindex!`?
#  * Can you mutate the keys? How? Is it like a dictionary (`delete`, and `setindex!` doing update/insert), or a list (push, pop, insertat / deleteat)?
#
# For Indices, you are mutating both keys and values in-sync, but you can't use `setindex!`

# Factories
# ---------
# Base provides these factories:
#  * `similar` - construct container with given eltype and indices, and `undef` values
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
#  * The mutate + publish pattern. Let the user construct a mutable Map, then "publish" it
#    to become immutable. More flexible for user (they can fill the container in a loop,
#    so that the element calculations don't have to be independent).
#
# Some considerations
#  * Array's benefit from small, immutable indices. Being able to reuse the index of e.g. a
#    hash map would be an enormous saving! To do that safely, we'd want to know that the
#    keys won't change. (Possibly a copy-on-write technique could work well here).

Base.similar(m::AbstractMap) = similar(m, eltype(m), keys(m))
Base.similar(m::AbstractMap, ::Type{T}) where {T} = similar(m, T, keys(m))
Base.similar(m::AbstractMap, i::AbstractIndices) = similar(m, eltype(m), i)

Base.empty(m::AbstractIndices) = empty(m, eltype(m))

Base.empty(m::AbstractMap) = empty(m, keytype(m), eltype(m))
Base.empty(m::AbstractMap, ::Type{T}) where {T} = empty(m, keytype(m), T)