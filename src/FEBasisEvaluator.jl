####################
# FEBasisEvaluator #
####################
#
# steers the evaluation of finite element basis functions within an assembly pattern
#
# during construction it gets assigned a
#   AbstractFunctionOperator: what is evaluted (e.g. Identity, Gradient, Divergence...)
#   AbstractAssemblyType : cells, faces, bfaces? (to decide which dof field to use) 
#   ElementGeometry : triangles, quads? 
#   QuadratureRule : where to evaluate



"""
$(TYPEDEF)

root type for FunctionOperators.
"""
abstract type AbstractFunctionOperator end # to dispatch which evaluator of the FE_basis_caller is used
"""
$(TYPEDEF)

identity operator: evaluates finite element function.
"""
abstract type Identity <: AbstractFunctionOperator end # 1*v_h
"""
$(TYPEDEF)

reconstruction identity operator: evaluates a reconstructed version of the finite element function.

FEreconst specifies the reconstruction space and reconstruction algorithm if it is defined for the finite element that it is applied to.
"""
abstract type ReconstructionIdentity{FEreconst<:AbstractFiniteElement} <: Identity end # 1*R(v_h)
"""
$(TYPEDEF)

evaluates the normal-flux of the finite element function.

only available on FACES/BFACES and currently only for H1 and Hdiv elements
"""
abstract type NormalFlux <: AbstractFunctionOperator end # v_h * n_F # only for Hdiv/H1 on Faces/BFaces

abstract type TangentFlux <: AbstractFunctionOperator end # v_h * t_F # only for Hcurl on Edges
"""
$(TYPEDEF)

evaluates the gradient of the finite element function.
"""
abstract type Gradient <: AbstractFunctionOperator end # D_geom(v_h)
"""
$(TYPEDEF)

evaluates the symmetric part of the gradient of the finite element function.
"""
abstract type SymmetricGradient <: AbstractFunctionOperator end # sym(D_geom(v_h))
"""
$(TYPEDEF)

evaluates the gradient of the tangential part of some vector-valued finite element function.
"""
abstract type TangentialGradient <: AbstractFunctionOperator end # D_geom(v_h x n) = only gradient of tangential part of vector-valued function

abstract type Laplacian <: AbstractFunctionOperator end # L_geom(v_h)
abstract type Hessian <: AbstractFunctionOperator end # D^2(v_h)
abstract type Curl <: AbstractFunctionOperator end # only 2D: Curl(v_h) = D(v_h)^\perp
abstract type Rotation <: AbstractFunctionOperator end # only 3D: Rot(v_h) = D \times v_h
"""
$(TYPEDEF)

evaluates the divergence of the finite element function.
"""
abstract type Divergence <: AbstractFunctionOperator end # div(v_h)
"""
$(TYPEDEF)

evaluates the divergence of the reconstructed finite element function.

    FEreconst specifies the reconstruction space and reconstruction algorithm if it is defined for the finite element that it is applied to.
"""
abstract type ReconstructionDivergence{FEreconst<:AbstractFiniteElement} <: Divergence end # 1*R(v_h)

abstract type Trace <: AbstractFunctionOperator end # tr(v_h)
abstract type Deviator <: AbstractFunctionOperator end # dev(v_h)

# operator to be used for Dirichlet boundary data
DefaultDirichletBoundaryOperator4FE(::Type{<:AbstractH1FiniteElement}) = Identity
DefaultDirichletBoundaryOperator4FE(::Type{<:AbstractHdivFiniteElement}) = NormalFlux
DefaultDirichletBoundaryOperator4FE(::Type{<:AbstractHcurlFiniteElement}) = TangentFlux

NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{<:Identity}) = 0
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{NormalFlux}) = 0
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{TangentFlux}) = 0
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{Gradient}) = 1
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{SymmetricGradient}) = 1
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{TangentialGradient}) = 1
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{Laplacian}) = 2
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{Hessian}) = 2
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{Curl}) = 1
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{Rotation}) = 1
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{<:Divergence}) = 1
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{Trace}) = 0
NeededDerivative4Operator(::Type{<:AbstractFiniteElement},::Type{Deviator}) = 0

