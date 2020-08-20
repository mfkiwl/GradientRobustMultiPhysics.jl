###########################
# AbstractAssemblyPattern #
###########################

# provides several patterns for finite element assembly

# ItemIntegrator
#   - functional that computes piecewise integrals
#     for each item: I(item) = Int_item action(op(*)) dx
#   - can be called with evaluate! to compute piecewise integrals (of a given FEBlock)
#   - can be called with evaluate to compute total integral (of a given FEBlock)
#   - constructor is independent of FE or grid!


"""
$(TYPEDEF)

abstract type for assembly patterns
"""
abstract type AbstractAssemblyPattern{T <: Real, AT<:AbstractAssemblyType} end

"""
$(TYPEDEF)

assembly pattern linear form (that only depends on one quantity)
"""
struct LinearForm{T <: Real, AT <: AbstractAssemblyType} <: AbstractAssemblyPattern{T, AT}
    FE::FESpace
    operator::Type{<:AbstractFunctionOperator}
    action::AbstractAction
    regions::Array{Int,1}
end   

"""
````
function LinearForm(
    T::Type{<:Real},
    AT::Type{<:AbstractAssemblyType},
    FE::FESpace,
    operator::Type{<:AbstractFunctionOperator},
    action::AbstractAction;
    regions::Array{Int,1} = [0])
````

Creates a LinearForm.
"""
function LinearForm(
    T::Type{<:Real},
    AT::Type{<:AbstractAssemblyType},
    FE::FESpace,
    operator::Type{<:AbstractFunctionOperator},
    action::AbstractAction;
    regions::Array{Int,1} = [0])
    return LinearForm{T,AT}(FE,operator,action,regions)
end

"""
$(TYPEDEF)

assembly pattern bilinear form (that depends on two quantities)
"""
struct BilinearForm{T <: Real, AT <: AbstractAssemblyType} <: AbstractAssemblyPattern{T, AT}
    FE1::FESpace
    FE2::FESpace
    operator1::Type{<:AbstractFunctionOperator}
    operator2::Type{<:AbstractFunctionOperator}
    action::AbstractAction # is only applied to FE1/operator1
    regions::Array{Int,1}
    symmetric::Bool
end   

"""
````
function BilinearForm(
    T::Type{<:Real},
    AT::Type{<:AbstractAssemblyType},
    FE1::FESpace,
    FE2::FESpace,
    operator1::Type{<:AbstractFunctionOperator},
    operator2::Type{<:AbstractFunctionOperator},
    action::AbstractAction; # is only applied to FE1/operator1
    regions::Array{Int,1} = [0])
````

Creates an unsymmetric BilinearForm.
"""
function BilinearForm(
    T::Type{<:Real},
    AT::Type{<:AbstractAssemblyType},
    FE1::FESpace,
    FE2::FESpace,
    operator1::Type{<:AbstractFunctionOperator},
    operator2::Type{<:AbstractFunctionOperator},
    action::AbstractAction; # is only applied to FE1/operator1
    regions::Array{Int,1} = [0])
    return BilinearForm{T,AT}(FE1,FE2,operator1,operator2,action,regions,false)
end

"""
````
function SymmetricBilinearForm(
    T::Type{<:Real},
    AT::Type{<:AbstractAssemblyType},
    FE1::FESpace,
    operator1::Type{<:AbstractFunctionOperator},
    action::AbstractAction; # is only applied to FE1/operator1
    regions::Array{Int,1} = [0])
````

Creates a symmetric BilinearForm that can be assembled into a matrix or a vector (with one argument fixed)
"""
function SymmetricBilinearForm(
    T::Type{<:Real},
    AT::Type{<:AbstractAssemblyType},
    FE1::FESpace,
    operator1::Type{<:AbstractFunctionOperator},
    action::AbstractAction; # is only applied to FE1/operator1
    regions::Array{Int,1} = [0])
    return BilinearForm{T,AT}(FE1,FE1,operator1,operator1,action,regions,true)
end


"""
$(TYPEDEF)

assembly pattern trilinear form (that depends on three quantities)
"""
struct TrilinearForm{T <: Real, AT <: AbstractAssemblyType} <: AbstractAssemblyPattern{T, AT}
    FE1::FESpace # < --- FE position that has to be fixed by an FEVectorBlock during assembly
    FE2::FESpace
    FE3::FESpace
    operator1::Type{<:AbstractFunctionOperator}
    operator2::Type{<:AbstractFunctionOperator}
    operator3::Type{<:AbstractFunctionOperator}
    action::AbstractAction # is only applied to FE2/operator2
    regions::Array{Int,1}
end   

"""
````
function TrilinearForm(
    T::Type{<:Real},
    AT::Type{<:AbstractAssemblyType},
    FE1::FESpace,
    FE2::FESpace,
    FE3::FESpace,
    operator1::Type{<:AbstractFunctionOperator},
    operator2::Type{<:AbstractFunctionOperator},
    operator3::Type{<:AbstractFunctionOperator},
    action::AbstractAction; # is only applied to FE1/operator1 + FE2/operator2
    regions::Array{Int,1} = [0])
````

Creates a TrilinearForm that can be assembeld into a matrix (with one argument fixed) or into a vector (with two fixed arguments).
"""
function TrilinearForm(
    T::Type{<:Real},
    AT::Type{<:AbstractAssemblyType},
    FE1::FESpace,
    FE2::FESpace,
    FE3::FESpace,
    operator1::Type{<:AbstractFunctionOperator},
    operator2::Type{<:AbstractFunctionOperator},
    operator3::Type{<:AbstractFunctionOperator},
    action::AbstractAction; # is only applied to FE1/operator1 + FE2/operator2
    regions::Array{Int,1} = [0])
    return TrilinearForm{T,AT}(FE1,FE2,FE3,operator1,operator2,operator3,action,regions)
end

"""
$(TYPEDEF)

assembly pattern item integrator that can e.g. be used for error/norm evaluations
"""
struct ItemIntegrator{T <: Real, AT <: AbstractAssemblyType} <: AbstractAssemblyPattern{T, AT}
    operator::Type{<:AbstractFunctionOperator}
    action::AbstractAction
    regions::Array{Int,1}
end


