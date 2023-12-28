
# Lazy broadcasted dictionary

struct BroadcastedDictionary{I, T, F, Data <: Tuple} <: AbstractDictionary{I, T}
    f::F
    data::Data
    sharetokens::Bool
end

# We prevent @inbounds annotations from propagating into the call to the user
# defined function `d.f` using an extra layer of indirection with `_call_f`.
_call_f(d::BroadcastedDictionary, args...) = getfield(d, :f)(args...)

_f(d::BroadcastedDictionary) = getfield(d, :f)
_data(d::BroadcastedDictionary) = getfield(d, :data)

@propagate_inbounds function BroadcastedDictionary(f, data)
    dicts = _dicts(data...)
    sharetokens = _sharetokens(dicts...)
    I = keytype(dicts[1])
    Ts = Base.Broadcast.eltypes(data)
    T = return_type(f, Ts)

    return BroadcastedDictionary{I, T, typeof(f), typeof(data)}(f, data, sharetokens)
end

@inline Base.keys(d::BroadcastedDictionary) = _keys(_data(d)...)

@propagate_inbounds function Base.getindex(d::BroadcastedDictionary{I}, i::I) where {I}
    if istokenizable(d)
        t = gettoken(d, i)
        return _call_f(d, _gettokenvalue(t, _data(d)...)...)
    else
        return _call_f(d, _getindex(i, _data(d)...)...)
    end
end

function Base.isassigned(d::BroadcastedDictionary{I}, i::I) where {I}
    return _isassigned(i, _data(d)...)
end

istokenizable(d::BroadcastedDictionary) = getfield(d, :sharetokens)
function tokens(d::BroadcastedDictionary)
    _tokens(_data(d)...)
end

@propagate_inbounds function gettoken(d::BroadcastedDictionary, i)
    return gettoken(_tokens(_data(d)...), i)
end

function istokenassigned(d::BroadcastedDictionary, t)
    return _istokenassigned(t, _data(d)...)
end

@propagate_inbounds function gettokenvalue(d::BroadcastedDictionary, t)
    return _call_f(d, _gettokenvalue(t, _data(d)...)...)
end

@inline function Base.similar(d::BroadcastedDictionary, ::Type{T}) where {T}
    return similar(_dicts(d.data...)[1], T)
end

@inline _dicts(d::AbstractDictionary, ds...) = (d, _dicts(ds...)...)
@inline _dicts(d, ds...) = (_dicts(ds...)...,)
_dicts() = ()

@inline _tokens(d::AbstractDictionary, ds...) = tokens(d)
@inline _tokens(d, ds...) = _tokens(ds...)

@inline _keys(d::AbstractDictionary, ds...) = keys(d)
@inline _keys(d, ds...) = _keys(ds...)

_sharetokens(d) = true
@propagate_inbounds function _sharetokens(d, d2, ds...)
    if sharetokens(d, d2)
        return _sharetokens(d, ds...)
    else
        @boundscheck if !isequal(keys(d), keys(d2))
            throw(IndexError("Indices do not match"))
        end
        return false
    end
end

_getindex(i) = ()
@propagate_inbounds _getindex(i, d::AbstractDictionary, ds...) = (d[i], _getindex(i, ds...)...)
@propagate_inbounds _getindex(i, d::Ref, ds...) = (d[], _getindex(i, ds...)...)
@propagate_inbounds _getindex(i, d, ds...) = (d[CartesianIndex()], _getindex(i, ds...)...)

_gettokenvalue(t) = ()
@propagate_inbounds _gettokenvalue(t, d::AbstractDictionary, ds...) = (gettokenvalue(d, t), _gettokenvalue(t, ds...)...)
@propagate_inbounds _gettokenvalue(t, d::Ref, ds...) = (d[], _gettokenvalue(t, ds...)...)
@propagate_inbounds _gettokenvalue(t, d, ds...) = (d[CartesianIndex()], _gettokenvalue(t, ds...)...)

_isassigned(i) = true
_isassigned(i, d, ds...) = _isassigned(i, ds...)
function _isassigned(i, d::AbstractDictionary, ds...)
    if isassigned(d, i)
        return _isassigned(i, ds...)
    else
        return false
    end
end

_istokenassigned(t) = true
_istokenassigned(t, d, ds...) = _istokenassigned(t, ds...)
function _istokenassigned(t, d::AbstractDictionary, ds...)
    if istokenassigned(d, t)
        return _istokenassigned(t, ds...)
    else
        return false
    end
end

## Hook into `Base.Broadcast` machinery

Base.Broadcast.broadcastable(d::AbstractDictionary) = d

struct DictionaryStyle <: Base.Broadcast.BroadcastStyle
end

Base.Broadcast.BroadcastStyle(::Type{<:AbstractDictionary}) = DictionaryStyle()
Base.Broadcast.BroadcastStyle(::DictionaryStyle, ::Base.Broadcast.AbstractArrayStyle{0}) = DictionaryStyle()

# Now we overload `broadcasted` directly
function Base.Broadcast.broadcasted(::DictionaryStyle, f, args...)
    return BroadcastedDictionary(f, args)
end

Base.Broadcast.materialize(d::BroadcastedDictionary) = copy(d)
Base.Broadcast.materialize!(out::AbstractDictionary, d::BroadcastedDictionary) = copyto!(out, d)

Base.Broadcast.materialize!(out::AbstractDictionary, bc::Base.Broadcast.Broadcasted{Base.Broadcast.DefaultArrayStyle{0}, Nothing, typeof(identity)}) = fill!(out, bc.args[1][])