# length for operator result (> 0 to be multiplied with ncomponents, = 0 fixed size)
Length4Operator(::Type{<:Identity}, xdim::Int, ncomponents::Int) = ncomponents
Length4Operator(::Type{NormalFlux}, xdim::Int, ncomponents::Int) = ceil(ncomponents/xdim)
Length4Operator(::Type{TangentFlux}, xdim::Int, ncomponents::Int) = ceil(ncomponents/(xdim-1))
Length4Operator(::Type{Divergence}, xdim::Int, ncomponents::Int) = ceil(ncomponents/xdim)
Length4Operator(::Type{Trace}, xdim::Int, ncomponents::Int) = ceil(sqrt(ncomponents))
Length4Operator(::Type{Curl}, xdim::Int, ncomponents::Int) = ((xdim == 2) ? xdim*ncomponents : ceil(xdim*(ncomponents/xdim)))
Length4Operator(::Type{Gradient}, xdim::Int, ncomponents::Int) = xdim*ncomponents
Length4Operator(::Type{TangentialGradient}, xdim::Int, ncomponents::Int) = 1
Length4Operator(::Type{SymmetricGradient}, xdim::Int, ncomponents::Int) = ((xdim == 2) ? 3 : 6)*ceil(ncomponents/xdim)
Length4Operator(::Type{Hessian}, xdim::Int, ncomponents::Int) = xdim*xdim*ncomponents

QuadratureOrderShift4Operator(::Type{<:AbstractFiniteElement},::Type{<:Identity}) = 0
QuadratureOrderShift4Operator(::Type{<:AbstractFiniteElement},::Type{NormalFlux}) = 0
QuadratureOrderShift4Operator(::Type{<:AbstractFiniteElement},::Type{TangentFlux}) = 0
QuadratureOrderShift4Operator(::Type{<:AbstractFiniteElement},::Type{Gradient}) = -1
QuadratureOrderShift4Operator(::Type{<:AbstractFiniteElement},::Type{<:Divergence}) = -1
QuadratureOrderShift4Operator(::Type{<:AbstractFiniteElement},::Type{SymmetricGradient}) = -1
QuadratureOrderShift4Operator(::Type{<:AbstractFiniteElement},::Type{TangentialGradient}) = -1
QuadratureOrderShift4Operator(::Type{<:AbstractFiniteElement},::Type{Laplacian}) = -2
QuadratureOrderShift4Operator(::Type{<:AbstractFiniteElement},::Type{Hessian}) = -2

mutable struct FEBasisEvaluator{T <: Real, FEType <: AbstractFiniteElement, EG <: AbstractElementGeometry, FEOP <: AbstractFunctionOperator, AT <: AbstractAssemblyType}
    FE::FESpace                          # link to full FE (e.g. for coefficients)
    FE2::FESpace                         # link to reconstruction FE
    ItemDofs::VariableTargetAdjacency    # link to ItemDofs
    L2G::L2GTransformer                  # local2global mapper
    L2GM::Array{T,2}                     # heap for transformation matrix (possibly tinverted)
    iteminfo::Array{T,1}                 # (e.g. current determinant for Hdiv, current tangent)
    xref::Array{Array{T,1},1}            # xref of quadrature formula
    refbasisvals::Array{T,3}             # basis evaluation on EG reference cell 
    refoperatorvals::Array{T,3}          # additional values to evaluate operator
    ncomponents::Int                     # number of FE components
    offsets::Array{Int,1}                # offsets for gradient entries of each dof
    offsets2::Array{Int,1}               # offsets for dof entries of each gradient (on ref)
    citem::Int                           # current item
    cvals::Array{T,3}                    # current operator vals on item
    coefficients::Array{T,2}             # coefficients
    coefficients2::Array{T,2}            # coefficients for reconstruction
    coefficients3::Array{T,2}            # coefficients for operator (e.g. TangentialGradient)
end

function vector_hessian(f, x)
    n = length(x)
    return ForwardDiff.jacobian(x -> ForwardDiff.jacobian(f, x), x)
end