function prepare_assembly(
    form::AbstractAssemblyPattern{T,AT},
    operator::Array{DataType,1},
    FE::Array{<:FESpace,1},
    regions::Array{Int32,1},
    nrfactors::Int,
    bonus_quadorder::Int,
    verbosity::Int) where {T<: Real, AT <: AbstractAssemblyType}

    xItemGeometries = FE[1].xgrid[GridComponentGeometries4AssemblyType(AT)]
    xItemRegions = FE[1].xgrid[GridComponentRegions4AssemblyType(AT)]
    xItemDofs = Array{Union{VariableTargetAdjacency,SerialVariableTargetAdjacency},1}(undef,length(FE))
    for j=1:length(FE)
        xItemDofs[j] = Dofmap4Operator(FE[j],AT,operator[j])
    end    

    # find unique ElementGeometries
    EG, ndofs4EG = Base.unique(xItemGeometries, xItemRegions, xItemDofs, regions)

    # get function that handles the dofitem information for every integration item
    dii4op = Array{Function,1}(undef,length(FE))
    dofitemAT = Array{Type{<:AbstractAssemblyType},1}(undef,length(FE))
    for j=1:length(FE)
        dii4op[j], dofitemAT[j]  = DofitemInformation4Operator(FE[j], EG, AT, operator[j])
    end

    # find proper quadrature QuadratureRules
    # and construct matching FEBasisEvaluators
    # dimension 1 = id of element geometry combination of integration domains/dofitem domains
    # dimension 2 = id finite element
    # dimension 3 = position if integration domain in dofitem
    qf = Array{QuadratureRule,1}(undef,length(EG))
    basisevaler = Array{Array{Array{FEBasisEvaluator,1},1},1}(undef,length(EG))
    quadorder = 0
    for j = 1 : length(EG)
        basisevaler[j] = Array{Array{FEBasisEvaluator,1},1}(undef,length(FE))
        quadorder = bonus_quadorder
        for k = 1 : length(FE)
            quadorder += get_polynomialorder(eltype(FE[k]), EG[j]) + QuadratureOrderShift4Operator(eltype(FE[k]),operator[k])
        end
        quadorder = max(quadorder,0)          
        qf[j] = QuadratureRule{T,EG[j]}(quadorder);
        # choose quadrature order for all finite elements
        for k = 1 : length(FE)
            if dofitemAT[k] == AT
                basisevaler[j][k] = Array{FEBasisEvaluator,1}(undef,1)
                if k > 1 && FE[k] == FE[1] && operator[k] == operator[1]
                    basisevaler[j][k][1] = basisevaler[j][1][1] # e.g. for symmetric bilinerforms
                elseif k > 2 && FE[k] == FE[2] && operator[k] == operator[2]
                    basisevaler[j][k][1] = basisevaler[j][2][1]
                else    
                    basisevaler[j][k][1] = FEBasisEvaluator{T,eltype(FE[k]),EG[j],operator[k],AT}(FE[k], qf[j]; verbosity = verbosity)
                end    
            elseif (dofitemAT[k] == ON_CELLS) && (AT == ON_FACES)
                # generate basis evaler for each face of the cell geometry by mapping the quadrature points of the face to
                # the quadrature points of the respective cellface (weights stay the same)
                # TODO: we need all possible pairs of FACE/CELL geometry combinations here !!!
                nfaces4cell = nfaces_for_geometry(EG[j])
                qfxref = qf[j].xref
                xrefFACE2CELL = xrefFACE2xrefCELL(EG[j])
                basisevaler[j][k] = Array{FEBasisEvaluator,1}(undef,nfaces4cell)
                for f = 1 : nfaces4cell
                    for i = 1 : length(qfxref)
                        qf[j].xref[i] = xrefFACE2CELL[f](qfxref[i])
                    end
                    for k = 1 : length(FE)
                        basisevaler[j][k][f] = FEBasisEvaluator{T,eltype(FE[k]),EG[j],operator[k],AT}(FE[k], qf[j])
                    end    
                end
            end
        end
    end        
    if verbosity > 1
        println("\nASSEMBLY PREPARATION $(typeof(form))")
        println("====================================")
        for k = 1 : length(FE)
            println("      FE[$k] = $(FE[k].name), ndofs = $(FE[k].ndofs)")
            println("operator[$k] = $(operator[k])")
        end    
        println("     action = $(form.action)")
        println("    regions = $regions")
        println("   Base.unique = $EG")
        for j = 1 : length(EG)
            println("\nQuadratureRule [$j] for $(EG[j]):")
            Base.show(qf[j])
        end
    end
    return EG, ndofs4EG, qf, basisevaler, dii4op
end


function parse_regions(regions, xItemRegions)
    regions = deepcopy(regions)
    if regions == [0]
        try
            regions = Array{Int32,1}(Base.unique(xItemRegions[:]))
        catch
            regions = [xItemRegions[1]]
        end        
    else
        regions = Array{Int32,1}(regions)    
    end
    return regions
end


"""
````
function evaluate!(
    b::AbstractArray{<:Real,2},
    form::ItemIntegrator{T,AT},
    FEB::FEVectorBlock;
    verbosity::Int = 0) where {T<: Real, AT <: AbstractAssemblyType}
````

Evaluation of an ItemIntegrator form with given FEVectorBlock FEB into given two-dimensional Array b.
"""
function evaluate!(
    b::AbstractArray{<:Real,2},
    form::ItemIntegrator{T,AT},
    FEB::FEVectorBlock;
    verbosity::Int = 0) where {T<: Real, AT <: AbstractAssemblyType}

    # get adjacencies
    FE = FEB.FES
    operator = form.operator
    xItemNodes = FE.xgrid[GridComponentNodes4AssemblyType(AT)]
    xItemVolumes::Array{Float64,1} = FE.xgrid[GridComponentVolumes4AssemblyType(AT)]
    xItemGeometries = FE.xgrid[GridComponentGeometries4AssemblyType(AT)]
    xItemDofs = Dofmap4Operator(FE,AT,operator)
    xItemRegions = FE.xgrid[GridComponentRegions4AssemblyType(AT)]
    nitems = num_sources(xItemNodes)

    # prepare assembly
    action = form.action
    regions = parse_regions(form.regions, xItemRegions)
    EG, ndofs4EG, qf, basisevaler, dii4op = prepare_assembly(form, [operator], [FE], regions, 1, action.bonus_quadorder, verbosity - 1)

    # get size informations
    ncomponents::Int = get_ncomponents(eltype(FE))
    cvals_resultdim::Int = size(basisevaler[1][1][1].cvals,1)
    @assert size(b,1) == cvals_resultdim

    # loop over items
    EG4dofitem = [1,1] # type of the current item
    ndofs4dofitem = 0 # number of dofs for item
    dofitems = [0,0] # itemnr where the dof numbers can be found
    itempos4dofitem = [1,1] # local item position in dofitem
    coefficient4dofitem = [0,0]
    dofitem = 0
    coeffs = zeros(Float64,max_num_targets_per_source(xItemDofs))
    action_input::Array{T,1} = zeros(T,cvals_resultdim) # heap for action input
    action_result::Array{T,1} = zeros(T,action.resultdim) # heap for action output
    weights::Array{T,1} = qf[1].w # somehow this saves A LOT allocations
    basisevaler4dofitem = basisevaler[1][1][1]

    nregions::Int = length(regions)
    for item = 1 : nitems
    for r = 1 : nregions
    # check if item region is in regions
    if xItemRegions[item] == regions[r]

        # get dofitem informations
        dii4op[1](dofitems, EG4dofitem, itempos4dofitem, coefficient4dofitem, item)

        # loop over associated dofitems
        for di = 1 : length(dofitems)
            dofitem = dofitems[di]
            if dofitem != 0

                # get number of dofs on this dofitem
                ndofs4dofitem = ndofs4EG[1][EG4dofitem[di]]

                # update FEbasisevaler on dofitem
                basisevaler4dofitem = basisevaler[EG4dofitem[di]][1][itempos4dofitem[di]]
                update!(basisevaler4dofitem,dofitem)

                # update action on dofitem
                update!(action, basisevaler4dofitem, dofitem, regions[r])

                # update coeffs on dofitem
                for j=1:ndofs4dofitem
                    coeffs[j] = FEB[xItemDofs[j,dofitem]]
                end

                weights = qf[EG4dofitem[di]].w
                for i in eachindex(weights)
                    # apply action to FEVector
                    fill!(action_input, 0)
                    eval!(action_input, basisevaler4dofitem, coeffs, i)
                    apply_action!(action_result, action_input, action, i)
                    for j = 1 : action.resultdim
                        b[j,item] += action_result[j] * weights[i] * xItemVolumes[item] * coefficient4dofitem[di]
                    end
                end  
            end
        end
        break; # region for loop
    end # if in region    
    end # region for loop
    end # item for loop
    return nothing
