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
        print(io, " │ ")
        show(io, v)
        comma = true
        limit -= 1
    end
    print(io, "}")
end

# The "display"-like rendering
function Base.show(io::IO, ::MIME"text/plain", d::AbstractIndices)
    n_inds = length(d)
    print(io, "$n_inds-element $(typeof(d))")
    if n_inds == 0
        return
    end
    n_lines = max(3, get(io, :limit, false) ? Int64(displaysize(io)[1] - 5) : typemax(Int64))
    n_cols = max(2, get(io, :limit, false) ? Int64(displaysize(io)[2] - 1) : typemax(Int64))
    lines = 1

    # First we collect strings of all the relevant elements
    ind_strs = Vector{String}()

    lines = 1
    too_many_lines = false
    for i in keys(d)
        push!(ind_strs, sprint(show, i, context = io, sizehint = 0))
        lines += 1
        if lines > n_lines && lines < n_inds
            too_many_lines = true
            break
        end
    end

    # Now find padding sizes
    max_ind_width = maximum(textwidth, ind_strs)
    if max_ind_width + 1 > n_cols
        shrink_to!(ind_strs, n_cols)
    end

    for ind_str in ind_strs
        print(io, "\n ")
        print(io, ind_str)
    end
    if too_many_lines
        print(io, "\n ⋮")
    end
end

function Base.show(io::IO, ::MIME"text/plain", d::AbstractDictionary)
    n_inds = length(d)
    print(io, "$n_inds-element $(typeof(d))")
    if n_inds == 0
        return
    end
    n_lines = max(3, get(io, :limit, false) ? Int64(displaysize(io)[1] - 5) : typemax(Int64))
    n_cols = max(8, get(io, :limit, false) ? Int64(displaysize(io)[2] - 4) : typemax(Int64))
    lines = 1

    # First we collect strings of all the relevant elements
    ind_strs = Vector{String}()
    val_strs = Vector{String}()

    lines = 1
    too_many_lines = false
    for i in keys(d)
        push!(ind_strs, sprint(show, i, context = io, sizehint = 0))
        if isassigned(d, i)
            push!(val_strs, sprint(show, d[i], context = io, sizehint = 0))
        else
            push!(val_strs, "#undef")
        end
        lines += 1
        if lines > n_lines && lines < n_inds
            too_many_lines = true
            break
        end
    end

    # Now find padding sizes
    max_ind_width = maximum(textwidth, ind_strs)
    max_val_width = maximum(textwidth, val_strs)
    if max_ind_width + max_val_width > n_cols
        val_width = max_val_width
        ind_width = max_ind_width
        while ind_width + val_width > n_cols
            if ind_width > val_width 
                ind_width -= 1
            else 
                val_width -= 1
            end
        end
        if ind_width != max_ind_width
            shrink_to!(ind_strs, ind_width)
        end
        if val_width != max_val_width
            shrink_to!(val_strs, val_width)
        end
    else
        ind_width = max_ind_width
    end

    for (ind_str, val_str) in zip(ind_strs, val_strs)
        print(io, "\n ")
        print(io, " " ^ max(0, ind_width - textwidth(ind_str)))
        print(io, ind_str)
        print(io, " │ ")
        print(io, val_str)
    end
    if too_many_lines
        print(io, "\n")
        print(io, " " ^ ind_width)
        print(io, "⋮ │ ⋮")
    end
end

function shrink_to!(strs, width)
    for i in keys(strs)
        str = strs[i]
        if textwidth(str) > width
            new_str = ""
            w = 0
            for c in str
                new_w = textwidth(c)
                if new_w + w < width
                    new_str = new_str * c
                    w += new_w
                else
                    new_str = new_str * "…"
                    break
                end
            end
            strs[i] = new_str
        end
    end
end

# TODO fix `repr`
