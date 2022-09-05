#= 

# A12 : Navier-Stokes-Problem with periodic boundary
([source code](SOURCE_URL))

This example computes the solution ``u`` of the Navier-Stokes problem
```math
\begin{aligned}
-\mu \Delta u + \nabla p & = \lambda \int_0^1 v_1(1,y) dy \quad \text{in } \Omega
\end{aligned}
```
with some given ``\lambda`` on the unit square domain ``\Omega`` and periodic boundary conditions left and right.

The resulting flow is a Hagen-Poiseuille flow and ``\lambda``scales the pressure difference between the left and right boundary.
The problem is tested with the Taylor--Hood element of the specified order. For oder = 1 the Bernardi--Raugel element is used
(where the normal-weighted face bubbles at the boundary require a different factor in the coupling due to the changed orientation
of the normal vector.)

=#

module ExampleA12_NavierStokesPeriodic

using GradientRobustMultiPhysics
using ExtendableGrids
using GridVisualize

## everything is wrapped in a main function
function main(; verbosity = 0, μ = 1, order = 2, periodic = true, nrefinements = 5, λ = 2, Plotter = nothing)

    ## set log level
    set_verbosity(verbosity)

    ## exact solution
    u = DataFunction((result,x) -> (
        result[1] = λ*x[2]*(1.0-x[2])/2;
        result[2] = 0.0;
     ), [2,2]; name = "u", dependencies = "X", bonus_quadorder = 2)

    p = DataFunction((result,x) -> (
        result[1] = λ*μ*(-2*x[1]+1.0)/2;
     ), [1,2]; name = "u", dependencies = "X", bonus_quadorder = 2)


    ## build/load any grid (here: a uniform-refined 2D unit square into triangles)
    xgrid = uniform_refine(grid_unitsquare(Triangle2D), nrefinements)

    ## problem description
    Problem = PDEDescription("Navier-Stokes Equations")
    add_unknown!(Problem; equation_name = "momentum equation", unknown_name = "u")
    add_unknown!(Problem; equation_name = "incompressibility constraint", unknown_name = "p", algebraic_constraint = true)
    add_operator!(Problem, [1,1], LaplaceOperator(μ))
    add_operator!(Problem, [1,2], LagrangeMultiplier(Divergence))

    ## discretise = choose FEVector with appropriate FESpaces
    if order == 1
        FETypes = [H1BR{2}, L2P0{1}] 
    elseif order > 1
        FETypes = [H1Pk{2,2,order}, H1Pk{1, 2, order-1}] 
    else
        @error "order must be a positive integer"
    end
    FES = [FESpace{FETypes[1]}(xgrid), FESpace{FETypes[2]}(xgrid)]
    Solution = FEVector(FES)

    ## add periodic boundary
    if periodic
        dofsX, dofsY, factors = get_periodic_coupling_info(FES[1], xgrid, 2, 4, (f1,f2) -> abs(f1[2] - f2[2]) < 1e-14)
        add_constraint!(Problem, CombineDofs(1, 1, dofsX, dofsY, factors))
        add_rhsdata!(Problem, 1, LinearForm(NormalFlux, DataFunction([λ]); regions = [2], AT = ON_BFACES))
        add_boundarydata!(Problem, 1, [1,3], HomogeneousDirichletBoundary)
    else
        add_boundarydata!(Problem, 1, [1,2,3,4], InterpolateDirichletBoundary; data = u)
    end
    add_constraint!(Problem, FixedIntegralMean(2, 0.0))

    ## show problem and Solution structure
    @show Problem Solution

    ## solve for chosen Solution vector
    solve!(Solution, Problem; show_statistics = true)

    ## calculate L2 error
    L2ErrorV = L2ErrorIntegrator(u, Identity)
    L2ErrorP = L2ErrorIntegrator(p, Identity)
    eu = sqrt(evaluate(L2ErrorV,Solution[1]))
    ep = sqrt(evaluate(L2ErrorP,Solution[2]))
    println("|| u - u_h || = $(eu)")
    println("|| p - p_h || = $(ep)")

    ## plot solution (for e.g. Plotter = PyPlot)
    p = GridVisualizer(; Plotter = Plotter, layout = (1,2), clear = true, resolution = (1000,500))
    scalarplot!(p[1,1], xgrid, view(nodevalues(Solution[1]),1,:), levels = 7, title = "u_x")
    scalarplot!(p[1,2], xgrid, view(nodevalues(Solution[2]),1,:), levels = 7, title = "p_h")
    return [eu, ep]
end

## test function that is called by test unit
function test()
    error = []
    for order in [2,3]
        push!(error, maximum(main(order = order, nrefinements = 0)))
    end
    return maximum(error)
end

end