end

"""
````
function evaluate(
    form::ItemIntegrator{T,AT},
    FEB::FEVectorBlock;
    verbosity::Int = 0) where {T<: Real, AT <: AbstractAssemblyType}

````

Evaluation of an ItemIntegrator form with given FEVectorBlock FEB, only returns accumulation over all items.
"""
function evaluate(
    form::ItemIntegrator{T,AT},
    FEB::FEVectorBlock;
    verbosity::Int = 0) where {T<: Real, AT <: AbstractAssemblyType}

    # get adjacencies
    FE = FEB.FES
    operator = form.operator
    xItemNodes = FE.xgrid[GridComponentNodes4AssemblyType(AT)]
    xItemVolumes::Array{Float64,1} = FE.xgrid[GridComponentVolumes4AssemblyType(AT)]
    xItemGeometries = FE.xgrid[GridComponentGeometries4AssemblyType(AT)]
    xItemDofs = Dofmap4Operator(FE,AT,operator)
    xItemRegions = FE.xgrid[GridComponentRegions4AssemblyType(AT)]
    nitems = num_sources(xItemNodes)

    # prepare assembly
    action = form.action
    regions = parse_regions(form.regions, xItemRegions)
    EG, ndofs4EG, qf, basisevaler, dii4op = prepare_assembly(form, [operator], [FE], regions, 1, action.bonus_quadorder, verbosity - 1)

    # get size informations
    ncomponents::Int = get_ncomponents(eltype(FE))
    cvals_resultdim::Int = size(basisevaler[1][1][1].cvals,1)

    # loop over items
    EG4dofitem = [1,1] # type of the current item
    ndofs4dofitem = 0 # number of dofs for item
    dofitems = [0,0] # itemnr where the dof numbers can be found
    itempos4dofitem = [1,1] # local item position in dofitem
    coefficient4dofitem = [0,0]
    dofitem = 0
    coeffs = zeros(Float64,max_num_targets_per_source(xItemDofs))
    action_input::Array{T,1} = zeros(T,cvals_resultdim) # heap for action input
    action_result::Array{T,1} = zeros(T,action.resultdim) # heap for action output
    weights::Array{T,1} = qf[1].w # somehow this saves A LOT allocations
    basisevaler4dofitem = basisevaler[1][1][1]
    
    nregions::Int = length(regions)
    result = zeros(T,action.resultdim)
    for item = 1 : nitems
    for r = 1 : nregions
    # check if item region is in regions
    if xItemRegions[item] == regions[r]

        # get dofitem informations
        dii4op[1](dofitems, EG4dofitem, itempos4dofitem, coefficient4dofitem, item)

        # loop over associated dofitems
        for di = 1 : length(dofitems)
            dofitem = dofitems[di]
            if dofitem != 0

                # get number of dofs on this dofitem
                ndofs4dofitem = ndofs4EG[1][EG4dofitem[di]]

                # update FEbasisevaler on dofitem
                basisevaler4dofitem = basisevaler[EG4dofitem[di]][1][itempos4dofitem[di]]
                update!(basisevaler4dofitem,dofitem)

                # update action on dofitem
                update!(action, basisevaler4dofitem, dofitem, regions[r])

                # update coeffs on dofitem
                for j=1:ndofs4dofitem
                    coeffs[j] = FEB[xItemDofs[j,dofitem]]
                end

                weights = qf[EG4dofitem[di]].w
                for i in eachindex(weights)
                    # apply action to FEVector
                    fill!(action_input, 0)
                    eval!(action_input, basisevaler4dofitem, coeffs, i)
                    apply_action!(action_result, action_input, action, i)
                    for j = 1 : action.resultdim
                        result[j] += action_result[j] * weights[i] * xItemVolumes[item] * coefficient4dofitem[di]
                    end
                end  
            end
        end
        break; # region for loop
    end # if in region    
    end # region for loop
    end # item for loop
    if action.resultdim ==  1
        return result[1]
    else
        return result
    end
end


"""
````
assemble!(
    b::AbstractArray{<:Real,2},
    LF::LinearForm{T,AT};
    verbosity::Int = 0) where {T<: Real, AT <: AbstractAssemblyType}

````

Assembly of a LinearForm LF into given two-dimensional Array b.
"""
function assemble!(
    b::Union{AbstractArray{<:Real,1},AbstractArray{<:Real,2}},
    LF::LinearForm{T,AT};
    verbosity::Int = 0,
    factor::Real = 1) where {T<: Real, AT <: AbstractAssemblyType}

    # get adjacencies
    FE = LF.FE
    operator = LF.operator
    xItemNodes = FE.xgrid[GridComponentNodes4AssemblyType(AT)]
    xItemVolumes::Array{Float64,1} = FE.xgrid[GridComponentVolumes4AssemblyType(AT)]
    xItemGeometries = FE.xgrid[GridComponentGeometries4AssemblyType(AT)]
    xItemDofs = Dofmap4Operator(FE,AT,operator)
    xItemRegions = FE.xgrid[GridComponentRegions4AssemblyType(AT)]
    nitems = num_sources(xItemNodes)

    # prepare assembly
    action = LF.action
    regions = parse_regions(LF.regions, xItemRegions)
    EG, ndofs4EG, qf, basisevaler, dii4op = prepare_assembly(LF, [operator], [FE], regions, 1, action.bonus_quadorder, verbosity - 1)

    # get size informations
    ncomponents::Int = get_ncomponents(eltype(FE))
    cvals_resultdim::Int = size(basisevaler[1][1][1].cvals,1)

    if typeof(b) <: AbstractArray{<:Real,1}
        @assert action.resultdim == 1
        onedimensional = true
    else
        onedimensional = false
    end

    # loop over items
    EG4dofitem = [1,1] # type of the current item
    ndofs4dofitem = 0 # number of dofs for item
    dofitems = [0,0] # itemnr where the dof numbers can be found
    itempos4dofitem = [1,1] # local item position in dofitem
    coefficient4dofitem = [0,0]
    dofitem = 0
    maxndofs = max_num_targets_per_source(xItemDofs)
    dofs = zeros(Int32,maxndofs)
    action_input::Array{T,1} = zeros(T,cvals_resultdim) # heap for action input
    action_result::Array{T,1} = zeros(T,action.resultdim) # heap for action output
    weights::Array{T,1} = qf[1].w # somehow this saves A LOT allocations
    basisevaler4dofitem = basisevaler[1][1][1]
    localb::Array{T,2} = zeros(Float64,maxndofs,action.resultdim)

    nregions::Int = length(regions)
    for item = 1 : nitems
    for r = 1 : nregions
    # check if item region is in regions
    if xItemRegions[item] == regions[r]

        # get dofitem informations
        dii4op[1](dofitems, EG4dofitem, itempos4dofitem, coefficient4dofitem, item)

        # loop over associated dofitems
        for di = 1 : length(dofitems)
            dofitem = dofitems[di]
            if dofitem != 0

                # get number of dofs on this dofitem
                ndofs4dofitem = ndofs4EG[1][EG4dofitem[di]]

                # update FEbasisevaler on dofitem
                basisevaler4dofitem = basisevaler[EG4dofitem[di]][1][itempos4dofitem[di]]
                update!(basisevaler4dofitem,dofitem)

                # update action on dofitem
                update!(action, basisevaler4dofitem, dofitem, regions[r])

                # update dofs
                for j=1:ndofs4dofitem
                    dofs[j] = xItemDofs[j,dofitem]
                end

                weights = qf[EG4dofitem[di]].w
                for i in eachindex(weights)
                    for dof_i = 1 : ndofs4dofitem
                        # apply action
                        eval!(action_input, basisevaler4dofitem , dof_i, i)
                        apply_action!(action_result, action_input, action, i)
                        for j = 1 : action.resultdim
                            localb[dof_i,j] += action_result[j] * weights[i]
                        end
                    end 
                end  

                if onedimensional
                    for dof_i = 1 : ndofs4dofitem
                        b[dofs[dof_i]] += factor * localb[dof_i,1] * xItemVolumes[item]
                    end
                else
                    for dof_i = 1 : ndofs4dofitem, j = 1 : action.resultdim
                        b[dofs[dof_i],j] += factor * localb[dof_i,j] * xItemVolumes[item]
                    end
                end
                fill!(localb, 0.0)
            end
        end
        break; # region for loop
    end # if in region    
    end # region for loop
    end # item for loop
    return nothing
