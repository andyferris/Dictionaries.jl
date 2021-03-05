# Return `nothing` if not found?

function Base.searchsortedfirst(d::AbstractDictionary, x)
    t = searchsortedfirsttoken(d, x)
    if t === nothing
        return nothing
    else
        return gettokenvalue(keys(d), t)
    end
end

function searchsortedfirsttoken(d::AbstractDictionary, x)
    @inbounds begin
        t_low = first(tokens(d))
        if !isless(gettokenvalue(d, t_low), x)
            return t_low
        end
        t_high = last(tokens(d))
        if isless(gettokenvalue(d, t_high), x)
            return nothing
        end

        while isless(t_low, t_high)
            (t_mid1, t_mid2) = midtoken(keys(d), t_low, t_high)
            if isless(gettokenvalue(d, t_mid2), x)
                t_low = t_mid2
            elseif isless(x, gettokenvalue(d, t_mid1))
                t_high = t_mid1
            else
                return isequal(x, gettokenvalue(d, t_mid1)) ? t_mid1 : t_mid2
            end
        end
        return t_high
    end
end

function Base.searchsortedlast(d::AbstractDictionary, x)
    t = searchsortedlasttoken(d, x)
    if t === nothing
        return nothing
    else
        return gettokenvalue(keys(d), t)
   end
end

function searchsortedlasttoken(d::AbstractDictionary, x)
    @inbounds begin
        t_low = first(tokens(d))
        if isless(x, gettokenvalue(d, t_low))
            return nothing
        end
        t_high = last(tokens(d))
        if !isless(x, gettokenvalue(d, t_high))
            return t_high
        end

        while isless(t_low, t_high)
            (t_mid1, t_mid2) = midtoken(keys(d), t_low, t_high)
            if isless(x, gettokenvalue(d, t_mid1))
                t_high = t_mid1
            elseif isless(gettokenvalue(d, t_mid2), x)
                t_low = t_mid2
            else
                return isequal(x, gettokenvalue(d, t_mid2)) ? t_mid2 : t_mid1
            end
        end
        return t_high
    end
end

function Base.sort(dict::AbstractDictionary; kwargs...)
    out = copy(dict)
    sort!(out; kwargs...)
    return out
end

function sortkeys(dict::AbstractDictionary; kwargs...)
    out = copy(dict)
    return sortkeys!(out; kwargs...)
    return out
end

function sortpairs(dict::AbstractDictionary; kwargs...)
    out = copy(dict)
    return sortpairs!(out; kwargs...)
    return out
end

# function Base.sortperm(dict::AbstractDictionary; by = identity, kwargs...)
#     token_perm = sortpermtokens(dict::AbstractDictionary; by = identity, kwargs...)
#     return @inbounds permutetokens(keys(dict), token_perm)
# end

# function sortpermtokens(dict::AbstractDictionary; by = identity, kwargs...)
#     x = collect(tokens(dict))
#     sort!(x; by = t -> by(@inbounds gettokenvalue(dict, t)), kwargs...)
#     out = similar(dict, eltype(x))
#     i = 1
#     for t in tokens(dict)
#         @inbounds settokenvalue!(out, t, x[i])
#         i += 1
#     end
#     return out
# end

# function permutetokens(dict::AbstractDictionary, perm)
#     out = empty(dict)
#     p = pairs(dict)
#     for t in perm
#         (i, v) = @inbounds gettokenvalue(p, t)
#         insert!(out, i, v)
#     end
#     return out
# end

# function permutetokens(inds::AbstractIndices, perm)
#     out = empty(inds)
#     for t in perm
#         insert!(out, @inbounds gettokenvalue(inds, t))
#     end
#     return out
# end

# function permutetokenvalues!(dict::AbstractDictionary, perm)

# end