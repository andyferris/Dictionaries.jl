# Simple "print"-like rendering, use "{ ... }" brackets for compactness
function Base.show(io::IO, inds::AbstractIndices)
    limit = get(io, :limit, false) ? Int(10) : typemax(Int)
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
    limit = get(io, :limit, false) ? Int(10) : typemax(Int)
    comma = false
    print(io, "{")
    for i in keys(d)
        if comma
            print(io, ", ")
        end
        if limit == 0
            print(io, "…")
            break
        end
        show(io, i)
        print(io, " = ")
        if isassigned(d, i)
            show(io, d[i])
        else
            print(io, "#undef")
        end
        comma = true
        limit -= 1
    end
    print(io, "}")
end

# The "display"-like rendering
function Base.show(io::IO, ::MIME"text/plain", d::AbstractIndices)
    if isempty(d)
        print(io, "0-element $(typeof(d))")
        return
    end

    # Designed to be efficient for very large sets of unknown lengths

    n_lines = max(Int(3), get(io, :limit, false) ? Int(displaysize(io)[1] - 4) : typemax(Int))
    n_cols = max(Int(2), get(io, :limit, false) ? Int(displaysize(io)[2] - 1) : typemax(Int))
    n_lines_top = n_lines ÷ Int(2)
    n_lines_bottom = n_lines - n_lines_top

    # First we collect strings of all the relevant elements
    top_ind_strs = Vector{String}()
    bottom_ind_strs = Vector{String}()

    top_lines = Int(1)
    top_full = false
    top_last_index = Base.RefValue{keytype(d)}()
    for i in keys(d)
        push!(top_ind_strs, sprint(show, i, context = io, sizehint = 0))
        top_lines += 1
        if top_lines > n_lines_top
            top_full = true
            top_last_index[] = i
            break
        end
    end

    bottom_lines = Int(1)
    bottom_full = false
    if top_full
        for i in Iterators.reverse(keys(d))
            if bottom_full
                if isequal(i, top_last_index[])
                    bottom_full = false # override this, we don't need the ⋮
                else
                    bottom_ind_strs[end] = "⋮"
                end
                break
            end

            if isequal(i, top_last_index[])
                # Already rendered, we are finished
                break
            end

            push!(bottom_ind_strs, sprint(show, i, context = io, sizehint = 0))
            bottom_lines += 1
            if bottom_lines > n_lines_bottom
                bottom_full = true
                # We check the next element to see if this one should be a ⋮
            end
        end
        ind_strs = vcat(top_ind_strs, reverse(bottom_ind_strs))
    else
        ind_strs = top_ind_strs
    end

    if Base.IteratorSize(d) === Base.SizeUnknown()
        if bottom_full
            print(io, "Greater than $(length(ind_strs))-element $(typeof(d)):")
        else
            print(io, "$(length(ind_strs))-element $(typeof(d)):")
        end
    else
        print(io, "$(length(d))-element $(typeof(d)):")
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
end

# The "display"-like rendering
function Base.show(io::IO, ::MIME"text/plain", d::AbstractDictionary)
    if isempty(d)
        print(io, "0-element $(typeof(d))")
        return
    end

    # Designed to be efficient for very large sets of unknown lengths

    n_lines = max(Int(3), get(io, :limit, false) ? Int(displaysize(io)[1] - 4) : typemax(Int))
    n_cols = max(Int(8), get(io, :limit, false) ? Int(displaysize(io)[2] - 4) : typemax(Int))
    n_lines_top = n_lines ÷ Int(2)
    n_lines_bottom = n_lines - n_lines_top

    # First we collect strings of all the relevant elements
    top_ind_strs = Vector{String}()
    top_val_strs = Vector{String}()
    bottom_val_strs = Vector{String}()
    bottom_ind_strs = Vector{String}()

    top_lines = Int(1)
    top_full = false
    top_last_index = Base.RefValue{keytype(d)}()
    for i in keys(d)
        push!(top_ind_strs, sprint(show, i, context = io, sizehint = 0))
        if isassigned(d, i)
            push!(top_val_strs, sprint(show, d[i], context = io, sizehint = 0))
        else
            push!(top_val_strs, "#undef")
        end
        top_lines += 1
        if top_lines > n_lines_top
            top_full = true
            top_last_index[] = i
            break
        end
    end

    bottom_lines = Int(1)
    bottom_full = false
    if top_full
        for i in Iterators.reverse(keys(d))
            if bottom_full
                if isequal(i, top_last_index[])
                    bottom_full = false # override this, we don't need the ⋮
                else
                    bottom_ind_strs[end] = "⋮"
                    bottom_val_strs[end] = "⋮"
                end
                break
            end

            if isequal(i, top_last_index[])
                # Already rendered, we are finished
                break
            end

            push!(bottom_ind_strs, sprint(show, i, context = io, sizehint = 0))
            if isassigned(d, i)
                push!(bottom_val_strs, sprint(show, d[i], context = io, sizehint = 0))
            else
                push!(bottom_val_strs, "#undef")
            end

            bottom_lines += 1
            if bottom_lines > n_lines_bottom
                bottom_full = true
                # We check the next element to see if this one should be a ⋮
            end
        end
        ind_strs = vcat(top_ind_strs, reverse(bottom_ind_strs))
        val_strs = vcat(top_val_strs, reverse(bottom_val_strs))
    else
        ind_strs = top_ind_strs
        val_strs = top_val_strs
    end

    if Base.IteratorSize(d) === Base.SizeUnknown()
        if bottom_full
            print(io, "Greater than $(length(ind_strs))-element $(typeof(d)):")
        else
            print(io, "$(length(ind_strs))-element $(typeof(d)):")
        end
    else
        print(io, "$(length(d))-element $(typeof(d)):")
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
end

function shrink_to!(strs, width)
    @static if VERSION >= v"1.9"
      strs .= Base._truncate_at_width_or_chars.(true, strs, width)
    else
      strs .= Base._truncate_at_width_or_chars.(strs, width)
    end
end

# TODO fix `repr`
