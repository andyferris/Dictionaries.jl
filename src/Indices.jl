const hash_mask = typemax(UInt) >>> 0x01
const deletion_mask = hash_mask + 0x01

mutable struct Indices{I} <: AbstractIndices{I}
    # The hash table
    slots::Vector{Int}

    # Hashes and values
    hashes::Vector{UInt} # Deletion marker stored in high bit
    values::Vector{I}

    holes::Int # Number of "vacant" slots in hashes and values
end

_slots(inds::Indices) = getfield(inds, :slots)
_hashes(inds::Indices) = getfield(inds, :hashes)
_values(inds::Indices) = getfield(inds, :values)
_holes(inds::Indices) = getfield(inds, :holes)

Indices(; sizehint = 8) = Indices{Any}(; sizehint = sizehint)

function Indices{I}(; sizehint = 8) where {I}
    newsize = Base._tablesz((3 * sizehint) >> 0x01);
    hashes = Vector{UInt}()
    values = Vector{I}()
    sizehint!(hashes, sizehint)
    sizehint!(values, sizehint)
    Indices{I}(fill(0, newsize), hashes, values, 0)
end

"""
    Indices(iter)
    Indices{I}(iter)

Construct a `Indices` with indices from iterable container `iter`.

Note that the elements of `iter` must be distinct/unique. Instead, the `distinct` function
can be used for finding the unique elements.

# Examples

```julia
julia> Indices([1,2,3])
3-element Indices{Int64}
 1
 2
 3

julia> Indices([1,2,3,3])
ERROR: IndexError("Indices are not unique (inputs at positions 3 and 4) - consider using the distinct function")
Stacktrace:
 [1] Indices{Int64}(::Array{Int64,1}) at /home/ferris/.julia/dev/Dictionaries/src/Indices.jl:92
 [2] Indices(::Array{Int64,1}) at /home/ferris/.julia/dev/Dictionaries/src/Indices.jl:53
 [3] top-level scope at REPL[12]:1

julia> distinct([1,2,3,3])
3-element Indices{Int64}
 1
 2
 3
```
"""
function Indices(iter)
    if Base.IteratorEltype(iter) === Base.EltypeUnknown()
        iter = collect(iter)
    end

    # This is necessary to make map'ing across an empty dictionary work
    # In both Julia 1.9 and 1.10 eltype(::Tuple{}) == Union{}
    # but in Julia 1.10, this causes problems downstream when Indices{Union{}}
    # is used. For an empty iterator, we actually don't know what the 
    # True(tm) eltype is, so the top of the type hierarchy (Any) is 
    # just as reasonable as the bottom (Union{})
    I = typeof(iter) == Tuple{} ? Any : eltype(iter)
    
    return Indices{I}(iter)
end

function Indices{I}(iter) where {I}
    iter_size = Base.IteratorSize(iter)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        values = Vector{I}(undef, length(iter))
        @inbounds for (i, value) in enumerate(iter)
            values[i] = value
        end
    else
        values = Vector{I}()
        @inbounds for value in iter
            push!(values, value)
        end
    end
    return Indices{I}(values)
end

function Indices{I}(values::Vector{I}) where {I}
    # The input must have unique elements (the constructor is not to be used in place of `distinct`)
    hashes = map(v -> hash(v) & hash_mask, values)
    
    # Incrementally build the hashmap and throw if duplicates detected
    newsize = Base._tablesz(3*length(values) >> 0x01)
    bit_mask = newsize - 1 # newsize is a power of two
    slots = zeros(Int, newsize)
    @inbounds for index in keys(hashes)
        full_hash = hashes[index]
        trial_slot = reinterpret(Int, full_hash) & bit_mask
        @inbounds while true
            trial_slot = (trial_slot + 1)
            if slots[trial_slot] == 0
                slots[trial_slot] = index
                break
            else
                # TODO make this check optional
                if isequal(values[index], values[slots[trial_slot]])
                    throw(IndexError("Indices are not unique (inputs at positions $(slots[trial_slot]) and $index) - consider using the distinct function"))
                end
            end
            trial_slot = trial_slot & bit_mask
            # This is potentially an infinte loop and care must be taken not to overfill the container
        end
    end
    return Indices{I}(slots, hashes, values, 0)
