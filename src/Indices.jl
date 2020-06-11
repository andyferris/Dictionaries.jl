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

Indices(; sizehint = 8) = Indices{Any}(; sizehint = sizehint)

function Indices{I}(; sizehint = 8) where {I}
    newsize = Base._tablesz((3 * sizehint) >> 0x01);
    Indices{I}(fill(0, sizehint), Vector{UInt}(), Vector{I}(), 0)
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

    return Indices{eltype(iter)}(iter)
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

Base.convert(::Type{Indices}, inds::AbstractIndices{I}) where {I} = convert(Indices{I}, inds)

function Base.convert(::Type{Indices{I}}, inds::AbstractIndices) where {I}
    # Fast path
    if inds isa Indices && inds.holes == 0
        # Note: `convert` doesn't have copy semantics
        return Indices{I}(inds.slots, inds.hashes, convert(Vector{I}, inds.values), 0)
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
function Base.copy(indices::Indices, ::Type{I}) where {I}
    _copy = I === eltype(indices) ? copy : identity # the constructor will call `convert`
    if indices.holes == 0
        return Indices{I}(_copy(indices.slots), _copy(indices.hashes), _copy(indices.values), 0)
    else
        out = Indices{I}(Vector{Int}(), _copy(indices.hashes), _copy(indices.values), indices.holes)
        newsize = Base._tablesz(3*length(indices) >> 0x01)
        rehash!(out, newsize)
    end
end

# private (note that newsize must be power of two)
function rehash!(indices::Indices{I}, newsize::Int, values = (), include_last_values::Bool = true) where {I}
    slots = resize!(indices.slots, newsize)
    fill!(slots, 0)
    bit_mask = newsize - 1 # newsize is a power of two
    
    if indices.holes == 0
        for (index, full_hash) in enumerate(indices.hashes)
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
        # Compactify indices.values, indices.hashes and the values while we are at it
        to_index = Ref(1) # Reassigning to to_index/from_index gives the closure capture boxing issue, so mutate a reference instead
        from_index = Ref(1)
        n_values = length(indices.values)
        @inbounds while from_index[] <= n_values
            full_hash = indices.hashes[from_index[]]
            if full_hash & deletion_mask === zero(UInt)
                trial_slot = reinterpret(Int, full_hash) & bit_mask
                @inbounds while true
                    trial_slot = trial_slot + 1
                    if slots[trial_slot] == 0
                        slots[trial_slot] = to_index[]
                        indices.hashes[to_index[]] = indices.hashes[from_index[]]
                        indices.values[to_index[]] = indices.values[from_index[]]
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
    
        new_size = n_values - indices.holes
        resize!(indices.values, new_size)
        resize!(indices.hashes, new_size)
        map(values) do (vals)
            resize!(vals, new_size)
        end
        indices.holes = 0
    end
    return indices
end

Base.length(indices::Indices) = length(indices.values) - indices.holes

# Token interface
istokenizable(::Indices) = true

tokentype(::Indices) = Int

# Duration iteration the token cannot be used for deletion - we do not worry about the slots
@propagate_inbounds function iteratetoken(indices::Indices)
    if indices.holes == 0
        return length(indices) > 0 ? ((0, 1), 1) : nothing
    end
    index = 1
    @inbounds while index <= length(indices.hashes)
        if indices.hashes[index] & deletion_mask === zero(UInt)
            return ((0, index), index)
        end
        index += 1
    end
    return nothing
end

@propagate_inbounds function iteratetoken(indices::Indices, index::Int)
    index += 1
    if indices.holes == 0 # apparently this is enough to make it iterate as fast as `Vector`
        return index <= length(indices.values) ? ((0, index), index) : nothing
    end
    @inbounds while index <= length(indices.hashes)
        if indices.hashes[index] & deletion_mask === zero(UInt)
            return ((0, index), index)
        end
        index += 1
    end
    return nothing
end

function gettoken(indices::Indices{I}, i::I) where {I}
    full_hash = hash(i) & hash_mask
    n_slots = length(indices.slots)
    bit_mask = n_slots - 1 # n_slots is always a power of two

    trial_slot = reinterpret(Int, full_hash) & bit_mask
    @inbounds while true
        trial_slot = (trial_slot + 1)
        trial_index = indices.slots[trial_slot]
        if trial_index > 0
            value = indices.values[trial_index]
            if i === value || isequal(i, value)
                return (true, (trial_slot, trial_index))
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
    return indices.values[index]
