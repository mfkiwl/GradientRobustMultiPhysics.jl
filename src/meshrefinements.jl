
# functions that tell how to split one ElementGeometry into another
split_rule(::Type{Triangle2D}, ::Type{Triangle2D}) = reshape([1,2,3],1,3)
split_rule(::Type{<:Quadrilateral2D}, ::Type{Triangle2D}) = [1 2 3;1 3 4]
split_rule(::Type{Edge1D}, ::Type{Triangle2D}) = reshape([1,2,2],1,3)

"""
$(TYPEDSIGNATURES)

generates a new ExtendableGrid by splitting each cell into subcells of the specified targetgeometry

split rules exist for
    - Quadrilateral2D into Triangle2D
"""
function split_grid_into(source_grid::ExtendableGrid{T,K}, targetgeometry::Type{Triangle2D}) where {T,K}
    xgrid=ExtendableGrid{T,K}()
    xgrid[Coordinates]=source_grid[Coordinates]
    oldCellGeometries = source_grid[CellGeometries]
    EG = Base.unique(oldCellGeometries)
    
    split_rules = Array{Array{Int,2},1}(undef,length(EG))
    for j = 1 : length(EG)
        split_rules[j] = split_rule(EG[j],targetgeometry)
    end
    xCellNodes=[]
    oldCellNodes=source_grid[CellNodes]
    nnodes4item = 0
    ncells = 0
    itemEG = Triangle2D
    iEG = 1
    for cell = 1 : num_sources(oldCellNodes)
        nnodes4item = num_targets(oldCellNodes,cell)
        itemEG = oldCellGeometries[cell]
        iEG = findfirst(isequal(itemEG), EG)
        for j = 1 : size(split_rules[iEG],1), k = 1 : size(split_rules[iEG],2)
            append!(xCellNodes,oldCellNodes[split_rules[iEG][j,k],cell])
        end    
        ncells += size(split_rules[iEG],1)
    end
    xCellNodes = reshape(xCellNodes,3,ncells)
    xgrid[CellNodes] = Array{Int32,2}(xCellNodes)
    xgrid[CellGeometries] = VectorOfConstants(Triangle2D,ncells)
    xgrid[CellRegions]=ones(Int32,ncells)
    xgrid[BFaceNodes]=source_grid[BFaceNodes]
    xgrid[BFaceRegions]=source_grid[BFaceRegions]
    xgrid[BFaceGeometries]=VectorOfConstants(Edge1D,num_sources(source_grid[BFaceNodes]))
    xgrid[CoordinateSystem]=source_grid[CoordinateSystem]
    return xgrid
end


uniform_refine_needfacemidpoints(::Type{<:AbstractElementGeometry}) = true
uniform_refine_needcellmidpoints(::Type{<:AbstractElementGeometry}) = false

# uniform refinement rules in 1D
# first k nodes are the CellNodes
# next node is the CellMidpoint
uniform_refine_rule(::Type{<:Edge1D}) = [1 3; 3 2]
uniform_refine_needcellmidpoints(::Type{<:Edge1D}) = true

# uniform refinement rules in 2D
# first k nodes are the CellNodes
# next m nodes are the CellFaces midpoints
# next node is the CellMidpoint (if needed)
uniform_refine_rule(::Type{<:Triangle2D}) = [1 4 6; 2 5 4; 3 6 5; 4 5 6]
uniform_refine_rule(::Type{<:Quadrilateral2D}) = [1 5 9 8; 2 6 9 5; 3 7 9 6; 4 8 9 7]
uniform_refine_needcellmidpoints(::Type{<:Quadrilateral2D}) = true

# uniform refinement rules in 3D
# first k nodes are the CellNodes
# next m nodes are the CellEdges midpoints
# next n nodes are the CellFaces midpoints
# next node is the CellMidpoint (if needed)
uniform_refine_rule(::Type{<:Tetrahedron3D}) = [ 1 5 6 7;
                                                 2 8 5 9;
                                                 3 6 8 10;
                                                 4 10 9 7;
                                                 5 9 6 7;
                                                 5 9 8 6;
                                                 6 9 10 7;
                                                 6 9 8 10]