end

Base.convert(::Type{AbstractIndices{I}}, inds::AbstractIndices) where {I} = convert(Indices{I}, inds) # the default AbstractIndices type
Base.convert(::Type{AbstractIndices{I}}, inds::AbstractIndices{I}) where {I} = inds

Base.convert(::Type{AbstractIndices{I}}, inds::Indices) where {I} = convert(Indices{I}, inds)
Base.convert(::Type{Indices}, inds::AbstractIndices{I}) where {I} = convert(Indices{I}, inds)

Base.convert(::Type{Indices{I}}, inds::Indices{I}) where {I} = inds
function Base.convert(::Type{Indices{I}}, inds::AbstractIndices) where {I}
    # Fast path
    if inds isa Indices
        # Note: `convert` doesn't have copy semantics
        return Indices{I}(_slots(inds), _hashes(inds), convert(Vector{I}, _values(inds)), _holes(inds))
    end

    # The input is already unique
    values = collect(I, inds)
    hashes = map(v -> hash(v) & hash_mask, values)

    # Incrementally build the hashmap
    newsize = Base._tablesz(3*length(values) >> 0x01)
    bit_mask = newsize - 1 # newsize is a power of two
    slots = zeros(Int, newsize)
    @inbounds for index in keys(hashes)
        full_hash = hashes[index]
        trial_slot = reinterpret(Int, full_hash) & bit_mask
        @inbounds while true
            trial_slot = (trial_slot + 1)
            if slots[trial_slot] == 0
                slots[trial_slot] = index
                break
            else
                # TODO make this check optional
                if isequal(values[index], values[slots[trial_slot]])
                    throw(IndexError("Indices are not unique (inputs at positions $(slots[trial_slot]) and $index)"))
                end
            end
            trial_slot = trial_slot & bit_mask
            # This is potentially an infinte loop and care must be taken not to overfill the container
        end
    end
    return Indices{I}(slots, hashes, values, 0)
end

"""
    copy(inds::AbstractIndices)
    copy(inds::AbstractIndices, ::Type{I})

Create a shallow copy of the indices, optionally changing the element type.

(Note that `copy` on a dictionary does not copy its indices).
"""
function Base.copy(indices::Indices{I}, ::Type{I2}) where {I, I2}
    return Indices{I2}(copy(_slots(indices)), copy(_hashes(indices)), collect(I2, _values(indices)), _holes(indices))
end

function Base.copy(indices::ReverseIndices{I,Indices{I}}, ::Type{I2}) where {I, I2}
    p = parent(indices)
    l = length(_values(p)) + 1
    old_slots = _slots(p)
    new_slots = similar(old_slots)
    @inbounds for i in keys(_slots(p))
        index = old_slots[i]
        if index > 0
            new_slots[i] = l - index
        else
            new_slots[i] = index
        end
    end
    return Indices{I2}(new_slots, reverse(_hashes(p)), collect(I2, Iterators.reverse(_values(p))), _holes(p))
end

function Base.deepcopy_internal(ind::Indices{T}, id::IdDict) where {T}
    return Indices{T}(Base.deepcopy_internal(collect(ind), id))
end

function Serialization.serialize(s::AbstractSerializer, ind::T) where {T<:Indices}
    serialize_type(s, T, false)
    serialize(s, collect(ind))
end

function Serialization.deserialize(s::AbstractSerializer, T::Type{<:Indices})
    tag = Int32(read(s.io, UInt8)::UInt8)
    if tag != UNDEFREF_TAG
        vals = handle_deserialize(s, tag)
    else
        error("could not deserialize $T")
    end
    return T(vals)
end

