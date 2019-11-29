group(iter) = group(identity, iter)

group(by::Function, iter) = group(by, identity, iter)

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

function groupreduce(by::Function, f::Function, op::Function, iter)
    I = Core.Compiler.return_type(by, Tuple{eltype(iter)})
    T = Core.Compiler.return_type(f, Tuple{eltype(iter)})
    
    out = HashDictionary{I, T}()
    for x in iter
        (hadtoken, token) = gettoken!(out, by(x))
        if hadtoken
            settokenvalue!(out, token, op(gettokenvalue(out, token), f(x)))
        else
            settokenvalue!(out, token, f(x))
        end
    end

    return out
end
