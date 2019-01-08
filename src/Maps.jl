module Maps

using Indexing
using SplitApplyCombine

using Base: @propagate_inbounds

export AbstractMap, AbstractIndices, IndexError, Indices, HashIndices, HashMap, Map, IdentityIndices, MappedMap

export isinsertable, set!, unset!

include("AbstractMap.jl")

include("tokens.jl")
include("iteration.jl")
include("indexing.jl")
include("insertion.jl")

include("Indices.jl")
include("Map.jl")
include("HashIndices.jl")
include("HashMap.jl")
include("MappedMap.jl")

end # module