# private (note that newsize must be power of two)
function rehash!(indices::Indices{I}, newsize::Int, values = (), include_last_values::Bool = true) where {I}
    slots = resize!(_slots(indices), newsize)
    fill!(slots, 0)
    bit_mask = newsize - 1 # newsize is a power of two
    
    if _holes(indices) == 0
        for (index, full_hash) in enumerate(_hashes(indices))
            trial_slot = reinterpret(Int, full_hash) & bit_mask
            @inbounds while true
                trial_slot = (trial_slot + 1)
                if slots[trial_slot] == 0
                    slots[trial_slot] = index
                    break
                else
                    trial_slot = trial_slot & bit_mask
                end
                # This is potentially an infinte loop and care must be taken not to overfill the container
            end
        end
    else
        # Compactify _values(indices), _hashes(indices) and the values while we are at it
        to_index = Ref(1) # Reassigning to to_index/from_index gives the closure capture boxing issue, so mutate a reference instead
        from_index = Ref(1)
        n_values = length(_values(indices))
        @inbounds while from_index[] <= n_values
            full_hash = _hashes(indices)[from_index[]]
            if full_hash & deletion_mask === zero(UInt)
                trial_slot = reinterpret(Int, full_hash) & bit_mask
                @inbounds while true
                    trial_slot = trial_slot + 1
                    if slots[trial_slot] == 0
                        slots[trial_slot] = to_index[]
                        _hashes(indices)[to_index[]] = _hashes(indices)[from_index[]]
                        _values(indices)[to_index[]] = _values(indices)[from_index[]]
                        if include_last_values || from_index[] < n_values
                            # Note - the last slot might end up with a random value (or
                            # GC'd reference). It's the callers responsibility to ensure the
                            # last slot is written to after this operation.
                            map(values) do (vals)
                                @inbounds vals[to_index[]] = vals[from_index[]]
                            end
                        end
                        to_index[] += 1
                        break
                    else
                        trial_slot = trial_slot & bit_mask
                    end
                end
            end
            
            from_index[] += 1
        end
    
        new_size = n_values - _holes(indices)
        resize!(_values(indices), new_size)
        resize!(_hashes(indices), new_size)
        map(values) do (vals)
            resize!(vals, new_size)
        end
        setfield!(indices, :holes, 0)
    end
    return indices
end

Base.length(indices::Indices) = length(_values(indices)) - _holes(indices)

# Token interface
istokenizable(::Indices) = true

tokentype(::Indices) = Int

# Duration iteration the token cannot be used for deletion - we do not worry about the slots
@propagate_inbounds function iteratetoken(indices::Indices)
    if _holes(indices) == 0
        return length(indices) > 0 ? ((0, 1), 1) : nothing
    end
    index = 1
    @inbounds while index <= length(_hashes(indices))
        if _hashes(indices)[index] & deletion_mask === zero(UInt)
            return ((0, index), index)
        end
        index += 1
    end
    return nothing
end

@propagate_inbounds function iteratetoken(indices::Indices, index::Int)
    index += 1
    if _holes(indices) == 0 # apparently this is enough to make it iterate as fast as `Vector`
        return index <= length(_values(indices)) ? ((0, index), index) : nothing
    end
    @inbounds while index <= length(_hashes(indices))
        if _hashes(indices)[index] & deletion_mask === zero(UInt)
            return ((0, index), index)
        end
        index += 1
    end
    return nothing
end

@propagate_inbounds function iteratetoken_reverse(indices::Indices)
    index = length(indices)
    if _holes(indices) == 0
        return index > 0 ? ((0, index), index) : nothing
    end
    @inbounds while index > 0
        if _hashes(indices)[index] & deletion_mask === zero(UInt)
            return ((0, index), index)
        end
        index -= 1
    end
    return nothing
end

@propagate_inbounds function iteratetoken_reverse(indices::Indices, index::Int)
    index -= 1
    if _holes(indices) == 0 # apparently this is enough to make it iterate as fast as `Vector`
        return index > 0 ? ((0, index), index) : nothing
    end
    @inbounds while index > 0
        if _hashes(indices)[index] & deletion_mask === zero(UInt)
            return ((0, index), index)
        end
        index -= 1
    end
    return nothing