uniform_refine_needfacemidpoints(::Type{<:Tetrahedron3D}) = false
uniform_refine_rule(::Type{<:Hexahedron3D}) = [ 1 9 10 11 21 22 25 27; 
                                                    9 2 21 22 12 13 27 23;
                                                    10 21 3 25 14 27 15 24; 
                                                    21 12 14 27 5 23 24 18; 
                                                    11 22 25 4 27 16 17 26; 
                                                    22 13 27 16 23 6 26 19; 
                                                    25 27 15 17 24 26 7 20; 
                                                    27 23 24 26 18 19 20 8]
uniform_refine_needcellmidpoints(::Type{<:Hexahedron3D}) = true


"""
$(TYPEDSIGNATURES)

generates a new ExtendableGrid by uniform refinement of each cell in the given grid

uniform refinement rules are available for these AbstractElementGeometries:
    - Line1D (bisection into two subsegments)
    - Triangle2D (red refinement into four subtriangles)
    - Quadrilateral2D (into four subquadrilaterals)
    - Tetrahedron (into eight subtetrahedrons)
    - Hexahedron (into eight subhexahedrons)

if multiple geometries are in the mesh uniform refinement will only work
if all refinement rules refine faces and edges (in 3D) equally
(so no hanging nodes are created)
"""
function uniform_refine(source_grid::ExtendableGrid{T,K}) where {T,K}
    xgrid = ExtendableGrid{T,K}()
    xgrid[CoordinateSystem]=source_grid[CoordinateSystem]

    # unpack stuff from source grid
    oldCoordinates = source_grid[Coordinates]
    oldCellGeometries = source_grid[CellGeometries]
    EG = Base.unique(oldCellGeometries)

    # get dimension of CellGeometries
    # currently it is assumed to be the same for all cells
    dim = dim_element(EG[1]) 
    
    refine_rules = Array{Array{Int,2},1}(undef,length(EG))
    need_facemidpoints = uniform_refine_needfacemidpoints(EG[1])
    for j = 1 : length(EG)
        refine_rules[j] = uniform_refine_rule(EG[j])
        @assert uniform_refine_needfacemidpoints(EG[j]) == need_facemidpoints
    end
    xCellNodes = VariableTargetAdjacency(Int32)
    xCellGeometries = []
    oldCellNodes = source_grid[CellNodes]
    oldCellFaces = source_grid[CellFaces]
    oldCellEdges = []
    nfaces = 0
    if dim > 1
        oldFaceNodes = source_grid[FaceNodes]
        nfaces = num_sources(oldFaceNodes)
    end
    nedges = 0
    if dim > 2 
        oldEdgeNodes = source_grid[EdgeNodes]
        nedges = num_sources(oldEdgeNodes)
        oldCellEdges = source_grid[CellEdges]
    end


    # determine number of new vertices
    itemEG = Triangle2D
    newvertices = 0 # in 1D no additional vertices on the faces are needed
    if dim == 2 # in 2D each face is halved
        newvertices = nfaces
    elseif dim == 3 # in 2D each face and edge is halved
        newvertices = nedges
        if need_facemidpoints 
            newvertices += nfaces
        end
    end
    oldvertices = size(oldCoordinates,2)
    newnode = oldvertices + newvertices
    # additionally cell midpoints are needed for some refinements
    for cell = 1 : num_sources(oldCellNodes)
        itemEG = oldCellGeometries[cell]
        if uniform_refine_needcellmidpoints(itemEG) == true
            newvertices += 1
        end    
    end
    xCoordinates = zeros(Float64,size(oldCoordinates,1),oldvertices+newvertices)
    @views xCoordinates[:,1:oldvertices] = oldCoordinates

    
    newvertex = zeros(Float64,size(xCoordinates,1))
    nnodes4item = 0
    if dim > 2 # add edge midpoints to Coordinates
        for edge = 1 : nedges
            nnodes4item = num_targets(oldEdgeNodes,edge)
            fill!(newvertex,0.0)
            for k = 1 : nnodes4item, d = 1 : size(xCoordinates,1)
                newvertex[d] += xCoordinates[d,oldEdgeNodes[k,edge]] 
            end    
            newvertex ./= nnodes4item
            for d = 1 : size(xCoordinates,1)
                xCoordinates[d,oldvertices+edge] = newvertex[d]
            end
        end    
    end
    if dim > 1 && need_facemidpoints 
        # add face midpoints to Coordinates
        for face = 1 : nfaces
            nnodes4item = num_targets(oldFaceNodes,face)
            fill!(newvertex,0.0)
            for k = 1 : nnodes4item, d = 1 : size(xCoordinates,1)
                newvertex[d] += xCoordinates[d,oldFaceNodes[k,face]] 
            end    
            newvertex ./= nnodes4item
            for d = 1 : size(xCoordinates,1)
                xCoordinates[d,oldvertices+nedges+face] = newvertex[d]
            end
        end    
    end
    
    # determine new cells
    nnodes4item = 0
    nfaces4item = 0
    nedges4item = 0
    ncells = 0
    iEG = 1
    subitemnodes = zeros(Int32,max_num_targets_per_source(oldCellNodes)+max_num_targets_per_source(oldCellFaces)+1)
    m = 0
    for cell = 1 : num_sources(oldCellNodes)
        itemEG = oldCellGeometries[cell]
        nnodes4item = nnodes_for_geometry(itemEG)
        nfaces4item = nfaces_for_geometry(itemEG)
        nedges4item = nedges_for_geometry(itemEG)
        iEG = findfirst(isequal(itemEG), EG)
        if uniform_refine_needcellmidpoints(itemEG) == true
            # add cell midpoint to Coordinates
            newnode += 1
            fill!(newvertex,0.0)
            for k = 1 : nnodes4item, d = 1 : size(xCoordinates,1)
                newvertex[d] += xCoordinates[d,oldCellNodes[k,cell]] 
            end    
            newvertex ./= nnodes4item
            for d = 1 : size(xCoordinates,1)
                xCoordinates[d,newnode] = newvertex[d]
            end
        end
        for j = 1 : size(refine_rules[iEG],1)
            for k = 1 : size(refine_rules[iEG],2)
                m = refine_rules[iEG][j,k]
                if dim == 1
                    if m <= nnodes4item 
                        subitemnodes[k] = oldCellNodes[m,cell]
                    else
                        subitemnodes[k] = newnode
                    end
                elseif dim == 2
                    if m <= nnodes4item 
                        subitemnodes[k] = oldCellNodes[m,cell]
                    elseif m <= nnodes4item + nfaces4item
                        subitemnodes[k] = oldvertices + oldCellFaces[m-nnodes4item,cell]
                    else
                        subitemnodes[k] = newnode
                    end        
                elseif dim == 3
                    if m <= nnodes4item 
                        subitemnodes[k] = oldCellNodes[m,cell]
                    elseif m <= nnodes4item + nedges4item
                        subitemnodes[k] = oldvertices + oldCellEdges[m-nnodes4item,cell]
                    elseif m <= nnodes4item + nedges4item + nfaces4item
                        subitemnodes[k] = oldvertices + nedges + oldCellFaces[m-nnodes4item-nedges4item,cell]
                    else
                        subitemnodes[k] = newnode
                    end        
                end
            end    
            append!(xCellNodes,subitemnodes[1:size(refine_rules[iEG],2)])
            push!(xCellGeometries,itemEG)
        end    
        ncells += size(refine_rules[iEG],1)
    end

    # assign new cells to grid
    xgrid[Coordinates] = xCoordinates
    if typeof(oldCellNodes) == Array{Int32,2}
        nnodes4item = size(oldCellNodes,1)
        xgrid[CellNodes] = reshape(xCellNodes.colentries,nnodes4item,num_sources(xCellNodes))
    else
        xgrid[CellNodes] = xCellNodes
    end
    xgrid[CellRegions]=VectorOfConstants{Int32}(1,ncells)
    xgrid[CellGeometries] = Array{DataType,1}(xCellGeometries)


    # determine new boundary faces
    oldBFaceNodes = source_grid[BFaceNodes]
    oldBFaces = source_grid[BFaces]
    oldBFaceRegions = source_grid[BFaceRegions]
    oldBFaceGeometries = source_grid[BFaceGeometries]
    oldBFacesCellPos = source_grid[BFaceCellPos]
    oldFaceCells = source_grid[FaceCells]
    
    if dim == 1
        xgrid[BFaceNodes] = oldBFaceNodes
        xgrid[BFaceRegions] = oldBFaceRegions
        xgrid[BFaceGeometries] = oldBFaceGeometries
    else
        xBFaceRegions = zeros(Int32,0)
        xBFaceGeometries = []
        nbfaces = num_sources(oldBFaceNodes)
        if dim == 2
            xBFaceNodes = []
        else
            xBFaceNodes = VariableTargetAdjacency(Int32)
        end
        if dim == 3
            xCellEdges = source_grid[CellEdges]
            xNodeEdges = atranspose(oldEdgeNodes)
        else
            xCellEdges = []
        end

        EG = Base.unique(oldBFaceGeometries)

        refine_rules = Array{Array{Int,2},1}(undef,length(EG))
        for j = 1 : length(EG)
            refine_rules[j] = uniform_refine_rule(EG[j])
        end


        bcell = 0
        edge = 0
        for bface = 1 : nbfaces
            face = oldBFaces[bface]
            itemEG = oldBFaceGeometries[bface]
            nnodes4item = nnodes_for_geometry(itemEG)
            nfaces4item = nfaces_for_geometry(itemEG)
            iEG = findfirst(isequal(itemEG), EG)
            bface_enum_rule = face_enum_rule(itemEG)

            for j = 1 : size(refine_rules[iEG],1)
                for k = 1 : size(refine_rules[iEG],2)
                    m = refine_rules[iEG][j,k]
                    if dim == 2
                        if m <= nnodes4item 
                            subitemnodes[k] = oldBFaceNodes[m,bface]
                        else
                            subitemnodes[k] = oldvertices + face
                        end        
                    elseif dim == 3
                        if m <= nnodes4item 
                            subitemnodes[k] = oldBFaceNodes[m,bface]
                        elseif m <= nnodes4item + nfaces4item
                            edge = m-nnodes4item # local number
                            # find global edge number
                            edge = intersect(xNodeEdges[:,oldBFaceNodes[bface_enum_rule[edge,1],bface]],xNodeEdges[:,oldBFaceNodes[bface_enum_rule[edge,2],bface]])[1]
                            subitemnodes[k] = oldvertices + edge
                        else
                            subitemnodes[k] = oldvertices + nedges + face
                        end        
                    end
                end
                append!(xBFaceNodes,subitemnodes[1:size(refine_rules[iEG],2)])
                push!(xBFaceGeometries,itemEG)
                push!(xBFaceRegions,oldBFaceRegions[bface])
            end    
        end
        if dim == 2 # plotter needs Array which is ok in 2D as there can only be Edge1D boundary faces
            xgrid[BFaceNodes] = Array{Int32,2}(reshape(xBFaceNodes,(2,nbfaces*2)))
        else
            xgrid[BFaceNodes] = xBFaceNodes
        end
        xgrid[BFaceRegions] = xBFaceRegions
        xgrid[BFaceGeometries] = Array{DataType,1}(xBFaceGeometries)
    end    


    return xgrid