end


"""
````
assemble!(
    A::AbstractArray{<:Real,2},
    BLF::BilinearForm{T, AT};
    apply_action_to::Int = 1,
    verbosity::Int = 0,
    factor::Real = 1,
    transposed_assembly::Bool = false,
    transpose_copy = Nothing) where {T<: Real, AT <: AbstractAssemblyType}
````

Assembly of a BilinearForm BLF into given two-dimensional AbstractArray (e.g. FEMatrixBlock).
"""
function assemble!(
    A::AbstractArray{<:Real,2},
    BLF::BilinearForm{T, AT};
    apply_action_to::Int = 1,
    verbosity::Int = 0,
    factor::Real = 1,
    transposed_assembly::Bool = false,
    transpose_copy = Nothing) where {T<: Real, AT <: AbstractAssemblyType}

    # get adjacencies
    FE = [BLF.FE1, BLF.FE2]
    operator = [BLF.operator1, BLF.operator2]
    xItemNodes = FE[1].xgrid[GridComponentNodes4AssemblyType(AT)]
    xItemVolumes::Array{Float64,1} = FE[1].xgrid[GridComponentVolumes4AssemblyType(AT)]
    xItemGeometries = FE[1].xgrid[GridComponentGeometries4AssemblyType(AT)]
    xItemDofs1 = Dofmap4Operator(FE[1],AT,operator[1])
    xItemDofs2 = Dofmap4Operator(FE[2],AT,operator[2])
    xItemRegions = FE[1].xgrid[GridComponentRegions4AssemblyType(AT)]
    nitems = Int64(num_sources(xItemNodes))

    # prepare assembly
    action = BLF.action
    regions = parse_regions(BLF.regions, xItemRegions)
    EG, ndofs4EG, qf, basisevaler, dii4op = prepare_assembly(BLF, operator, FE, regions, 2, action.bonus_quadorder, verbosity - 1)
 
 
    # get size informations
    ncomponents::Int = get_ncomponents(eltype(FE[1]))
    cvals_resultdim::Int = size(basisevaler[1][apply_action_to][1].cvals,1)
    action_resultdim::Int = action.resultdim
 
    # loop over items
    EG4dofitem1 = [1,1] # EG id of the current item with respect to operator 1
    EG4dofitem2 = [1,1] # EG id of the current item with respect to operator 2
    dofitems1 = [0,0] # itemnr where the dof numbers can be found (operator 1)
    dofitems2 = [0,0] # itemnr where the dof numbers can be found (operator 2)
    itempos4dofitem1 = [1,1] # local item position in dofitem1
    itempos4dofitem2 = [1,1] # local item position in dofitem2
    coefficient4dofitem1 = [0,0] # coefficients for operator 1
    coefficient4dofitem2 = [0,0] # coefficients for operator 2
    ndofs4item1::Int = 0 # number of dofs for item
    ndofs4item2::Int = 0 # number of dofs for item
    dofitem1 = 0
    dofitem2 = 0
    maxdofs1::Int = max_num_targets_per_source(xItemDofs1)
    maxdofs2::Int = max_num_targets_per_source(xItemDofs2)
    dofs = zeros(Int,maxdofs1)
    dofs2 = zeros(Int,maxdofs2)
    action_input::Array{T,1} = zeros(T,cvals_resultdim) # heap for action input
    action_result::Array{T,1} = zeros(T,action.resultdim) # heap for action output
    weights::Array{T,1} = qf[1].w # somehow this saves A LOT allocations
    basisevaler4dofitem1 = basisevaler[1][1][1]
    basisevaler4dofitem2 = basisevaler[1][2][1]
    basisvals1::Array{T,3} = basisevaler4dofitem1.cvals
    basisvals2::Array{T,3} = basisevaler4dofitem2.cvals
    localmatrix::Array{T,2} = zeros(T,maxdofs1,maxdofs2)
    temp::T = 0 # some temporary variable

    for item = 1 : nitems
    for r = 1 : length(regions)
    # check if item region is in regions
    if xItemRegions[item] == regions[r]

        # get dofitem informations
        dii4op[1](dofitems1, EG4dofitem1, itempos4dofitem1, coefficient4dofitem1, item)
        dii4op[2](dofitems2, EG4dofitem2, itempos4dofitem2, coefficient4dofitem2, item)

        # get quadrature weights for integration domain
        weights = qf[EG4dofitem1[1]].w

        # loop over associated dofitems (maximal 2 for jump calculations)
        # di, dj == 2 is only performed if one of the operators jumps
        for di = 1 : 2, dj = 1 : 2
            dofitem1 = dofitems1[di]
            dofitem2 = dofitems2[dj]
            if dofitem1 > 0 && dofitem2 > 0

                # get number of dofs on this dofitem
                ndofs4item1 = ndofs4EG[1][EG4dofitem1[di]]
                ndofs4item2 = ndofs4EG[2][EG4dofitem2[dj]]

                # update FEbasisevaler
                basisevaler4dofitem1 = basisevaler[EG4dofitem1[di]][1][itempos4dofitem1[di]]
                basisevaler4dofitem2 = basisevaler[EG4dofitem2[dj]][2][itempos4dofitem2[dj]]
                basisvals1 = basisevaler4dofitem1.cvals
                basisvals2 = basisevaler4dofitem2.cvals
                update!(basisevaler4dofitem1,dofitem1)
                update!(basisevaler4dofitem2,dofitem2)

                # update action on dofitem
                if apply_action_to == 1
                    update!(action, basisevaler4dofitem1, dofitem1, regions[r])
                else
                    update!(action, basisevaler4dofitem2, dofitem2, regions[r])
                end

                # update dofs
                for j=1:ndofs4item1
                    dofs[j] = xItemDofs1[j,dofitem1]
                end
                for j=1:ndofs4item2
                    dofs2[j] = xItemDofs2[j,dofitem2]
                end

                for i in eachindex(weights)
                    if apply_action_to == 1
                        for dof_i = 1 : ndofs4item1
                            eval!(action_input, basisevaler4dofitem1, dof_i, i)
                            apply_action!(action_result, action_input, action, i)
                            action_result .*= weights[i] * coefficient4dofitem1[di]

                            if BLF.symmetric == false
                                for dof_j = 1 : ndofs4item2
                                    temp = 0
                                    for k = 1 : action_resultdim
                                        temp += action_result[k] * basisvals2[k,dof_j,i]
                                    end
                                    temp *= coefficient4dofitem2[dj]
                                    localmatrix[dof_i,dof_j] += temp
                                end
                            else # symmetric case
                                for dof_j = dof_i : ndofs4item2
                                    temp = 0
                                    for k = 1 : action_resultdim
                                        temp += action_result[k] * basisvals2[k,dof_j,i]
                                    end
                                    temp *= coefficient4dofitem1[di]
                                    localmatrix[dof_i,dof_j] += temp
                                end
                            end
                        end 
                    else
                        for dof_j = 1 : ndofs4item2
                            eval!(action_input, basisevaler4dofitem2, dof_j, i)
                            apply_action!(action_result, action_input, action, i)
                            action_result .*= weights[i] * coefficient4dofitem2[dj]

                            if BLF.symmetric == false
                                for dof_i = 1 : ndofs4item1
                                    temp = 0
                                    for k = 1 : action_resultdim
                                        temp += action_result[k] * basisvals1[k,dof_j,i]
                                    end
                                    temp *= coefficient4dofitem1[di]
                                    localmatrix[dof_i,dof_j] += temp 
                                end
                            else # symmetric case
                                for dof_i = dof_j : ndofs4item1
                                    temp = 0
                                    for k = 1 : action_resultdim
                                        temp += action_result[k] * basisvals1[k,dof_j,i]
                                    end
                                    temp *= coefficient4dofitem1[di]
                                    localmatrix[dof_i,dof_j] += temp
                                end
                            end
                        end 
                    end
                end

                # copy localmatrix into global matrix
                if BLF.symmetric == false
                    for dof_i = 1 : ndofs4item1, dof_j = 1 : ndofs4item2
                        if localmatrix[dof_i,dof_j] != 0
                            if transposed_assembly == true
                                _addnz(A,dofs2[dof_j],dofs[dof_i],localmatrix[dof_i,dof_j] * xItemVolumes[item],factor)
                            else 
                                _addnz(A,dofs[dof_i],dofs2[dof_j],localmatrix[dof_i,dof_j] * xItemVolumes[item],factor)  
                            end
                            if transpose_copy != Nothing # sign is changed in case nonzero rhs data is applied to LagrangeMultiplier (good idea?)
                                if transposed_assembly == true
                                    _addnz(transpose_copy,dofs[dof_i],dofs2[dof_j],localmatrix[dof_i,dof_j] * xItemVolumes[item],-factor)
                                else
                                    _addnz(transpose_copy,dofs2[dof_j],dofs[dof_i],localmatrix[dof_i,dof_j] * xItemVolumes[item],-factor)
                                end
                            end
                        end
                    end
                else # symmetric case
                    for dof_i = 1 : ndofs4item1, dof_j = dof_i+1 : ndofs4item2
                        if localmatrix[dof_i,dof_j] != 0 
                            temp = localmatrix[dof_i,dof_j] * xItemVolumes[item]
                            _addnz(A,dofs2[dof_j],dofs[dof_i],temp,factor)
                            _addnz(A,dofs2[dof_i],dofs[dof_j],temp,factor)
                        end
                    end    
                    for dof_i = 1 : ndofs4item1
                       _addnz(A,dofs2[dof_i],dofs[dof_i],localmatrix[dof_i,dof_i] * xItemVolumes[item],factor)
                    end    
                end    
                fill!(localmatrix,0.0)
            end
        end 
        break; # region for loop
    end # if in region    
    end # region for loop
    end # item for loop

    return nothing