end

function gettoken(indices::Indices{I}, i) where {I}
    full_hash = hash(i) & hash_mask
    n_slots = length(_slots(indices))
    bit_mask = n_slots - 1 # n_slots is always a power of two
    hashes = indices.hashes

    trial_slot = reinterpret(Int, full_hash) & bit_mask
    @inbounds while true
        trial_slot = (trial_slot + 1)
        trial_index = _slots(indices)[trial_slot]
        if trial_index > 0
            if isbitstype(I) || Base.isbitsunion(I) || I === Symbol || full_hash === @inbounds hashes[trial_index]
                value = _values(indices)[trial_index]
                if i === value || isequal(i, value)
                    return (true, (trial_slot, trial_index))
                end
            end
        elseif trial_index === 0
            return (false, (0, 0))
        end

        trial_slot = trial_slot & bit_mask
        # This is potentially an infinte loop and care must be taken upon insertion not
        # to completely fill the container
    end
end

@propagate_inbounds function gettokenvalue(indices::Indices, (_slot, index))
    return _values(indices)[index]
end

@propagate_inbounds function gettokenvalue(indices::Indices, index::Int)
    return _values(indices)[index]
end

# Insertion interface
isinsertable(::Indices) = true

function gettoken!(indices::Indices{I}, i::I, values = ()) where {I}
    full_hash = hash(i) & hash_mask
    n_slots = length(_slots(indices))
    bit_mask = n_slots - 1 # n_slots is always a power of two
    n_values = length(_values(indices))
    hashes = indices.hashes

    trial_slot = reinterpret(Int, full_hash) & bit_mask
    trial_index = 0
    deleted_slot = 0
    @inbounds while true
        trial_slot = (trial_slot + 1)
        trial_index = _slots(indices)[trial_slot]
        if trial_index == 0
            break
        elseif trial_index < 0
            if deleted_slot == 0
                deleted_slot = trial_slot
            end
        else
            if isbitstype(I) || Base.isbitsunion(I) || I === Symbol || full_hash === @inbounds hashes[trial_index]
                value = _values(indices)[trial_index]
                if i === value || isequal(i, value)
                    return (true, (trial_slot, trial_index))
                end
            end
        end

        trial_slot = trial_slot & bit_mask
        # This is potentially an infinte loop and care must be taken upon insertion not
        # to completely fill the container
    end

    new_index = n_values + 1
    if deleted_slot == 0
        # Use the trail slot
        _slots(indices)[trial_slot] = new_index
    else
        # Use the deleted slot
        _slots(indices)[deleted_slot] = new_index
    end
    push!(_hashes(indices), full_hash)
    push!(_values(indices), i)
    map(values) do (vals)
        resize!(vals, length(vals) + 1)
    end

    # Expand the hash map when it reaches 2/3rd full
    if 3 * new_index > 2 * n_slots
        # Grow faster for small hash maps than for large ones
        newsize = n_slots > 16000 ? 2 * n_slots : 4 * n_slots
        rehash!(indices, newsize, values, false)

        # The index has changed
        new_index = length(_values(indices))

        # The slot also has changed
        bit_mask = newsize - 1
        trial_slot = reinterpret(Int, full_hash) & bit_mask
        @inbounds while true
            trial_slot = (trial_slot + 1)
            if _slots(indices)[trial_slot] == new_index
                break
            end
            trial_slot = trial_slot & bit_mask
        end
    end

    return (false, (trial_slot, new_index))
end

@propagate_inbounds function deletetoken!(indices::Indices{I}, (slot, index), values = ()) where {I}
    @boundscheck if slot == 0
        error("Cannot use iteration token for deletion")
    end
    _slots(indices)[slot] = -index
    _hashes(indices)[index] = deletion_mask
    isbitstype(I) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), _values(indices), index-1)
    setfield!(indices, :holes, _holes(indices) + 1)

    # Recreate the hash map when 1/3rd of the values are deletions
    n_values = length(_values(indices)) - _holes(indices)
    if 3 * _holes(indices) > n_values
        # Halve if necessary
        n_slots = length(_slots(indices))
        halve = 4 * n_values < n_slots && n_slots > 8
        rehash!(indices, halve ? n_slots >> 0x01 : n_slots, values)
    end

    return indices
