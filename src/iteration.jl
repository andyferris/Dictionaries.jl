
function Base.iterate(d::AbstractDictionary{I, T}, s...) where {I, T}
    inds = keys(d)
    tmp = iterate(inds, s...)
    tmp === nothing && return nothing
    (i::I, s2) = tmp
    return (@inbounds(d[i]::T), s2)
end

# We use a "token" system to optimize iteration-based algorithms (map, reduce, ...)

# map

# TODO do I need @noinline?
@noinline function _map!(f, tokens, out_tokenized, d_tokenized)
    @inbounds for t in tokens
        out_tokenized[t] = f(d_tokenized[t])
    end
end

@noinline function _map!(f, tokens, out_tokenized, d_tokenized, ds_tokenized...)
    @inbounds for t in tokens
        out_tokenized[t] = f(map(mt -> mt[t], d_tokenized, ds_tokenized...)...)
    end
end

function Base.map!(f, out::AbstractDictionary, d::AbstractDictionary)
    _map!(f, tokenize(out, d)...)
    return out
end

function Base.map!(f, out::AbstractDictionary, d::AbstractDictionary, ds::AbstractDictionary...)
    _map!(f, tokenize(out, d, ds...)...)
    return out
end

function Base.map(f, d::AbstractDictionary)
    out = similar(d, Core.Compiler.return_type(f, Tuple{eltype(d)}))
    map!(f, out, d)
    return out
end

function Base.map(f, d::AbstractDictionary, ds::AbstractDictionary...)
    out = similar(d, Base.promote_op(f, Tuple{eltype(d), map(eltype, ds)...}))
    map!(f, out, d, ds...)
    return out
end

##

# like zip, but iterates through matched-up indices rather than natural iteration order
