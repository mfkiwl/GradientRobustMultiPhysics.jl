# top-level layer to define PDE operators between
# trial and testfunctions in weak form of PDE

# IDEAS for future
# depending on the chosen FETypes different assemblys of an operator might be triggered
# e.g. Laplacian for Hdiv might be with additional tangential jump stabilisation term

abstract type AbstractPDEOperator end
abstract type NoConnection <: AbstractPDEOperator end # => empy block in matrix

struct LaplaceOperator <: AbstractPDEOperator
    action :: AbstractAction             #      --ACTION--     
                                        # e.g. (K grad u) : grad v
end

struct LagrangeMultiplier <: AbstractPDEOperator
    operator :: Type{<:AbstractFunctionOperator} # e.g. Divergence, automatically aligns with transposed block
end

struct ConvectionOperator <: AbstractPDEOperator
    action :: AbstractAction             #      ----ACTION----
                                        # e.g. (beta * gradu) * v
end

function ConvectionOperator(beta::Function, xdim::Int; bonus_quadorder::Int = 0)
    function convection_function() # dot(convection!, input=Gradient)
        convection_vector = zeros(Float64,xdim)
        function closure(result, input, x)
            beta(convection_vector,x)
            result[1] = 0.0
            for j = 1 : length(input)
                result[1] += convection_vector[j]*input[j]
            end
        end    
    end    
    convection_action = XFunctionAction(convection_function(), 1, xdim; bonus_quadorder = bonus_quadorder)
    return ConvectionOperator(convection_action)
end

struct ReactionOperator <: AbstractPDEOperator
    action :: AbstractAction             #      --ACTION--                  
                                        # e.g. (gamma * u) * v 
end

struct RhsOperator <: AbstractPDEOperator
    operator :: Type{<:AbstractFunctionOperator}
    action :: AbstractAction              #       -----ACTION----
                                          # e.g.  f * operator(v)
end

function RhsOperator(operator::Type{<:AbstractFunctionOperator}, f4region, xdim::Int, ncomponents::Int = 1; bonus_quadorder::Int = 0)
    function rhs_function()
        temp = zeros(Float64,ncomponents)
        function closure(result,input,x,region)
            f4region[region](temp,x)
            result[1] = 0
            for j = 1 : ncomponents
                result[1] = temp[j]*input[j] 
            end
        end
    end    
    action = RegionWiseXFunctionAction(rhs_function(),1,xdim; bonus_quadorder = bonus_quadorder)
    return RhsOperator(operator, action)
end


abstract type AbstractBoundaryType end
abstract type DirichletBoundary <: AbstractBoundaryType end
abstract type BestapproxDirichletBoundary <: DirichletBoundary end
abstract type InterpolateDirichletBoundary <: DirichletBoundary end
abstract type HomogeneousDirichletBoundary <: DirichletBoundary end
abstract type NeumannBoundary <: AbstractBoundaryType end
abstract type DoNothingBoundary <: NeumannBoundary end


struct BoundaryOperator <: AbstractPDEOperator
    regions4boundarytype :: Dict{Type{<:AbstractBoundaryType},Array{Int,1}}
    data4bregion :: Array{Any,1}
    xdim :: Int
    ncomponents :: Int
end

function BoundaryOperator(xdim::Int, ncomponents::Int = 1)
    regions4boundarytype = Dict{Type{<:AbstractBoundaryType},Array{Int,1}}()
    return BoundaryOperator(regions4boundarytype, [], xdim, ncomponents)
end

function BoundaryOperator(boundarytype4bregion::Array{DataType,1}, data4region, xdim::Int, ncomponents::Int = 1; bonus_quadorder::Int = 0)
    regions4boundarytype = Dict{Type{<:AbstractBoundaryType},Array{Int,1}}()
    for j = 1 : length(boundarytype4bregion)
        btype = boundarytype4bregion[j]
        regions4boundarytype[btype]=push!(get(regions4boundarytype, btype, []),j)
    end
    return BoundaryOperator(regions4boundarytype, data4region, xdim, ncomponents)
end

function Base.append!(O::BoundaryOperator,region::Int, btype::Type{<:AbstractBoundaryType}; data = Nothing)
    O.regions4boundarytype[btype]=push!(get(O.regions4boundarytype, btype, []),region)
    while length(O.data4bregion) < region
        push!(O.data4bregion, Nothing)
    end
    O.data4bregion[region] = data
end

# A PDE is described by an nxn matrix and vector of PDEOperator
# the indices of matrix relate to FEBlocks given to solver
# all Operators of [i,k] - matrixblock are assembled into system matrix block [i*n+k]
# all Operators of [i] - rhs-block are assembled into rhs block [i]
# 
#
# EXAMPLE 1 : PoissonProblem with convection term
#   LHSOperators = [[LaplaceOperator(1.0), ConvectionOperator(beta)]]
#   RHSOperators = [[RhsOperator(Identity,...)]]
#
# EXAMPLE 2 : StokesProblem
#   LHSOperators = [[LaplaceOperator(nu)] [LagrangeMultiplier(operator)];
#                                []          [NoConnection]]
#   RHSOperators = [[RhsOperator(Identity, XFunctionAction)]]

struct PDEDescription
    name::String
    LHSOperators::Array{Array{AbstractPDEOperator,1},2}
    RHSOperators::Array{Array{AbstractPDEOperator,1},1}
    BoundaryOperators::Array{BoundaryOperator,1}
end
