using RecipesBase

RecipesBase.debug(false)

@recipe function f(C::AbstractCurve,n=500)
    aspect_ratio --> 1.0
    point(C,LinRange(0,1,n+1))
end

@recipe function f(C::Union{Circle,Arc})
    aspect_ratio --> 1.0
    point(C,LinRange(0,1,601))
end

@recipe function f(C::Union{Line,Segment})
    aspect_ratio --> 1.0
    point(C,[0.0,1.0])
end

@recipe function f(p::AbstractPath)
    for c in p 
        @series begin 
            c
        end 
    end
end

# @recipe function f(z::Array{Spherical{T}}) where T
#     markersize --> 1
#     x = [ cos(z.lat)*cos(z.lon) for z in z ]
#     y = [ cos(z.lat)*sin(z.lon) for z in z ]
#     z = [ sin(z.lat) for z in z ]
#     x,y,z
# end
