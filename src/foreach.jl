function Base.foreach(f, d::AbstractDictionary, d2::AbstractDictionary, ds::AbstractDictionary...)
    if sharetokens(d, d2, ds...)
        @inbounds for t in tokens(d)
            f(gettokenvalue(d, t), gettokenvalue(d2, t), map(x -> @inbounds(gettokenvalue(x, t)), ds)...)
        end
    else
        @inbounds for i in keys(d)
            f(d[i], d2[i], map(x -> @inbounds(x[i]), ds)...)
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
        @inbounds for i in keys(d)
            f(d[i], d2[i])
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
