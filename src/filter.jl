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
Base.IteratorSize(::FilteredIndices) = Base.SizeUnknown() # You can still call `length`, but it is slower
Base.length(inds::FilteredIndices) = count(inds.pred, inds.parent)

function Base.in(i::I, inds::FilteredIndices{I}) where {I}
    return i in inds.parent && inds.pred(i)
end

function Base.iterate(inds::FilteredIndices{I}, s...) where {I}
    tmp = iterate(inds.parent, s...)
    tmp === nothing && return nothing
    (i::I, s2) = tmp
    if inds.pred(i)
        return (i, s2)
    else
        return iterate(inds, s2)
    end
end

function filterview(pred, inds::AbstractIndices{I}) where {I}
    return FilteredIndices{I, typeof(inds), typeof(pred)}(inds, pred)
end

Iterators.reverse(inds::FilteredIndices) = filterview(inds.pred, Iterators.reverse(parent(inds)))

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

Base.IteratorSize(::FilteredDictionary) = Base.SizeUnknown # You can still call `length`, but it is slower

@inline function Base.keys(dict::FilteredDictionary)
    return filterview(i -> dict.pred(dict.parent[i]), keys(dict.parent))
end

@propagate_inbounds function Base.getindex(dict::FilteredDictionary{I}, i::I) where {I}
    parent = dict.parent
    (hastoken, token) = gettoken(parent, i)
    @boundscheck if !hastoken
        throw(IndexError("Dictionary does not contain index: $i"))
    end
    out = gettokenvalue(parent, token)
    @boundscheck if !dict.pred(out)
        throw(IndexError("Dictionary does not contain index: $i"))
    end
    return out
end

function filterview(pred, inds::AbstractDictionary{I, T}) where {I, T}
    return FilteredDictionary{I, T, typeof(inds), typeof(pred)}(inds, pred)
end

Base.similar(dict::FilteredDictionary, ::Type{T}, indices) where {T} = similar(dict.parent, T, indices)
Base.empty(dict::FilteredDictionary, ::Type{T}) where {T} = similar(dict.parent, T)