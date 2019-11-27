# These can be changed, to trade off better performance for space
const global maxallowedprobe = 16
const global maxprobeshift   = 6

mutable struct HashIndices{T} <: AbstractIndices{T}
    slots::Array{UInt8,1}
    inds::Array{T,1}
    ndel::Int
    count::Int
    idxfloor::Int  # an index <= the indices of all used slots
    maxprobe::Int
end

HashIndices() = HashIndices{Any}()

"""
    HashIndices{I}()

Construct an empty `HashIndices` with indices of type `I`. This container uses hashes for
fast lookup, and is insertable. (See `isinsertable`).
"""
function HashIndices{T}(; sizehint::Int = 16) where {T}
    sz = Base._tablesz(sizehint)
    HashIndices{T}(zeros(UInt8, sz), Vector{T}(undef, sz), 0, 0, 1, 0)
end


## Constructors

"""
    HashIndices(iter)
    HashIndices{I}(iter)

Construct a `HashIndices` with indices from iterable container `iter`.
"""
function HashIndices(iter)
    if Base.IteratorEltype(iter) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnkown
        iter = collect(iter)
    end

    return HashIndices{eltype(iter)}(iter)
end

function HashIndices{T}(iter) where {T}
    iter_size = Base.IteratorSize(iter)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        h = HashIndices{T}(; sizehint = length(iter)*2)
    else
        h = HashIndices{T}()
    end

    for i in iter
        insert!(h, i) # should this be `set!` or `insert!`?
    end

    return h
end

function Base.copy(h::HashIndices{T}) where {T}
    return HashIndices{T}(copy(h.slots), copy(h.inds), h.ndel, h.count, h.idxfloor, h.maxprobe)
end

Base.empty(::HashIndices, ::Type{T}) where {T} = HashIndices{T}()


## Length
Base.length(h::HashIndices) = h.count


## Token interface

istokenizable(::HashIndices) = true
tokentype(::HashIndices) = Int

@propagate_inbounds isslotempty(h::HashIndices, i::Int) = h.slots[i] == 0x0
@propagate_inbounds isslotfilled(h::HashIndices, i::Int) = h.slots[i] == 0x1
@propagate_inbounds isslotdeleted(h::HashIndices, i::Int) = h.slots[i] == 0x2 # deletion marker/tombstone

istokenassigned(h::HashIndices, i::Int) = isslotfilled(h, i)

# iteratetoken

function skip_deleted(h::HashIndices, i)
    L = length(h.slots)
    @inbounds while i <= L && !isslotfilled(h, i)
        i += 1
    end
    return i
end

@propagate_inbounds function iteratetoken(h::HashIndices{T}) where {T}
    idx = skip_deleted(h, h.idxfloor)
    h.idxfloor = idx # An optimization to skip unnecessary elements when iterating multiple times
    
    if idx > length(h.inds)
        return nothing
    else
        return (idx, idx + 1)
    end
end

@propagate_inbounds function iteratetoken(h::HashIndices{T}, idx::Int) where {T}
    idx = skip_deleted(h, idx)
    
    if idx > length(h.inds)
        return nothing
    else
        return (idx, idx + 1)
    end
end

# gettoken
function hashtoken(key, sz::Int)
    # Given key what is the hash slot? sz is a power of two
    (((hash(key)%Int) & (sz-1)) + 1)::Int
end

function gettoken(h::HashIndices{T}, key::T) where {T}
    sz = length(h.inds)
    iter = 0
    maxprobe = h.maxprobe
    token = hashtoken(key, sz)
    keys = h.inds

    @inbounds while true
        if isslotempty(h, token)
            break
        end
        if !isslotdeleted(h, token) && (key === keys[token] || isequal(key, keys[token]))
            return (true, token)
        end

        token = (token & (sz-1)) + 1
        iter += 1
        iter > maxprobe && break
    end
    return (false, 0)
end

# gettokenvalue
@propagate_inbounds function gettokenvalue(h::HashIndices, token::Int)
    return h.inds[token]
end


# insertable interface
isinsertable(::HashIndices) = true

