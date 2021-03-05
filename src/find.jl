# findall

@inline Base.findall(d::AbstractDictionary) = findall(identity, d)
function Base.findall(pred::Function, d::AbstractDictionary)
    out = empty(keys(d))
    @inbounds for (i, v) in pairs(d)
        if pred(v)
            insert!(out, i)
        end
    end
    return out
end
# Note that `findall` implements Boolean indexing. Compare:
#     array[array_of_bools]
# to:
#     getindices(dict, findall(dict_of_bools))

# findfirst

@inline Base.findfirst(d::AbstractDictionary) = findfirst(identity, d)
function Base.findfirst(pred::Function, d::AbstractDictionary)
    for (i, v) in pairs(d)
        if pred(v)
            return i
        end
    end
    return nothing
end

@inline findfirsttoken(d::AbstractDictionary) = findfirsttoken(identity, d)
function findfirsttoken(pred::Function, d::AbstractDictionary)
    @inbounds for t in tokens(d)
        v = gettokenvalue(d, t)
        if pred(v)
            return t
        end
    end
    return nothing
end

# findnext

@propagate_inbounds Base.findnext(d::AbstractDictionary, i) = findnext(identity, d, i)
@propagate_inbounds function Base.findnext(pred::Function, d::AbstractDictionary, i)
    (hastoken, t) = gettoken(d, i)
    @boundscheck if !hastoken
        throw(IndexError("Index $i not found"))
    end

    t_next = @inbounds findnexttoken(pred, d, t)
    if t_next === nothing
        return nothing
    else
        return @inbounds gettokenvalue(keys(d), t_next)
    end
end

@propagate_inbounds findnexttoken(d::AbstractDictionary, t) = findnexttoken(identity, d, t)
@propagate_inbounds function findnexttoken(pred, d::AbstractDictionary, t)
    ks = keys(d)
    tmp = iteratetoken(ks, t)
    @inbounds while tmp !== nothing
        (t, s) = tmp
        if pred(gettokenvalue(d, t))
            return t
        end
        tmp = iteratetoken(ks, s)
    end
end

# findlast

function Base.findlast(pred::Function, d::AbstractDictionary)
    for (i, k) in reverse(pairs(d))
        if pred(k)
            return i
        end
    end
    return nothing
end

@inline findlassttoken(d::AbstractDictionary) = findlassttoken(identity, d)
function findlassttoken(pred::Function, d::AbstractDictionary)
    @inbounds for t in reverse(tokens(d))
        v = gettokenvalue(d, t)
        if pred(v)
            return t
        end
    end
    return nothing
end

# findnext

@propagate_inbounds Base.findprev(d::AbstractDictionary, i) = findprev(identity, d, i)
@propagate_inbounds function Base.findprev(pred::Function, d::AbstractDictionary, i)
    (hastoken, t) = gettoken(d, i)
    @boundscheck if !hastoken
        throw(IndexError("Index $i not found"))
    end

    t_next = @inbounds findprevtoken(pred, d, t)
    if t_next === nothing
        return nothing
    else
        return @inbounds gettokenvalue(keys(d), t_next)
    end
end

@propagate_inbounds findprevtoken(d::AbstractDictionary, t) = findprevtoken(identity, d, t)
@propagate_inbounds function findprevtoken(pred, d::AbstractDictionary, t)
    ks = keys(d)
    tmp = iteratetoken_reverse(ks, t)
    @inbounds while tmp !== nothing
        (t, s) = tmp
        if pred(gettokenvalue(d, t))
            return t
        end
        tmp = iteratetoken_reverse(ks, s)
    end
end

# findmax

function Base.findmax(d::AbstractDictionary)
    ks = keys(d)
    tmp = @inbounds iteratetoken(ks)
    if tmp === nothing
        throw(ArgumentError("collection must be non-empty"))
    end
    (t, s) = tmp
    max_i = @inbounds gettokenvalue(ks, t)
    max_v = @inbounds gettokenvalue(d, t)
    tmp = @inbounds iteratetoken(ks, s)
    @inbounds while tmp !== nothing
        (t, s) = tmp
        new_v = gettokenvalue(d, t)
        if isless(max_v, new_v)
            max_v = new_v
            max_i = gettokenvalue(ks, t)
        end
        tmp = iteratetoken(ks, s)
    end
    return (max_v, max_i) # Maybe should have been an index => value pair?
end

# findmin

function Base.findmin(d::AbstractDictionary)
    ks = keys(d)
    tmp = @inbounds iteratetoken(ks)
    if tmp === nothing
        throw(ArgumentError("collection must be non-empty"))
    end
    (t, s) = tmp
    min_i = @inbounds gettokenvalue(ks, t)
    min_v = @inbounds gettokenvalue(d, t)
    tmp = @inbounds iteratetoken(ks, s)
    @inbounds while tmp !== nothing
        (t, s) = tmp
        new_v = gettokenvalue(d, t)
        if isless(new_v, min_v)
            min_v = new_v
            min_i = gettokenvalue(ks, t)
        end
        tmp = iteratetoken(ks, s)
    end
    return (min_v, min_i) # Maybe should have been an index => value pair?
end