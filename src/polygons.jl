abstract type AbstractCircularPolygon <: AbstractClosedPath end
abstract type AbstractPolygon <: AbstractCircularPolygon end

sides(p::AbstractCircularPolygon) = curves(p)
side(p::AbstractCircularPolygon,args...) = curve(p,args...)

function show(io::IO,P::AbstractCircularPolygon)
	print(IOContext(io,:compact=>true),typeof(P)," with ",length(P)," sides") 
end
function show(io::IO,::MIME"text/plain",P::AbstractCircularPolygon) 
	print(io,typeof(P)," with ",length(P)," sides")
end

# Other methods
# TODO: unreliable results for points on the boundary
# Ref Dan Sunday, http://geomalgorithms.com/a03-_inclusion.html
"""
	winding(z,P::AbstractCircularPolygon)
Compute the winding number of `P` about the point `z`. Each counterclockwise rotation about `z` contributes +1, and each clockwise rotation about it counts -1. The winding number is zero for points not in the region enclosed by `P`. 

The result is unreliable for points on `P` (for which the problem is ill-posed).
"""
function winding(z::Number,p::AbstractCircularPolygon)
	Integer(sum( raycrossing(z,s) for s in sides(truncate(p)) ))
end

""" 
	isleft(z,P::AbstractCircularPolygon) 
Determine whether the number `z` lies "to the left" of the polygon `P`. This means that the point lies inside the bounded region if the path is positively oriented, and outside otherwise. 
"""
isleft(z::Number,p::AbstractCircularPolygon) = winding(z,p) > 0
""" 
	isright(z,P::AbstractCircularPolygon) 
Determine whether the number `z` lies "to the right" of the polygon `P`. This means that the point lies outside the bounded region if the path is positively oriented, and inside otherwise. 
"""
isright(z::Number,p::AbstractCircularPolygon) = winding(z,p) < 0

#
# CircularPolygon
#
"""
	(type) CircularPolygon 
Type for closed paths consisting entirely of arcs, segments, and rays. 
"""
struct CircularPolygon <: AbstractCircularPolygon
	path
	function CircularPolygon(p::AbstractClosedPath)
		# Assumes continuity and closure have been checked previously
		valid = isa.(curves(p),Union{Arc,Segment,Ray})
		@assert all(valid) "All sides must be an Arc, Segment, or Ray"
		new(p)
	end
end

# Constructors
""" 
	CircularPolygon(p::AbstractPath; tol=<default>) 
	CircularPolygon(p::AbstractVector; tol=<default>)
Construct a circular polygon from a (possibly closed) path, or from a vector of curves. The `tol` parameter is a tolerance used when checking continuity and closedness of the path.
"""
CircularPolygon(p::AbstractPath;kw...) = CircularPolygon(ClosedPath(p;kw...))
function CircularPolygon(p::AbstractVector{T};kw...) where T<:AbstractCurve 
	CircularPolygon(ClosedPath(p;kw...))
end

# Required methods
curves(p::CircularPolygon) = curves(p.path) 
curve(p::CircularPolygon,k::Integer) = curve(p.path,k) 
arclength(p::CircularPolygon) = arclength(p.path)
(p::CircularPolygon)(t) = point(p.path,t)

# TODO truncate circular polygons
function truncate(p::CircularPolygon) 
	isfinite(p) && return p   # nothing to do
	# try to find a circle clear of the polygon
	v = filter(isfinite,vertices(p))
	@error "Truncation of CircularPolygon not yet implemented"
end

# 
# Polygon 
# 

# Type 
"""
	(type) Polygon 
Type for closed paths consisting entirely of segments and rays. 
"""
struct Polygon <: AbstractPolygon
	path
	function Polygon(p::AbstractClosedPath) where T<:AbstractCurve
		# Assumes continuity and closure have been checked previously
		valid = isa.(curves(p),Union{Segment,Ray})
		@assert all(valid) "All sides must be a Segment or Ray"
		new(p)
	end
end

# Constructors
""" 
	Polygon(p::AbstractPath; tol=<default>) 
	Polygon(p::AbstractVector{T<:AbstractCurve}; tol=<default>)
Construct a polygon from a (possibly closed) path, or from a vector of curves. The `tol` parameter is a tolerance used when checking continuity and closedness of the path.
"""
Polygon(p::AbstractPath;kw...) = Polygon(ClosedPath(p;kw...))
function Polygon(p::AbstractVector{T};kw...) where T<:AbstractCurve 
	Polygon(ClosedPath(p;kw...))
end
"""
	Polygon(v::AbstractVector)
Construct a polygon from a vector of its vertices. Each element of `v` should be either a finite vertex, or a tuple of two angles that indicate the angles of two rays incident to an infinite vertex: one "to" infinity, and a second "from" infinity.  
"""
function Polygon(v::AbstractVector) 
	n = length(v)
	p = Vector{Union{Segment,Ray}}(undef,n)
	for j = 1:n
		vthis = v[j]
		vnext = v[mod(j,n)+1]
		if isa(vthis,Tuple)
			if isa(vnext,Tuple)
				@error("Cannot have consecutive infinite vertices")
				return nothing
			else
				p[j] = Ray(vnext,vthis[2],true)
			end 
		else
			if isa(vnext,Tuple)
				p[j] = Ray(vthis,vnext[1])
			else
				p[j] = Segment(vthis,vnext)
			end
		end
	end
	return Polygon(ClosedPath(p))
