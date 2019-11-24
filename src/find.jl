# findall

function Base.findall(pred::Function, d::AbstractDictionary)
    out = empty(keys(d))
    @inbounds for (i, v) in pairs(d)
        if pred(v)
            insert!(out, i)
        end
    end
    return out
end

# Note this implements Boolean indexing. Compare:
#     array[array_of_bools]
#     getindices(dict, findall(dict_of_bools))
@inline Base.findall(d::AbstractDictionary) = findall(identity, d)

# findfirst

# TODO what do do about findlast, findnext, findprev?
#  * findnext would require us to be able to restart iteration from an index or token
#    (this might be useful even for a hashmap, e.g. if `findall` allocates too much)
#  * findlast and findprev would require thinking about Iterators.reverse