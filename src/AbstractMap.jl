"""
    AbstractMap{I, T}

Abstract type for a mapping between unique indices of type `I` to elements of type `T`.

At minimum, an `AbstractMap` should implement:

 * `getindex(::AbstractMap{I, T}, ::I) --> I`
 * `keys(::AbstractMap{I, T}) --> AbstractIndices{I}`
"""
abstract type AbstractMap{I, T}; end

Base.eltype(m::AbstractMap) = eltype(typeof(m))
Base.eltype(::Type{<:AbstractMap{I, T}}) where {I, T} = T
Base.keytype(m::AbstractMap) = keytype(typeof(m))
Base.keytype(::Type{<:AbstractMap{I, T}}) where {I, T} = I

"""
    AbstractIndices{I} <: AbstractMap{I, I}

Abstract type for the unique keys of an `AbstractMap`. It is itself an `AbstractMap` which
for which `getindex` is idempotent, such that `indices[i] = i`. This is a generalization of
`Slice`.

At minimum, an `AbstractIndices` should implement:

 * The `iterate` protocol, returning unique values of type `I`.
 * `length(::AbstractIndices) --> Integer`
"""
abstract type AbstractIndices{I} <: AbstractMap{I, I}; end

Base.unique(i::AbstractIndices) = i

@inline function Base.getindex(indices::AbstractIndices{I}, i::I) where {I}
    @boundscheck checkindex(indices, i)
    return i
end

Base.keys(i::AbstractIndices) = i

struct IndexError
	msg::String
end


function checkindex(indices::AbstractIndices{I}, i::I) where {I}
	if i ∉ indices
		throw(IndexError("Index $i not found in indices $indices"))
	end
end
checkindex(indices::AbstractIndices{I}, i) where {I} = convert(I, i)


function Base.show(io::IO, m::AbstractMap)
    print(io, "$(length(m))-element $(typeof(m))")
    for (k, v) in pairs(m)
    	println(io, "\n  ", k, " => ", v)
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