end

# Required methods
curves(p::Polygon) = curves(p.path)
arclength(p::Polygon) = arclength(p.path)
(p::Polygon)(t) = point(p.path,t)

# Display methods 
function show(io::IO,::MIME"text/plain",P::Polygon) 
	print(io,"Polygon with ",length(P)," vertices:")
	for (v,a) in zip(vertices(P),angles(P))
		print(io,"\n   ")
		show(io,MIME("text/plain"),v)
		print(io,", interior angle ",a/pi,"⋅π")
	end
end

# Other methods
"""
	angles(P::Polygon) 
Compute a vector of interior angles at the vertices of the polygon `P`. At a finite vertex these lie in (0,2π]; at an infinite vertex, the angle is in [-2π,0]. 
"""
function angles(p::Polygon)
	# computes a turn angle in (-pi,pi]  (neg = left turn)
	turn(s1,s2) = π - mod(angle(s2/s1)+π,2π)
	s = unittangent.(p) 
	n = length(p) 
	if n==2  # empty interior 
		return zeros(2)
	end
	v = vertices(p)
	θ = similar(real(s))
	for k = 1:n 
		kprev = mod(k-2,n)+1
		θ[k] = π + turn(s[kprev],s[k])
		if isinf(v[k]) 
			θ[k] -= 2π
			if θ[k]==0
				# need a finite perturbation to distinguish 0,-2
				R = maximum(abs.(filter(isfinite,v)))
				C = Circle(0,100*R)
				zprev = intersect(p[kprev],C)
				znext = intersect(p[k],C) 
				if angle(znext[1]/zprev[1]) < 0 
					θ[k] -= 2π
				end
			end
		end
	end
	# correct for possible clockwise orientation
	sum(θ) > 0 ? θ : -θ
end

"""
	truncate(P::Polygon,C::Circle) 
Compute a trucated form of the polygon by replacing each pair of rays incident at infinity with two segments connected by an arc along the given circle. This is *not* a true clipping of the polygon, as finite sides are not altered. The result is either a CircularPolygon or the original `P`. 
"""
function truncate(p::Polygon,c::Circle) 
	n = length(p)
	s,v = sides(p),vertices(p)
	snew = Vector{Any}(undef,n)
	z_pre = NaN
	if isa(s[1],Ray) && isa(s[n],Ray)
		# recognize that first side is actually the return from an infinite vertex 
		z_pre = intersect(c,s[n])[1]
	end
	for k = 1:n	
		if !isa(s[k],Ray)
			snew[k] = s[k] 
		else
			# first of a pair? 
			if isnan(z_pre) 
				z_pre = intersect(c,s[k])[1]
				snew[k] = Segment(s[k].base,z_pre)
			else
				z_post = intersect(c,s[k])[1]
				t0 = arg(c,z_pre)
				delta = mod( angle( (z_post-c.center)/(z_pre-c.center) ) / (2π), 1)
				snew[k] = [Arc(c,t0,delta),Segment(z_post,s[k].base)]
				z_pre = NaN
			end
		end
	end
	return CircularPolygon(vcat(snew...))
end

"""
	truncate(P::Polygon) 
Apply `truncate` to `P` using a circle that is centered at the centroid of its finite vertices, and a radius twice the maximum from the centroid to the finite vertices. 
"""
function truncate(p::Polygon) 
	isfinite(p) && return p   # nothing to do
	# try to find a circle clear of the polygon
	v = filter(isfinite,vertices(p))
	zc = sum(v)/length(v) 
	R = maximum(@. abs(v - zc))
	return truncate(p,Circle(zc,2*R))
end

# Special polygon constructors

"""
	rectangle(xlim,ylim) 
Construct the rectangle defined by `xlim[1]`` < x < `xlim[2]`, `ylim[1]`` < y < `ylim[2]`, where z=complex(x,y).
"""
function rectangle(xlim::AbstractVector,ylim::AbstractVector)  
	x = [xlim[1],xlim[2],xlim[2],xlim[1],xlim[1]]
	y = [ylim[1],ylim[1],ylim[2],ylim[2],ylim[1]]
	Polygon( [Segment(complex(x[k],y[k]),complex(x[k+1],y[k+1])) for k in 1:4] )
end

""" 
	rectangle(z1,z2) 
Construct the rectangle whose opposing corners are the given complex values. 
"""
rectangle(z1::AnyComplex,z2::AnyComplex) = rectangle([real(z1),real(z2)],[imag(z1),imag(z2)])
rectangle(z1::Number,z2::Number) = rectangle(promote(complex(float(z1)),complex(float(z2)))...)

"""
	n_gon(n)
Construct a regular n-gon with vertices on the unit circle.
"""
function n_gon(n::Integer) 
	@assert n > 2 "Must have at least three vertices"
	Polygon( exp.(2im*pi*(0:n-1)/n) ) 
end