function FEBasisEvaluator{T,FEType,EG,FEOP,AT}(FE::FESpace, qf::QuadratureRule; verbosity::Int = 0) where {T <: Real, FEType <: AbstractFiniteElement, EG <: AbstractElementGeometry, FEOP <: AbstractFunctionOperator, AT <: AbstractAssemblyType}
    ItemDofs = FEPropertyDofs4AssemblyType(FE,AT)
    L2G = L2GTransformer{T, EG, FE.xgrid[CoordinateSystem]}(FE.xgrid,AT)
    L2GM = copy(L2G.A)

    if verbosity > 0
        println("  ...constructing FEBasisEvaluator for $FEType, EG = $EG, operator = $FEOP")
    end

    # pre-allocate memory for basis functions
    ncomponents = get_ncomponents(FEType)
    if AT <: Union{AssemblyTypeBFACE,AssemblyTypeFACE}
        if FEType <: AbstractHdivFiniteElement
            refbasis = get_basis_normalflux_on_face(FEType, EG)
            ncomponents = 1
        else
            refbasis = get_basis_on_face(FEType, EG)
        end
    else
        refbasis = get_basis_on_cell(FEType, EG)
    end    
    
    # probe for ndofs4item
    ndofs4item::Int = 0
    try
        test = refbasis(qf.xref[1]')'
        ndofs4item = ceil(length(test[:])/ncomponents)
    catch
    end

    refbasisvals = zeros(T,ncomponents,ndofs4item,length(qf.w));
    for i in eachindex(qf.w)
        # evaluate basis functions at quadrature point
        if ncomponents == 1
            refbasisvals[:,:,i] = reshape(refbasis(qf.xref[i]),1,:)
        else
            refbasisvals[:,:,i] = refbasis(qf.xref[i]')'
        end    
    end    

    derivorder = NeededDerivative4Operator(FEType,FEOP)
    edim = dim_element(EG)
    xdim = size(FE.xgrid[Coordinates],1)
    if derivorder > 0
        refoperatorvals = zeros(T,ndofs4item*ncomponents,edim,length(qf.w));
        current_eval = zeros(T,ncomponents*edim,ndofs4item,length(qf.w));
        for i in eachindex(qf.w)
            # evaluate gradients of basis function
            # = list of vectors [du_k/dx_1; du_k,dx_2]
            refoperatorvals[:,:,i] = ForwardDiff.jacobian(refbasis,qf.xref[i]);
        end 
    end
    if derivorder > 1
        refoperatorvals = zeros(T,ndofs4item*ncomponents*edim,edim,length(qf.w));
        current_eval = zeros(T,ncomponents*edim*edim,ndofs4item,length(qf.w));
        for i in eachindex(qf.w)
            # evaluate gradients of basis function
            refoperatorvals[:,:,i] = vector_hessian(refbasis,qf.xref[i])
        end   
    end

    xref = copy(qf.xref)
    if FEType <: Union{AbstractH1FiniteElementWithCoefficients, AbstractHdivFiniteElement}
        coefficients = zeros(T,ncomponents,ndofs4item)
    else
        coefficients = zeros(T,0,0)
    end    
    coefficients2 = zeros(T,0,0)
    coefficients3 = zeros(T,0,0)
    if derivorder == 0
        refoperatorvals = zeros(T,0,0,0);
        if FEOP == NormalFlux
            coefficients3 = FE.xgrid[FaceNormals]
            current_eval = zeros(T,1,ndofs4item,length(qf.w));
        elseif FEOP == Identity    
            current_eval = deepcopy(refbasisvals) 
        end
    else
        if FEOP == TangentialGradient
            coefficients3 = FE.xgrid[FaceNormals]
            current_eval = zeros(T,ncomponents*edim,ndofs4item,length(qf.w));
        end
    end
    offsets = 0:edim:(ncomponents*edim);
    offsets2 = 0:ndofs4item:ncomponents*ndofs4item;
    
    return FEBasisEvaluator{T,FEType,EG,FEOP,AT}(FE,FE, ItemDofs,L2G,L2GM,zeros(T,xdim+1),xref,refbasisvals,refoperatorvals,ncomponents,offsets,offsets2,0,current_eval,coefficients, coefficients2, coefficients3)
end    

# constructor for ReconstructionIdentity, ReconstructionDivergence
function FEBasisEvaluator{T,FEType,EG,FEOP,AT}(FE::FESpace, qf::QuadratureRule; verbosity::Int = 0) where {T <: Real, FEType <: AbstractFiniteElement, FETypeReconst <: AbstractFiniteElement, EG <: AbstractElementGeometry, FEOP <: Union{ReconstructionIdentity{FETypeReconst},ReconstructionDivergence{FETypeReconst}}, AT <: AbstractAssemblyType}
    # generate reconstruction space
    # avoid computation of full dofmap
    # we will just use local basis functions

    if verbosity > 0
        println("  ...constructing FEBasisEvaluator for $FEOP operator of $FEType on $EG")
    end

    FE2 = FESpace{FETypeReconst}(FE.xgrid; dofmap_needed = false)
    
    ItemDofs = FEPropertyDofs4AssemblyType(FE,AT)
    L2G = L2GTransformer{T, EG, FE.xgrid[CoordinateSystem]}(FE.xgrid,AT)
    L2GM = copy(L2G.A)

    # pre-allocate memory for reconstruction basis functions
    ncomponents = get_ncomponents(FEType)
    refbasis = get_basis_on_cell(FEType, EG)
    refbasis_reconst = get_basis_on_cell(FETypeReconst, EG)
    
    # probe for ndofs4item
    ndofs4item::Int = 0
    ndofs4item2::Int = 0
    try
        test = refbasis(qf.xref[1]')'
        ndofs4item = ceil(length(test[:])/ncomponents)
        test = refbasis_reconst(qf.xref[1]')'
        ndofs4item2 = ceil(length(test[:])/ncomponents)
    catch
    end

    refbasisvals = zeros(T,ncomponents,ndofs4item2,length(qf.w));
    for i in eachindex(qf.w)
        # evaluate basis functions at quadrature point
        if ncomponents == 1
            refbasisvals[:,:,i] = reshape(refbasis_reconst(qf.xref[i]),1,:)
        else
            refbasisvals[:,:,i] = refbasis_reconst(qf.xref[i]')'
        end    
    end    

    derivorder = NeededDerivative4Operator(FEType,FEOP)
    edim = dim_element(EG)
    xdim = size(FE.xgrid[Coordinates],1)
    if derivorder > 0
        refoperatorvals = zeros(T,ndofs4item2*ncomponents,edim,length(qf.w));
        for i in eachindex(qf.w)
            # evaluate gradients of basis function
            # = list of vectors [du_k/dx_1; du_k,dx_2]
            refoperatorvals[:,:,i] = ForwardDiff.jacobian(refbasis_reconst,qf.xref[i]);
        end 
    end

    xref = copy(qf.xref)
    coefficients = zeros(T,ncomponents,ndofs4item2)
    coefficients2 = zeros(T,ndofs4item,ndofs4item2)
    if FEOP <: ReconstructionIdentity
        refoperatorvals = zeros(T,ncomponents,ndofs4item2,length(qf.w));
        current_eval = zeros(T,ncomponents,ndofs4item,length(qf.w));
    elseif FEOP <: ReconstructionDivergence
        current_eval = zeros(T,1,ndofs4item,length(qf.w));
    else
        refoperatorvals = zeros(T,1,ndofs4item2,length(qf.w));
        current_eval = zeros(T,1,ndofs4item,length(qf.w));
    end
    offsets = 0:edim:(ncomponents*edim);
    offsets2 = 0:ndofs4item2:ncomponents*ndofs4item2;
    coefficients3 = zeros(T,0,0)
    
    return FEBasisEvaluator{T,FEType,EG,FEOP,AT}(FE,FE2, ItemDofs,L2G,L2GM,zeros(T,xdim+1),xref,refbasisvals,refoperatorvals,ncomponents,offsets,offsets2,0,current_eval,coefficients, coefficients2,coefficients3)
end    


# IDENTITY OPERATOR
# H1 ELEMENTS (nothing has to be done)
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,Identity,AT}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElement, EG <: AbstractElementGeometry, AT <:AbstractAssemblyType}
    FEBE.citem = item
end


# RECONSTRUCTION IDENTITY OPERATOR
# H1 ELEMENTS
# HDIV RECONSTRUCTION
# Piola transform Hdiv reference basis and multiply Hdiv coefficients and Trafo coefficients
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,FEOP,AT}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElement, EG <: AbstractElementGeometry, AT <:AbstractAssemblyType, FETypeReconst <: AbstractFiniteElement, FEOP <: ReconstructionIdentity{FETypeReconst}}
    if FEBE.citem != item
        FEBE.citem = item
    
        # cell update transformation
        update!(FEBE.L2G, item)
        get_coefficients_on_cell!(FEBE.coefficients, FEBE.FE2, EG, item)

        # use Piola transformation on Hdiv basis
        # and save it in refoperatorvals
        for i = 1 : length(FEBE.xref)
            # evaluate Piola matrix at quadrature point
            if FEBE.L2G.nonlinear || i == 1
                FEBE.iteminfo[1] = piola!(FEBE.L2GM,FEBE.L2G,FEBE.xref[i])
            end
            for dof_i = 1 : size(FEBE.refoperatorvals,2) # ndofs4item (Hdiv)
                for k = 1 : FEBE.offsets[2] # ncomponents
                    FEBE.refoperatorvals[k,dof_i,i] = 0.0;
                    for l = 1 : FEBE.offsets[2] # ncomponents
                        FEBE.refoperatorvals[k,dof_i,i] += FEBE.L2GM[k,l]*FEBE.refbasisvals[l,dof_i,i];
                    end    
                    FEBE.refoperatorvals[k,dof_i,i] *= FEBE.coefficients[k,dof_i] / FEBE.iteminfo[1]
                end
            end
        end

        # get local reconstruction coefficients
        # and accumulate
        get_reconstruction_coefficients_on_cell!(FEBE.coefficients2, FEBE.FE, eltype(FEBE.FE2), EG, item)

        fill!(FEBE.cvals,0.0)
        for i = 1 : length(FEBE.xref)
            for dof_i = 1 : size(FEBE.cvals,2), dof_j = 1 : size(FEBE.refoperatorvals,2) # ndofs4item (Hdiv)
                if FEBE.coefficients2[dof_i,dof_j] != 0
                    for k = 1 : FEBE.offsets[2] # ncomponents
                        FEBE.cvals[k,dof_i,i] += FEBE.coefficients2[dof_i,dof_j] * FEBE.refoperatorvals[k,dof_j,i]; 
                    end
                end
            end
        end
    end
end


# IDENTITY OPERATOR
# Hdiv ELEMENTS (Piola trafo)
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,Identity,AT}, item::Int) where {T <: Real, FEType <: AbstractHdivFiniteElement, EG <: AbstractElementGeometry, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item
    
        # cell update transformation
        update!(FEBE.L2G, item)
        get_coefficients_on_cell!(FEBE.coefficients, FEBE.FE, EG, item)

        # use Piola transformation on basisvals
        for i = 1 : length(FEBE.xref)
            # evaluate Piola matrix at quadrature point
            if FEBE.L2G.nonlinear || i == 1
                FEBE.iteminfo[1] = piola!(FEBE.L2GM,FEBE.L2G,FEBE.xref[i])
            end
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                for k = 1 : FEBE.offsets[2] # ncomponents
                    FEBE.cvals[k,dof_i,i] = 0.0;
                    for l = 1 : FEBE.offsets[2] # ncomponents
                        FEBE.cvals[k,dof_i,i] += FEBE.L2GM[k,l]*FEBE.refbasisvals[l,dof_i,i];
                    end    
                    FEBE.cvals[k,dof_i,i] *= FEBE.coefficients[k,dof_i] / FEBE.iteminfo[1]
                end
            end
        end
    end
end


# IDENTITY OPERATOR
# H1 ELEMENTS WITH COEFFICIENTS
# (no transformation needed, just multiply coefficients)
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,Identity,AT}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElementWithCoefficients, EG <: AbstractElementGeometry, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item
        
        # get coefficients
        if AT <: Union{AssemblyTypeBFACE,AssemblyTypeFACE}
            get_coefficients_on_face!(FEBE.coefficients, FEBE.FE, EG, item)
        else
            get_coefficients_on_cell!(FEBE.coefficients, FEBE.FE, EG, item)
        end    


        for i = 1 : length(FEBE.xref)
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                for k = 1 : FEBE.offsets[2] # ncomponents
                    FEBE.cvals[k,dof_i,i] = FEBE.refbasisvals[k,dof_i,i] * FEBE.coefficients[k,dof_i];
                end    
            end
        end
    end
