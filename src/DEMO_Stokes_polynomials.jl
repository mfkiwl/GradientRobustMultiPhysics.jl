###############################################
### DEMONSTRATION SCRIPT STOKES POLYNOMIALS ###
###############################################
#
# solves (Navier-)Stokes test problem polynomials of order (0,1,2,3)
#
# demonstrates:
#   - convergence rates of implemented finite element methods
#   - exactness
#

using Triangulate
using Grid
using Quadrature
using FiniteElements
using FESolveCommon
using FESolveStokes
using FESolveNavierStokes
using ExtendableSparse
ENV["MPLBACKEND"]="tkagg"
using PyPlot

# load problem data and common grid generator
include("PROBLEMdefinitions/GRID_unitsquare.jl")
include("PROBLEMdefinitions/STOKES_2D_polynomials.jl");


function main()

    # problem modification switches
    polynomial_order = 0
    nu = 1
    nonlinear = true

    # refinement termination criterions
    maxlevel = 5
    maxdofs = 50000

    # other switches
    show_plots = true
    show_convergence_history = true
    use_reconstruction = 0 # do not change here
    barycentric_refinement = false # do not change here


    ########################
    ### CHOOSE FEM BELOW ###
    ########################

    #fem_velocity = "CR"; fem_pressure = "P0"
    #fem_velocity = "CR"; fem_pressure = "P0"; use_reconstruction = 1
    #fem_velocity = "MINI"; fem_pressure = "P1"
    #fem_velocity = "P2";  fem_pressure = "P1"
    #fem_velocity = "P2";  fem_pressure = "P1dc"; barycentric_refinement = true
    #fem_velocity = "P2"; fem_pressure = "P0"
    #fem_velocity = "P2B"; fem_pressure = "P1dc"
    #fem_velocity = "BR"; fem_pressure = "P0"
    fem_velocity = "BR"; fem_pressure = "P0"; use_reconstruction = 1


    # load problem data
    PD, exact_velocity!, exact_pressure! = getProblemData(polynomial_order, nu, nonlinear, 4);
    FESolveStokes.show(PD);

    L2error_velocity = zeros(Float64,maxlevel)
    L2error_pressure = zeros(Float64,maxlevel)
    ndofs_velocity = 0
    ndofs = zeros(Int,maxlevel)
    grid = Nothing
    FE_velocity = Nothing
    FE_pressure = Nothing
    val4dofs = Nothing
    for level = 1 : maxlevel

        if nonlinear
            println("Solving Navier-Stokes problem on refinement level...", level);
        else
            println("Solving Stokes problem on refinement level...", level);
        end

        println("Generating grid by triangle...");
        maxarea = 4.0^(-level)
        grid = gridgen_unitsquare(maxarea, barycentric_refinement)
        Grid.show(grid)

        # load finite element
        FE_velocity = FiniteElements.string2FE(fem_velocity,grid,2,2)
        FE_pressure = FiniteElements.string2FE(fem_pressure,grid,2,1)
        FiniteElements.show(FE_velocity)
        FiniteElements.show(FE_pressure)
        ndofs_velocity = FiniteElements.get_ndofs(FE_velocity);
        ndofs_pressure = FiniteElements.get_ndofs(FE_pressure);
        ndofs[level] = ndofs_velocity + ndofs_pressure;

        # stop here if too many dofs
        if ndofs[level] > maxdofs 
            println("terminating (maxdofs exceeded)...");
            maxlevel = level - 1
            if (show_plots)
                maxarea = 4.0^(-maxlevel)
                grid = gridgen_unitsquare(maxarea, barycentric_refinement)
                FE_velocity = FiniteElements.string2FE(fem_velocity,grid,2,2)
                FE_pressure = FiniteElements.string2FE(fem_pressure,grid,2,1)
                ndofs_velocity = FiniteElements.get_ndofs(FE_velocity);
            end    
            break
        end

        # solve Stokes problem
        val4dofs = zeros(Base.eltype(grid.coords4nodes),ndofs[level]);
        if nonlinear
            residual = solveNavierStokesProblem!(val4dofs,PD,FE_velocity,FE_pressure, use_reconstruction);
        else    
            residual = solveStokesProblem!(val4dofs,PD,FE_velocity,FE_pressure; reconst_variant = use_reconstruction);
        end

        # compute errors
        integral4cells = zeros(size(grid.nodes4cells,1),1);
        integrate!(integral4cells,eval_L2_interpolation_error!(exact_pressure!, val4dofs[ndofs_velocity+1:end], FE_pressure), grid, 2*polynomial_order, 1);
        L2error_pressure[level] = sqrt(abs(sum(integral4cells)));
        integral4cells = zeros(size(grid.nodes4cells,1),2);
        integrate!(integral4cells,eval_L2_interpolation_error!(exact_velocity!, val4dofs[1:ndofs_velocity], FE_velocity), grid, 2*polynomial_order, 2);
        L2error_velocity[level] = sqrt(abs(sum(integral4cells[:])));

    end # loop over levels

    println("\n L2 pressure error");
    show(L2error_pressure)
    println("\n L2 velocity error");
    show(L2error_velocity)

    #plot
    if (show_plots)
        pygui(true)
        
        # evaluate velocity and pressure at grid points
        if use_reconstruction > 0
            FE_Reconstruction = FiniteElements.get_Hdivreconstruction_space(FE_velocity, use_reconstruction);
            T = ExtendableSparseMatrix{Float64,Int64}(ndofs_velocity,FiniteElements.get_ndofs(FE_Reconstruction))
            FiniteElements.get_Hdivreconstruction_trafo!(T,FE_velocity,FE_Reconstruction);
            val4dofs_Hdiv = T'*val4dofs[1:ndofs_velocity];
            velo = FESolveCommon.eval_at_nodes(val4dofs_Hdiv,FE_Reconstruction);
        else
            velo = FESolveCommon.eval_at_nodes(val4dofs,FE_velocity);
        end    
        pressure = FESolveCommon.eval_at_nodes(val4dofs,FE_pressure,FiniteElements.get_ndofs(FE_velocity));

        PyPlot.figure(1)
        PyPlot.plot_trisurf(view(grid.coords4nodes,:,1),view(grid.coords4nodes,:,2),view(velo,:,1),cmap=get_cmap("ocean"))
        PyPlot.title("Stokes Problem Solution - velocity component 1")
        PyPlot.figure(2)
        PyPlot.plot_trisurf(view(grid.coords4nodes,:,1),view(grid.coords4nodes,:,2),view(velo,:,2),cmap=get_cmap("ocean"))
        PyPlot.title("Stokes Problem Solution - velocity component 2")
        PyPlot.figure(3)
        PyPlot.plot_trisurf(view(grid.coords4nodes,:,1),view(grid.coords4nodes,:,2),pressure[:],cmap=get_cmap("ocean"))
        PyPlot.title("Stokes Problem Solution - pressure")
        show()
    end

    if (show_convergence_history)
        PyPlot.figure()
        PyPlot.loglog(ndofs[1:maxlevel],L2error_velocity[1:maxlevel],"-o")
        PyPlot.loglog(ndofs[1:maxlevel],L2error_pressure[1:maxlevel],"-o")
        PyPlot.loglog(ndofs,ndofs.^(-1/2),"--",color = "gray")
        PyPlot.loglog(ndofs,ndofs.^(-1),"--",color = "gray")
        PyPlot.loglog(ndofs,ndofs.^(-3/2),"--",color = "gray")
        PyPlot.legend(("L2 error velocity","L2 error pressure","O(h)","O(h^2)","O(h^3)"))   
        PyPlot.title("Convergence history (fem=" * fem_velocity * "/" * fem_pressure * ")")
        ax = PyPlot.gca()
        ax.grid(true)
    end    

        
end


main()
