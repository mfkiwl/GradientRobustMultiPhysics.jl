module QuadratureRules

using LinearAlgebra
using XGrid
using FEXGrid

export QuadratureRule, integrate!

struct QuadratureRule{T <: Real, ET <: AbstractElementGeometry}
    name::String
    xref::Array{Array{T, 1}}
    w::Array{T, 1}
end

Base.eltype(::QuadratureRule{T,ET}) where{T <: Real, ET <: AbstractElementGeometry} = [T,ET]

# show function for Quadrature
function show(Q::QuadratureRule{T,ET} where{T <: Real, ET <: AbstractElementGeometry})
    npoints = length(Q.xref);
    println("QuadratureRule information");
    println("    shape ; $(eltype(Q)[2])")
	println("     name : $(Q.name)");
	println("  npoints : $(npoints) ($(eltype(Q)[1]))")
end

function QuadratureRule{T,ET}(order::Int) where {T<:Real, ET <: AbstractElementGeometry1D}
    if order <= 1
        name = "midpoint rule"
        xref = Vector{Array{T,1}}(undef,1);
        xref[1] = ones(T,2) * 1 // 2
        w = [1]
    elseif order == 2
        name = "Simpson's rule"
        xref = Vector{Array{T,1}}(undef,3);
        xref[1] = [0 ,1];
        xref[2] = [1//2, 1//2];
        xref[3] = [1,0];
        w = [1//6; 2//3; 1//6]     
    else
        name = "generic Gauss rule of order $order"
        xref, w = get_generic_quadrature_Gauss(order)
    end
    return QuadratureRule{T, ET}(name, xref, w)
end

function QuadratureRule{T,ET}(order::Int) where {T<:Real, ET <: AbstractElementGeometry0D}
    name = "point evaluation"
    xref = Vector{Array{T,1}}(undef,1);
    xref[1] = ones(T,1)
    w = [1]
    return QuadratureRule{T, ET}(name, xref, w)
end


function QuadratureRule{T,ET}(order::Int) where {T<:Real, ET <: Triangle2D}
  if order <= 1
      name = "midpoint rule"
      xref = Vector{Array{T,1}}(undef,1);
      xref[1] = ones(T,3) * 1 // 3
      w = [1]
  elseif order == 2 # face midpoint rule  
      name = "face midpoints rule"
      xref = Vector{Array{T,1}}(undef,3);
      xref[1] = [1//2,1//2,0//1];
      xref[2] = [0//1,1//2,1//2];
      xref[3] = [1//2,0//1,1//2];
      w = [1//3; 1//3; 1//3]     
  else
      name = "generic Stroud rule of order $order"
      xref, w = get_generic_quadrature_Stroud(order)
  end
  return QuadratureRule{T, ET}(name, xref, w)
end


function QuadratureRule{T,ET}(order::Int) where {T<:Real, ET <: Parallelogram2D}
  if order <= 1
      name = "midpoint rule"
      xref = Vector{Array{T,1}}(undef,1);
      xref[1] = ones(T,2) * 1 // 2
      w = [1]
  else
      name = "generic Gauss tensor rule of order $order"
      xref1D, w1D = get_generic_quadrature_Gauss(order)
      xref = Vector{Array{T,1}}(undef,length(xref1D)^2)
      w = zeros(T,length(xref1D)^2)
      index = 1
      for j = 1 : length(xref1D), k = 1 : length(xref1D)
        xref[index] = zeros(T,2)
        xref[index][1] = xref1D[j][1]
        xref[index][2] = xref1D[k][1]
        w[index] = w1D[j] * w1D[k]
        index += 1
      end
  end
  return QuadratureRule{T, ET}(name, xref, w)
end


function get_generic_quadrature_Gauss(order::Int)
    ngpts::Int = div(order, 2) + 1
    
    # compute 1D Gauss points on interval [-1,1] and weights
    gamma = (1 : ngpts-1) ./ sqrt.(4 .* (1 : ngpts-1).^2 .- ones(ngpts-1,1) );
    F = eigen(diagm(1 => gamma[:], -1 => gamma[:]));
    r = F.values;
    w = 2*F.vectors[1,:].^2;
    
    # transform to interval [0,1]
    r = .5 .* r .+ .5;
    w = .5 .* w';
    xref = Array{Array{Float64,1}}(undef,length(r))
    for j = 1 : length(r)
        xref[j] = [r[j],1-r[j]];
    end
    
    return xref, w[:]
end
  
# computes quadrature points and weights by Stroud Conical Product rule
function get_generic_quadrature_Stroud(order::Int)
    ngpts::Int = div(order, 2) + 1
    
    # compute 1D Gauss points on interval [-1,1] and weights
    gamma = (1 : ngpts-1) ./ sqrt.(4 .* (1 : ngpts-1).^2 .- ones(ngpts-1,1) );
    F = eigen(diagm(1 => gamma[:], -1 => gamma[:]));
    r = F.values;
    a = 2*F.vectors[1,:].^2;
    
    # compute 1D Gauss-Jacobi Points for Intervall [-1,1] and weights
    delta = -1 ./ (4 .* (1 : ngpts).^2 .- ones(ngpts,1));
    gamma = sqrt.((2 : ngpts) .* (1 : ngpts-1)) ./ (2 .* (2 : ngpts) .- ones(ngpts-1,1));
    F = eigen(diagm(0 => delta[:], 1 => gamma[:], -1 => gamma[:]));
    s = F.values;
    b = 2*F.vectors[1,:].^2;
    
    # transform to interval [0,1]
    r = .5 .* r .+ .5;
    s = .5 .* s .+ .5;
    a = .5 .* a';
    b = .5 .* b';
    
    # apply conical product rule
    # xref[:,[1 2]] = [ s_j , r_i(1-s_j) ] 
    # xref[:,3] = 1 - xref[:,1] - xref[:,2]
    # w = a_i*b_j
    s = repeat(s',ngpts,1)[:];
    r = repeat(r,ngpts,1);
    xref = Array{Array{Float64,1}}(undef,length(s))
    for j = 1 : length(s)
        xref[j] = s[j].*[1,0,-1] - r[j]*(s[j]-1).*[0,1,-1] + [0,0,1];
    end
    w = a'*b;
    
    return xref, w[:]
end


# integrates and writes item-wise integrals into integral4cells
# AT can be AbstractAssemblyTypeCELL or AbstractAssemblyTypeFACE to integrate over cells/faces
# integrand has to have the form function integrand!(result,x)
function integrate!(integral4items::Array, grid::ExtendableGrid, AT::Type{<:AbstractAssemblyType}, integrand!::Function, order::Int, resultdim::Int, NumberType::Type{<:Number} = Float64; talkative::Bool = false)
    xCoords = grid[Coordinates]
    dim = size(xCoords,1)
    xItemNodes = grid[GridComponentNodes4AssemblyType(AT)]
    xItemVolumes = grid[GridComponentVolumes4AssemblyType(AT)]
    xItemTypes = grid[GridComponentTypes4AssemblyType(AT)]
    nitems = num_sources(xItemNodes)
    
    # find proper quadrature rules
    EG = unique(xItemTypes)
    qf = Array{QuadratureRule,1}(undef,length(EG))
    local2global = Array{L2GTransformer,1}(undef,length(EG))
    for j = 1 : length(EG)
        qf[j] = QuadratureRule{NumberType,EG[j]}(order);
        local2global[j] = L2GTransformer{NumberType,EG[j],grid[CoordinateSystem]}(grid,AT)
    end    
    if talkative
        println("INTEGRATE")
        println("=========")
        println("nitems = $nitems")
        for j = 1 : length(EG)
            println("QuadratureRule [$j] for $(EG[j]):")
            show(qf[j])
        end
    end

    # loop over items
    fill!(integral4items, 0)
    x = zeros(NumberType, dim)
    result = zeros(NumberType, resultdim)
    itemET = xItemTypes[1]
    iEG = 1
    for item = 1 : nitems
        # find index for CellType
        itemET = xItemTypes[item]
        iEG = findfirst(isequal(itemET), EG)

        update!(local2global[iEG],item)

        for i in eachindex(qf[iEG].w)
            eval!(x, local2global[iEG], qf[iEG].xref[i])
            integrand!(result,x)
            for j = 1 : resultdim
                integral4items[item, j] += result[j] * qf[iEG].w[i] * xItemVolumes[item];
            end
        end  
    end
end

end