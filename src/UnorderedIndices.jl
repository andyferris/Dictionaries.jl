# These can be changed, to trade off better performance for space
const global maxallowedprobe = 16
const global maxprobeshift   = 6

mutable struct UnorderedIndices{T} <: AbstractIndices{T}
    slots::Array{UInt8,1}
    inds::Array{T,1}
    ndel::Int
    count::Int
    idxfloor::Int  # an index <= the indices of all used slots
    maxprobe::Int
end

UnorderedIndices() = UnorderedIndices{Any}()

"""
    UnorderedIndices{I}()

Construct an empty `UnorderedIndices` with indices of type `I`. This container uses hashes for
fast lookup, and is insertable. (See `isinsertable`). Unlike `Indices`, the order of elements
is undefined (depending on the implementation of `hash` and the history of the collection).
"""
function UnorderedIndices{T}(; sizehint::Int = 16) where {T}
    sz = Base._tablesz(sizehint)
    UnorderedIndices{T}(zeros(UInt8, sz), Vector{T}(undef, sz), 0, 0, 1, 0)
end


## Constructors

"""
    UnorderedIndices(iter)
    UnorderedIndices{I}(iter)

Construct a `UnorderedIndices` with indices from iterable container `iter`.
"""
function UnorderedIndices(iter)
    if Base.IteratorEltype(iter) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnkown
        iter = collect(iter)
    end

    return UnorderedIndices{eltype(iter)}(iter)
end

function UnorderedIndices{T}(iter) where {T}
    iter_size = Base.IteratorSize(iter)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        h = UnorderedIndices{T}(; sizehint = length(iter)*2)
    else
        h = UnorderedIndices{T}()
    end

    for i in iter
        insert!(h, i) # should this be `set!` or `insert!`?
    end

    return h
end

Base.convert(::Type{AbstractIndices{I}}, inds::UnorderedIndices) where {I} = convert(UnorderedIndices{I}, inds)
Base.convert(::Type{UnorderedIndices}, inds::AbstractIndices{I}) where {I} = convert(UnorderedIndices{I}, inds)
function Base.convert(::Type{UnorderedIndices{I}}, inds::AbstractIndices) where {I}
    return  UnorderedIndices{I}(inds)
end

Base.convert(::Type{UnorderedIndices{I}}, inds::UnorderedIndices{I}) where {I} = inds
function Base.convert(::Type{UnorderedIndices{I}}, inds::UnorderedIndices) where {I}
    return copy(inds, I)
end

function Base.copy(h::UnorderedIndices{T}, ::Type{T}) where {T}
    return UnorderedIndices{T}(copy(h.slots), copy(h.inds), h.ndel, h.count, h.idxfloor, h.maxprobe)
end

## Length
Base.length(h::UnorderedIndices) = h.count

## Token interface

istokenizable(::UnorderedIndices) = true
tokentype(::UnorderedIndices) = Int

@propagate_inbounds isslotempty(h::UnorderedIndices, i::Int) = h.slots[i] == 0x00
@propagate_inbounds isslotfilled(h::UnorderedIndices, i::Int) = h.slots[i] == 0x01
@propagate_inbounds isslotdeleted(h::UnorderedIndices, i::Int) = h.slots[i] == 0x02 # deletion marker/tombstone

istokenassigned(h::UnorderedIndices, i::Int) = h.slots[i] == 0x01 # isslotfilled(h, i)

# iteratetoken

@propagate_inbounds function iteratetoken(h::UnorderedIndices{T}) where {T}
    idx = h.idxfloor
    slots = h.slots
    L = length(slots)

    @inbounds while idx <= L
        if slots[idx] == 0x01
            h.idxfloor = idx # An optimization to skip unnecessary elements when iterating multiple times
            return (idx, idx + 1)
        end

        idx += 1
    end

    return nothing
end

@propagate_inbounds function iteratetoken(h::UnorderedIndices{T}, idx::Int) where {T}
    slots = h.slots
    L = length(slots)

    @inbounds while idx <= L
        if slots[idx] == 0x01
            return (idx, idx + 1)
        end

        idx += 1
    end

    return nothing