end



# NORMALFLUX OPERATOR
# H1 ELEMENTS
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,NormalFlux,AT}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElement, EG <: AbstractElementGeometry, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item

        # fetch normal of item
        for k = 1 : size(FEBE.coefficients3,1) # ncomponents of normal
            FEBE.iteminfo[k] = FEBE.coefficients3[k,item]
        end

        for i = 1 : length(FEBE.xref)
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                FEBE.cvals[1,dof_i,i] = 0.0
                for k = 1 : size(FEBE.coefficients3,1) # ncomponents of normal
                    FEBE.cvals[1,dof_i,i] += FEBE.refbasisvals[k,dof_i,i] * FEBE.iteminfo[k];
                end    
            end
        end
    end
end

# NORMALFLUX OPERATOR
# H1 ELEMENTS WITH COEFFICIENTS
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,NormalFlux,AT}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElementWithCoefficients, EG <: AbstractElementGeometry, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item

        # fetch normal of item
        for k = 1 : size(FEBE.coefficients3,1) # ncomponents of normal
            FEBE.iteminfo[k] = FEBE.coefficients3[k,item]
        end
        
        # get coefficients
        get_coefficients_on_face!(FEBE.coefficients, FEBE.FE, EG, item)

        for i = 1 : length(FEBE.xref)
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                FEBE.cvals[1,dof_i,i] = 0.0
                for k = 1 : size(FEBE.coefficients3,1) # ncomponents of normal
                    FEBE.cvals[1,dof_i,i] += FEBE.refbasisvals[k,dof_i,i] * FEBE.coefficients[k,dof_i] * FEBE.iteminfo[k];
                end    
            end
        end
    end
