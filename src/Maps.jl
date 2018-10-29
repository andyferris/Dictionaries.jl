module Maps

using Indexing

using Base: @propagate_inbounds

export AbstractMap, AbstractIndices, Indices, HashIndices, Map, IdentityIndices

include("AbstractMap.jl")
include("Index.jl")
include("HashIndex.jl")
include("Map.jl")
include("iteration.jl")
include("indexing.jl")

end # module