end

function Base.empty!(indices::Indices{I}, values = ()) where {I} 
    setfield!(indices, :hashes, Vector{UInt}())
    setfield!(indices, :values, Vector{I}())
    setfield!(indices, :slots, fill(0, 8))
    setfield!(indices, :holes, 0)

    foreach(empty!, values)
    
    return indices
end

# Accelerated filtering

function Base.filter!(pred, indices::Indices)
    _filter!(token -> pred(@inbounds gettokenvalue(indices, token)), indices, ())
end

@inline function _filter!(pred, indices::Indices, values = ())
    indices_values = _values(indices)
    hashes = _hashes(indices)
    n = length(indices_values)
    i = Ref(0)
    j = Ref(0)
    @inbounds while i[] < n
        i[] += 1
        if hashes[i[]] & deletion_mask === zero(UInt) && pred(i[])
            j[] += 1
            indices_values[j[]] = indices_values[i[]]
            hashes[j[]] = hashes[i[]]
            map(vec -> @inbounds(vec[j[]] = vec[i[]]), values)
        end
    end
    newsize = j[]
    resize!(indices_values, newsize)
    resize!(hashes, newsize)
    map(vec -> resize!(vec, newsize), values)
    setfield!(indices, :holes, 0)
    newsize = Base._tablesz(3*length(_values(indices)) >> 0x01)
    rehash!(indices, newsize, values)
end

# Factories

# TODO make this generic... maybe a type-based `empty`?
function _distinct(::Type{Indices}, itr)
    if Base.IteratorEltype(itr) === Base.HasEltype()
        return _distinct(Indices{eltype(itr)}, itr)
    end

    tmp = iterate(itr)
    if tmp === nothing
        return Indices{Base.@default_eltype(itr)}()
    end
    (x, s) = tmp
    indices = Indices{typeof(x)}()
    insert!(indices, x)
    return __distinct!(indices, itr, s, x)
end

# An auto-widening constructor for insertable AbstractIndices
function __distinct!(indices::AbstractIndices, itr, s, x_old)
    T = eltype(indices)
    tmp = iterate(itr, s)
    while tmp !== nothing
        (x, s) = tmp
        if !isequal(x, x_old) # Optimized for repeating elements of `itr`, e.g. if `itr` is sorted
            if !(x isa T) && promote_type(typeof(x), T) != T
                new_indices = copy(indices, promote_type(T, typeof(x)))
                set!(new_indices, x)
                return __distinct!(new_indices, itr, s, x)
            end
            set!(indices, x)
            x_old = x
        end
        tmp = iterate(itr, s)
    end
    return indices
end

function randtoken(rng::Random.AbstractRNG, inds::Indices)
    if length(inds) == 0
        throw(ArgumentError("collection must be non-empty"))
    end

    if inds.holes === 0
        return (0, rand(rng, Base.OneTo(length(inds))))
    end

    # Rejection sampling to handle deleted tokens (which are sparse)
    range = Base.OneTo(length(_hashes(inds)))
    @inbounds while true
        i = rand(rng, range)
        if inds.hashes[i] !== deletion_mask
            return (0, i)
        end
    end
end

function Base.sort!(inds::Indices; kwargs...)
    if inds.holes != 0
        rehash!(inds, length(inds.slots))
    end
    perm = sortperm(inds.values; kwargs...)
    inds.values = @inbounds inds.values[perm]
    inds.hashes = @inbounds inds.hashes[perm]
    @inbounds for i in keys(inds.slots)
        s = inds.slots[i]
        if s > 0
            inds.slots[i] = perm[s]
        end
    end
    return inds
end

Base.sortperm(inds::AbstractIndices; kwargs...) = sort(inds; kwargs...)
