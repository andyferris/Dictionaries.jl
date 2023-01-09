"""
    isinsertable(dict::AbstractDictionary)

Return `true` if `dict` supports the insertable interface, or `false` otherwise. The primary
functions `dict` needs to implement for the insertable interface are:

 * `insert!(dict, i, value)` - add a new `value` at index `i` (will error if index exists)
 * `delete!(dict, i)` - remove element at index `i` (will error if index does not exist)

Functions `get!`, `set!` and `unset!` are also provided for common operations where you are
not sure if an index exists or not. New insertable dictionaries are primarily generated via
the `empty` function.

See also `issettable` and `istokenizable`.
"""
isinsertable(::AbstractDictionary) = false

"""
    isinsertable(indices::AbstractIndices)

Return `true` if `indices` supports the insertable interface, or `false` otherwise. The
primary functions a map needs to implement for the insertable interface are:

 * `insert!(indices, i)` - add new index `i` to `indices` (will error if index exists)
 * `delete!(indices, i)` - remove an existing index `i` from `indices` (will error if index does not exist).

Functions `set!` and `unset!` are also provided for common operations where you are not sure
if an index exists or not. New insertable indices are primarily generated via the `empty`
function.
"""
isinsertable(::AbstractIndices) = false

function safe_convert(::Type{I}, i) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    return i2
end

### Underlying token interface functions

"""
    gettoken!(dict, i)

Return the tuple `(hadindex, token)`, where `hadindex` is `true` if `i` previously existed
in `dict`, or `false` otherwise (in which case `dict` was mutated to insert a slot for the
new index `i`). The `token` may be used to retrieve a value using the `gettokenvalue` or set
a corresponding value via the `settokenvalue!`.

See also `gettoken` and `deletetoken!`.
"""
@propagate_inbounds function gettoken!(d::AbstractDictionary{I}, i) where {I}
    return gettoken!(d, convert(I, i))
end

function gettoken!(d::AbstractDictionary{I}, i::I) where {I}
    if isinsertable(d)
        error("gettoken! needs to be defined for insertable dictionary: $(typeof(d))")
    else
        error("dictionary not insertable: $(typeof(d))")
    end
end

function gettoken!(d::AbstractIndices{I}, i::I) where {I}
    if isinsertable(d)
        error("gettoken! needs to be defined for insertable indices: $(typeof(d))")
    else
        error("indices not insertable: $(typeof(d))")
    end
end

"""
    deletetoken!(dict, token)

Remove the slot of the dictionary at `token`.

See also `gettoken` and `gettoken!`.
"""
function deletetoken!(d::AbstractDictionary, token)
    if isinsertable(d)
        error("deletetoken! needs to be defined for insertable dictionary: $(typeof(d))")
    else
        error("dictionary not insertable: $(typeof(d))")
    end
end

function deletetoken!(d::AbstractIndices, token)
    if isinsertable(d)
        error("deletetoken! needs to be defined for insertable indices: $(typeof(d))")
    else
        error("indices not insertable: $(typeof(d))")
    end
end

### User-facing scalar insertion/deletion

"""
    insert!(indices::AbstractIndices, i)

Insert the new index `i` into `indices`. An error is thrown if `i` already exists.
"""
@propagate_inbounds function Base.insert!(indices::AbstractIndices{I}, i) where {I}
    i2 = safe_convert(I, i)
    return insert!(indices, i2)
end

function Base.insert!(indices::AbstractIndices{I}, i::I) where {I}
    (hadindex, token) = gettoken!(indices, i)
    if hadindex
        throw(IndexError("Indices already contains index: $i"))
    end
    return indices
end

"""
    insert!(dict::AbstractDictionary, i, value)

Insert the `value` at new index `i` into `dict`. An error is thrown if index `i` already
exists.

Hint: Use `setindex!` to update an existing value, and `set!` to perform an "upsert"
(update-or-insert) operation.
"""
function Base.insert!(d::AbstractDictionary{I}, i, value) where {I}
    i2 = safe_convert(I, i)
    return insert!(d, i2, value)
end

function Base.insert!(d::AbstractDictionary{I, T}, i::I, value) where {I, T}
    return insert!(d, i, convert(T, value))
end

function Base.insert!(d::AbstractDictionary{I, T}, i::I, value::T) where {I, T}
    (hadtoken, token) = gettoken!(d, i)
    if hadtoken
        throw(IndexError("Dictionary already contains index: $i"))
    end
    @inbounds settokenvalue!(d, token, value)
    return d
end

