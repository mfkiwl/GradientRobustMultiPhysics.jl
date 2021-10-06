"""
````
abstract type HDIVRT0{edim} <: AbstractHdivFiniteElement where {edim<:Int}
````

Hdiv-conforming vector-valued (ncomponents = edim) lowest-order Raviart-Thomas space.

allowed ElementGeometries:
- Triangle2D
- Quadrilateral2D
- Tetrahedron3D
- Hexahedron3D
"""
abstract type HDIVRT0{edim} <: AbstractHdivFiniteElement where {edim<:Int} end

function Base.show(io::Core.IO, FEType::Type{<:HDIVRT0{edim}}) where {edim}
    print(io,"HDIVRT0{$edim}")
end

get_ncomponents(FEType::Type{<:HDIVRT0}) = FEType.parameters[1]
get_ndofs(::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, FEType::Type{<:HDIVRT0}, EG::Type{<:AbstractElementGeometry}) = 1
get_ndofs(::Type{ON_CELLS}, FEType::Type{<:HDIVRT0}, EG::Type{<:AbstractElementGeometry}) = num_faces(EG)

get_polynomialorder(::Type{<:HDIVRT0{2}}, ::Type{<:AbstractElementGeometry1D}) = 0;
get_polynomialorder(::Type{<:HDIVRT0{2}}, ::Type{<:AbstractElementGeometry2D}) = 1;
get_polynomialorder(::Type{<:HDIVRT0{3}}, ::Type{<:AbstractElementGeometry2D}) = 0;
get_polynomialorder(::Type{<:HDIVRT0{3}}, ::Type{<:AbstractElementGeometry3D}) = 1;

get_dofmap_pattern(FEType::Type{<:HDIVRT0}, ::Type{CellDofs}, EG::Type{<:AbstractElementGeometry}) = "f1"
get_dofmap_pattern(FEType::Type{<:HDIVRT0}, ::Type{FaceDofs}, EG::Type{<:AbstractElementGeometry}) = "i1"
get_dofmap_pattern(FEType::Type{<:HDIVRT0}, ::Type{BFaceDofs}, EG::Type{<:AbstractElementGeometry}) = "i1"

isdefined(FEType::Type{<:HDIVRT0}, ::Type{<:Triangle2D}) = true
isdefined(FEType::Type{<:HDIVRT0}, ::Type{<:Quadrilateral2D}) = true
isdefined(FEType::Type{<:HDIVRT0}, ::Type{<:Tetrahedron3D}) = true
isdefined(FEType::Type{<:HDIVRT0}, ::Type{<:Hexahedron3D}) = true

function interpolate!(Target::AbstractArray{T,1}, FE::FESpace{Tv,Ti,FEType,APT}, ::Type{ON_FACES}, exact_function!; items = [], time=  0) where {T,Tv,Ti,FEType <: HDIVRT0,APT}
    ncomponents = get_ncomponents(FEType)
    if items == []
        items = 1 : num_sources(FE.xgrid[FaceNodes])
    end

    # compute exact face means
    xFaceNormals::Array{Tv,2} = FE.xgrid[FaceNormals]
    function normalflux_eval()
        temp = zeros(T,ncomponents)
        function closure(result, x, face)
            eval_data!(temp, exact_function!, x, time) 
            result[1] = 0.0
            for j = 1 : ncomponents
                result[1] += temp[j] * xFaceNormals[j,face]
            end 
        end   
    end   
    edata_function = ExtendedDataFunction(normalflux_eval(), [1, ncomponents]; dependencies = "XI", quadorder = exact_function!.quadorder)
    integrate!(Target, FE.xgrid, ON_FACES, edata_function; items = items, time = time)
end

function interpolate!(Target::AbstractArray{<:Real,1}, FE::FESpace{Tv,Ti,FEType,APT}, ::Type{ON_CELLS}, exact_function!; items = [], time = 0) where {Tv,Ti,FEType <: HDIVRT0,APT}
    # delegate cell faces to face interpolation
    subitems = slice(FE.xgrid[CellFaces], items)
    interpolate!(Target, FE, ON_FACES, exact_function!; items = subitems, time = time)
end

# only normalfluxes on faces
function get_basis(::Union{Type{<:ON_FACES}, Type{<:ON_BFACES}}, ::Type{<:HDIVRT0}, ::Type{<:AbstractElementGeometry})
    function closure(refbasis, xref)
        refbasis[1,1] = 1
    end
end

function get_basis(::Type{ON_CELLS}, ::Type{HDIVRT0{2}}, ::Type{<:Triangle2D})
    function closure(refbasis, xref)
        refbasis[1,:] .= [xref[1], xref[2]-1]
        refbasis[2,:] .= [xref[1], xref[2]]
        refbasis[3,:] .= [xref[1]-1, xref[2]]
    end
end

function get_basis(::Type{ON_CELLS}, ::Type{HDIVRT0{2}}, ::Type{<:Quadrilateral2D})
    function closure(refbasis, xref)
        refbasis[1,:] .= [0, xref[2]-1]
        refbasis[2,:] .= [xref[1], 0]
        refbasis[3,:] .= [0, xref[2]]
        refbasis[4,:] .= [xref[1]-1, 0]
    end
end

function get_basis(::Type{ON_CELLS}, ::Type{HDIVRT0{3}}, ::Type{<:Tetrahedron3D})
    function closure(refbasis, xref)
        refbasis[1,:] .= 2*[xref[1], xref[2], xref[3]-1]
        refbasis[2,:] .= 2*[xref[1], xref[2]-1, xref[3]]
        refbasis[3,:] .= 2*[xref[1], xref[2], xref[3]]
        refbasis[4,:] .= 2*[xref[1]-1, xref[2], xref[3]]
    end
    # note: factor 2 is chosen, such that normal-flux integrated over faces is 1 again
end

function get_basis(::Type{ON_CELLS}, ::Type{HDIVRT0{3}}, ::Type{<:Hexahedron3D})
    function closure(refbasis, xref)
        refbasis[1,:] .= [0, 0, xref[3]-1]
        refbasis[2,:] .= [0, xref[2]-1, 0]
        refbasis[3,:] .= [xref[1], 0, 0]
        refbasis[4,:] .= [0, xref[2], 0]
        refbasis[5,:] .= [xref[1]-1, 0, 0]
        refbasis[6,:] .= [0, 0, xref[3]]
    end
end

function get_coefficients(::Type{ON_CELLS}, FE::FESpace{Tv,Ti,<:HDIVRT0,APT}, EG::Type{<:AbstractElementGeometry}) where {Tv,Ti,APT}
    xCellFaceSigns = FE.xgrid[CellFaceSigns]
    nfaces = num_faces(EG)
    function closure(coefficients, cell)
        # multiplication with normal vector signs
        for j = 1 : nfaces,  k = 1 : size(coefficients,1)
            coefficients[k,j] = xCellFaceSigns[j,cell];
        end
        return nothing
    end
end    