function Base.empty!(h::HashIndices{T}) where {T}
    fill!(h.slots, 0x0) # It should be OK to reduce this back to some smaller size.
    sz = length(h.slots)
    empty!(h.inds)
    resize!(h.inds, sz)
    h.ndel = 0
    h.count = 0
    h.idxfloor = 1
    return h
end

function Base.rehash!(h::HashIndices, newsz::Int = length(h.inds))
    _rehash!(h, nothing, newsz)
    return h
end

function _rehash!(h::HashIndices{T}, oldv::Union{Nothing, Vector}, newsz::Int) where {T}
    olds = h.slots
    oldk = h.inds
    sz = length(olds)
    newsz = Base._tablesz(newsz)
    h.idxfloor = 1
    if h.count == 0
        resize!(h.slots, newsz)
        fill!(h.slots, 0)
        resize!(h.inds, newsz)
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

Base.sizehint!(h::HashIndices, newsz::Int) = _sizehint!(h, nothing, newsz)

function _sizehint!(h::HashIndices{T}, values::Union{Nothing, Vector}, newsz::Int) where {T}
    oldsz = length(h.slots)
    if newsz <= oldsz
        # todo: shrink
        # be careful: rehash!() assumes everything fits. it was only designed
        # for growing.
        return hash
    end
    # grow at least 25%
    newsz = min(max(newsz, (oldsz*5)>>2),
                Base.max_values(T))
    _rehash!(h, values, newsz)
end



function gettoken!(h::HashIndices{T}, key::T) where {T}
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
function _gettoken!(h::HashIndices{T}, values::Union{Nothing, Vector}, key::T) where {T}
    sz = length(h.inds)
    iter = 0
    maxprobe = h.maxprobe
    token = hashtoken(key, sz)
    avail = 0
    keys = h.inds

    # Search of the key is present or if there is a deleted slot `key` could fill.
    @inbounds while true
        if isslotempty(h, token)
            if avail < 0
                return (avail, values)
            end
            return (-token, values)
        end

        if isslotdeleted(h, token)
            if avail == 0
                # found an available deleted slot, but we need to keep scanning
                # in case `key` already exists in a later collided slot.
                avail = -token
            end
        elseif key === keys[token] || isequal(key, keys[token])
            return (token, values)
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
        if !isslotfilled(h,token)
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

@propagate_inbounds function _insert!(h::HashIndices{T}, values::Union{Nothing, Vector}, key::T, token::Int) where {T}
    h.slots[token] = 0x1
    h.inds[token] = key
    h.count += 1
    if token < h.idxfloor
        h.idxfloor = token
    end
    
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


function deletetoken!(h::HashIndices{T}, token::Int) where {T}
    h.slots[token] = 0x2
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), h.inds, token-1)
    
    h.ndel += 1
    h.count -= 1
    return h
end

# Since deleting elements doesn't mess with iteration, we can use `unsafe_filter!``
Base.filter!(pred, h::HashIndices) = Base.unsafe_filter!(pred, h)

# The default insertable indices
Base.empty(d::AbstractIndices, ::Type{T}) where {T} = HashIndices{T}()

# ------------------------------------------------------------------------
# The tokens of a hash index is an AbstractDictionary from keys to integer token
#=
struct HashTokens{I} <: AbstractDictionary{I, Int}
    indices::HashIndices{I}
end

tokens(h::HashIndices{I}) where {I} = HashTokens{I}(h)

Base.keys(t::HashTokens) = t.indices
@inline function Base.getindex(t::HashTokens{I}, i::I) where {I}
    token = gettoken(t.indices, i)

    @boundscheck if token < 0
        throw(IndexError("HashTokens has no index: $i"))
    end

    return token
end

@propagate_inbounds _iterate(t::HashTokens{T}, i::Int) where {T} = i > length(t.indices.inds) ? nothing : (i, i + 1)
function Base.iterate(t::HashTokens)
    _iterate(t, skip_deleted_floor!(t.indices))
end
@propagate_inbounds Base.iterate(t::HashTokens, i::Int) = _iterate(t, skip_deleted(t.indices, i))

tokenized(t::HashTokens, h::HashIndices) = h.inds
=#