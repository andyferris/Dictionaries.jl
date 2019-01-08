tokens(m::AbstractMap) = keys(i)
tokens(i::AbstractIndices) = i

function _tokens(i1::AbstractIndices, i2::AbstractIndices)
    if issetequal(i1, i2)
        return i1
    else
        throw(IndexError("Indices do not match"))
    end
end

_tokens(t1::AbstractMap, i2::AbstractIndices) = tokens(keys(t1), i2)
_tokens(i1::AbstractIndices, t2::AbstractMap) = tokens(i1, keys(t2))
function _tokens(t1::AbstractMap, t2::AbstractMap)
    if t1 === t2 # Could possibly do a bit less strict than ===
        return t1
    else
        return _tokens(keys(t1), keys(t2))
    end
end

tokens(m1::AbstractMap, m2::AbstractMap, ms::AbstractMap...) = _tokens(tokens(m1), tokens(m2, ms...))

function tokenize(m::AbstractMap, ms::AbstractMap...)
    t = tokens(m, ms...)
    return (t, _tokenize(t, m, ms...)...)
end

_tokenize(t::AbstractMap, m::AbstractMap) = (tokenized(t, m),)
_tokenize(t::AbstractMap, m::AbstractMap, ms::AbstractMap...) = (tokenized(t, m), _tokenize(t, ms...)...)

tokenized(t::AbstractMap, m::AbstractMap) = m

# iteration
#=
function iterate(m::AbstractMap, s...)
    (tokens, m2) = tokenize(m)
    it = iterate(tokens(AbstractMap), s...)
    if it === nothing
        return nothing
    else
        (i, s2) = it
        return (@inbounds(m2[i]), s2)
    end
end
=#
