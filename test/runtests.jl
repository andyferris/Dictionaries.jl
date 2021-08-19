using Test
using Dictionaries
using Indexing

include("Indices.jl")
include("Dictionary.jl")
include("ArrayIndices.jl")
include("ArrayDictionary.jl")
include("PairDictionary.jl")
include("FillDictionary.jl")
include("indexing.jl")
include("foreach.jl")
include("map.jl")
include("broadcast.jl")
include("filter.jl")
include("find.jl")
include("reverse.jl")
include("show.jl")

# Run the following test without julia --check-bounds=yes mode
cmd = deepcopy(Base.julia_cmd())
filter!(a->!startswith(a, "--check-bounds="), cmd.exec)
@test process_exited(run(`$cmd auto_boundscheck.jl`))