end

# NORMALFLUX OPERATOR
# Hdiv ELEMENTS (just divide by face volume)
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,FEOP,AT}, item::Int) where {T <: Real, FEType <: AbstractHdivFiniteElement, EG <: AbstractElementGeometry, FEOP <: NormalFlux, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item
    
        # use Piola transformation on basisvals
        for i = 1 : length(FEBE.xref)
            for dof_i = 1 : FEBE.offsets2[2], k = 1 : FEBE.offsets[2] # ncomponents
                FEBE.cvals[k,dof_i,i] = FEBE.refbasisvals[k,dof_i,i] / FEBE.L2G.ItemVolumes[item]
            end
        end
    end
end


# GRADIENT OPERATOR
# H1 ELEMENTS
# multiply tinverted jacobian of element trafo with gradient of basis function
# which yields (by chain rule) the gradient in x coordinates
#
# Note: for e.g. EDGE1D/CARTESIAN2D the tangentialderivative is produced,
#       i.e. the surface derivative in general
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,FEOP}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElement, EG <: AbstractElementGeometry, FEOP <: Gradient, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item

        # update L2G (we need the matrix)
        update!(FEBE.L2G, item)

        for i = 1 : length(FEBE.xref)
            if FEBE.L2G.nonlinear || i == 1
                mapderiv!(FEBE.L2GM,FEBE.L2G,FEBE.xref[i])
            end
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                for c = 1 : FEBE.ncomponents, k = 1 : FEBE.offsets[2] # xdim
                    FEBE.cvals[k + FEBE.offsets[c],dof_i,i] = 0.0;
                    for j = 1 : FEBE.offsets[2] # xdim
                        # compute duc/dxk
                        FEBE.cvals[k + FEBE.offsets[c],dof_i,i] += FEBE.L2GM[k,j]*FEBE.refoperatorvals[dof_i + FEBE.offsets2[c],j,i]
                    end    
                end    
            end    
        end  
    end    
