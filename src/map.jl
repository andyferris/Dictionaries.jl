# Make `map!` fast if the inputs and output share tokens

# TODO consider if `map` should respect iteration order or indices??

function Base.map!(f, out::AbstractDictionary, d::AbstractDictionary, d2::AbstractDictionary, ds::AbstractDictionary...)
    if sharetokens(out, d, d2, ds...)
        @inbounds for t in tokens(out)
            settokenvalue!(out, t, f(gettokenvalue(d, t), gettokenvalue(d2, t), map(x -> @inbounds(gettokenvalue(x, t)), ds)...))
        end
    else
        @boundscheck nothing # TODO check that indices match
        @inbounds for i in keys(out)
            out[i] = f(d[i], d2[i], map(x -> @inbounds(x[i]), ds)...)
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
    else
        @boundscheck nothing # TODO check that indices match
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
    else
        @boundscheck nothing # TODO check that indices match
        @inbounds for i in keys(out)
            out[i] = f(d[i])
        end
    end
    return out
end

function Base.map(f, d::AbstractDictionary)
    out = similar(d, Core.Compiler.return_type(f, Tuple{eltype(d)}))
    map!(f, out, d)
    return out
end

function Base.map(f, d::AbstractDictionary, ds::AbstractDictionary...)
    out = similar(d, Core.Compiler.return_type(f, Tuple{eltype(d), map(eltype, ds)...}))
    map!(f, out, d, ds...)
    return out
end
