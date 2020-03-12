#############################################
### DEMONSTRATION SCRIPT INTERPOLATION 1D ###
#############################################
#
# interpolates test polynomials arbitrary order
#
# demonstrates:
#   - finite element interpolation


using Grid
using Quadrature
using FiniteElements
using FESolveCommon
using FESolvePoisson
ENV["MPLBACKEND"]="tkagg"
using PyPlot


# load problem data and common grid generator
include("PROBLEMdefinitions/GRID_unitinterval.jl")
include("PROBLEMdefinitions/POISSON_1D_polynomials.jl");

function main()

    # refinement
    reflevel = 1
    reflevel_exact = 5

    # other switches
    show_plots = true

    ########################
    ### CHOOSE FEM BELOW ###
    ########################

    fem = "P1"
    #fem = "P2"

    # choose coefficients of exact solution

    #polynomial_coefficients = [0, -3.0, 2.0, -1.0, 1.0] # quartic
    #polynomial_coefficients = [0, 0, 0, -1.0]  # cubic
    polynomial_coefficients = [1.0, 1.0, 1.0]  # quadratic
    #polynomial_coefficients = [0, 1.0]   # linear
    #polynomial_coefficients = [1.0, 0]   # constant
    


    # load problem data
    PD, exact_solution! = getProblemData(polynomial_coefficients);
    FESolvePoisson.show(PD);

    # generate grid
    grid = gridgen_unitinterval(2.0^(-reflevel))
    Grid.show(grid)

    # generate FE
    FE = FiniteElements.string2FE(fem, grid, 1, 1)
    FiniteElements.show(FE)
    ndofs = FiniteElements.get_ndofs(FE);

    println("Interpolating...");    
    val4dofs = FiniteElements.createFEVector(FE);
    computeFEInterpolation!(val4dofs, exact_solution!, FE);

    # compute interpolation error
    integral4cells = zeros(size(grid.nodes4cells,1),1);
    integrate!(integral4cells,eval_L2_interpolation_error!(exact_solution!, val4dofs, FE), grid, 2*length(polynomial_coefficients), 1);
    L2error = sqrt(abs(sum(integral4cells)));
    println("L2_interpolation_error = " * string(L2error));

    # plot
    if (show_plots)
        nodevals = FESolveCommon.eval_at_nodes(val4dofs,FE);

        grid_exact = gridgen_unitinterval(2.0^(-reflevel_exact))
        nodevals_exact = zeros(Float64,size(grid_exact.coords4nodes,1))
        result = [0.0]
        for j = 1 : size(grid_exact.coords4nodes,1)
            exact_solution!(result,grid_exact.coords4nodes[j,:]); 
            nodevals_exact[j] = result[1]
        end
        pygui(true)
        PyPlot.figure(1)
        I = sortperm(grid.coords4nodes[:])
        PyPlot.plot(grid.coords4nodes[I],nodevals[I])
        I = sortperm(grid_exact.coords4nodes[:])
        PyPlot.plot(grid_exact.coords4nodes[I],nodevals_exact[I])
        PyPlot.title("interpolation (nodal values only) vs exact solution")
        #show()
    end    


end


main()