end



"""
````
assemble!(
    b::AbstractArray{<:Real,1},
    fixedFE::FEVectorBlock,    # coefficient for fixed 2nd component
    BLF::BilinearForm{T, AT};
    apply_action_to::Int = 1,
    factor::Real = 1,
    verbosity::Int = 0) where {T<: Real, AT <: AbstractAssemblyType}
````

Assembly of a BilinearForm BLF into given one-dimensional AbstractArray (e.g. a FEVectorBlock).
Here, the second argument is fixed by the given coefficients in fixedFE.
With apply_action_to=2 the action can be also applied to the second fixed argument instead of the first one (default).
"""
function assemble!(
    b::AbstractArray{<:Real,1},
    fixedFE::FEVectorBlock,    # coefficient for fixed 2nd component
    BLF::BilinearForm{T, AT};
    apply_action_to::Int = 1,
    factor::Real = 1,
    verbosity::Int = 0) where {T<: Real, AT <: AbstractAssemblyType}

    # get adjacencies
    FE = [BLF.FE1, BLF.FE2]
    operator = [BLF.operator1, BLF.operator2]
    xItemNodes = FE[1].xgrid[GridComponentNodes4AssemblyType(AT)]
    xItemVolumes::Array{Float64,1} = FE[1].xgrid[GridComponentVolumes4AssemblyType(AT)]
    xItemGeometries = FE[1].xgrid[GridComponentGeometries4AssemblyType(AT)]
    xItemDofs1 = Dofmap4Operator(FE[1],AT,operator[1])
    xItemDofs2 = Dofmap4Operator(FE[2],AT,operator[2])
    xItemRegions = FE[1].xgrid[GridComponentRegions4AssemblyType(AT)]
    nitems = Int64(num_sources(xItemNodes))

    # prepare assembly
    action = BLF.action
    regions = parse_regions(BLF.regions, xItemRegions)
    EG, ndofs4EG, qf, basisevaler, dii4op = prepare_assembly(BLF, operator, FE, regions, 2, action.bonus_quadorder, verbosity - 1)


    # get size informations
    ncomponents::Int = get_ncomponents(eltype(FE[1]))
    ncomponents2::Int = get_ncomponents(eltype(FE[2]))
    cvals_resultdim::Int = size(basisevaler[1][apply_action_to][1].cvals,1)
    cvals_resultdim2::Int = size(basisevaler[1][2][1].cvals,1)
    action_resultdim::Int = action.resultdim

    # loop over items
    EG4dofitem1 = [1,1] # EG id of the current item with respect to operator 1
    EG4dofitem2 = [1,1] # EG id of the current item with respect to operator 2
    dofitems1 = [0,0] # itemnr where the dof numbers can be found (operator 1)
    dofitems2 = [0,0] # itemnr where the dof numbers can be found (operator 2)
    itempos4dofitem1 = [1,1] # local item position in dofitem1
    itempos4dofitem2 = [1,1] # local item position in dofitem2
    coefficient4dofitem1 = [0,0] # coefficients for operator 1
    coefficient4dofitem2 = [0,0] # coefficients for operator 2
    ndofs4item1::Int = 0 # number of dofs for item
    ndofs4item2::Int = 0 # number of dofs for item
    dofitem1 = 0
    dofitem2 = 0
    maxdofs1::Int = max_num_targets_per_source(xItemDofs1)
    maxdofs2::Int = max_num_targets_per_source(xItemDofs2)
    dofs = zeros(Int,maxdofs1)
    coeffs2 = zeros(T,maxdofs2)
    action_input::Array{T,1} = zeros(T,cvals_resultdim) # heap for action input
    action_result::Array{T,1} = zeros(T,action.resultdim) # heap for action output
    weights::Array{T,1} = qf[1].w # somehow this saves A LOT allocations
    basisevaler4dofitem1 = basisevaler[1][1][1]
    basisevaler4dofitem2 = basisevaler[1][2][1]
    basisvals1::Array{T,3} = basisevaler4dofitem1.cvals
    localmatrix = zeros(T,maxdofs1,maxdofs2)
    fixedval = zeros(T, cvals_resultdim2) # some temporary variable
    temp::T = 0 # some temporary variable
    localb::Array{T,1} = zeros(T,maxdofs1)

    for item = 1 : nitems
    for r = 1 : length(regions)
    # check if item region is in regions
    if xItemRegions[item] == regions[r]

        # get dofitem informations
        dii4op[1](dofitems1, EG4dofitem1, itempos4dofitem1, coefficient4dofitem1, item)
        dii4op[2](dofitems2, EG4dofitem2, itempos4dofitem2, coefficient4dofitem2, item)

        # get quadrature weights for integration domain
        weights = qf[EG4dofitem1[1]].w

        # loop over associated dofitems (maximal 2 for jump calculations)
        # di, dj == 2 is only performed if one of the operators jumps
        for di = 1 : 2, dj = 1 : 2
            dofitem1 = dofitems1[di]
            dofitem2 = dofitems2[dj]
            if dofitem1 > 0 && dofitem2 > 0

                # get number of dofs on this dofitem
                ndofs4item1 = ndofs4EG[1][EG4dofitem1[di]]
                ndofs4item2 = ndofs4EG[2][EG4dofitem2[dj]]

                # update FEbasisevaler
                basisevaler4dofitem1 = basisevaler[EG4dofitem1[di]][1][itempos4dofitem1[di]]
                basisevaler4dofitem2 = basisevaler[EG4dofitem2[dj]][2][itempos4dofitem2[dj]]
                basisvals1 = basisevaler4dofitem1.cvals
                update!(basisevaler4dofitem1,dofitem1)
                update!(basisevaler4dofitem2,dofitem2)

                # update action on dofitem
                if apply_action_to == 1
                    update!(action, basisevaler4dofitem1, dofitem1, regions[r])
                else
                    update!(action, basisevaler4dofitem2, dofitem2, regions[r])
                end

                # update dofs
                for j=1:ndofs4item1
                    dofs[j] = xItemDofs1[j,dofitem1]
                end
                for j=1:ndofs4item2
                    coeffs2[j] = fixedFE[xItemDofs2[j,dofitem2]]
                end

                for i in eachindex(weights)
                
                    # evaluate second component
                    fill!(fixedval, 0.0)
                    eval!(fixedval, basisevaler4dofitem2, coeffs2, i)
                    fixedval .*= coefficient4dofitem2[dj]

                    if apply_action_to == 2
                        # apply action to second argument
                        apply_action!(action_result, fixedval, action, i)

                        # multiply first argument
                        for dof_i = 1 : ndofs4item1
                            temp = 0
                            for k = 1 : action_resultdim
                                temp += action_result[k] * basisvals1[k,dof_i,i]
                            end
                            localb[dof_i] += temp * weights[i] * coefficient4dofitem1[di]
                        end 
                    else
                        for dof_i = 1 : ndofs4item1
                            # apply action to first argument
                            eval!(action_input, basisevaler4dofitem1, dof_i, i)
                            apply_action!(action_result, action_input, action, i)
            
                            # multiply second argument
                            temp = 0
                            for k = 1 : action_resultdim
                                temp += action_result[k] * fixedval[k]
                            end
                            localb[dof_i] += temp * weights[i] * coefficient4dofitem1[di]
                        end 
                    end
                end

                for dof_i = 1 : ndofs4item1
                    b[dofs[dof_i]] += localb[dof_i] * xItemVolumes[item] * factor
                end
                fill!(localb, 0.0)
            end
        end 
        break; # region for loop
    end # if in region    
    end # region for loop
    end # item for loop
    return nothing
