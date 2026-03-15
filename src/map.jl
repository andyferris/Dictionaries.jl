# Make `map!` fast if the inputs and output share tokens

function Base.map!(f, out::AbstractDictionary, d::AbstractDictionary, d2::AbstractDictionary, ds::AbstractDictionary...)
    if sharetokens(out, d, d2, ds...)
        for t in tokens(out)
            y = f(@inbounds(gettokenvalue(d, t)), @inbounds(gettokenvalue(d2, t)), map(x -> @inbounds(gettokenvalue(x, t)), ds)...)
            @inbounds settokenvalue!(out, t, y)
        end
    elseif istokenizable(out)
       @boundscheck if !isequal(keys(out), keys(d)) || !isequal(keys(out), keys(d2)) || any(dict -> !isequal(keys(out), keys(dict)), ds)
            throw(IndexError("Indices do not match"))
       end
       for txs in zip(tokens(out), d, d2, ds...)
            t = @inbounds txs[1]
            xs = @inbounds Base.tail(txs)
            y = f(xs...)
            @inbounds settokenvalue!(out, t, y)
       end
    else
        @boundscheck if !isequal(keys(out), keys(d)) || !isequal(keys(out), keys(d2)) || any(dict -> !isequal(keys(out), keys(dict)), ds)
            throw(IndexError("Indices do not match"))
        end 
        for ixs in zip(keys(out), d, d2, ds...)
            i = @inbounds ixs[1]
            xs = @inbounds Base.tail(ixs)
            y = f(xs...)
            @inbounds out[i] = y
        end
    end
    return out
end

# (avoid an _apply for the two-input case)
function Base.map!(f, out::AbstractDictionary, d::AbstractDictionary, d2::AbstractDictionary)
    if sharetokens(out, d, d2)
        for t in tokens(out)
            x = @inbounds gettokenvalue(d, t)
            x2 = @inbounds gettokenvalue(d2, t)
            y = f(x, x2)
            @inbounds settokenvalue!(out, t, y)
        end
    elseif istokenizable(out)
        @boundscheck if !isequal(keys(out), keys(d)) || !isequal(keys(out), keys(d2))
            throw(IndexError("Indices do not match"))
       end
       for (t, x, x2) in zip(tokens(out), d, d2)
            y = f(x, x2)
            @inbounds settokenvalue!(out, t, y)
       end
    else
        @boundscheck if !isequal(keys(out), keys(d)) || !isequal(keys(out), keys(d2))
            throw(IndexError("Indices do not match"))
        end 
        for i in keys(out)
            y = f(@inbounds(d[i]), @inbounds(d2[i]))
            @inbounds out[i] = y
        end
    end
    return out
end

function Base.map!(f, out::AbstractDictionary, d::AbstractDictionary)
    if sharetokens(out, d)
        for t in tokens(out)
            x = @inbounds gettokenvalue(d, t)
            y = f(x)
            @inbounds settokenvalue!(out, t, y)
        end
    elseif istokenizable(out)
       @boundscheck if !isequal(keys(out), keys(d))
            throw(IndexError("Indices do not match"))
       end
       for (t, x) in zip(tokens(out), d)
            y = f(x)
            @inbounds settokenvalue!(out, t, y)
       end
    else
        @boundscheck if !isequal(keys(out), keys(d))
             throw(IndexError("Indices do not match"))
        end
        for (i, x) in zip(keys(out), d)
            y = f(x)
            @inbounds out[i] = y
        end
    end
    return out
end

function Base.map!(f, out::AbstractDictionary)
    if istokenizable(out)
        for t in tokens(out)
            y = f()
            @inbounds settokenvalue!(out, t, y)
        end
    else
        for i in keys(out)
            y = f()
            @inbounds out[i] = y
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
