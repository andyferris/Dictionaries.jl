module HashDictionaries

using Dictionaries
using Base: @propagate_inbounds

export HashIndices, HashDictionary

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

function Base.copy(h::HashIndices{T}, ::Type{T}) where {T}
    return HashIndices{T}(copy(h.slots), copy(h.inds), h.ndel, h.count, h.idxfloor, h.maxprobe)
end

## Length
Base.length(h::HashIndices) = h.count


## Token interface

Dictionaries.istokenizable(::HashIndices) = true
Dictionaries.tokentype(::HashIndices) = Int

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

@propagate_inbounds function Dictionaries.iteratetoken(h::HashIndices{T}) where {T}
    idx = skip_deleted(h, h.idxfloor)
    h.idxfloor = idx # An optimization to skip unnecessary elements when iterating multiple times
    
    if idx > length(h.inds)
        return nothing
    else
        return (idx, idx + 1)
    end
end

@propagate_inbounds function Dictionaries.iteratetoken(h::HashIndices{T}, idx::Int) where {T}
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

function Dictionaries.gettoken(h::HashIndices{T}, key::T) where {T}
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
@propagate_inbounds function Dictionaries.gettokenvalue(h::HashIndices, token::Int)
    return h.inds[token]
end


# insertable interface
Dictionaries.isinsertable(::HashIndices) = true

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

function rehash!(h::HashIndices, newsz::Int = length(h.inds))
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



function Dictionaries.gettoken!(h::HashIndices{T}, key::T) where {T}
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


function Dictionaries.deletetoken!(h::HashIndices{T}, token::Int) where {T}
    h.slots[token] = 0x2
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), h.inds, token-1)
    
    h.ndel += 1
    h.count -= 1
    return h
end

# Since deleting elements doesn't mess with iteration, we can use `unsafe_filter!``
Base.filter!(pred, h::HashIndices) = Base.unsafe_filter!(pred, h)

# The default insertable indices
Base.empty(d::HashIndices, ::Type{T}) where {T} = HashIndices{T}()


mutable struct HashDictionary{I,T} <: AbstractDictionary{I, T}
    indices::HashIndices{I}
    values::Vector{T}

    HashDictionary{I, T}(indices::HashIndices{I}, values::Vector{T}, ::Nothing) where {I, T} = new(indices, values)
end

"""
    HashDictionary{I, T}()

Construct an empty `HashDictionary` with index type `I` and element type `T`. This type of
dictionary uses hashes for fast lookup and insertion, and is both mutable and insertable.
(See `issettable` and `isinsertable`).
"""
function HashDictionary{I, T}(; sizehint::Int = 16) where {I, T}
    indices = HashIndices{I}(; sizehint=sizehint)
    HashDictionary{I, T}(indices, Vector{T}(undef, length(indices.slots)), nothing)
end
HashDictionary{I}() where {I} = HashDictionary{I, Any}()
HashDictionary() = HashDictionary{Any}()

"""
    HashDictionary{I, T}(indices, undef::UndefInitializer)

Construct a `HashDictionary` with index type `I` and element type `T`. The container is
initialized with `keys` that match the values of `indices`, but the values are unintialized.
"""
function HashDictionary{I, T}(indices, ::UndefInitializer) where {I, T} 
    return HashDictionary{I, T}(HashIndices{I}(indices), undef)
end

function HashDictionary{I, T}(h::HashIndices{I}, ::UndefInitializer) where {I, T}
    return HashDictionary{I, T}(h, Vector{T}(undef, length(h.slots)), nothing)
end

function HashDictionary{I, T}(indices::HashIndices{I}, values) where {I, T}
    vals = Vector{T}(undef, length(indices.slots))
    d = HashDictionary{I, T}(indices, vals, nothing)

    @inbounds for (i, v) in zip(tokens(indices), values)
        vals[i] = v
    end

    return d
end