end

"""
````
assemble!(
    assemble!(
    A::AbstractArray{<:Real,2},
    FE1::FEVectorBlock,
    TLF::TrilinearForm{T, AT};
    verbosity::Int = 0,
    transposed_assembly::Bool = false,
    factor::Real = 1)
````

Assembly of a TrilinearForm TLF into given two-dimensional AbstractArray (e.g. a FEMatrixBlock).
Here, the first argument is fixed by the given coefficients in FE1.
"""
function assemble!(
    A::AbstractArray{<:Real,2},
    FE1::FEVectorBlock,
    TLF::TrilinearForm{T, AT};
    verbosity::Int = 0,
    transposed_assembly::Bool = false,
    factor::Real = 1) where {T<: Real, AT <: AbstractAssemblyType}
    
    # get adjacencies
    FE = [TLF.FE1, TLF.FE2, TLF.FE3]
    operator = [TLF.operator1, TLF.operator2, TLF.operator3]
    xItemNodes = FE[1].xgrid[GridComponentNodes4AssemblyType(AT)]
    xItemVolumes::Array{Float64,1} = FE[1].xgrid[GridComponentVolumes4AssemblyType(AT)]
    xItemGeometries = FE[1].xgrid[GridComponentGeometries4AssemblyType(AT)]
    xItemDofs1 = Dofmap4Operator(FE[1],AT,operator[1])
    xItemDofs2 = Dofmap4Operator(FE[2],AT,operator[2])
    xItemDofs3 = Dofmap4Operator(FE[3],AT,operator[3])
    xItemRegions = FE[1].xgrid[GridComponentRegions4AssemblyType(AT)]
    nitems = Int64(num_sources(xItemNodes))

    # prepare assembly
    action = TLF.action
    regions = parse_regions(TLF.regions, xItemRegions)
    EG, ndofs4EG, qf, basisevaler, dii4op = prepare_assembly(TLF, operator, FE, regions, 3, action.bonus_quadorder, verbosity - 1)

    # get size informations
    ncomponents::Int = get_ncomponents(eltype(FE[1]))
    ncomponents2::Int = get_ncomponents(eltype(FE[2]))
    cvals_resultdim::Int = size(basisevaler[1][1][1].cvals,1)
    cvals_resultdim2::Int = size(basisevaler[1][2][1].cvals,1)
    action_resultdim::Int = action.resultdim

    # loop over items
    EG4dofitem1::Array{Int,1} = [1,1] # EG id of the current item with respect to operator 1
    EG4dofitem2::Array{Int,1} = [1,1] # EG id of the current item with respect to operator 2
    EG4dofitem3::Array{Int,1} = [1,1] # EG id of the current item with respect to operator 3
    dofitems1::Array{Int,1} = [0,0] # itemnr where the dof numbers can be found (operator 1)
    dofitems2::Array{Int,1} = [0,0] # itemnr where the dof numbers can be found (operator 2)
    dofitems3::Array{Int,1} = [0,0] # itemnr where the dof numbers can be found (operator 3)
    itempos4dofitem1::Array{Int,1} = [1,1] # local item position in dofitem1
    itempos4dofitem2::Array{Int,1} = [1,1] # local item position in dofitem2
    itempos4dofitem3::Array{Int,1} = [1,1] # local item position in dofitem3
    coefficient4dofitem1::Array{Int,1} = [0,0] # coefficients for operator 1
    coefficient4dofitem2::Array{Int,1} = [0,0] # coefficients for operator 2
    coefficient4dofitem3::Array{Int,1} = [0,0] # coefficients for operator 3
    ndofs4item1::Int = 0 # number of dofs for item
    ndofs4item2::Int = 0 # number of dofs for item
    ndofs4item3::Int = 0 # number of dofs for item
    dofitem1::Int = 0
    dofitem2::Int = 0
    dofitem3::Int = 0
    maxdofs1::Int = max_num_targets_per_source(xItemDofs1)
    maxdofs2::Int = max_num_targets_per_source(xItemDofs2)
    maxdofs3::Int = max_num_targets_per_source(xItemDofs3)
    coeffs::Array{T,1} = zeros(T,maxdofs1)
    dofs2::Array{Int,1} = zeros(Int,maxdofs2)
    dofs3::Array{Int,1} = zeros(Int,maxdofs3)
    action_input::Array{T,1} = zeros(T,cvals_resultdim+cvals_resultdim2) # heap for action input
    action_result::Array{T,1} = zeros(T,action.resultdim) # heap for action output
    weights::Array{T,1} = qf[1].w # somehow this saves A LOT allocations
    basisevaler4dofitem1 = basisevaler[1][1][1]
    basisevaler4dofitem2 = basisevaler[1][2][1]
    basisevaler4dofitem3 = basisevaler[1][3][1]
    basisvals3::Array{T,3} = basisevaler4dofitem3.cvals
    localmatrix::Array{T,2} = zeros(T,maxdofs2,maxdofs3)
    evalFE1::Array{T,1} = zeros(T,cvals_resultdim) # evaluation of argument 1
    temp::T = 0 # some temporary variable

    for item = 1 : nitems
    for r = 1 : length(regions)
    # check if item region is in regions
    if xItemRegions[item] == regions[r]

        # get dofitem informations
        dii4op[1](dofitems1, EG4dofitem1, itempos4dofitem1, coefficient4dofitem1, item)
        dii4op[2](dofitems2, EG4dofitem2, itempos4dofitem2, coefficient4dofitem2, item)
        dii4op[2](dofitems3, EG4dofitem3, itempos4dofitem3, coefficient4dofitem3, item)

        # get quadrature weights for integration domain
        weights = qf[EG4dofitem1[1]].w

        # loop over associated dofitems (maximal 2 for jump calculations)
        # di, dj == 2 is only performed if one of the operators jumps
        for di = 1 : 2, dj = 1 : 2, dk = 1 : 2
            dofitem1 = dofitems1[di]
            dofitem2 = dofitems2[dj]
            dofitem3 = dofitems3[dj]
            if dofitem1 > 0 && dofitem2 > 0 && dofitem3 > 0

                # get number of dofs on this dofitem
                ndofs4item1 = ndofs4EG[1][EG4dofitem1[di]]
                ndofs4item2 = ndofs4EG[2][EG4dofitem2[dj]]
                ndofs4item3 = ndofs4EG[3][EG4dofitem3[dk]]

                # update FEbasisevaler
                basisevaler4dofitem1 = basisevaler[EG4dofitem1[di]][1][itempos4dofitem1[di]]
                basisevaler4dofitem2 = basisevaler[EG4dofitem2[dj]][2][itempos4dofitem2[dj]]
                basisevaler4dofitem3 = basisevaler[EG4dofitem3[dj]][3][itempos4dofitem3[dk]]
                basisvals3 = basisevaler4dofitem3.cvals
                update!(basisevaler4dofitem1,dofitem1)
                update!(basisevaler4dofitem2,dofitem2)
                update!(basisevaler4dofitem3,dofitem3)

                # update action on dofitem
                update!(action, basisevaler4dofitem2, dofitem1, regions[r])

                # update coeffs, dofs
                for j=1:ndofs4item1
                    coeffs[j] = FE1[xItemDofs1[j,dofitem1]]
                end
                for j=1:ndofs4item2
                    dofs2[j] = xItemDofs2[j,dofitem2]
                end
                for j=1:ndofs4item3
                    dofs3[j] = xItemDofs3[j,dofitem3]
                end

                for i in eachindex(weights)
        
                    # evaluate first component
                    fill!(action_input, 0.0)
                    eval!(action_input, basisevaler4dofitem1,coeffs, i)
                    action_input *= coefficient4dofitem1[di]
                    
                    for dof_i = 1 : ndofs4item2
                        # apply action to FE1 eval and second argument
                        eval!(action_input, basisevaler4dofitem2, dof_i, i, offset = cvals_resultdim, factor = coefficient4dofitem2[dj])
                        apply_action!(action_result, action_input, action, i)
        
                        for dof_j = 1 : ndofs4item3
                            temp = 0
                            for k = 1 : action_resultdim
                                    temp += action_result[k] * basisvals3[k,dof_j,i]
                            end
                            localmatrix[dof_i,dof_j] += temp * weights[i] * coefficient4dofitem3[dk]
                        end
                    end 
                end 
        
                # copy localmatrix into global matrix
                for dof_i = 1 : ndofs4item2, dof_j = 1 : ndofs4item3
                        if localmatrix[dof_i,dof_j] != 0
                        if transposed_assembly == true
                            _addnz(A,dofs3[dof_j],dofs2[dof_i],localmatrix[dof_i,dof_j] * xItemVolumes[item], factor)
                        else
                            _addnz(A,dofs2[dof_i],dofs3[dof_j],localmatrix[dof_i,dof_j] * xItemVolumes[item], factor)
                        end
                    end
                end
                fill!(localmatrix,0.0)
            end
        end 
        break; # region for loop
    end # if in region    
    end # region for loop
    end # item for loop
    return nothing
