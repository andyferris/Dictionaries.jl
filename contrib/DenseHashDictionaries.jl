module DenseHashDictionaries

import Base: @propagate_inbounds
using Dictionaries
export DenseHashIndices, DenseHashDictionary

perfect_hash(::Any) = false
perfect_hash(::Union{Bool, UInt8, UInt16, UInt32, UInt, Int8, Int16, Int32, Int, Char}) = true

struct DenseHashIndices{I} <: AbstractIndices{I}
    # The hash table
    slots::Vector{Int}

    # Densely ordered hashes and values
    hashes::Vector{UInt}
    values::Vector{I}
end

function DenseHashIndices{I}(; sizehint = 8) where {I}
    @assert sizehint > 0
    DenseHashIndices{I}(fill(0, sizehint), Vector{UInt}(), Vector{I}())
end

function rehash!(indices::DenseHashIndices{I}, newsize::Integer) where {I}
    slots = resize!(indices.slots, newsize)
    fill!(slots, 0)
    bit_mask = newsize - one(typeof(newsize)) # newsize is a power of two
    
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
            # This is potentially an infinte loop and care must be taken by the callee not
            # to overfill the container
        end
    end
end

Base.length(indices::DenseHashIndices) = length(indices.values)

# Token interface
Dictionaries.istokenizable(::DenseHashIndices) = true

Dictionaries.tokentype(::DenseHashIndices) = Int

# Duration iteration the token cannot be used for deletion - we do not worry about the slots
@propagate_inbounds function Dictionaries.iteratetoken(indices::DenseHashIndices)
    if isempty(indices.values)
        return nothing
    end
    return ((0, 1), 1)
end

@propagate_inbounds function Dictionaries.iteratetoken(indices::DenseHashIndices, index::Int)
    if index == length(indices.values)
        return nothing
    end
    index = index + 1
    return ((0, index), index)
end


function Dictionaries.gettoken(indices::DenseHashIndices{I}, i::I) where {I}
    full_hash = hash(i)
    n_slots = length(indices.slots)
    bit_mask = n_slots - 1 # n_slots is always a power of two

    trial_slot = reinterpret(Int, full_hash) & bit_mask
    @inbounds while true
        trial_slot = (trial_slot + 1)
        trial_index = indices.slots[trial_slot]
        if trial_index == 0
            return (false, (0, 0))
        end

        if full_hash == indices.hashes[trial_index] && (perfect_hash(i) || isequal(i, indices.values[trial_index]))
            return (true, (trial_slot, trial_index))
        end

        trial_slot = trial_slot & bit_mask
        # This is potentially an infinte loop and care must be taken upon insertion not
        # to completely fill the container
    end
end

@propagate_inbounds function Dictionaries.gettokenvalue(indices::DenseHashIndices, (_slot, index))
    return indices.values[index]
end

# Insertion interface
Dictionaries.isinsertable(::DenseHashIndices) = true

function Dictionaries.gettoken!(indices::DenseHashIndices{I}, i::I) where {I}
    full_hash = hash(i)
    n_slots = length(indices.slots)
    bit_mask = n_slots - 1 # n_slots is always a power of two
    n_values = length(indices.values)

    trial_slot = reinterpret(Int, full_hash) & bit_mask
    trial_index = 0
    @inbounds while true
        trial_slot = (trial_slot + 1)
        trial_index = indices.slots[trial_slot]
        if trial_index <= 0
            indices.slots[trial_slot] = n_values + 1
            break
        end

        trial_hash = indices.hashes[trial_index]

        if trial_hash == full_hash && (perfect_hash(i) || isequal(i, indices.values[trial_index]))
            return (true, (trial_slot, trial_index))
        end

        trial_slot = trial_slot & bit_mask
        # This is potentially an infinte loop and care must be taken upon insertion not
        # to completely fill the container
    end

    push!(indices.hashes, full_hash)
    push!(indices.values, i)
    
    # Expand the hash map when it reaches 2/3rd full
    if 3 * (n_values + 1) > 2 * n_slots
        # Grow faster for small hash maps than for large ones
        rehash!(indices, n_slots > 16000 ? 2 * n_slots : 4 * n_slots)
    end

    return (false, (trial_slot, n_values + 1))
end

@propagate_inbounds function Dictionaries.deletetoken!(indices::DenseHashIndices, (slot, index))
    indices.slots[slot] = -1
    splice!(indices.hashes, index)
    splice!(indices.values, index)

    # Shrink the hash map when it is less than 1/4th full
    n_slots = length(indices.slots)
    n_values = length(indices.values)
    if 4 * n_values < n_slots && n_slots > 8
        # Halve each time
        rehash!(indices, n_slots >> 0x01)
    end

    return indices
end

# Factories

Base.empty(::DenseHashIndices, ::Type{I}) where {I} = DenseHashIndices{I}()

########

struct DenseHashDictionary{I, T} <: AbstractDictionary{I, T}
    indices::DenseHashIndices{I}
    values::Vector{T}
end

function DenseHashDictionary{I, T}(; sizehint = 8) where {I, T}
    DenseHashDictionary{I, T}(DenseHashIndices{I}(; sizehint = sizehint), Vector{T}())
end

# indices

Base.keys(dict::DenseHashDictionary) = dict.indices

# tokens

Dictionaries.tokenized(dict::DenseHashDictionary) = dict.values

# values

function Dictionaries.istokenassigned(dict::DenseHashDictionary, (_slot, index))
    return isassigned(dict.values, index)
end

@propagate_inbounds function Dictionaries.gettokenvalue(dict::DenseHashDictionary, (_slot, index))
    return dict.values[index]
end

Dictionaries.issettable(::DenseHashDictionary) = true

@propagate_inbounds function Dictionaries.settokenvalue!(dict::DenseHashDictionary{<:Any, T}, (_slot, index), value::T) where {T}
    dict.values[index] = value
    return dict
end

# insertion

function Dictionaries.gettoken!(dict::DenseHashDictionary{I}, i::I) where {I}
    (hadtoken, (slot, index)) = gettoken!(keys(dict), i)
    if !hadtoken
        resize!(dict.values, length(dict.values) + 1)
    end
    return (hadtoken, (slot, index))
end

function Dictionaries.deletetoken!(dict::DenseHashDictionary, (slot, index))
    deletetoken!(dict.indices, (slot, index))
    splice!(dict.values, index)
    return dict
end


# Factories

Base.empty(::DenseHashIndices, ::Type{I}, ::Type{T}) where {I, T} = DenseHashDictionary{I, T}()

function Base.similar(indices::DenseHashIndices{I}, ::Type{T}) where {I, T}
    return DenseHashDictionary(indices, Vector{T}(undef, length(indices)))
end

end # module