# Insertable maps can have both keys and values that mutate
#
# TODO: define functions like `empty` that guarantee an insertable map.
#
#    - empty_insertable(input) - no keys or values
#    - similar_insertable(input) - same keys, undef values
#    - copy_insertable(input) - same keys and values
#    - something for empty / similar insertable indices ?

"""
    isinsertable(map::AbstractMap)

Return `true` if `map` supports the insertable interface, or `false` otherwise. The primary
functions a map needs to implement for the insertable interface are:
 
 * `insert!(map, i, value)` - add a new `value` at index `i` (will error if index exists)
 * `delete!(map, i)` - remove element at index `i` (will error if index does not exist)

Functions `get!`, `set!` and `unset!` are also provided for common operations where you are
not sure if an index exists or not.
"""
isinsertable(::AbstractMap) = false

"""
    isinsertable(indices::AbstractIndices)

Return `true` if `indices` supports the insertable interface, or `false` otherwise. The
primary functions a map needs to implement for the insertable interface are:
 
 * `insert!(indices, i)` - add new index `i` to `indices` (will error if index exists)
 * `delete!(indices, i)` - remove an existing index `i` from `indices` (will error if index does not exist).

Functions `set!` and `unset!` are also provided for common operations where you are not sure
if an index exists or not.
"""
isinsertable(::AbstractIndices) = false

"""
    insert!(indices::AbstractIndices, i)

Insert the new index `i` into `indices`. An error is thrown if `i` already exists.
"""
@propagate_inbounds function Base.insert!(indices::AbstractIndices{I}, i) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    return insert!(indices, i2)
end

function Base.insert!(indices::AbstractIndices{I}, ::I) where {I}
    if isinsertable(indices)
        error("insert! needs to be defined for insertable indices: $(typeof(indices))")
    else
        error("indices not insertable: $(typeof(indices))")
    end
end

"""
    insert!(indices::AbstractMap, value, i)

Insert the `value` at new index `i` into `map`. An error is thrown if index `i` already
exists. 

Hint: Use `setindex!` to update an existing value, and `set!` to perform an "upsert"
(update-or-insert) operation.
"""
@propagate_inbounds function Base.insert!(map::AbstractMap{I}, value, i) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    return insert!(map, value, i2)
end

function Base.insert!(map::AbstractMap{I, T}, value, i::I) where {I, T}
    return insert!(map, convert(T, value), i)
end

function Base.insert!(map::AbstractMap{I, T}, ::T, ::I) where {I, T}
    if isinsertable(map)
        error("insert! needs to be defined for insertable map: $(typeof(map))")
    else
        error("map not insertable: $(typeof(map))")
    end
end

"""
    set!(indices::AbstractMap, value, i)

Update or insert the `value` at index `i` into `map`. Sometimes referred to as an "upsert"
operation.

Hint: Use `setindex!` to exclusively update an existing value, and `insert!` to exclusively
insert a new value. See also `get!`.
"""
@propagate_inbounds function set!(map::AbstractMap{I}, value, i) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    return insert!(map, value, i2)
end

function set!(map::AbstractMap{I, T}, value, i::I) where {I, T}
    return insert!(map, convert(T, value), i)
end

function set!(map::AbstractMap{I, T}, value::T, i::I) where {I, T}
    if haskey(map, i)
        @inbounds map[i] = value
    else
        insert!(map, value, i)
    end
    return map
end

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
    if i ∉ indices
        insert!(indices, i)
    end
    return indices
end

"""
    get!(map::AbstractMap, i, default)

Return the value `map[i]` if index `i` exists. Otherwise, a new index `i` is inserted and
set to `default`, which is returned.

See also `get`, `set!`.
"""
@propagate_inbounds function Base.get!(map::AbstractMap{I}, i, default) where {I}
    i2 = convert(I, i)
    if !isequal(i, i2)
        throw(ArgumentError("$i is not a valid key for type $I"))
    end
    return get!(map, i2, default)
end

function Base.get!(map::AbstractMap{I, T}, i::I, default) where {I, T}
    return get!(map, i, convert(T, default))
end

function Base.get!(map::AbstractMap{I, T}, i::I, default::T) where {I, T}
    if haskey(map, i)
        return @inbounds map[i]
    else
        insert!(map, default, i)
        return default
    end
end

Base.merge!(m::AbstractMap, ms::AbstractMap...) = merge!(last, m, ms...)

function Base.merge!(combine::Function, m::AbstractMap, m2::AbstractMap)
    for (i, v) in pairs(m2)
        if haskey(m, i)
            m[i] = combine(m[i], v)
        else
            insert!(m, v, i)
        end
    end
    return m
end

function Base.merge!(::typeof(last), m::AbstractMap, m2::AbstractMap)
    for (i, v) in pairs(m2)
        set!(m, v, i)
    end
    return m
end

function Base.merge!(::typeof(first), m::AbstractMap, m2::AbstractMap)
    for (i, v) in pairs(m2)
        get!(m, i, v)
    end
    return m
end

function Base.merge!(combine::Function, m::AbstractMap, m2::AbstractMap, ms::AbstractMap...)
    merge!(combine, merge!(combine, m, m2), ms...)
end

function Base.merge!(::typeof(last), m::AbstractIndices, m2::AbstractIndices)
    union!(m, m2)
end

# TODO some kind of exclusive merge (throw on key clash like `insert!`)


"""
    delete!(map::AbstractMap, i)

Delete the index `i` from `map`. An error is thrown if `i` does not exist.
"""
@propagate_inbounds function Base.delete!(map::AbstractMap{I}, i) where {I}
    return delete!(map, convert(i, I))
end

function Base.delete!(map::AbstractMap{I}, ::I) where {I}
    if isinsertable(map)
        error("delete! needs to be defined for insertable map: $(typeof(map))")
    else
        error("map is not insertable: $(typeof(map))")
    end
end

function unset!(map::AbstractMap{I}, i::I) where {I}
    if i ∈ keys(map)
        delete!(map, i)
    end
    return map
end

# TODO: deletemany!, unsetmany! (which is setdiff! on indices)

### Indices (set) versions of above

function Base.union!(s1::AbstractIndices, s2::AbstractIndices)
    for i in s2
        set!(s1, i)
    end
    return s1
end

function Base.intersect!(s1::AbstractIndices, s2::AbstractIndices)
    for i in s1
        if i ∉ s2
            delete!(s1, i)
        end
    end
    return s1
end

function Base.setdiff!(s1::AbstractIndices, s2::AbstractIndices)
    for i in s2
        unset!(s1, i)
    end
    return s1
end

function Base.symdiff!(s1::AbstractIndices, s2::AbstractIndices)
    for i in s2
        if i in s1
            delete!(s1, i)
        else
            insert!(s1, i)
        end
    end
    return s1
end

# filter! is a programmatic version of intersect!
function Base.filter!(f, indices::AbstractIndices)
    for i in indices
        if !f(i)
            delete!(indices, i)
        end
    end
    return indices
end