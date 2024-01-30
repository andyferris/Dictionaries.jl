using Dictionaries
using Test

# The following tests are run without the --bounds-check option.

d3 = Dictionary([:a, :b], [[1,2], [3,4]])
@test_throws ArgumentError only.(d3)
