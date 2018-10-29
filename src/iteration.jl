# We allow use of a "token" system to optimize iteration.

# By default the tokens are the indices. This can be easily overriden.
@inline tokens(m::AbstractMap) = keys(m)
@propagate_inbounds gettoken(m::AbstractMap, i) = m[i]
@propagate_inbounds settoken!(m::AbstractMap, v, i) = m[i] = v

# We iterate the tokens
@propagate_inbounds function Base.iterate(m::AbstractMap, state...)
	it = iterate(tokens(m), state...)
	if it === nothing
		return nothing
	end
	(index, state) = it
	return (@inbounds getoken(m, index), state)
end
