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

function HashIndices{T}(; sizehint::Int = 16) where {T}
    HashIndices{T}(zeros(UInt8, sizehint), Vector{T}(undef, sizehint), 0, 0, 1, 0)
end

HashIndices() = HashIndices{Any}()

isinsertable(::HashIndices) = true
Base.empty(::HashIndices, ::Type{T}) where {T} = HashIndices{T}()

function Base.empty!(h::HashIndices{T}) where {T}
    fill!(h.slots, 0x0)
    sz = length(h.slots)
    empty!(h.inds)
    resize!(h.inds, sz)
    h.ndel = 0
    h.count = 0
    h.idxfloor = 1
    return h
end

function Base.copy(h::HashIndices{T}) where {T}
    return HashIndices{T}(copy(h.slots), copy(h.inds), h.ndel, h.count, h.idxfloor, h.maxprobe)
end

hashtoken(key, sz::Int) = (((hash(key)%Int) & (sz-1)) + 1)::Int

@propagate_inbounds isslotempty(h::HashIndices, i::Int) = h.slots[i] == 0x0
@propagate_inbounds isslotfilled(h::HashIndices, i::Int) = h.slots[i] == 0x1
@propagate_inbounds isslotmissing(h::HashIndices, i::Int) = h.slots[i] == 0x2

Base.rehash!(h::HashIndices, newsz::Int = length(h.inds)) = _rehash!(h, nothing, newsz)

function _rehash!(h::HashIndices{T}, values::Union{Nothing, Vector}, newsz::Int) where {T}
    olds = h.slots
    oldk = h.inds
    sz = length(olds)
    newsz = Base._tablesz(newsz)
    h.idxfloor = 1
    if h.count == 0
        resize!(h.slots, newsz)
        fill!(h.slots, 0)
        resize!(h.inds, newsz)
        values === nothing || resize!(values, newsz)
        h.ndel = 0
        return h
    end

    slots = zeros(UInt8, newsz)
    keys = Vector{T}(undef, newsz)
    count = 0
    maxprobe = h.maxprobe

    # We want to mutate `values`, need to be careful...
    oldv = values === nothing ? nothing : copy(values)
    isbitstype(eltype(values)) || for i ∈ 1:sz
        @inbounds if olds[i] == 0x1
            ccall(:jl_arrayunset, Cvoid, (Any, UInt), values, i-1)
        end
    end

    for i ∈ 1:sz
        @inbounds if olds[i] == 0x1
            k = oldk[i]
            v = values === nothing ? nothing : oldv[i]
            index0 = index = hashtoken(k, newsz)
            while slots[index] != 0
                index = (index & (newsz-1)) + 1
            end
            probe = (index - index0) & (newsz-1)
            probe > maxprobe && (maxprobe = probe)
            slots[index] = 0x1
            keys[index] = k
            (values !== nothing) || (values[index] = v)
            count += 1
        end
    end

    h.slots = slots
    h.inds = keys
    h.count = count
    h.ndel = 0
    h.maxprobe = maxprobe

    return h
end

Base.sizehint!(h::HashIndices, newsz::Int) = _sizehint!(h, nothing, newsz)

function _sizehint!(h::HashIndices{T}, values::Union{Nothing, Vector}, newsz::Int) where {T}
    oldsz = length(d.slots)
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

# get the token where a key is stored, or -1 if not present
function indextoken(h::HashIndices{T}, key::T) where {T}
    sz = length(h.inds)
    iter = 0
    maxprobe = h.maxprobe
    token = hashtoken(key, sz)
    keys = h.inds

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
function indextoken!(h::HashIndices{T}, values::Union{Nothing, Vector}, key::T) where {T}
    sz = length(h.inds)
    iter = 0
    maxprobe = h.maxprobe
    token = hashtoken(key, sz)
    avail = 0
    keys = h.inds

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

    _rehash!(h, values, h.count > 64000 ? sz*2 : sz*4)

    return indextoken!(h, values, key)
end

@propagate_inbounds function _insert!(h::HashIndices{T}, values::Union{Nothing, Vector}, key::T, token::Int) where {T}
    h.slots[token] = 0x1
    h.inds[token] = key
    h.count += 1
    if token < h.idxfloor
        h.idxfloor = token
    end

    sz = length(h.inds)
    # Rehash now if necessary
    if h.ndel >= ((3*sz)>>2) || h.count*3 > sz*2
        # > 3/4 deleted or > 2/3 full
        _rehash!(h, values, h.count > 64000 ? h.count*2 : h.count*4)
    end
end

function Base.insert!(h::HashIndices{T}, i::T) where {T}
    token = -indextoken!(h, nothing, i)

    if token < 0
        throw(IndexError("HashIndices already contains index: $i"))
    end

    @inbounds _insert!(h, nothing, i, token)

    return h
end

function Base.in(i::T, h::HashIndices{T}) where {T}
    return indextoken(h, i) >= 0
end

function _delete!(h::HashIndices{T}, token::Int) where {T}
    h.slots[token] = 0x2
    isbitstype(T) || ccall(:jl_arrayunset, Cvoid, (Any, UInt), h.inds, token-1)
    
    h.ndel += 1
    h.count -= 1
    return h
end

function Base.delete!(h::HashIndices{T}, i::T) where {T}
    token = indextoken(h, i)
    if token > 0
        _delete!(h, token)
    else
        throw(IndexError("HashIndices does not contain index: $i"))
    end
    return h
end

# Iteration
function skip_deleted(h::HashIndices, i)
    L = length(h.slots)
    @inbounds while i <= L && !isslotfilled(h, i)
        i += 1
    end
    return i
end

function skip_deleted_floor!(h::HashIndices)
    idx = skip_deleted(h, h.idxfloor)
    h.idxfloor = idx
    idx
end

@propagate_inbounds _iterate(h::HashIndices{T}, i::Int) where {T} = i > length(h.inds) ? nothing : (h.inds[i], i + 1)

function Base.iterate(h::HashIndices)
    _iterate(h, skip_deleted_floor!(h))
end
@propagate_inbounds Base.iterate(h::HashIndices, i::Int) = _iterate(h, skip_deleted(h, i))

Base.isempty(h::HashIndices) = (h.count == 0)
Base.length(h::HashIndices) = h.count

# ------------------------------------------------------------------------
# The tokens of a hash index is an AbstractDictionary from keys to integer token

struct HashTokens{I} <: AbstractDictionary{I, Int}
    indices::HashIndices{I}
end

tokens(h::HashIndices{I}) where {I} = HashTokens{I}(h)

Base.keys(t::HashTokens) = t.indices
@inline function Base.getindex(t::HashTokens{I}, i::I) where {I}
    token = indextoken(t.indices, i)

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