end


# barycentric refinement rules
# first k nodes are the CellNodes, k+1-th  node is cell midpoint
barycentric_refine_rule(::Type{<:Triangle2D}) = [1 2 4; 2 3 4; 3 1 4]


"""
$(TYPEDSIGNATURES)

generates a new ExtendableGrid by barycentric refinement of each cell in the source grid

barcentric refinement is available for these ElementGeometries
    - Quadrilateral2D (first split into Triangle2D)
    - Triangle2D
"""
function barycentric_refine(source_grid::ExtendableGrid{T,K}) where {T,K}
    # split first into triangles
    source_grid = split_grid_into(source_grid,Triangle2D)

    xgrid = ExtendableGrid{T,K}()
    oldCoordinates = source_grid[Coordinates]
    oldCellGeometries = source_grid[CellGeometries]
    EG = Base.unique(oldCellGeometries)
    
    refine_rules = Array{Array{Int,2},1}(undef,length(EG))
    for j = 1 : length(EG)
        refine_rules[j] = barycentric_refine_rule(EG[j])
    end
    xCellNodes = VariableTargetAdjacency(Int32)
    xCellGeometries = []

    oldCellNodes = source_grid[CellNodes]
    oldCellFaces = source_grid[CellFaces]

    # determine number of new vertices
    itemEG = Triangle2D
    newvertices = 0
    for cell = 1 : num_sources(oldCellNodes)
        newvertices += 1
    end
    oldvertices = size(oldCoordinates,2)
    xCoordinates = zeros(Float64,size(oldCoordinates,1),oldvertices+newvertices)
    @views xCoordinates[:,1:oldvertices] = oldCoordinates

    # determine new cells
    nnodes4item = 0
    ncells = 0
    iEG = 1
    subitemnodes = zeros(Int32,max_num_targets_per_source(oldCellNodes)+max_num_targets_per_source(oldCellFaces)+1)
    newnode = oldvertices
    m = 0
    newvertex = zeros(Float64,size(xCoordinates,1))
    for cell = 1 : num_sources(oldCellNodes)
        nnodes4item = num_targets(oldCellNodes,cell)
        nfaces4item = num_targets(oldCellFaces,cell)
        itemEG = oldCellGeometries[cell]
        iEG = findfirst(isequal(itemEG), EG)
        
            # add cell midpoint to Coordinates
            newnode += 1
            fill!(newvertex,0.0)
            for k = 1 : nnodes4item, d = 1 : size(xCoordinates,1)
                newvertex[d] += xCoordinates[d,oldCellNodes[k,cell]] 
            end    
            newvertex ./= nnodes4item
            for d = 1 : size(xCoordinates,1)
                xCoordinates[d,newnode] = newvertex[d]
            end

        for j = 1 : size(refine_rules[iEG],1)
            for k = 1 : size(refine_rules[iEG],2)
                m = refine_rules[iEG][j,k]
                if m <= nnodes4item 
                    subitemnodes[k] = oldCellNodes[m,cell]
                else
                    subitemnodes[k] = newnode
                end        
            end    
            append!(xCellNodes,subitemnodes[1:size(refine_rules[iEG],2)])
            push!(xCellGeometries,itemEG)
        end    
        ncells += size(refine_rules[iEG],1)
    end

    xgrid[Coordinates] = xCoordinates
    if typeof(oldCellNodes) == Array{Int32,2}
        nnodes4item = size(oldCellNodes,1)
        xgrid[CellNodes] = reshape(xCellNodes.colentries,nnodes4item,num_sources(xCellNodes))
    else
        xgrid[CellNodes] = xCellNodes
    end
    xgrid[CellRegions]=VectorOfConstants{Int32}(1,ncells)
    xgrid[CellGeometries] = Array{DataType,1}(xCellGeometries)
    xgrid[BFaceNodes]=source_grid[BFaceNodes]
    xgrid[BFaceRegions]=source_grid[BFaceRegions]
    xgrid[BFaceGeometries]=source_grid[BFaceGeometries]
    xgrid[CoordinateSystem]=source_grid[CoordinateSystem]
    Base.show()
    return xgrid
end