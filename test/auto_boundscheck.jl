using Dictionaries
using Test

# The following tests are run without the --bounds-check option.

# Issue #63 - Broadcasting only omitted bounds check due to inbounds propagation
@static if VERSION < v"1.4" # Duplicate of Base implementation
    Base.@propagate_inbounds function only(x)
        i = iterate(x)
        @boundscheck if i === nothing
            throw(ArgumentError("Collection is empty, must contain exactly 1 element"))
        end
        (ret, state) = i
        @boundscheck if iterate(x, state) !== nothing
            throw(ArgumentError("Collection has multiple elements, must contain exactly 1 element"))
        end
        return ret
    end
end
d3 = Dictionary([:a, :b], [[1,2], [3,4]])
@test_throws ArgumentError only.(d3)
