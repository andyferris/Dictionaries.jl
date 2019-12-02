group(iter) = group(identity, iter)

group(by::Function, iter) = group(by, identity, iter)

group(by::Function, f::Function, iter1, iter2, iters...) = group((x -> by(x...)), (x -> f(x...)), zip(iter1, iter2, iters...))

function group(by::Function, f::Function, iter)
    I = Core.Compiler.return_type(by, Tuple{eltype(iter)})
    T = Core.Compiler.return_type(f, Tuple{eltype(iter)})

    out = HashDictionary{I, Vector{T}}()
    for x in iter
        (hadtoken, token) = gettoken!(out, by(x))
        if hadtoken
            push!(gettokenvalue(out, token), f(x))
        else
            settokenvalue!(out, token, T[f(x)])
        end
    end

    return out
end

groupunique(iter) = groupunique(identity, iter)

groupunique(by::Function, iter) = groupunique(by, identity, iter)

function groupunique(by::Function, f::Function, iter)
    I = Core.Compiler.return_type(by, Tuple{eltype(iter)})
    T = Core.Compiler.return_type(f, Tuple{eltype(iter)})

    out = HashDictionary{I, HashIndices{T}}()
    for x in iter
        (hadtoken, token) = gettoken!(out, by(x))
        if hadtoken
            set!(gettokenvalue(out, token), f(x))
        else
            tmp = HashIndices{T}()
            set!(tmp, f(x))
            settokenvalue!(out, token, tmp)
        end
    end

    return out
end

groupfirst(iter) = groupfirst(identity, iter)

groupfirst(by::Function, iter) = groupfirst(by, identity, iter)

function groupfirst(by::Function, f::Function, iter)
    I = Core.Compiler.return_type(by, Tuple{eltype(iter)})
    T = Core.Compiler.return_type(f, Tuple{eltype(iter)})

    out = HashDictionary{I, T}()
    for x in iter
        (hadtoken, token) = gettoken!(out, by(x))
        if !hadtoken
            settokenvalue!(out, token, f(x))
        end
    end

    return out
end

grouplast(iter) = grouplast(identity, iter)

grouplast(by::Function, iter) = grouplast(by, identity, iter)

function grouplast(by::Function, f::Function, iter)
    I = Core.Compiler.return_type(by, Tuple{eltype(iter)})
    T = Core.Compiler.return_type(f, Tuple{eltype(iter)})

    out = HashDictionary{I, T}()
    for x in iter
        set!(out, by(x), f(x))
    end

    return out
end

grouponly(iter) = grouponly(identity, iter)

grouponly(by::Function, iter) = grouponly(by, identity, iter)

function grouponly(by::Function, f::Function, iter)
    I = Core.Compiler.return_type(by, Tuple{eltype(iter)})
    T = Core.Compiler.return_type(f, Tuple{eltype(iter)})

    out = HashDictionary{I, T}()
    for x in iter
        insert!(out, by(x), f(x))
    end

    return out
end

groupcount(iter) = groupcount(identity, iter)

function groupcount(by::Function, iter)
    I = Core.Compiler.return_type(by, Tuple{eltype(iter)})
    
    out = HashDictionary{I, Int}()
    for x in iter
        (hadtoken, token) = gettoken!(out, by(x))
        if hadtoken
            settokenvalue!(out, token, gettokenvalue(out, token) + 1)
        else
            settokenvalue!(out, token, 1)
        end
    end

    return out
end

groupreduce(by::Function, op::Function, iter) = groupreduce(by, identity, op, iter)

groupreduce(by, f, op, iter1, iter2, iters...; kw...) = groupreduce((x -> by(x...)), (x -> f(x...)), op, zip(iter1, iter2, iters...); kw...)

function groupreduce(by::Function, f::Function, op::Function, iter; kw...)
    I = Core.Compiler.return_type(by, Tuple{eltype(iter)})
    T = Core.Compiler.return_type(f, Tuple{eltype(iter)})
    nt = kw.data
    
    out = HashDictionary{I, T}()
    for x in iter
        (hadtoken, token) = gettoken!(out, by(x))
        if hadtoken
            settokenvalue!(out, token, op(gettokenvalue(out, token), f(x)))
        else
            if nt isa NamedTuple{()}
                settokenvalue!(out, token, f(x))
            elseif nt isa NamedTuple{(:init,)}
                settokenvalue!(out, token, op(nt.init, f(x)))
            else
                throw(ArgumentError("groupreduce doesn't support these keyword arguments: $(setdiff(keys(nt), (:init,)))"))
            end
        end
    end

    return out
end

groupsum(iter) = groupsum(identity, iter)
groupsum(by, iter) = groupsum(by, identity, iter)
groupsum(by, f, iter) = groupreduce(by, f, +, iter)

groupprod(iter) = groupprod(identity, iter)
groupprod(by, iter) = groupprod(by, identity, iter)
groupprod(by, f, iter) = groupreduce(by, f, *, iter)
