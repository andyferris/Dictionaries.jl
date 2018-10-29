
@propagate_inbounds function Base.getindex(m::AbstractMap{I}, i) where {I}
	return m[convert(I, i)]
end

# IdentityIndex
#struct IdentityIndex{I} <: AbstractIndex{I}
#end

#@inline getindex(::IdentityIndex{I}, i::I) where {I} = i
#@inline getindex(::IdentityIndex{I}, i) where {I} = convert(I, i)

#checkindex(::IdentitiyIndex{I}, i::I) where {I} = nothing
#checkindex(::IdentitiyIndex{I}, i) where {I} = (convert(I, i); nothing)


#getindices(m::AbstractMap{I}, ::Colon) where {I} = getindices(m, IdentityIndex{I})

#@inline getindices(m::AbstractMap{I}, ::IdentityIndex{I}) where {I} = copy(m)
#@inline getindices(i::IdentityIndex{I}, ::IdentityIndex{I}) where {I} = i
#@inline getindices(m::IdentityIndex{I}, m::AbstractMap{<:Any, I}) where {I} = m

# Non-scalar indexing