end


# TANGENTGRADIENT OPERATOR
# H1 ELEMENTS
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,FEOP}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElement, EG <: AbstractElementGeometry, FEOP <: TangentialGradient, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item

        # update L2G (we need the matrix)
        update!(FEBE.L2G, item)

        # compute tangent of item
        FEBE.iteminfo[1] = FEBE.coefficients3[2,item]
        FEBE.iteminfo[2] = -FEBE.coefficients3[1,item]

        for i = 1 : length(FEBE.xref)
            if FEBE.L2G.nonlinear || i == 1
                mapderiv!(FEBE.L2GM,FEBE.L2G,FEBE.xref[i])
            end
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                for c = 1 : FEBE.ncomponents, k = 1 : FEBE.offsets[2] # xdim
                    FEBE.cvals[k + FEBE.offsets[c],dof_i,i] = 0.0;
                    for j = 1 : FEBE.offsets[2] # xdim
                        # compute duc/dxk
                        FEBE.cvals[1,dof_i,i] += FEBE.L2GM[k,j]*FEBE.refoperatorvals[dof_i + FEBE.offsets2[c],j,i] * FEBE.iteminfo[c]
                    end    
                end    
            end    
        end  
    end    
end


# SYMMETRIC GRADIENT OPERATOR
# H1 ELEMENTS
# multiply tinverted jacobian of element trafo with gradient of basis function
# which yields (by chain rule) the gradient in x coordinates
# symmetric gradients are saved in reduced Voigt notation
# the following mapping tells where each entry of the full gradient lands in the reduced vector
voigt_mapper = Array{Array{Int64,1},1}(undef,3)
voigt_mapper[1] = [1,1]
voigt_mapper[2] = [1,3,3,2]
voigt_mapper[3] = [1,4,5,4,2,6,5,6,3]

