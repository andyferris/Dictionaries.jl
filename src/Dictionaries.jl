module Dictionaries

using Indexing
using SplitApplyCombine

using Base: @propagate_inbounds

export AbstractDictionary, AbstractIndices, IndexError, Indices, HashIndices, HashDictionary, Dictionary, MappedDictionary

export issettable, isinsertable, set!, unset!
export tokentype, tokens, tokenized, gettoken, gettokenvalue, istokenassigned, gettoken!, settokenvalue!, deletetoken!, sharetokens

export filterview # TODO move to SplitApplyCombine.jl

include("AbstractDictionary.jl")
include("AbstractIndices.jl")

include("tokens.jl")
include("indexing.jl")
include("insertion.jl")
include("filter.jl")
include("map.jl")

include("PairDictionary.jl")
include("Indices.jl")
include("Dictionary.jl")
include("HashIndices.jl")
include("HashDictionary.jl")
include("MappedDictionary.jl")

end # module
