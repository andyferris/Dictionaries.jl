module Dictionaries

using Indexing
using SplitApplyCombine

using Base: @propagate_inbounds

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