end


"""
````
assemble!(
    assemble!(
    b::AbstractArray{<:Real,1},
    FE1::FEVectorBlock,
    FE2::FEVectorBlock.
    TLF::TrilinearForm{T, AT};
    verbosity::Int = 0,
    factor::Real = 1)
````

Assembly of a TrilinearForm TLF into given two-dimensional AbstractArray (e.g. a FEMatrixBlock).
Here, the first two arguments are fixed by the given coefficients in FE1 and FE2.
"""
function assemble!(
    b::AbstractArray{<:Real,1},
    FE1::FEVectorBlock,
    FE2::FEVectorBlock,
    TLF::TrilinearForm{T, AT};
    verbosity::Int = 0,
    factor::Real = 1) where {T<: Real, AT <: AbstractAssemblyType}

    # get adjacencies
    FE = [TLF.FE1, TLF.FE2, TLF.FE3]
    operator = [TLF.operator1, TLF.operator2, TLF.operator3]
    xItemNodes = FE[1].xgrid[GridComponentNodes4AssemblyType(AT)]
    xItemVolumes::Array{Float64,1} = FE[1].xgrid[GridComponentVolumes4AssemblyType(AT)]
    xItemGeometries = FE[1].xgrid[GridComponentGeometries4AssemblyType(AT)]
    xItemDofs1 = Dofmap4Operator(FE[1],AT,operator[1])
    xItemDofs2 = Dofmap4Operator(FE[2],AT,operator[2])
    xItemDofs3 = Dofmap4Operator(FE[3],AT,operator[3])
    xItemRegions = FE[1].xgrid[GridComponentRegions4AssemblyType(AT)]
    nitems = Int64(num_sources(xItemNodes))

    # prepare assembly
    action = TLF.action
    regions = parse_regions(TLF.regions, xItemRegions)
    EG, ndofs4EG, qf, basisevaler, dii4op = prepare_assembly(TLF, operator, FE, regions, 3, action.bonus_quadorder, verbosity - 1)

    # get size informations
    ncomponents::Int = get_ncomponents(eltype(FE[1]))
    ncomponents2::Int = get_ncomponents(eltype(FE[2]))
    cvals_resultdim::Int = size(basisevaler[1][1][1].cvals,1)
    cvals_resultdim2::Int = size(basisevaler[1][2][1].cvals,1)
    action_resultdim::Int = action.resultdim

    # loop over items
    EG4dofitem1::Array{Int,1} = [1,1] # EG id of the current item with respect to operator 1
    EG4dofitem2::Array{Int,1} = [1,1] # EG id of the current item with respect to operator 2
    EG4dofitem3::Array{Int,1} = [1,1] # EG id of the current item with respect to operator 3
    dofitems1::Array{Int,1} = [0,0] # itemnr where the dof numbers can be found (operator 1)
    dofitems2::Array{Int,1} = [0,0] # itemnr where the dof numbers can be found (operator 2)
    dofitems3::Array{Int,1} = [0,0] # itemnr where the dof numbers can be found (operator 3)
    itempos4dofitem1::Array{Int,1} = [1,1] # local item position in dofitem1
    itempos4dofitem2::Array{Int,1} = [1,1] # local item position in dofitem2
    itempos4dofitem3::Array{Int,1} = [1,1] # local item position in dofitem3
    coefficient4dofitem1::Array{Int,1} = [0,0] # coefficients for operator 1
    coefficient4dofitem2::Array{Int,1} = [0,0] # coefficients for operator 2
    coefficient4dofitem3::Array{Int,1} = [0,0] # coefficients for operator 3
    ndofs4item1::Int = 0 # number of dofs for item
    ndofs4item2::Int = 0 # number of dofs for item
    ndofs4item3::Int = 0 # number of dofs for item
    dofitem1::Int = 0
    dofitem2::Int = 0
    dofitem3::Int = 0
    maxdofs1::Int = max_num_targets_per_source(xItemDofs1)
    maxdofs2::Int = max_num_targets_per_source(xItemDofs2)
    maxdofs3::Int = max_num_targets_per_source(xItemDofs3)
    coeffs1::Array{T,1} = zeros(T,maxdofs1)
    coeffs2::Array{T,1} = zeros(T,maxdofs2)
    dofs3::Array{Int,1} = zeros(Int,maxdofs3)
    action_input::Array{T,1} = zeros(T,cvals_resultdim+cvals_resultdim2) # heap for action input
    action_result::Array{T,1} = zeros(T,action.resultdim) # heap for action output
    weights::Array{T,1} = qf[1].w # somehow this saves A LOT allocations
    basisevaler4dofitem1 = basisevaler[1][1][1]
    basisevaler4dofitem2 = basisevaler[1][2][1]
    basisevaler4dofitem3 = basisevaler[1][3][1]
    basisvals3::Array{T,3} = basisevaler4dofitem3.cvals
    localmatrix::Array{T,2} = zeros(T,maxdofs2,maxdofs3)
    temp::T = 0 # some temporary variable
    localb::Array{T,1} = zeros(T,maxdofs1)

    for item = 1 : nitems
    for r = 1 : length(regions)
    # check if item region is in regions
    if xItemRegions[item] == regions[r]

        # get dofitem informations
        dii4op[1](dofitems1, EG4dofitem1, itempos4dofitem1, coefficient4dofitem1, item)
        dii4op[2](dofitems2, EG4dofitem2, itempos4dofitem2, coefficient4dofitem2, item)
        dii4op[2](dofitems3, EG4dofitem3, itempos4dofitem3, coefficient4dofitem3, item)

        # get quadrature weights for integration domain
        weights = qf[EG4dofitem1[1]].w

        # loop over associated dofitems (maximal 2 for jump calculations)
        # di, dj == 2 is only performed if one of the operators jumps
        for di = 1 : 2, dj = 1 : 2, dk = 1 : 2
            dofitem1 = dofitems1[di]
            dofitem2 = dofitems2[dj]
            dofitem3 = dofitems3[dj]
            if dofitem1 > 0 && dofitem2 > 0 && dofitem3 > 0

                # get number of dofs on this dofitem
                ndofs4item1 = ndofs4EG[1][EG4dofitem1[di]]
                ndofs4item2 = ndofs4EG[2][EG4dofitem2[dj]]
                ndofs4item3 = ndofs4EG[3][EG4dofitem3[dk]]

                # update FEbasisevaler
                basisevaler4dofitem1 = basisevaler[EG4dofitem1[di]][1][itempos4dofitem1[di]]
                basisevaler4dofitem2 = basisevaler[EG4dofitem2[dj]][2][itempos4dofitem2[dj]]
                basisevaler4dofitem3 = basisevaler[EG4dofitem3[dj]][3][itempos4dofitem3[dk]]
                basisvals3 = basisevaler4dofitem3.cvals
                update!(basisevaler4dofitem1,dofitem1)
                update!(basisevaler4dofitem2,dofitem2)
                update!(basisevaler4dofitem3,dofitem3)

                # update action on dofitem
                update!(action, basisevaler4dofitem2, dofitem1, regions[r])

                # update coeffs, dofs
                for j=1:ndofs4item1
                    coeffs1[j] = FE1[xItemDofs1[j,dofitem1]]
                end
                for j=1:ndofs4item2
                    coeffs2[j] = FE1[xItemDofs2[j,dofitem2]]
                end
                for j=1:ndofs4item3
                    dofs3[j] = xItemDofs3[j,dofitem3]
                end

                for i in eachindex(weights)

                    # evaluate first and second component
                    fill!(action_input, 0.0)
                    eval!(action_input, basisevaler4dofitem1, coeffs1, i; factor = coefficient4dofitem1[di])
                    eval!(action_input, basisevaler4dofitem2, coeffs2, i; offset = cvals_resultdim, factor = coefficient4dofitem2[dj])
        
                    # apply action to FE1 and FE2
                    apply_action!(action_result, action_input, action, i)
                   
                    # multiply third component
                    for dof_j = 1 : ndofs4item2
                        temp = 0
                        for k = 1 : action_resultdim
                            temp += action_result[k]*basisvals3[k,dof_j,i]
                        end
                        localb[dof_j] += temp * weights[i]
                    end 
                end 
        
                for dof_i = 1 : ndofs4item3
                    b[dofs3[dof_i]] += localb[dof_i] * xItemVolumes[item] * factor * coefficient4dofitem3[dk]
                end
                fill!(localb, 0.0)
            end
        end 
        break; # region for loop
    end # if in region    
    end # region for loop
    end # item for loop
    return nothing
