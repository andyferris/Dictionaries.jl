module Dictionaries

using Random

using Indexing
using SplitApplyCombine

using Base: @propagate_inbounds

export getindices, setindices!, mapview

export AbstractDictionary, AbstractIndices, IndexError, Indices, HashIndices, HashDictionary, Dictionary, MappedDictionary, DictionaryView, FilteredDictionary, FilteredIndices, BroadcastedDictionary

export issettable, isinsertable, set!, unset!, dictionary
export istokenizable, tokentype, tokens, tokenized, gettoken, gettokenvalue, istokenassigned, settokenvalue!, gettoken!, deletetoken!, sharetokens

export filterview # TODO move to SplitApplyCombine.jl (and re-order project dependencies?)

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
include("group.jl")
include("show.jl")

include("PairDictionary.jl")
include("Indices.jl")
include("Dictionary.jl")
include("HashIndices.jl")
include("HashDictionary.jl")
include("MappedDictionary.jl")

end # module

# # TODO
#
# * Improved printing - don't calculate length (beyond some cutoff) if it is `SizeUnknown`.
# * `hash` and `isless`
# * A manually-ordered dictionary would be quite useful, like [OrderedCollections.jl](https://github.com/JuliaCollections/OrderedCollections.jl).
# * A surface interface for updates like https://github.com/JuliaLang/julia/pull/31367
# * Soon we will have the concept of "ordered" indices/sets (sort-based dictionaries and
#   B-trees). We can probably formalize an interface around a trait here. Certain operations
#   like slicing out an interval or performing a sort-merge co-iteration for `merge` become
#   feasible.