# Since `AbstractIndices <: AbstractDictionary` we should still obey the supertype's interface where possible...
function Base.insert!(indices::AbstractIndices{I}, i1::I, i2::I) where {I}
    if isinsertable(indices)
        if isequal(i1, i2)
            return insert!(indices, i1)
        else
            error("Attempted to set distinct key-value pair ($i1, $i2) to indices: $(typeof(indices))")
        end
    else
        error("indices not insertable: $(typeof(indices))")
    end
end

"""
    set!(dict::AbstractDictionary, i, value)

Update or insert the `value` at index `i` into `dict`. Sometimes referred to as an "upsert"
operation.

Hint: Use `setindex!` to exclusively update an existing value, and `insert!` to exclusively
insert a new value. See also `get!`.
"""
@propagate_inbounds function set!(d::AbstractDictionary{I}, i, value) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    return set!(d, i2, value)
end

function set!(d::AbstractDictionary{I, T}, i::I, value) where {I, T}
    return set!(d, i, convert(T, value))
end

function set!(d::AbstractDictionary{I, T}, i::I, value::T) where {I, T}
    (hadtoken, token) = gettoken!(d, i)
    @inbounds settokenvalue!(d, token, value)
    return d
end

# Since `AbstractIndices <: AbstractDictionary` we should still obey the supertype's interface where possible...
function set!(indices::AbstractIndices{I}, i1::I, i2::I) where {I}
    if isinsertable(indices)
        if isequal(i1, i2)
            return set!(indices, i1)
        else
            error("Attempted to set distinct key-value pair ($i1, $i2) to indices: $(typeof(indices))")
        end
    else
        error("indices not insertable: $(typeof(indices))")
    end
end

"""
    setwith!(f, dict::AbstractDictionary, i, value)

Update the value at `i` with the function `f` (`f(dict[i], value)`) or insert `value`.

Hint: Use [`mergewith!`](@ref) to exclusively update an existing value, and `insert!` to exclusively
insert a new value. See also `get!`.
"""
function setwith!(f, d::AbstractDictionary{I}, i, value) where {I}
    i2 = safe_convert(I, i)
    old_value = get(d, i2, nothing)
    isnothing(old_value) ? insert!(d, i2, value) : d[i2] = f(old_value, value) 
    return d
end

setwith!(f, ::AbstractIndices, i, value) = error("`insertwith!` does not work with `AbstractIndices`")

"""
    set!(indices::AbstractIndices, i)

Insert a new value `i` into `indices` if it doesn't exist, or do nothing otherwise.
"""
@propagate_inbounds function set!(indices::AbstractIndices{I}, i) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    return set!(indices, i2)
end

function set!(indices::AbstractIndices{I}, i::I) where {I}
    gettoken!(indices, i)
    return indices
end

"""
    get!(dict::AbstractDictionary, i, default)

Return the value `dict[i]` if index `i` exists. Otherwise, a new index `i` is inserted and
set to `default`, which is returned.

See also `get`, `set!`.
"""
@propagate_inbounds function Base.get!(d::AbstractDictionary{I}, i, default) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    return get!(d, i2, default)
end

function Base.get!(d::AbstractDictionary{I, T}, i::I, default) where {I, T}
    return get!(d, i, convert(T, default))
end

function Base.get!(d::AbstractDictionary{I, T}, i::I, default::T) where {I, T}
    (hadindex, token) = gettoken!(d, i)
    if hadindex
        return @inbounds gettokenvalue(d, token)
    else
        @inbounds settokenvalue!(d, token, default)
        return default
    end
end

"""
    get!(f::Union{Function, Type}, dict::AbstractDictionary, i)

Return the value `dict[i]` if index `i` exists. Otherwise, a new index `i` is inserted and
set to the value `f()`, which is returned.
"""
function Base.get!(f::Callable, d::AbstractDictionary{I}, i) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    get!(f, d, i2)
end


function Base.get!(f::Callable, d::AbstractDictionary{I, T}, i::I) where {I, T}
    (hadindex, token) = gettoken!(d, i)
    if hadindex
        return @inbounds gettokenvalue(d, token)
    else
        default = convert(T, f())
        @inbounds settokenvalue!(d, token, default)
        return default
    end
end


"""
    delete!(indices::AbstractIndices, i)

Delete the index `i` from `indices`. An error is thrown if `i` does not exist.

    delete!(dict::AbstractDictionary, i)

Delete the index `i` from `dict`. An error is thrown if `i` does not exist.

See also `unset!`, `insert!`.
"""
@propagate_inbounds function Base.delete!(d::AbstractDictionary{I}, i) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    return delete!(d, i2)
end

function Base.delete!(d::AbstractDictionary{I}, i::I) where {I}
    (hasindex, token) = gettoken(d, i)
    if !hasindex
        throw(IndexError("Index doesn't exist: $i"))
    end
    @inbounds deletetoken!(d, token)
    return d
end