end



"""
````
function L2ErrorIntegrator(
    exact_function::Function,
    operator::Type{<:AbstractFunctionOperator},
    xdim::Int,
    ncomponents::Int = 1;
    AT::Type{<:AbstractAssemblyType} = ON_CELLS,
    bonus_quadorder::Int = 0)
````

Creates an ItemIntegrator that compares FEVectorBlock operator-evaluations against the given exact_function and returns the L2-error.
"""
function L2ErrorIntegrator(
    exact_function!::Function,
    operator::Type{<:AbstractFunctionOperator},
    xdim::Int,
    ncomponents::Int = 1;
    AT::Type{<:AbstractAssemblyType} = ON_CELLS,
    bonus_quadorder::Int = 0,
    time = 0)

    temp = zeros(Float64,ncomponents)
    if applicable(exact_function!, temp, 0, 0)
        exact_func! = exact_function!
    else
        exact_func!(temp,x,t) = exact_function!(temp,x)
    end
    function L2error_function(result,input,x)
        exact_func!(temp,x,time)
        result[1] = 0.0
        for j=1:length(temp)
            result[1] += (temp[j] - input[j])^2
        end    
    end    
    L2error_action = XFunctionAction(L2error_function,1,xdim; bonus_quadorder = bonus_quadorder)
    return ItemIntegrator{Float64,AT}(operator, L2error_action, [0])
end