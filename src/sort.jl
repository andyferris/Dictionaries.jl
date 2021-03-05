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

"""
    sort(dict::AbstractDictionary; lt=isless, by=identity, rev:Bool=false, order::Ordering=Forward)

Return a new dictionary sorted by the values of `dict`. Accepts the same keyword arguments
as `sort`.

To sort a dictionary by its keys instead, use `sortkeys(dict)`. See also `sortpairs`.

# Example

```julia
julia> dict = Dictionary([:b, :c, :a], [3, 2, 1])
3-element Dictionary{Symbol,Int64}
 :b │ 3
 :c │ 2
 :a │ 1

julia> sort(dict)
3-element Dictionary{Symbol,Int64}
 :a │ 1
 :c │ 2
 :b │ 3
```
"""
function Base.sort(dict::AbstractDictionary; kwargs...)
    inds = copy(keys(dict))
    out = map(i -> @inbounds(dict[i]), inds)
    sort!(out; kwargs...)
    return out
end

"""
    sort(inds::AbstractIndices; lt=isless, by=identity, rev:Bool=false, order::Ordering=Forward)

Return a new indices sorted by the values of `inds`. Accepts the same keyword arguments as 
`sort`.

```julia
julia> inds = Indices([3, 2, 1])
3-element Indices{Int64}
 3
 2
 1

julia> sort(inds)
3-element Indices{Int64}
 1
 2
 3
```
"""
function Base.sort(inds::AbstractIndices; kwargs...)
    out = copy(inds)
    sort!(out; kwargs...)
    return out
end

"""
    sortkeys(dict::AbstractDictionary; lt=isless, by=identity, rev:Bool=false, order::Ordering=Forward)

Return a new dictionary sorted by the keys of `dict`.

# Example

```julia
julia> dict = Dictionary([:b, :c, :a], [3, 2, 1])
3-element Dictionary{Symbol,Int64}
 :b │ 3
 :c │ 2
 :a │ 1

julia> sortkeys(dict)
3-element Dictionary{Symbol,Int64}
 :a │ 1
 :b │ 3
 :c │ 2
```
"""
function sortkeys(dict::AbstractDictionary; kwargs...)
    out = copy(dict)
    return sortkeys!(out; kwargs...)
    return out
end

function sortkeys(inds::AbstractIndices; kwargs...)
    return sort(inds; kwargs...)
end

"""
    sortpairs(dict::AbstractDictionary; lt=isless, by=identity, rev:Bool=false, order::Ordering=Forward)

Return a new dictionary sorted by the key => value pairs of `dict`. The `by` function would
generally needed to be specified.

See also `sortkeys`.
"""
function sortpairs(dict::AbstractDictionary; kwargs...)
    out = copy(dict)
    return sortpairs!(out; kwargs...)
    return out
end

function sortpairs(inds::AbstractIndices; by = identity, kwargs...)
    return sort(inds; by = v -> by(v => v), kwargs...)
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