"""
    HashDictionary(indices, values)
    HashDictionary{I}(indices, values)
    HashDictionary{I, T}(indices, values)

Construct a `HashDictionary` with indices from `indices` and values from `values`, matched
in iteration order.
"""
function HashDictionary{I, T}(indices, values) where {I, T}
    iter_size = Base.IteratorSize(indices)
    if iter_size isa Union{Base.HasLength, Base.HasShape}
        d = HashDictionary{I, T}(; sizehint = length(indices)*2)
    else
        d = HashDictionary{I, T}()
    end

    for (i, v) in zip(indices, values)
        insert!(d, i, v)
    end

    return d
end
function HashDictionary{I}(indices, values) where {I}
    if Base.IteratorEltype(values) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnkown
        values = collect(values)
    end

    return HashDictionary{I, eltype(values)}(indices, values)
end

function HashDictionary(indices, values)
    if Base.IteratorEltype(indices) === Base.EltypeUnknown()
        # TODO: implement automatic widening from iterators of Base.EltypeUnkown
        indices = collect(indices)
    end

    return HashDictionary{eltype(indices)}(indices, values)
end

"""
    HashDictionary(dict::AbstractDictionary)
    HashDictionary{I}(dict::AbstractDictionary)
    HashDictionary{I, T}(dict::AbstractDictionary)

Construct a copy of `dict` with the same keys and values.
(For copying an `AbstractDict` or other iterable of `Pair`s, see `dictionary`).
"""
HashDictionary(dict::AbstractDictionary) = HashDictionary(keys(dict), dict)
HashDictionary{I}(dict::AbstractDictionary) where {I} = HashDictionary{I}(keys(dict), dict)
HashDictionary{I, T}(dict::AbstractDictionary) where {I, T} = HashDictionary{I, T}(keys(dict), dict)

## Implementation

Base.keys(d::HashDictionary) = d.indices
Dictionaries.isinsertable(d::HashDictionary) = true
Dictionaries.issettable(d::HashDictionary) = true

@propagate_inbounds function Dictionaries.gettoken(d::HashDictionary{I}, i::I) where {I}
    return gettoken(keys(d), i)
end

@inline function Dictionaries.gettokenvalue(d::HashDictionary, token)
    return @inbounds d.values[token]
end

function Dictionaries.istokenassigned(d::HashDictionary, token)
    return isassigned(d.values, token)
end

@inline function Dictionaries.settokenvalue!(d::HashDictionary{I, T}, token, value::T) where {I, T}
    @inbounds d.values[token] = value
    return d
end

function Dictionaries.gettoken!(d::HashDictionary{T}, key::T) where {T}
    indices = keys(d)
    (token, values) = _gettoken!(indices, d.values, key)
    if token < 0
        (token, values) = _insert!(indices, values, key, -token)
        d.values = values
        return (false, token)
    else
        d.values = values
        return (true, token)
    end 
end

function Base.copy(d::HashDictionary{I, T}, ::Type{I}, ::Type{T}) where {I, T}
    return HashDictionary{I, T}(d.indices, copy(d.values), nothing)
end

Dictionaries.tokenized(d::HashDictionary) = d.values

function Base.empty!(d::HashDictionary)
    empty!(d.indices)
    empty!(d.values)
    resize!(d.values, length(keys(d).slots))
    return d
end

function Dictionaries.deletetoken!(d::HashDictionary{I, T}, token) where {I, T}
    deletetoken!(keys(d), token)
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), d.values, token-1)
    return d
end

function Base.sizehint!(d::HashDictionary, sz::Int)
    d.values = _sizehint!(d.indices, d.values, sz)
    return d
end

function Base.rehash!(d::HashDictionary, newsz::Int = length(d.indices))
    _rehash!(d.indices, d.values, newsz)
    return d
end

Base.filter!(pred, d::HashDictionary) = Base.unsafe_filter!(pred, d)

# For `HashIndices` we don't copy the indices, we allow the `keys` to remain identical (`===`)
function Base.similar(indices::HashIndices{I}, ::Type{T}) where {I, T}
    return HashDictionary{I, T}(indices, undef)
end

function Base.empty(indices::HashIndices, ::Type{I}, ::Type{T}) where {I, T}
    return HashDictionary{I, T}()
end

end # module