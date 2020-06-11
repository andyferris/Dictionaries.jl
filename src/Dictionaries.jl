module Dictionaries

using Random
using Indexing
using Base: @propagate_inbounds, Callable

export getindices, setindices!

export AbstractDictionary, AbstractIndices, IndexError, ArrayIndices, Indices, Dictionary, ArrayDictionary, MappedDictionary, DictionaryView, FilteredDictionary, FilteredIndices, BroadcastedDictionary

export dictionary, index, distinct, disjoint, isdictequal, filterview
export issettable, isinsertable, set!, unset!
export istokenizable, tokentype, tokens, tokenized, gettoken, gettokenvalue, istokenassigned, settokenvalue!, gettoken!, deletetoken!, sharetokens

include("AbstractDictionary.jl")
include("AbstractIndices.jl")

include("tokens.jl")
include("indexing.jl")
include("insertion.jl")
include("filter.jl")
include("foreach.jl")
include("map.jl")
include("broadcast.jl")
include("find.jl")
include("show.jl")

include("PairDictionary.jl")
include("ArrayIndices.jl")
include("ArrayDictionary.jl")
include("Indices.jl")
include("Dictionary.jl")
include("MappedDictionary.jl")

end # module

# # TODO
#
# * Improved printing - don't calculate length (beyond some cutoff) if it is `SizeUnknown` and limit=true, fix indentiation problems for wider values
# * TODO: have `delete!` return next key, `deletetoken!` return next token.
#   For these kinds of algorithms, probably need: firstindex, firsttoken, nextind, prevind,
#   nexttoken, prevtoken, lastindex, lasttoken.
# * A surface interface for updates like https://github.com/JuliaLang/julia/pull/31367
# * More operations for "ordered" indices/sets (sort-based dictionaries and
#   B-trees). We can probably formalize an interface around a trait here. Certain operations
#   like slicing out an interval or performing a sort-merge co-iteration for `merge` become
#   feasible.
