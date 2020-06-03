const hash_mask = typemax(UInt) >>> 0x01
const deletion_mask = hash_mask + 0x01

mutable struct HashIndices{I} <: AbstractIndices{I}
    # The hash table
    slots::Vector{Int}

    # Hashes and values
    hashes::Vector{UInt} # Deletion marker stored in high bit
    values::Vector{I}

    holes::Int # Number of "vacant" slots in hashes and values
end

HashIndices(; sizehint = 8) = HashIndices{Any}(; sizehint = sizehint)

function HashIndices{I}(; sizehint = 8) where {I}
    newsize = Base._tablesz((3 * sizehint) >> 0x01);
    HashIndices{I}(fill(0, sizehint), Vector{UInt}(), Vector{I}(), 0)
end

"""
    HashIndices(iter)
    HashIndices{I}(iter)

Construct a `HashIndices` with indices from iterable container `iter`.
"""
function HashIndices(iter)
    if Base.IteratorEltype(iter) === Base.EltypeUnknown()
        iter = collect(iter)
    end

    return HashIndices{eltype(iter)}(iter)
end

function HashIndices{I}(iter) where {I}
    iter_size = Base.IteratorSize(iter)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        values = Vector{I}(undef, length(iter))
        @inbounds for (i, value) in enumerate(iter)
            values[i] = value
        end
        return HashIndices{I}(values)
    else
        h = HashIndices{I}()
        for i in iter
            insert!(h, i)
        end
        return h
    end
end

function HashIndices{I}(values::Vector{I}) where {I}
    # TODO Incrementally build the hashmap removing duplicates
    hashes = map(v -> hash(v) & hash_mask, values)
    slots = Vector{Int}()
    out = HashIndices{I}(slots, hashes, values, 0)
    newsize = Base._tablesz(3*length(values) >> 0x01)
    rehash!(out, newsize)
    return out
end

function Base.copy(indices::HashIndices{I}) where {I}
    if indices.holes == 0
        return HashIndices{I}(copy(indices.slots), copy(indices.hashes), copy(indices.values), 0)
    else
        out = HashIndices{I}(Vector{Int}(), copy(indices.hashes), copy(indices.values), indices.holes)
        newsize = Base._tablesz(3*length(indices) >> 0x01)
        rehash!(out, newsize)
    end
end

# private (note that newsize must be power of two)
function rehash!(indices::HashIndices{I}, newsize::Int, values = (), include_last_values::Bool = true) where {I}
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

Base.length(indices::HashIndices) = length(indices.values) - indices.holes

# Token interface
istokenizable(::HashIndices) = true

tokentype(::HashIndices) = Int

# Duration iteration the token cannot be used for deletion - we do not worry about the slots
@propagate_inbounds function iteratetoken(indices::HashIndices)
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

@propagate_inbounds function iteratetoken(indices::HashIndices, index::Int)
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

function gettoken(indices::HashIndices{I}, i::I) where {I}
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

@propagate_inbounds function gettokenvalue(indices::HashIndices, (_slot, index))
    return indices.values[index]
end

# Insertion interface
isinsertable(::HashIndices) = true

function gettoken!(indices::HashIndices{I}, i::I, values = ()) where {I}
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

@propagate_inbounds function deletetoken!(indices::HashIndices{I}, (slot, index), values = ()) where {I}
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

function Base.empty!(indices::HashIndices{I}) where {I} 
    indices.hashes = Vector{UInt}()
    indices.values = Vector{I}()
    indices.slots = fill(0, 8)
    indices.holes = 0
    
    return indices
end

# Accelerated filtering

function Base.filter!(pred, indices::HashIndices)
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

Base.empty(::AbstractIndices, ::Type{I}) where {I} = HashIndices{I}()
