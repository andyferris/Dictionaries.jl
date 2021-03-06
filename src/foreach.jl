function Base.foreach(f, d::AbstractDictionary, d2::AbstractDictionary, ds::AbstractDictionary...)
    if sharetokens(d, d2, ds...)
        @inbounds for t in tokens(d)
            f(gettokenvalue(d, t), gettokenvalue(d2, t), map(x -> @inbounds(gettokenvalue(x, t)), ds)...)
        end
    else
       @boundscheck if !isequal(keys(d), keys(d2)) || any(dict -> !isequal(keys(d), keys(dict)), ds)
            throw(IndexError("Indices do not match"))
       end
       @inbounds for xs in zip(d, d2, ds...)
            f(xs...)
       end
    end
    return nothing
end

# (avoid an _apply for the two-input case)
function Base.foreach(f, d::AbstractDictionary, d2::AbstractDictionary)
    if sharetokens(d, d2)
        @inbounds for t in tokens(d)
            f(gettokenvalue(d, t), gettokenvalue(d2, t))
        end
    else
       @boundscheck if !isequal(keys(d), keys(d2))
            throw(IndexError("Indices do not match"))
       end
       @inbounds for (x, x2) in zip(d, d2)
            f(x, x2)
       end
    end
    return nothing
end

function Base.foreach(f, d::AbstractDictionary)
    @inbounds for x in d
        f(x)
    end
    return nothing
end
