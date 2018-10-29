# These can be changed, to trade off better performance for space
const global maxallowedprobe = 16
const global maxprobeshift   = 6

mutable struct HashIndex{T} <: AbstractIndices{T}
    slots::Array{UInt8,1}
    keys::Array{T,1}
    ndel::Int
    count::Int
    idxfloor::Int  # an index <= the indices of all used slots
    maxprobe::Int
end

function HashIndex{T}(; sizehint::Int = 16) where {T}
    HashIndex{T}(zeros(UInt8, sizehint), Vector{T}(undef, sizehint), 0, 0, 1, 0)
end

HashIndex() = HashIndex{Any}()

Base.empty(h::HashIndex, ::Type{T}) where {T} = HashIndex{T}()

function Base.empty!(h::HashIndex{T}) where {T}
    fill!(h.slots, 0x0)
    sz = length(h.slots)
    empty!(h.keys)
    resize!(h.keys, sz)
    h.ndel = 0
    h.count = 0
    h.idxfloor = 1
    return h
end

hashtoken(key, sz::Int) = (((hash(key)%Int) & (sz-1)) + 1)::Int

@propagate_inbounds isslotempty(h::HashIndex, i::Int) = h.slots[i] == 0x0
@propagate_inbounds isslotfilled(h::HashIndex, i::Int) = h.slots[i] == 0x1
@propagate_inbounds isslotmissing(h::HashIndex, i::Int) = h.slots[i] == 0x2

function rehash!(h::HashIndex{T}, newsz::Int = length(h.keys)) where {T}
    olds = h.slots
    oldk = h.keys
    sz = length(olds)
    newsz = _tablesz(newsz)
    h.idxfloor = 1
    if h.count == 0
        resize!(h.slots, newsz)
        fill!(h.slots, 0)
        resize!(h.keys, newsz)
        h.ndel = 0
        return h
    end

    slots = zeros(UInt8, newsz)
    keys = Vector{T}(undef, newsz)
    count = 0
    maxprobe = h.maxprobe

    for i ∈ 1:sz
        @inbounds if olds[i] == 0x1
            k = oldk[i]
            index0 = index = hashtoken(k, newsz)
            while slots[index] != 0
                index = (index & (newsz-1)) + 1
            end
            probe = (index - index0) & (newsz-1)
            probe > maxprobe && (maxprobe = probe)
            slots[index] = 0x1
            keys[index] = k
            count += 1
        end
    end

    h.slots = slots
    h.keys = keys
    h.count = count
    h.ndel = 0
    h.maxprobe = maxprobe

    return h
end

function sizehint!(h::HashIndex{T}, newsz::Int) where {T}
    oldsz = length(d.slots)
    if newsz <= oldsz
        # todo: shrink
        # be careful: rehash!() assumes everything fits. it was only designed
        # for growing.
        return d
    end
    # grow at least 25%
    newsz = min(max(newsz, (oldsz*5)>>2),
                Base.max_values(T))
    rehash!(d, newsz)
end

# get the token where a key is stored, or -1 if not present
function indextoken(h::HashIndex{T}, key::T) where {T}
    sz = length(h.keys)
    iter = 0
    maxprobe = h.maxprobe
    token = hashtoken(key, sz)
    keys = h.keys

    @inbounds while true
        if isslotempty(h, token)
            break
        end
        if !isslotmissing(h, token) && (key === keys[token] || isequal(key, keys[token]))
            return token
        end

        token = (token & (sz-1)) + 1
        iter += 1
        iter > maxprobe && break
    end
    return -1
end

# get the index where a key is stored, or -pos if not present
# and the key would be inserted at pos
# This version is for use by setindex! and get!
function indextoken!(h::HashIndex{T}, key::T) where {T}
    sz = length(h.keys)
    iter = 0
    maxprobe = h.maxprobe
    token = hashtoken(key, sz)
    avail = 0
    keys = h.keys

    @inbounds while true
        if isslotempty(h,token)
            if avail < 0
                return avail
            end
            return -token
        end

        if isslotmissing(h, token)
            if avail == 0
                # found an available slot, but need to keep scanning
                # in case "key" already exists in a later collided slot.
                avail = -token
            end
        elseif key === keys[token] || isequal(key, keys[token])
            return token
        end

        token = (token & (sz-1)) + 1
        iter += 1
        iter > maxprobe && break
    end

    avail < 0 && return avail

    maxallowed = max(maxallowedprobe, sz>>maxprobeshift)
    # Check if key is not present, may need to keep searching to find slot
    @inbounds while iter < maxallowed
        if !isslotfilled(h,token)
            h.maxprobe = iter
            return -token
        end
        token = (token & (sz-1)) + 1
        iter += 1
    end

    rehash!(h, h.count > 64000 ? sz*2 : sz*4)

    return indextoken!(h, key)
end

@propagate_inbounds function _insert!(h::HashIndex{T}, key::T, token::Int) where {T}
    h.slots[token] = 0x1
    h.keys[token] = key
    h.count += 1
    if token < h.idxfloor
        h.idxfloor = token
    end

    sz = length(h.keys)
    # Rehash now if necessary
    if h.ndel >= ((3*sz)>>2) || h.count*3 > sz*2
        # > 3/4 deleted or > 2/3 full
        rehash!(h, h.count > 64000 ? h.count*2 : h.count*4)
    end
end

function Base.insert!(h::HashIndex{T}, key0) where {T}
    key = convert(T, key0)
    if !isequal(key, key0)
        throw(ArgumentError("$key0 is not a valid key for type $T"))
    end
    _insert!(h, v0, key)
end

function Base.insert!(h::HashIndex{T}, key::T) where {T}
    token = indextoken!(h, key)

    if token > 0
        throw(IndexError("HashIndex already contains key: $key"))
    else
        @inbounds _insert!(h, key, -token)
    end

    return h
end

function Base.in(key::T, h::HashIndex{T}) where {T}
    return indextoken(h, key) >= 0
end

function _delete!(h::HashIndex{T}, token::Int) where {T}
    h.slots[token] = 0x2
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), h.keys, token-1)
    
    h.ndel += 1
    h.count -= 1
    return h
end

function Base.delete!(h::HashIndex{T}, key::T) where {T}
    index = indextoken(h, key)
    if index > 0
        _delete!(h, index)
    else
        throw(IndexError("HashIndex does not contain key: $key"))
    end
    return h
end

# Iteration
function skip_deleted(h::HashIndex, i)
    L = length(h.slots)
    @inbounds while i <= L && !isslotfilled(h, i)
        i += 1
    end
    return i
end

function skip_deleted_floor!(h::HashIndex)
    idx = skip_deleted(h, h.idxfloor)
    h.idxfloor = idx
    idx
end

@propagate_inbounds _iterate(t::HashIndex{T}, i::Int) where {T} = i > length(t.keys) ? nothing : (t.keys[i], i + 1)
function Base.iterate(h::HashIndex)
    _iterate(h, skip_deleted_floor!(h))
end
@propagate_inbounds Base.iterate(h::HashIndex, i::Int) = _iterate(h, skip_deleted(h, i))

Base.isempty(h::HashIndex) = (h.count == 0)
Base.length(h::HashIndex) = h.count
