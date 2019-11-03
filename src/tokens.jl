## A simple token-based interface

"""
    gettoken(dict, i)

Return the tuple `(hasindex, token)`, where `hasindex` is `true` if `i` exists in `dict`.
The `token` can be used to retrieve a value using the `gettokenvalue` function.

Mutable dictionaries allow you to set a corresponding value via the `settokenvalue!`
function (see `ismutable`).

Insertable dictionaries provide the `gettoken!` function (see `isinsertable`).
"""
@propagate_inbounds function gettoken(d::AbstractDictionary{I}, i::I) where I
    @boundscheck if !haskey(keys(d), i)
        return (false, i)
    end
    return (true, i)
end

@propagate_inbounds function gettokenvalue(d::AbstractDictionary, i)
    return d[i]
end

# This default method will generally work but maybe should be overloaded to be less crappy
@propagate_inbounds function istokenassigned(d::AbstractDictionary, token)
    try
        gettokenvalue(d, token)
        return true
    catch e
        if isa(e, BoundsError) || isa(e, IndexError) || isa(e, UndefRefError)
            return false
        else
            rethrow()
        end
    end
end

@propagate_inbounds function settokenvalue!(d::AbstractDictionary, i, value)
    return d[i] = value
end

# TODO: possibly istokenassigned(d::AbstractDictionary, token) --> Bool

## `tokenize` - for fast mutual iteration over multiple containers

tokens(d::AbstractDictionary) = keys(d)
tokens(i::AbstractIndices) = i

function _tokens(i1::AbstractIndices, i2::AbstractIndices)
    if issetequal(i1, i2)
        return i1
    else
        throw(IndexError("Indices do not match"))
    end
end

_tokens(t1::AbstractDictionary, i2::AbstractIndices) = tokens(keys(t1), i2)
_tokens(i1::AbstractIndices, t2::AbstractDictionary) = tokens(i1, keys(t2))
function _tokens(t1::AbstractDictionary, t2::AbstractDictionary)
    if t1 === t2 # Could possibly do a bit less strict than ===
        return t1
    else
        return _tokens(keys(t1), keys(t2))
    end
end

tokens(d1::AbstractDictionary, d2::AbstractDictionary, ds::AbstractDictionary...) = _tokens(tokens(d1), tokens(d2, ds...))

function tokenize(d::AbstractDictionary, ds::AbstractDictionary...)
    t = tokens(d, ds...)
    return (t, _tokenize(t, d, ds...)...)
end

_tokenize(t::AbstractDictionary, d::AbstractDictionary) = (tokenized(t, d),)
_tokenize(t::AbstractDictionary, d::AbstractDictionary, ds::AbstractDictionary...) = (tokenized(t, d), _tokenize(t, ds...)...)

tokenized(t::AbstractDictionary, d::AbstractDictionary) = d

# iteration
#=
function iterate(d::AbstractDictionary, s...)
    (tokens, d2) = tokenize(d)
    it = iterate(tokens(AbstractDictionary), s...)
    if it === nothing
        return nothing
    else
        (i, s2) = it
        return (@inbounds(d2[i]), s2)
    end
end
=#
