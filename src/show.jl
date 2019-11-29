# Simple "print"-like rendering, use "{ ... }" brackets for compactness
function Base.show(io::IO, inds::AbstractIndices)
    limit = get(io, :limit, false) ? Int64(10) : typemax(Int64)       
    comma = false
    print(io, "{")
    for i in inds
        if comma
            print(io, ", ")
        end
        if limit == 0
            print(io, "…")
            break
        end
        show(io, i)
        comma = true
        limit -= 1
    end
    print(io, "}")
end

function Base.show(io::IO, d::AbstractDictionary)
    limit = get(io, :limit, false) ? Int64(10) : typemax(Int64)       
    comma = false
    print(io, "{")
    for (i, v) in pairs(d)
        if comma
            print(io, ", ")
        end
        if limit == 0
            print(io, "…")
            break
        end
        show(io, i)
        print(io, " ⇒ ")
        show(io, v)
        comma = true
        limit -= 1
    end
    print(io, "}")
end

# The "display"-like rendering
function Base.show(io::IO, ::MIME"text/plain", i::AbstractIndices)
    print(io, "$(length(i))-element $(typeof(i))")
    n_lines = get(io, :limit, false) ? Int64(displaysize(io)[1] - 5) : typemax(Int64)
    lines = 1
    for k in i
        print(io, "\n ")
        show(io, k)
        lines += 1
        if lines > n_lines
            print(io, "\n ⋮")
            break
        end
    end
end

function Base.show(io::IO, ::MIME"text/plain", d::AbstractDictionary)
    print(io, "$(length(d))-element $(typeof(d))")
    n_lines = get(io, :limit, false) ? Int64(displaysize(io)[1] - 5) : typemax(Int64)
    lines = 1
    for k in keys(d)
        print(io, "\n ")
        show(io, k)
        print(io, " ⇒ ")
        if isassigned(d, k)
            show(io, d[k])
        else
            print(io, "#undef")
        end
        lines += 1
        if lines > n_lines
            print(io, "\n ⋮")
            break
        end
    end
end

# TODO fix `repr`
