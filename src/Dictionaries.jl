module Dictionaries

using Indexing
using SplitApplyCombine

using Base: @propagate_inbounds

export AbstractDictionary, AbstractIndices, IndexError, Indices, HashIndices, HashDictionary, Dictionary, MappedDictionary

export ismutable, isinsertable, set!, unset!
export tokens, gettoken, gettokenvalue, istokenassigned, gettoken!, settokenvalue!, deletetoken!

export filterview # TODO move to SplitApplyCombine.jl

include("AbstractDictionary.jl")
include("AbstractIndices.jl")

include("tokens.jl")
include("iteration.jl")
include("indexing.jl")
include("insertion.jl")
include("filter.jl")

include("PairDictionary.jl")
include("Indices.jl")
include("Dictionary.jl")
include("HashIndices.jl")
include("HashDictionary.jl")
include("MappedDictionary.jl")

end # module