end

# Insertion interface
isinsertable(::Indices) = true

function gettoken!(indices::Indices{I}, i::I, values = ()) where {I}
    full_hash = hash(i) & hash_mask
    n_slots = length(indices.slots)
    bit_mask = n_slots - 1 # n_slots is always a power of two
    n_values = length(indices.values)

    trial_slot = reinterpret(Int, full_hash) & bit_mask
    trial_index = 0
    deleted_slot = 0
    @inbounds while true
        trial_slot = (trial_slot + 1)
        trial_index = indices.slots[trial_slot]
        if trial_index == 0
            break
        elseif trial_index < 0
            if deleted_slot == 0
                deleted_slot = trial_slot
            end
        else
            value = indices.values[trial_index]            
            if i === value || isequal(i, value)
                return (true, (trial_slot, trial_index))
            end
        end

        trial_slot = trial_slot & bit_mask
        # This is potentially an infinte loop and care must be taken upon insertion not
        # to completely fill the container
    end

    new_index = n_values + 1
    if deleted_slot == 0
        # Use the trail slot
        indices.slots[trial_slot] = new_index
    else
        # Use the deleted slot
        indices.slots[deleted_slot] = new_index
    end
    push!(indices.hashes, full_hash)
    push!(indices.values, i)
    map(values) do (vals)
        resize!(vals, length(vals) + 1)
    end

    # Expand the hash map when it reaches 2/3rd full
    if 3 * new_index > 2 * n_slots
        # Grow faster for small hash maps than for large ones
        newsize = n_slots > 16000 ? 2 * n_slots : 4 * n_slots
        rehash!(indices, newsize, values, false)

        # The index has changed
        new_index = length(indices.values)

        # The slot also has changed
        bit_mask = newsize - 1
        trial_slot = reinterpret(Int, full_hash) & bit_mask
        @inbounds while true
            trial_slot = (trial_slot + 1)
            if indices.slots[trial_slot] == new_index
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
    indices.slots[slot] = -index
    indices.hashes[index] = deletion_mask
    isbitstype(I) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), indices.values, index-1)
    indices.holes += 1

    # Recreate the hash map when 1/3rd of the values are deletions
    n_values = length(indices.values) - indices.holes
    if 3 * indices.holes > n_values
        # Halve if necessary
        n_slots = length(indices.slots)
        halve = 4 * n_values < n_slots && n_slots > 8
        rehash!(indices, halve ? n_slots >> 0x01 : n_slots, values)
    end

    return indices
end

function Base.empty!(indices::Indices{I}) where {I} 
    indices.hashes = Vector{UInt}()
    indices.values = Vector{I}()
    indices.slots = fill(0, 8)
    indices.holes = 0
    
    return indices
end

# Accelerated filtering

function Base.filter!(pred, indices::Indices)
    _filter!(i -> pred(@inbounds indices.values[i]), indices.values, indices.hashes, ())
    indices.holes = 0
    newsize = Base._tablesz(3*length(indices.values) >> 0x01)
    rehash!(indices, newsize)
end

@inline function _filter!(pred, indices, hashes, values = ())
    n = length(indices)
    i = Ref(0)
    j = Ref(0)
    @inbounds while i[] < n
        i[] += 1
        if hashes[i[]] & deletion_mask === zero(UInt) && pred(i[])
            j[] += 1
            indices[j[]] = indices[i[]]
            hashes[j[]] = hashes[i[]]
            map(vec -> @inbounds(vec[j[]] = vec[i[]]), values)
        end
    end
    newsize = j[]
    resize!(indices, newsize)
    resize!(hashes, newsize)
    map(vec -> resize!(vec, newsize), values)
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

# CAUTION: I have observed Julia 1.4.2 fail to preserve the object identity of Indices
# (or perhaps there is a coding error I don't understand that causes it to be recreated)
sharetokens(i1::Indices, i2::Indices) = i1.slots === i2.slots