function update!(FEBE::FEBasisEvaluator{T,FEType,EG,FEOP}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElement, EG <: AbstractElementGeometry, FEOP <: SymmetricGradient, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item

        # update L2G (we need the matrix)
        update!(FEBE.L2G, item)

        fill!(FEBE.cvals,0.0)
        for i = 1 : length(FEBE.xref)
            if FEBE.L2G.nonlinear || i == 1
                mapderiv!(FEBE.L2GM,FEBE.L2G,FEBE.xref[i])
            end
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                for c = 1 : FEBE.ncomponents, k = 1 : FEBE.offsets[2] # xdim
                    for j = 1 : FEBE.offsets[2] # xdim
                        # compute duc/dxk
                        FEBE.cvals[voigt_mapper[dim_element(EG)][k + FEBE.offsets[c]],dof_i,i] += FEBE.L2GM[k,j]*FEBE.refoperatorvals[dof_i + FEBE.offsets2[c],j,i]
                    end    
                end    
            end    
        end  
    end    
end


# GRADIENT OPERATOR
# H1 ELEMENTS WITH COEFFICIENTS
# multiply tinverted jacobian of element trafo with gradient of basis function
# which yields (by chain rule) the gradient in x coordinates
#
# Note: for e.g. EDGE1D/CARTESIAN2D the tangentialderivative is produced,
#       i.e. the surface derivative in general
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,FEOP,AT}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElementWithCoefficients, EG <: AbstractElementGeometry, FEOP <: Gradient, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item

        # update L2G (we need the matrix)
        update!(FEBE.L2G, item)

        # get coefficients
        if AT <: Union{AssemblyTypeBFACE,AssemblyTypeFACE}
            get_coefficients_on_face!(FEBE.coefficients, FEBE.FE, EG, item)
        else
            get_coefficients_on_cell!(FEBE.coefficients, FEBE.FE, EG, item)
        end    

        for i = 1 : length(FEBE.xref)
            if FEBE.L2G.nonlinear || i == 1
                mapderiv!(FEBE.L2GM,FEBE.L2G,FEBE.xref[i])
            end
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                for c = 1 : FEBE.ncomponents, k = 1 : FEBE.offsets[2] # xdim
                    FEBE.cvals[k + FEBE.offsets[c],dof_i,i] = 0.0;
                    for j = 1 : FEBE.offsets[2] # xdim
                        # compute duc/dxk
                        FEBE.cvals[k + FEBE.offsets[c],dof_i,i] += FEBE.L2GM[k,j]*FEBE.refoperatorvals[dof_i + FEBE.offsets2[c],j,i]
                    end    
                    FEBE.cvals[k + FEBE.offsets[c], dof_i,i] *= FEBE.coefficients[c, dof_i]
                end    
            end    
        end  
    end    
end

# DIVERGENCE OPERATOR
# H1 ELEMENTS
# multiply tinverted jacobian of element trafo with gradient of basis function
# which yields (by chain rule) the gradient in x coordinates
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,Divergence}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElement, EG <: AbstractElementGeometry, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item

        # update L2G (we need the matrix)
        update!(FEBE.L2G, item)

        for i = 1 : length(FEBE.xref)
            if FEBE.L2G.nonlinear || i == 1
                mapderiv!(FEBE.L2GM,FEBE.L2G,FEBE.xref[i])
            end
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                FEBE.cvals[1,dof_i,i] = 0.0;
                for k = 1 : FEBE.offsets[2] # xdim
                    for j = 1 : FEBE.offsets[2] # xdim
                        # compute duk/dxk
                        FEBE.cvals[1,dof_i,i] += FEBE.L2GM[k,j]*FEBE.refoperatorvals[dof_i + FEBE.offsets2[k],j,i]
                    end    
                end    
            end    
        end  
    end    
end

