#= 

# 2D Lid-driven cavity (Anderson-Iteration)
([source code](SOURCE_URL))

This example solves the lid-driven cavity problem where one seeks
a velocity ``\mathbf{u}`` and pressure ``\mathbf{p}`` of the incompressible Navier--Stokes problem
```math
\begin{aligned}
- \mu \Delta \mathbf{u} + (\mathbf{u} \cdot \nabla) \mathbf{u} + \nabla p & = 0\\
\mathrm{div}(u) & = 0
\end{aligned}
```
where ``\mathbf{u} = (1,0)`` along the top boundary of a square domain.

For small viscosities (where a Newton and a classical Picard iteration do not converge anymore),
Anderson acceleration might help (see https://arxiv.org/pdf/1810.08494.pdf) which can be tested with this script.

=#

module Example_2DLidDrivenCavityAnderson

using GradientRobustMultiPhysics
using ExtendableGrids
using Printf

## data
function boundary_data_top!(result)
    result[1] = 1;
    result[2] = 0;
end

## everything is wrapped in a main function
function main(; verbosity = 2, Plotter = nothing, viscosity = 1e-3, anderson_iterations = 5)

    ## grid
    xgrid = uniform_refine(grid_unitsquare(Triangle2D), 5);

    ## problem parameters
    maxIterations = 50  # termination criterion 1 for nonlinear mode
    maxResidual = 1e-10 # termination criterion 2 for nonlinear mode
    barycentric_refinement = false # do not change

    ## choose one of these (inf-sup stable) finite element type pairs
    #FETypes = [H1P2{2,2}, H1P1{1}] # Taylor--Hood
    #FETypes = [H1CR{2}, L2P0{1}] # Crouzeix--Raviart
    #FETypes = [H1MINI{2,2}, H1P1{1}] # MINI element on triangles only
    #FETypes = [H1MINI{2,2}, H1CR{1}] # MINI element on triangles/quads
    FETypes = [H1BR{2}, L2P0{1}] # Bernardi--Raugel
    #FETypes = [H1P2{2,2}, L2P1{1}]; barycentric_refinement = true # Scott-Vogelius 

    #####################################################################################    
    #####################################################################################

    ## negotiate data functions to the package
    user_function_bnd = DataFunction(boundary_data_top!, [2,2]; name = "u_bnd", dependencies = "", quadorder = 0)

    ## load Stokes problem prototype and assign data
    StokesProblem = IncompressibleNavierStokesProblem(2; viscosity = viscosity, nonlinear = true)
    add_boundarydata!(StokesProblem, 1, [1,2,4], HomogeneousDirichletBoundary)
    add_boundarydata!(StokesProblem, 1, [3], BestapproxDirichletBoundary; data = user_function_bnd)

    ## uniform mesh refinement
    ## in case of Scott-Vogelius we use barycentric refinement
    if barycentric_refinement == true
        xgrid = barycentric_refine(xgrid)
    end

    ## generate FESpaces
    FESpaceVelocity = FESpace{FETypes[1]}(xgrid)
    FESpacePressure = FESpace{FETypes[2]}(xgrid)
    Solution = FEVector{Float64}("Stokes velocity",FESpaceVelocity)
    append!(Solution,"Stokes pressure",FESpacePressure)

    ## set nonlinear options and Newton terms
    StokesProblem.LHSOperators[1,1][1].store_operator = true   
    Base.show(StokesProblem)

    ## solve Stokes problem
    solve!(Solution, StokesProblem; verbosity = verbosity, AndersonIterations = anderson_iterations, maxIterations = maxIterations, maxResidual = maxResidual)

    ## plot
    GradientRobustMultiPhysics.plot(Solution, [1,2], [Identity, Identity]; Plotter = Plotter, verbosity = verbosity, use_subplots = true)

end

end