"""
    unset!(indices::AbstractIndices, i)

Delete the index `i` from `indices` if it exists, or do nothing otherwise.

    unset!(dict::AbstractDictionary, i)

Delete the index `i` from `dict` if it exists, or do nothing otherwise.

See also `delete!`, `set!`.
"""
@propagate_inbounds function unset!(indices::AbstractDictionary{I}, i) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    return unset!(indices, i2)
end

function unset!(d::AbstractDictionary{I}, i::I) where {I}
    (hasindex, token) = gettoken(d, i)
    if hasindex
        @inbounds deletetoken!(d, token)
    end
    return d
end

### Non-scalar insertion/deletion
function Base.merge!(d::AbstractDictionary, others::AbstractDictionary...)
    for other in others
        for (i, v) in pairs(other)
            set!(d, i, v)
        end
    end
    return d
end

if isdefined(Base, :mergewith) # Julia 1.5+
    function Base.mergewith!(combiner, d::AbstractDictionary, d2::AbstractDictionary)
        for (i, v) in pairs(d2)
            (hasindex, token) = gettoken!(d, i)
            if hasindex
                @inbounds settokenvalue!(d, token, combiner(gettokenvalue(d, token), v))
            else
                @inbounds settokenvalue!(d, token, v)
            end
        end
        return d
    end
    Base.mergewith!(combiner, d::AbstractDictionary, others::AbstractDictionary...) =
        foldl(mergewith!(combiner), others, init = d)
end

# TODO some kind of exclusive merge (throw on key clash like `insert!`)

# TODO: deletemany!, unsetmany! (which is setdiff! on indices)

### Indices ("sets") versions of above

function Base.union!(s1::AbstractIndices, itr)
    # Optimized to handle repeated values in `itr` - e.g. if `itr` is already sorted
    x = iterate(itr)
    if x === nothing
        return s1
    end
    (i, s) = x
    set!(s1, i)
    i_old = i
    while x !== nothing
        (i, s) = x
        !isequal(i, i_old) && set!(s1, i)
        i_old = i
        x = iterate(itr, s)
    end
    return s1
end

function Base.intersect!(s1::AbstractIndices, s2)
    return filter!(in(s2), s1)
end

function Base.setdiff!(s1::AbstractIndices, s2)
    for i in s2
        unset!(s1, i)
    end
    return s1
end

function Base.symdiff!(s1::AbstractIndices, s2)
    for i in s2
        (hastoken, token) = gettoken!(s1, i)
        if hastoken
            @inbounds deletetoken!(s1, token)
        end
    end
    return s1
end

## Filtering

# These generic implementations are gimped.

# # `filter!` is basically a programmatic version of `intersect!`.
# function Base.filter!(pred, indices::AbstractIndices)
#     for i in copy(indices)
#         if !pred(i)
#             delete!(indices, i)
#         end
#     end
#     return indices
# end

# # Dictionary version is similar
# function Base.filter!(pred, dict::AbstractDictionary)
#     for (i, v) in pairs(copy(dict))
#         if !pred(v)
#             delete!(dict, i)
#         end
#     end
#     return dict
# end

# This implementation is faster when deleting indices does not invalidate tokens/iteration,
# and is opt-in only. Works for both dictionaries and indices
function Base.unsafe_filter!(pred, dict::AbstractDictionary)
    for token in tokens(dict)
        @inbounds if !pred(gettokenvalue(dict, token))
            deletetoken!(dict, token)
        end
    end
end

# Factories for insertable Dictionaries/Indices

"""
    empty(inds::AbstractIndices, I::Type)
    empty(dict::AbstractDictionary, I::Type)

Return an empty, insertable `AbstractIndices` of element type `I` (even when the first
argument is a dictionary). The default container is `Indices{I}`, but the output may
depend on the first argument.

    empty(inds::AbstractIndices)

Return an empty, insertable `AbstractIndices` of element type `eltype(inds)`.
"""
Base.empty(inds::AbstractIndices) = empty(inds, eltype(inds))

"""
    empty(inds::AbstractIndices, I::Type, T::Type)
    empty(dict::AbstractDictionary, I::Type, T::Type)

Return an empty, insertable `AbstractDictionary` of with indices of type `I` and elements
of type `T` (even when the first argument is are indices). The default container is
`Dictionary{I}`, but the output may depend on the first argument.

    empty(dict::AbstractDictionary)

Return an empty, insertable `AbstractDictionary` with indices of type `keytype(dict)` and
elements of type `eltype(inds)`.
"""
Base.empty(d::AbstractDictionary) = empty(keys(d), keytype(d), eltype(d))

Base.empty(d::AbstractDictionary, ::Type{I}) where {I} = empty(keys(d), I)