# DIVERGENCE OPERATOR
# H1 ELEMENTS WITH COEFFICIENTS
# multiply tinverted jacobian of element trafo with gradient of basis function
# which yields (by chain rule) the gradient in x coordinates
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,Divergence,AT}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElementWithCoefficients, EG <: AbstractElementGeometry, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item

        # update L2G (we need the matrix)
        update!(FEBE.L2G, item)

        # get coefficients
        if AT <: Union{AssemblyTypeBFACE,AssemblyTypeFACE}
            get_coefficients_on_face!(FEBE.coefficients, FEBE.FE, EG, item)
        else
            get_coefficients_on_cell!(FEBE.coefficients, FEBE.FE, EG, item)
        end    

        for i = 1 : length(FEBE.xref)
            if FEBE.L2G.nonlinear || i == 1
                mapderiv!(FEBE.L2GM,FEBE.L2G,FEBE.xref[i])
            end
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                FEBE.cvals[1,dof_i,i] = 0.0;
                for k = 1 : FEBE.offsets[2] # xdim
                    for j = 1 : FEBE.offsets[2] # xdim
                        # compute duk/dxk
                        FEBE.cvals[1,dof_i,i] += FEBE.L2GM[k,j]*FEBE.refoperatorvals[dof_i + FEBE.offsets2[k],j,i] * FEBE.coefficients[k, dof_i]
                    end    
                end    
            end    
        end  
    end    
end


# RECONSTRUCTION DIVERGENCE OPERATOR
# H1 ELEMENTS
# HDIV RECONSTRUCTION
# Piola transform Hdiv reference basis and multiply Hdiv coefficients and Trafo coefficients
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,FEOP,AT}, item::Int) where {T <: Real, FEType <: AbstractH1FiniteElement, EG <: AbstractElementGeometry, AT <:AbstractAssemblyType, FETypeReconst <: AbstractFiniteElement, FEOP <: ReconstructionDivergence{FETypeReconst}}
    if FEBE.citem != item
        FEBE.citem = item
    
        # cell update transformation
        update!(FEBE.L2G, item)
        get_coefficients_on_cell!(FEBE.coefficients, FEBE.FE2, EG, item)

        # get local reconstruction coefficients
        get_reconstruction_coefficients_on_cell!(FEBE.coefficients2, FEBE.FE, eltype(FEBE.FE2), EG, item)

        # use Piola transformation on Hdiv basis
        # and accumulate according to reconstruction coefficients
        fill!(FEBE.cvals,0.0)
        for i = 1 : length(FEBE.xref)
            # evaluate Piola matrix at quadrature point
            if FEBE.L2G.nonlinear || i == 1
                FEBE.iteminfo[1] = piola!(FEBE.L2GM,FEBE.L2G,FEBE.xref[i])
            end
            for dof_i = 1 : size(FEBE.cvals,2) # ndofs4item (H1)
                for dof_j = 1 : FEBE.offsets2[2] # ndofs4item (Hdiv)
                    if FEBE.coefficients2[dof_i,dof_j] != 0
                        for j = 1 : FEBE.offsets[2] # xdim
                            FEBE.cvals[1,dof_i,i] += FEBE.coefficients2[dof_i,dof_j] * FEBE.refoperatorvals[dof_j + FEBE.offsets2[j],j,i] * FEBE.coefficients[1,dof_j]/FEBE.iteminfo[1]
                        end  
                    end
                end
            end
        end  

    end
end



# DIVERGENCE OPERATOR
# HDIV ELEMENTS
# Piola transformation preserves divergence (up to a factor 1/det(A))
function update!(FEBE::FEBasisEvaluator{T,FEType,EG,Divergence}, item::Int) where {T <: Real, FEType <: AbstractHdivFiniteElement, EG <: AbstractElementGeometry, AT <:AbstractAssemblyType}
    if FEBE.citem != item
        FEBE.citem = item
        
        # cell update transformation
        update!(FEBE.L2G, item)
        get_coefficients_on_cell!(FEBE.coefficients, FEBE.FE, EG, item)

        # use Piola transformation on basisvals
        for i = 1 : length(FEBE.xref)
            # evaluate Piola matrix at quadrature point
            if FEBE.L2G.nonlinear || i == 1
                FEBE.iteminfo[1] = piola!(FEBE.L2GM,FEBE.L2G,FEBE.xref[i])
            end
            for dof_i = 1 : FEBE.offsets2[2] # ndofs4item
                FEBE.cvals[1,dof_i,i] = 0.0;
                for j = 1 : FEBE.offsets[2] # xdim
                    FEBE.cvals[1,dof_i,i] += FEBE.refoperatorvals[dof_i + FEBE.offsets2[j],j,i]
                end  
                FEBE.cvals[1,dof_i,i] *= FEBE.coefficients[1,dof_i]/FEBE.iteminfo[1];
            end
        end    
    end  
end