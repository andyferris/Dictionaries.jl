
function Base.iterate(m::AbstractMap{I, T}, s...) where {I, T}
    inds = keys(m)
    tmp = iterate(inds, s...)
    tmp === nothing && return nothing
    (i::I, s2) = tmp
    return (@inbounds(m[i]::T), s2)
end

# We use a "token" system to optimize iteration-based algorithms (map, reduce, ...)

# map

@noinline function _map!(f, tokens, out_tokenized, m_tokenized)
    @inbounds for t in tokens
        out_tokenized[t] = f(m_tokenized[t])
    end
end

@noinline function _map!(f, tokens, out_tokenized, m_tokenized, ms_tokenized...)
    @inbounds for t in tokens
        out_tokenized[t] = f(map(mt -> mt[t], m_tokenized, ms_tokenized)...)
    end
end

function Base.map!(f, out::AbstractMap, m::AbstractMap)
    _map!(f, tokenize(out, m)...)
    return out
end

function Base.map!(f, out::AbstractMap, m::AbstractMap, ms::AbstractMap...)
    _map!(f, tokenize(out, m, ms...)...)
    return out
end

function Base.map(f, m::AbstractMap)
    out = similar(m, Core.Compiler.return_type(f, Tuple{eltype(m)}))
    map!(f, out, m)
    return out
end

function Base.map(f, m::AbstractMap, ms::AbstractMap...)
    out = similar(m, Base.promote_op(f, Tuple{eltype(m), eltype.(ms)...}))
    map!(f, out, m, ms...)
    return out
end