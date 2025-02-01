# Make `map!` fast if the inputs and output share tokens

function Base.map!(f, out::AbstractDictionary, d::AbstractDictionary, d2::AbstractDictionary, ds::AbstractDictionary...)
    if sharetokens(out, d, d2, ds...)
        @inbounds for t in tokens(out)
            settokenvalue!(out, t, f(gettokenvalue(d, t), gettokenvalue(d2, t), map(x -> @inbounds(gettokenvalue(x, t)), ds)...))
        end
    elseif istokenizable(out)
       @boundscheck if !isequal(keys(out), keys(d)) || !isequal(keys(out), keys(d2)) || any(dict -> !isequal(keys(out), keys(dict)), ds)
            throw(IndexError("Indices do not match"))
       end
       @inbounds for txs in zip(tokens(out), d, d2, ds...)
            t = txs[1]
            xs = Base.tail(txs)
            settokenvalue!(out, t, f(xs...))
       end
    else
        @boundscheck if !isequal(keys(out), keys(d)) || !isequal(keys(out), keys(d2)) || any(dict -> !isequal(keys(out), keys(dict)), ds)
            throw(IndexError("Indices do not match"))
        end 
        @inbounds for ixs in zip(keys(out), d, d2, ds...)
            i = ixs[1]
            xs = Base.tail(ixs)
            out[i] = f(xs...)
        end
    end
    return out
end

# (avoid an _apply for the two-input case)
function Base.map!(f, out::AbstractDictionary, d::AbstractDictionary, d2::AbstractDictionary)
    if sharetokens(out, d, d2)
        @inbounds for t in tokens(out)
            settokenvalue!(out, t, f(gettokenvalue(d, t), gettokenvalue(d2, t)))
        end
    elseif istokenizable(out)
        @boundscheck if !isequal(keys(out), keys(d)) || !isequal(keys(out), keys(d2))
            throw(IndexError("Indices do not match"))
       end
       @inbounds for (t, x, x2) in zip(tokens(out), d, d2)
            settokenvalue!(out, t, f(x, x2))
       end
    else
        @boundscheck if !isequal(keys(out), keys(d)) || !isequal(keys(out), keys(d2))
            throw(IndexError("Indices do not match"))
        end 
        @inbounds for i in keys(out)
            out[i] = f(d[i], d2[i])
        end
    end
    return out
end

function Base.map!(f, out::AbstractDictionary, d::AbstractDictionary)
    if sharetokens(out, d)
        @inbounds for t in tokens(out)
            settokenvalue!(out, t, f(gettokenvalue(d, t)))
        end
    elseif istokenizable(out)
       @boundscheck if !isequal(keys(out), keys(d))
            throw(IndexError("Indices do not match"))
       end
       @inbounds for (t, x) in zip(tokens(out), d)
            settokenvalue!(out, t, f(x))
       end
    else
        @boundscheck if !isequal(keys(out), keys(d))
             throw(IndexError("Indices do not match"))
        end
        @inbounds for (i, x) in zip(keys(out), d)
            out[i] = f(x)
        end
    end
    return out
end

function Base.map!(f, out::AbstractDictionary)
    if istokenizable(out)
        @inbounds for t in tokens(out)
            settokenvalue!(out, t, f())
        end
    else
        @inbounds for i in keys(out)
            out[i] = f()
        end
    end
    return out
end

function Base.map(f, d::AbstractDictionary)
    out = similar(d, Base.promote_op(f, eltype(d)))
    @inbounds map!(f, out, d)
    return out
end

function Base.map(f, d::AbstractDictionary, ds::AbstractDictionary...)
    out = similar(d, Base.promote_op(f, eltype(d), map(eltype, ds)...))
    @inbounds map!(f, out, d, ds...)
    return out
end

# Lazy map container

struct MappedDictionary{I, T, F, Maps <: Tuple{AbstractDictionary{<:I}, Vararg{AbstractDictionary{<:I}}}} <: AbstractDictionary{I, T}
    f::F
    dicts::Maps
end

Base.keys(d::MappedDictionary{I}) where {I} = keys(_dicts(d)[1])::AbstractIndices{I}
_dicts(d::MappedDictionary{I}) where {I} = getfield(d, :dicts)
_f(d::MappedDictionary{I}) where {I} = getfield(d, :f)

function Base.isassigned(d::MappedDictionary{I}, i::I) where {I}
    return all(Base.Fix2(isassigned, i), _dicts(d))
end

function Base.isassigned(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, i::I) where {I, T}
    return isassigned(_dicts(d)[1], i)
end

@propagate_inbounds function Base.getindex(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, i::I) where {I, T}
    return _f(d)(_dicts(d)[1][i])::T
end

@inline function Base.getindex(d::MappedDictionary{I, T}, i::I) where {I, T}
    @boundscheck checkindex(_dicts(d)[1], i)
    return _f(d)(map(x -> @inbounds(x[i]), _dicts(d))...)::T
end

# TODO FIXME what do about tokens when there is more than one mapped dictionary? For now, we disable them...
istokenizable(d::MappedDictionary) = false
function istokenizable(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}) where {I, T}
    return istokenizable(_dicts(d)[1])
end

@propagate_inbounds function gettokenvalue(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, t) where {I, T}
    return _f(d)(gettokenvalue(_dicts(d)[1], t))::T
end

function istokenassigned(d::MappedDictionary{I, T, <:Any, <:Tuple{AbstractDictionary{<:I}}}, t) where {I, T}
    return istokenassigned(_dicts(d)[1], t)
end

empty_type(::Type{<:MappedDictionary{<:Any, <:Any, <:Any, <:Tuple{D, Vararg{AbstractDictionary}}}}, ::Type{I}, ::Type{T}) where {I, T, D} = empty_type(D, I, T)

function Iterators.map(f, d::AbstractDictionary)
    I = keytype(d)
    T = Base.promote_op(f, eltype(d)) # Base normally wouldn't invoke inference for something like this...
    return MappedDictionary{I, T, typeof(f), Tuple{typeof(d)}}(f, (d,))
end