end

@propagate_inbounds function iteratetoken_reverse(h::UnorderedIndices{T}) where {T}
    slots = h.slots
    L = length(slots)
    idx = L

    @inbounds while idx > 0
        if slots[idx] == 0x01
            return (idx, idx - 1)
        end

        idx -= 1
    end

    return nothing
end

@propagate_inbounds function iteratetoken_reverse(h::UnorderedIndices{T}, idx::Int) where {T}
    slots = h.slots

    @inbounds while idx > 0
        if slots[idx] == 0x01
            return (idx, idx - 1)
        end

        idx -= 1
    end

    return nothing
end

# gettoken
function hashtoken(key, sz::Int)
    # Given key what is the hash slot? sz is a power of two
    (((hash(key)%Int) & (sz-1)) + 1)::Int
end

function gettoken(h::UnorderedIndices{T}, key) where {T}
    inds = h.inds
    slots = h.slots
    sz = length(inds)
    iter = 0
    maxprobe = h.maxprobe
    token = hashtoken(key, sz)

    @inbounds while true
        slot = slots[token]
        if slot == 0x00 # isslotempty(h, token)
            break
        elseif slot == 0x01 #= !isslotdeleted(h, token) =#
            k = inds[token]
            if key === k || isequal(key, k)
                return (true, token)
            end
        end

        token = (token & (sz-1)) + 1
        iter += 1
        iter > maxprobe && break
    end
    return (false, 0)
end

# gettokenvalue
@propagate_inbounds function gettokenvalue(h::UnorderedIndices, token::Int)
    return h.inds[token]
end


# insertable interface
isinsertable(::UnorderedIndices) = true

function Base.empty!(h::UnorderedIndices{T}) where {T}
    fill!(h.slots, 0x0) # It should be OK to reduce this back to some smaller size.
    sz = length(h.slots)
    empty!(h.inds)
    resize!(h.inds, sz)
    h.ndel = 0
    h.count = 0
    h.idxfloor = 1
    return h
end

function rehash!(h::UnorderedIndices, newsz::Int = length(h.inds))
    _rehash!(h, nothing, newsz)
    return h
end

function _rehash!(h::UnorderedIndices{T}, oldv::Union{Nothing, Vector}, newsz::Int) where {T}
    olds = h.slots
    oldk = h.inds
    sz = length(olds)
    newsz = Base._tablesz(newsz)
    h.idxfloor = 1
    if h.count == 0
        resize!(slots, newsz)
        fill!(slots, 0)
        resize!(inds, newsz)
        error()
        oldv === nothing || resize!(oldv, newsz)
        h.ndel = 0
        return oldv
    end

    slots = zeros(UInt8, newsz)
    keys = Vector{T}(undef, newsz)
    vals = oldv === nothing ? nothing : Vector{eltype(oldv)}(undef, newsz)
    count = 0
    maxprobe = h.maxprobe

    for i ∈ 1:sz
        @inbounds if olds[i] == 0x1
            k = oldk[i]
            v = vals === nothing ? nothing : oldv[i]
            index0 = index = hashtoken(k, newsz)
            while slots[index] != 0
                index = (index & (newsz-1)) + 1
            end
            probe = (index - index0) & (newsz-1)
            probe > maxprobe && (maxprobe = probe)
            slots[index] = 0x1
            keys[index] = k
            vals === nothing || (vals[index] = v)
            count += 1
        end
    end

    h.slots = slots
    h.inds = keys
    h.count = count
    h.ndel = 0
    h.maxprobe = maxprobe

    return vals
end

Base.sizehint!(h::UnorderedIndices, newsz::Int) = _sizehint!(h, nothing, newsz)

function _sizehint!(h::UnorderedIndices{T}, values::Union{Nothing, Vector}, newsz::Int) where {T}
    oldsz = length(h.slots)
    if newsz <= oldsz
        # TODO: shrink
        # be careful: rehash!() assumes everything fits. it was only designed
        # for growing.
        return hash
    end
    # grow at least 25%
    newsz = min(max(newsz, (oldsz*5)>>2),
                Base.max_values(T))
    return _rehash!(h, values, newsz)
