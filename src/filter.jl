## Indices

function Base.filter(pred, inds::AbstractIndices)
    out = empty(inds)
    for i in inds
        if pred(i)
            insert!(out, i)
        end
    end
    return out
end

# Occasionally it might be faster to copy all and remove just a few indices...
# TODO: export `unsafe_filter`, or hook up to certain datatypes or something
function unsafe_filter(pred, inds::AbstractIndices)
    out = copy(inds)
    Base.unsafe_filter!(pred, out)
    return out
end

struct FilteredIndices{I, Parent <: AbstractIndices{I}, Pred} <: AbstractIndices{I}
    parent::Parent
    pred::Pred
end

Base.parent(inds::FilteredIndices) = getfield(inds, :parent)
_pred(inds::FilteredIndices) = getfield(inds, :pred)
Base.IteratorSize(::FilteredIndices) = Base.SizeUnknown() # You can still call `length`, but it is slower
Base.length(inds::FilteredIndices) = count(_pred(inds), parent(inds))

function Base.in(i::I, inds::FilteredIndices{I}) where {I}
    return i in parent(inds) && _pred(inds)(i)
end

function Base.iterate(inds::FilteredIndices{I}, s...) where {I}
    tmp = iterate(parent(inds), s...)
    tmp === nothing && return nothing
    (i::I, s2) = tmp
    if _pred(inds)(i)
        return (i, s2)
    else
        return iterate(inds, s2)
    end
    return nothing
end

function Base.iterate(inds::ReverseIndices{I,<:FilteredIndices}, s...) where {I}
    tmp = iterate(Iterators.reverse(parent(inds)), s...)
    tmp === nothing && return nothing
    (i::I, s2) = tmp
    if _pred(inds)(i)
        return (i, s2)
    else
        return iterate(inds, s2)
    end
    return nothing
end

istokenizable(inds::FilteredIndices) = istokenizable(parent(inds))
@propagate_inbounds function iteratetoken(inds::FilteredIndices{I}, s...) where {I}
    p = parent(inds)
    tmp = iteratetoken(p, s...)
    while (tmp !== nothing)
        (token, state) = tmp
        i = gettokenvalue(p, token)
        if _pred(inds)(i)
            return tmp
        end
        tmp = iteratetoken(p, state)
    end
    return nothing
end
@propagate_inbounds function iteratetoken_reverse(inds::FilteredIndices{I}, s...) where {I}
    p = parent(inds)
    tmp = iteratetoken_reverse(p, s...)
    while (tmp !== nothing)
        (token, state) = tmp
        i = gettokenvalue(p, token)
        if _pred(inds)(i)
            return tmp
        end
        tmp = iteratetoken_reverse(p, state)
    end
    return nothing
end
@propagate_inbounds function gettoken(inds::FilteredIndices{I}, i::I) where {I}
    (hastoken, token) = gettoken(parent(inds), i)
    @boundscheck if hastoken
        return (_pred(inds)(@inbounds gettokenvalue(parent, token)), token)
    end
    return (hastoken, token)
end
@propagate_inbounds gettokenvalue(inds::FilteredIndices, t) = gettokenvalue(parent(inds), t)

function filterview(pred, inds::AbstractIndices{I}) where {I}
    return FilteredIndices{I, typeof(inds), typeof(pred)}(inds, pred)
end

Iterators.reverse(inds::FilteredIndices) = filterview(_pred(inds), Iterators.reverse(parent(inds)))

empty_type(::Type{<:FilteredIndices{<:Any, Inds}}, ::Type{I}) where {I, Inds} = empty_type(Inds, I)

function Base.isempty(inds::FilteredIndices)
    for _ in inds
        return false
    end
    return true
end

function randtoken(rng::Random.AbstractRNG, inds::FilteredIndices)
    if isempty(inds)
        throw(ArgumentError("range must be non-empty"))
    end
    p = parent(inds)
    while true
        # Rejection sampling
        token = randtoken(rng, p)
        if _pred(inds)(@inbounds gettokenvalue(p, token))
            return token
        end
    end
end

## Dictionaries

function Base.filter(pred, dict::AbstractDictionary)
    out = empty(dict)
    for (i, v) in pairs(dict)
        if pred(v)
            insert!(out, i, v)
        end
    end
    return out
end

# Occasionally it might be faster to copy all and remove just a few indices...
# TODO: export `unsafe_filter`, or hook up to certain datatypes or something
function unsafe_filter(pred, dict::AbstractDictionary)
    out = copy(dict)
    Base.unsafe_filter!(pred, dict)
    return out
end

struct FilteredDictionary{I, V, Parent <: AbstractDictionary{I, V}, Pred} <: AbstractDictionary{I, V}
    parent::Parent
    pred::Pred
end

Base.parent(dict::FilteredDictionary) = getfield(dict, :parent)
_pred(dict::FilteredDictionary) = getfield(dict, :pred)
Base.IteratorSize(::FilteredDictionary) = Base.SizeUnknown() # You can still call `length`, but it is slower

@inline function Base.keys(dict::FilteredDictionary)
    return filterview(i -> _pred(dict)(parent(dict)[i]), keys(parent(dict)))
end

function Base.isassigned(dict::FilteredDictionary{I}, i::I) where {I}
    p = parent(dict)
    if !isassigned(p, i)
        return false
    end
    @inbounds v = p[i]
    return _pred(dict)(v)
end

@propagate_inbounds function Base.getindex(dict::FilteredDictionary{I}, i::I) where {I}
    p = parent(dict)
    (hastoken, token) = gettoken(p, i)
    @boundscheck if !hastoken
        throw(IndexError("Dictionary does not contain index: $i"))
    end
    out = gettokenvalue(p, token)
    @boundscheck if !_pred(dict)(out)
        throw(IndexError("Dictionary does not contain index: $i"))
    end
    return out
end

# These dictionaries are not settable - changing the values can change the keys

istokenizable(dict::FilteredDictionary) = istokenizable(parent(dict))
@propagate_inbounds function gettoken(dict::FilteredDictionary{I}, i::I) where {I}
    (hastoken, token) = gettoken(parent(dict), i)
    @boundscheck if hastoken
        return (_pred(dict)(@inbounds gettokenvalue(parent, token)), token)
    end
    return (hastoken, token)
end
@propagate_inbounds gettokenvalue(dict::FilteredDictionary, t) = gettokenvalue(parent(dict), t)
@propagate_inbounds istokenassigned(dict::FilteredDictionary, t) = istokenassigned(parent(dict), t)

function filterview(pred, inds::AbstractDictionary{I, T}) where {I, T}
    return FilteredDictionary{I, T, typeof(inds), typeof(pred)}(inds, pred)
end

Base.similar(dict::FilteredDictionary, ::Type{T}) where {T} = similar(parent(dict), T)
empty_type(::Type{<:FilteredDictionary{<:Any, <:Any, D}}, ::Type{I}, ::Type{T}) where {I, T, D} = empty_type(D, I, T)
