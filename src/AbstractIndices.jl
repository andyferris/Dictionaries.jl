"""
    AbstractIndices{I} <: AbstractDictionary{I, I}

Abstract type for the unique keys of an `AbstractDictionary`. It is itself an `AbstractDictionary` for
which `getindex` is idempotent, such that `indices[i] = i`. (This is a generalization of
`Base.Slice`).

At minimum, an `AbstractIndices{I}` should implement:

 * The `iterate` protocol, returning unique values of type `I`.
 * `in`, such that `in(i, indices)` implies there is an element of `indices` which `isequal` to `i`.
 * A one-argument constructor `MyIndices(iter)` that builds indices by iterating `iter`.

While an `AbstractIndices` object is a dictionary, the value corresponding to each index is
fixed, so `ismutable(::AbstractIndices) = false` and `setindex!` is never defined.

If arbitrary indices can be added or removed from the set, implement:

* `isinsertable(::AbstractIndices)` (returning `true`)
* `insert!(indices::AbstractIndices{I}, ::I}` (returning `indices`)
* `delete!(indices::AbstractIndices{I}, ::I}` (returning `indices`)
* A zero-argument constructor `MyIndices()` returning an empty `MyIndices`.
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

function Base.show(io::IO, i::AbstractIndices)
    print(io, "$(length(i))-element $(typeof(i))")
    n_lines = displaysize(io)[1] - 5
    lines = 1
    for k in i
        print(io, "\n ", k)
        lines += 1
        if lines > n_lines
            print(io, "\n ⋮")
            break
        end
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

# TODO factory for empty indices