end



function gettoken!(h::UnorderedIndices{T}, key::T) where {T}
    (token, _) = _gettoken!(h, nothing, key) # This will make sure a slot is available at `token` (or `-token` if it is new)

    if token < 0
        @inbounds (token, _) = _insert!(h, nothing, key, -token) # This will fill the slot with `key`
        return (false, token)
    else
        return (true, token)
    end
end

# get the index where a key is stored, or -pos if not present 
# and the key would be inserted at pos
# This version is for use by insert!, set! and get!
function _gettoken!(h::UnorderedIndices{T}, values::Union{Nothing, Vector}, key::T) where {T}
    inds = h.inds
    slots = h.slots
    sz = length(inds)
    iter = 0
    maxprobe = h.maxprobe
    token = hashtoken(key, sz)
    avail = 0

    # Search of the key is present or if there is a deleted slot `key` could fill.
    @inbounds while true
        slot = slots[token]
        if slot == 0x00 # isslotempty(h, token)
            if avail < 0
                return (avail, values)
            end
            return (-token, values)
        elseif slot == 0x02 # isslotdeleted(h, token)
            if avail == 0
                # found an available deleted slot, but we need to keep scanning
                # in case `key` already exists in a later collided slot.
                avail = -token
            end
        else
            k = inds[token]
            if key === k || isequal(key, k)
                return (token, values)
            end
        end

        token = (token & (sz-1)) + 1
        iter += 1
        iter > maxprobe && break
    end

    avail < 0 && return (avail, values)

    # The key definitely isn't present, but a slot may become available if we increase
    # `maxprobe` (up to some reasonable global limits).
    maxallowed = max(maxallowedprobe, sz>>maxprobeshift)
    
    @inbounds while iter < maxallowed
        if slots[token] != 0x01 # !isslotfilled(h,token)
            h.maxprobe = iter
            return (-token, values)
        end
        token = (token & (sz-1)) + 1
        iter += 1
    end

    # If we get here, then all the probable slots are filled, and the only recourse is to
    # increase the size of the hash map and try again
    values = _rehash!(h, values, h.count > 64000 ? sz*2 : sz*4)
    return _gettoken!(h, values, key)
end

@propagate_inbounds function _insert!(h::UnorderedIndices{T}, values::Union{Nothing, Vector}, key::T, token::Int) where {T}
    h.slots[token] = 0x1
    h.inds[token] = key
    h.count += 1
    if token < h.idxfloor
        h.idxfloor = token
    end
    
    # TODO revisit this...
    #=
    sz = length(h.inds)
    # Rehash now if necessary
    if h.ndel >= ((3*sz)>>2) || h.count*3 > sz*2
        # > 3/4 deleted or > 2/3 full
        values = _rehash!(h, values, h.count > 64000 ? h.count*2 : h.count*4)
        (_, token) = gettoken(h, key)
    end
    =#

    return (token, values)
end


@inline function deletetoken!(h::UnorderedIndices{T}, token::Int) where {T}
    h.slots[token] = 0x2
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), h.inds, token-1)
    
    h.ndel += 1
    h.count -= 1
    return h
end

# Since deleting elements doesn't mess with iteration, we can use `unsafe_filter!``
Base.filter!(pred, h::UnorderedIndices) = Base.unsafe_filter!(pred, h)

empty_type(::Type{<:UnorderedIndices}, ::Type{I}) where {I} = UnorderedIndices{I}

function randtoken(rng::Random.AbstractRNG, inds::UnorderedIndices)
    if inds.count == 0
        throw(ArgumentError("collection must be non-empty"))
    end

    # Rejection sampling to handle holes
    range = Base.OneTo(length(inds.slots))
    @inbounds while true
        i = rand(rng, range)
        if inds.slots[i] === 0x01
            return i
        end
    end
end
