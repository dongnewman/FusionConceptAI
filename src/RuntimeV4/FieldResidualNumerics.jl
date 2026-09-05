using LinearAlgebra
using SparseArrays
using SHA
import FusionConceptAI: canonical_hash, semantic_view
const _FR_TOKEN = Ref{Nothing}(nothing)
const _FR_LITERAL_IDS = ("IDENTITY", "ADD", "SUB", "NEG", "SCALAR_MUL", "SCALAR_DIV", "LAPLACE")
const _FR_LITERAL_MANIFEST_HASHES = (
    ("IDENTITY", Digest256("6b2e8e860b9b279bcea6d018db148d43cbc6e7d135961da9d281a8847521d7cf")),
    ("ADD", Digest256("946ae165180118ba6ae0e0e2eeb21d0f9caafbbd070e17bbae4f66401121f76e")),
    ("SUB", Digest256("04c62613586553c60e3cc9d421cfb5a4031a420557bf40abea68ec412aecac87")),
    ("NEG", Digest256("a22bfd5c1bd8c4f60446355b7703abc8d07fa7387899f1d3dad6cfd890ea96fe")),
    ("SCALAR_MUL", Digest256("f847027543134765163c7077770cce6cd52c0330c2d5b692b41b3086f4a2f939")),
    ("SCALAR_DIV", Digest256("c866f195941558c598ef0a7102eabb725b49d36092b6255c0ec2a4fa6806a5e2")),
    ("LAPLACE", Digest256("fe1130870fe795ea3b48bcc1dca29543d5532ab79d4d3d3d5396957fa690d27a")))
_fr_literal_manifest_hash(id::String) = only(h for (name, h) in _FR_LITERAL_MANIFEST_HASHES if name == id)
field_residual_numerics_source_hash() = Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))

"""Adapt the published G2 FieldGridSpecV4 without redefining that authority type."""
function _fr_grid_coordinates(grid)
    isdefined(@__MODULE__, :FieldGridSpecV4) && grid isa getfield(@__MODULE__, :FieldGridSpecV4) ||
        throw(ArgumentError("grid must be the published G2 FieldGridSpecV4"))
    hasproperty(grid, :axes) || throw(ArgumentError("grid must be the published G2 FieldGridSpecV4"))
    raw = getproperty(grid, :axes)
    raw isa Tuple && length(raw) == 3 || throw(ArgumentError("grid needs three axes"))
    axes = ntuple(i -> Tuple(Float64(x) for x in raw[i]), 3)
    for a in axes
        length(a) in 3:33 || throw(ArgumentError("axis length must be 3:33"))
        all(isfinite, a) && all(a[j+1] > a[j] for j in 1:length(a)-1) ||
            throw(ArgumentError("grid coordinates must be finite and increasing"))
        h = [a[j+1]-a[j] for j in 1:length(a)-1]
        maximum(abs.(h .- h[1])) <= 64eps(maximum(abs.(a))) + eps(Float64) ||
            throw(ArgumentError("grid axis must be uniform"))
    end
    prod(length.(axes)) <= 35937 || throw(ArgumentError("grid is too large"))
    axes
end
_fr_grid_hash(grid) = hasproperty(grid, :grid_hash) ? getproperty(grid, :grid_hash) : canonical_hash(grid)

struct StructuredGridProtocolV4
    discretization::Symbol
    boundary::Symbol
    solver::Symbol
    abs_tol::Float64
    rel_tol::Float64
    max_iterations::Int
    backend_identity::NamedTuple
    protocol_hash::Digest256
    function StructuredGridProtocolV4(discretization::Symbol=:second_order_centered,
                                      boundary::Symbol=:dirichlet_elimination,
                                      solver::Symbol=:julia_sparse_lu;
                                      abs_tol::Real=1e-10, rel_tol::Real=1e-10,
                                      max_iterations::Integer=1)
        discretization === :second_order_centered || throw(ArgumentError("unsupported discretization"))
        boundary === :dirichlet_elimination || throw(ArgumentError("unsupported boundary scheme"))
        solver === :julia_sparse_lu || throw(ArgumentError("unsupported solver"))
        isfinite(abs_tol) && abs_tol > 0 && isfinite(rel_tol) && rel_tol >= 0 ||
            throw(ArgumentError("invalid solver tolerances"))
        max_iterations == 1 || throw(ArgumentError("direct sparse LU requires max_iterations == 1"))
        backend = (julia_version=string(VERSION), sparsearrays_version=string(Base.pkgversion(SparseArrays)),
                   machine=string(Sys.MACHINE), factorization="UMFPACK sparse LU")
        body = (discretization=discretization, boundary=boundary, solver=solver,
                abs_tol=Float64(abs_tol), rel_tol=Float64(rel_tol), max_iterations=Int(max_iterations), backend=backend)
        new(discretization, boundary, solver, Float64(abs_tol), Float64(rel_tol), Int(max_iterations), backend, canonical_hash(body))
    end
end
semantic_view(x::StructuredGridProtocolV4) = (discretization=x.discretization, boundary=x.boundary,
    solver=x.solver, abs_tol=x.abs_tol, rel_tol=x.rel_tol, max_iterations=x.max_iterations, backend_identity=x.backend_identity,
    protocol_hash=x.protocol_hash)
canonical_hash(x::StructuredGridProtocolV4) = x.protocol_hash

struct DiagonalAffineChartGeometryV4
    support::SpatialSupportGeneV1
    chart_ref::ChartRefV1
    factors::NTuple{3,Rational{Int64}}
    offsets::NTuple{3,Rational{Int64}}
    grid::Any
    scale::Float64
    jhat::NTuple{3,Float64}
    ghat::NTuple{3,Float64}
    laplace_weights::NTuple{3,Float64}
    geometry_hash::Digest256
    function DiagonalAffineChartGeometryV4(token::typeof(_FR_TOKEN), args...)
        token === _FR_TOKEN || throw(ArgumentError("sealed field geometry"))
        new(args...)
    end
end

function compile_diagonal_affine_geometry(support::SpatialSupportGeneV1, chart_ref::ChartRefV1,
                                          factors, offsets, grid)
    length(factors) == 3 && length(offsets) == 3 || throw(ArgumentError("affine map needs three factors and offsets"))
    f = ntuple(i -> Rational{Int64}(factors[i]), 3)
    o = ntuple(i -> Rational{Int64}(offsets[i]), 3)
    all(!iszero, f) || throw(ArgumentError("affine factors must be nonzero"))
    chart = only(filter(c -> c.chart_ref == chart_ref, support.charts))
    coordinates = _fr_grid_coordinates(grid)
    for i in 1:3
        lo, hi = chart.chart_bounds[i].interval.lower, chart.chart_bounds[i].interval.upper
        all(q -> lo <= q <= hi, coordinates[i]) || throw(ArgumentError("grid lies outside chart bounds"))
    end
    L = Float64(support.resolution_independent_scale.value)
    j = ntuple(i -> Float64(f[i]), 3); G = ntuple(i -> j[i]^2, 3)
    w = ntuple(i -> 1.0 / (L^2 * Float64(f[i])^2), 3)
    body = (support_hash=canonical_hash(support), chart_ref=chart_ref, factors=f, offsets=o,
            grid_hash=_fr_grid_hash(grid), scale=L, jhat=j, ghat=G, laplace_weights=w)
    DiagonalAffineChartGeometryV4(_FR_TOKEN, support, chart_ref, f, o, grid, L, j, G, w, canonical_hash(body))
end
DiagonalAffineChartGeometryV4(args...) = throw(ArgumentError("field geometry is sealed"))
semantic_view(x::DiagonalAffineChartGeometryV4) = (support_hash=canonical_hash(x.support), chart_ref=x.chart_ref,
    factors=x.factors, offsets=x.offsets, grid_hash=_fr_grid_hash(x.grid), scale=x.scale,
    jhat=x.jhat, ghat=x.ghat, laplace_weights=x.laplace_weights, geometry_hash=x.geometry_hash)
canonical_hash(x::DiagonalAffineChartGeometryV4) = x.geometry_hash

mutable struct _FRExpr
    u::Float64
    src::Vector{Float64}
    c::Float64
    lap::Float64
end
_FRExpr(n::Int) = _FRExpr(0.0, zeros(n), 0.0, 0.0)
_fr_add(a,b) = _FRExpr(a.u+b.u, a.src+b.src, a.c+b.c, a.lap+b.lap)
_fr_scale(a,s) = _FRExpr(a.u*s, a.src*s, a.c*s, a.lap*s)

struct LinearFieldResidualFormV4
    edge_hash::Digest256
    unknown_state_ref::StateGeneRefV1
    source_state_refs::Tuple{Vararg{StateGeneRefV1}}
    residual_state_ref::StateGeneRefV1
    unknown_type::PhysicalType
    source_types::Tuple{Vararg{PhysicalType}}
    residual_type::PhysicalType
    alpha::Float64
    beta::Float64
    source_coefficients::Tuple{Vararg{Float64}}
    constant::Float64
    form_hash::Digest256
    function LinearFieldResidualFormV4(token::typeof(_FR_TOKEN), args...)
        token === _FR_TOKEN || throw(ArgumentError("sealed field residual form"))
        new(args...)
    end
end
semantic_view(x::LinearFieldResidualFormV4) = (edge_hash=x.edge_hash, unknown_state_ref=x.unknown_state_ref,
    source_state_refs=x.source_state_refs, residual_state_ref=x.residual_state_ref, alpha=x.alpha,
    unknown_type=x.unknown_type, source_types=x.source_types, residual_type=x.residual_type,
    beta=x.beta, source_coefficients=x.source_coefficients, constant=x.constant)
canonical_hash(x::LinearFieldResidualFormV4) = x.form_hash

function _fr_expr(program::TypedASTProgramV1, i::Int, input_map::Dict{Int,Int}, nsrc::Int, memo=Dict{Int,_FRExpr}())
    haskey(memo, i) && return memo[i]
    n = program.nodes[i]
    out = if n isa ASTInputV1
        pos = get(input_map, n.port, 0); pos > 0 || throw(ArgumentError("unbound AST input port"))
        x = _FRExpr(nsrc); pos == 1 ? (x.u=1.0) : (x.src[pos-1]=1.0); x
    elseif n isa ASTConstantV1
        n.value isa Real && isfinite(Float64(n.value)) || throw(ArgumentError("constant is not finite scalar"))
        x = _FRExpr(nsrc); x.c=Float64(n.value); x
    elseif n isa ASTParameterV1
        throw(ArgumentError("deferred: ASTParameter is unsupported"))
    elseif n isa ASTApplyV1
        args = [_fr_expr(program, j, input_map, nsrc, memo) for j in n.inputs]
        op = n.operator_ref.qualified.id
        if op == "IDENTITY" && length(args) == 1
            args[1]
        elseif op == "ADD" && length(args) == 2
            _fr_add(args[1], args[2])
        elseif op == "SUB" && length(args) == 2
            _fr_add(args[1], _fr_scale(args[2], -1.0))
        elseif op == "NEG" && length(args) == 1
            _fr_scale(args[1], -1.0)
        elseif op == "SCALAR_MUL" && length(args) == 2
            scalar1 = all(iszero, args[1].src) && args[1].u == 0 && args[1].lap == 0
            scalar2 = all(iszero, args[2].src) && args[2].u == 0 && args[2].lap == 0
            if scalar1
                _fr_scale(args[2], args[1].c)
            elseif scalar2
                _fr_scale(args[1], args[2].c)
            else
                throw(ArgumentError("deferred: nonlinear multiplication"))
            end
        elseif op == "SCALAR_DIV" && length(args) == 2
            all(iszero, args[2].src) && args[2].u == 0 && args[2].lap == 0 && args[2].c != 0 ||
                throw(ArgumentError("deferred: division requires nonzero scalar constant"))
            _fr_scale(args[1], 1 / args[2].c)
        elseif op == "LAPLACE" && length(args) == 1
            args[1].u == 1.0 && all(iszero, args[1].src) && args[1].c == 0 && args[1].lap == 0 ||
                throw(ArgumentError("deferred: LAPLACE must act directly on unknown"))
            x = _FRExpr(nsrc); x.u=0.0; x.lap=1.0; x
        else
            throw(ArgumentError("deferred: unsupported AST operator $(op)"))
        end
    else
        throw(ArgumentError("deferred: unsupported AST node"))
    end
    memo[i] = out
end

function compile_linear_field_residual_form(edge::AtomicMIMOHyperedgeV1, graph::TypedOperatorHypergraphV1,
                                            operator_registry::OperatorRegistryV1;
                                            constraint_edge_hash::Digest256, unknown_state_ref::StateGeneRefV1,
                                            source_state_refs::Tuple, residual_state_ref::StateGeneRefV1)
    matches = [e for e in graph.hyperedges if e isa AtomicMIMOHyperedgeV1 && canonical_hash(e) == constraint_edge_hash]
    length(matches) == 1 && matches[1] === edge || throw(ArgumentError("constraint edge hash is not exact and unique"))
    edge.role === constraint || throw(ArgumentError("selected edge is not a constraint"))
    for (ref, mh) in edge.program.used_manifest_bindings
        m = operator_manifest(operator_registry, ref.qualified)
        m.manifest_hash == mh || throw(ArgumentError("operator manifest hash mismatch"))
        ref.qualified.id in _FR_LITERAL_IDS ||
            throw(ArgumentError("operator is outside field residual allowlist"))
        ref.qualified.version == "v1" || throw(ArgumentError("operator version is unsupported"))
        mh == _fr_literal_manifest_hash(ref.qualified.id) ||
            throw(ArgumentError("operator is not the audited literal manifest"))
    end
    length(edge.input_bindings) == 1 + length(source_state_refs) && length(edge.output_bindings) == 1 ||
        throw(ArgumentError("constraint binding arity mismatch"))
    allrefs = (unknown_state_ref, residual_state_ref, source_state_refs...)
    length(unique(r.value for r in allrefs)) == 2 + length(source_state_refs) ||
        throw(ArgumentError("state references must be unique"))
    sorted_sources = Tuple(sort(collect(source_state_refs), by = r -> r.value))
    refs = (unknown_state_ref, sorted_sources...)
    input_map = Dict{Int,Int}()
    seen_ports = Set{Int}()
    for b in edge.input_bindings
        node = graph.nodes[b.graph_node_index]
        node.node_kind === :state || throw(ArgumentError("constraint input must be a state"))
        pos = findfirst(r -> r.value == node.node_id, refs)
        pos === nothing && throw(ArgumentError("constraint input binding mismatch"))
        b.program_position <= length(edge.program.input_ports) || throw(ArgumentError("constraint input position mismatch"))
        input_node = edge.program.nodes[edge.program.input_ports[b.program_position]]
        input_node isa ASTInputV1 || throw(ArgumentError("constraint binding must target ASTInput"))
        input_node.port in seen_ports && throw(ArgumentError("duplicate AST input binding"))
        push!(seen_ports, input_node.port)
        input_map[input_node.port] = pos
    end
    length(seen_ports) == length(refs) || throw(ArgumentError("unused constraint input"))
    outbinding = only(edge.output_bindings)
    outbinding.program_position <= length(edge.program.roots) || throw(ArgumentError("constraint output position mismatch"))
    outnode = graph.nodes[outbinding.graph_node_index]
    outnode.node_kind === :state && outnode.node_id == residual_state_ref.value || throw(ArgumentError("constraint output binding mismatch"))
    root_count = length(edge.program.roots); root_count == 1 || throw(ArgumentError("constraint must have one root"))
    root = edge.program.roots[outbinding.program_position]
    x = _fr_expr(edge.program, root, input_map, length(sorted_sources))
    all(isfinite, (x.u, x.c, x.lap)) && all(isfinite, x.src) || throw(ArgumentError("nonfinite residual coefficients"))
    x.lap != 0.0 || throw(ArgumentError("deferred: residual form must contain a nonzero LAPLACE unknown"))
    unknown_node = graph.nodes[findfirst(n -> n.node_kind === :state && n.node_id == unknown_state_ref.value, graph.nodes)]
    source_nodes = Tuple(graph.nodes[findfirst(n -> n.node_kind === :state && n.node_id == r.value, graph.nodes)] for r in sorted_sources)
    unknown_node.physical_type.temporal_type.kind == static_time && unknown_node.physical_type.tensor_rank == 0 &&
        unknown_node.physical_type.value_kind == :scalar_field && unknown_node.physical_type.spatial_dimension == 3 ||
        throw(ArgumentError("unknown field type is outside static scalar 3D contract"))
    outnode.physical_type.temporal_type.kind == static_time && outnode.physical_type.tensor_rank == 0 &&
        outnode.physical_type.value_kind == :scalar_field && outnode.physical_type.spatial_dimension == 3 ||
        throw(ArgumentError("residual field type is outside static scalar 3D contract"))
    form = LinearFieldResidualFormV4(_FR_TOKEN, constraint_edge_hash, unknown_state_ref, sorted_sources, residual_state_ref,
        unknown_node.physical_type, Tuple(n.physical_type for n in source_nodes), outnode.physical_type,
        x.lap, x.u, Tuple(x.src), x.c, digest256_text(repeat("0", 64)))
    LinearFieldResidualFormV4(_FR_TOKEN, form.edge_hash, form.unknown_state_ref, form.source_state_refs, form.residual_state_ref,
        form.unknown_type, form.source_types, form.residual_type, form.alpha, form.beta,
        form.source_coefficients, form.constant, canonical_hash(semantic_view(form)))
end
LinearFieldResidualFormV4(args...) = throw(ArgumentError("field residual form is sealed"))

struct FieldResidualPayloadV4
    state_ref::StateGeneRefV1
    coordinates::NTuple{3,Tuple{Vararg{Float64}}}
    values::Tuple{Vararg{Float64}}
    physical_type::PhysicalType
    content_hash::Digest256
    function FieldResidualPayloadV4(token::typeof(_FR_TOKEN), args...)
        token === _FR_TOKEN || throw(ArgumentError("sealed field payload"))
        new(args...)
    end
end
function FieldResidualPayloadV4(state_ref::StateGeneRefV1, grid, values, physical_type::PhysicalType)
    coordinates = _fr_grid_coordinates(grid)
    v=Tuple(Float64.(values)); length(v)==prod(length.(coordinates)) && all(isfinite,v) || throw(ArgumentError("payload values invalid"))
    h=canonical_hash((state_ref=state_ref, coordinates=coordinates, values=Tuple(v), physical_type=physical_type))
    FieldResidualPayloadV4(_FR_TOKEN, state_ref, coordinates, v, physical_type, h)
end
FieldResidualPayloadV4(args...) = throw(ArgumentError("field residual payload is sealed"))

struct ResidualAssemblyV4
    n::Int
    colptr::Tuple{Vararg{Int}}
    rowval::Tuple{Vararg{Int}}
    nzval::Tuple{Vararg{Float64}}
    rhs::Tuple{Vararg{Float64}}
    boundary_values::Tuple{Vararg{Float64}}
    boundary_indices::Tuple{Vararg{Int}}
    row_ownership::Tuple
    form_hash::Digest256
    geometry_hash::Digest256
    grid_hash::Digest256
    protocol_hash::Digest256
    source_hashes::Tuple
    boundary_hash::Digest256
    assembly_hash::Digest256
    function ResidualAssemblyV4(token::typeof(_FR_TOKEN), args...)
        token === _FR_TOKEN || throw(ArgumentError("sealed residual assembly"))
        new(args...)
    end
end
canonical_hash(x::ResidualAssemblyV4) = x.assembly_hash
ResidualAssemblyV4(args...) = throw(ArgumentError("residual assembly is sealed"))
_fr_matrix(x::ResidualAssemblyV4) = SparseMatrixCSC(x.n, x.n, collect(x.colptr), collect(x.rowval), collect(x.nzval))
function _fr_protocol_integrity(x::StructuredGridProtocolV4)
    canonical_hash((discretization=x.discretization, boundary=x.boundary, solver=x.solver,
        abs_tol=x.abs_tol, rel_tol=x.rel_tol, max_iterations=x.max_iterations, backend=x.backend_identity))
end
function _fr_payload_integrity(x::FieldResidualPayloadV4)
    canonical_hash((state_ref=x.state_ref, coordinates=x.coordinates, values=x.values, physical_type=x.physical_type)) == x.content_hash
end
function _fr_form_integrity(x::LinearFieldResidualFormV4)
    canonical_hash((edge_hash=x.edge_hash, unknown_state_ref=x.unknown_state_ref,
        source_state_refs=x.source_state_refs, residual_state_ref=x.residual_state_ref,
        unknown_type=x.unknown_type, source_types=x.source_types, residual_type=x.residual_type,
        alpha=x.alpha, beta=x.beta, source_coefficients=x.source_coefficients, constant=x.constant)) == x.form_hash
end
function _fr_geometry_integrity(x::DiagonalAffineChartGeometryV4)
    body=(support_hash=canonical_hash(x.support), chart_ref=x.chart_ref, factors=x.factors, offsets=x.offsets,
        grid_hash=_fr_grid_hash(x.grid), scale=x.scale, jhat=x.jhat, ghat=x.ghat, laplace_weights=x.laplace_weights)
    canonical_hash(body) == x.geometry_hash
end
function _fr_assembly_integrity(x::ResidualAssemblyV4)
    body=(m=x.n,n=x.n,colptr=x.colptr,rowval=x.rowval,nzval=x.nzval,rhs=x.rhs,
        ownership=x.row_ownership,boundary_values=x.boundary_values,boundary_indices=x.boundary_indices,
        form_hash=x.form_hash,geometry_hash=x.geometry_hash,grid_hash=x.grid_hash,protocol_hash=x.protocol_hash,
        source_hashes=x.source_hashes,boundary_hash=x.boundary_hash)
    canonical_hash(body)
end

function _fr_index(ix,iy,iz,nx,ny,nz); (ix-1)*ny*nz+(iy-1)*nz+iz end
function _fr_boundary(ix,iy,iz,nx,ny,nz); ix==1||iy==1||iz==1||ix==nx||iy==ny||iz==nz end

function assemble_field_residual_kernel(form::LinearFieldResidualFormV4, geometry::DiagonalAffineChartGeometryV4,
                                        grid, source_payloads::Tuple, boundary_payload::FieldResidualPayloadV4,
                                        protocol::StructuredGridProtocolV4)
    _fr_protocol_integrity(protocol) == protocol.protocol_hash || throw(ArgumentError("protocol integrity mismatch"))
    coordinates = _fr_grid_coordinates(grid)
    _fr_form_integrity(form) && _fr_geometry_integrity(geometry) || throw(ArgumentError("form or geometry integrity mismatch"))
    _fr_grid_hash(grid) == _fr_grid_hash(geometry.grid) || throw(ArgumentError("grid hash mismatch"))
    grid == geometry.grid || throw(ArgumentError("grid/geometry mismatch"))
    length(source_payloads)==length(form.source_state_refs) || throw(ArgumentError("source count mismatch"))
    length(unique(p.state_ref.value for p in source_payloads)) == length(source_payloads) ||
        throw(ArgumentError("duplicate source state"))
    byref = Dict(p.state_ref.value => p for p in source_payloads)
    all(haskey(byref, r.value) for r in form.source_state_refs) || throw(ArgumentError("missing source state"))
    ordered_sources = Tuple(byref[r.value] for r in form.source_state_refs)
    all(p.physical_type == form.source_types[i] for (i,p) in enumerate(ordered_sources)) ||
        throw(ArgumentError("source type mismatch"))
    boundary_payload.state_ref == form.unknown_state_ref || throw(ArgumentError("boundary state mismatch"))
    all(_fr_payload_integrity(p) for p in source_payloads) && _fr_payload_integrity(boundary_payload) ||
        throw(ArgumentError("payload content hash mismatch"))
    boundary_payload.physical_type == form.unknown_type || throw(ArgumentError("boundary type mismatch"))
    n = prod(length.(coordinates)); length(boundary_payload.values)==n || throw(ArgumentError("boundary coverage mismatch"))
    boundary_payload.coordinates == coordinates || throw(ArgumentError("boundary grid mismatch"))
    all(length(p.values)==n && p.coordinates==coordinates for p in ordered_sources) || throw(ArgumentError("source grid mismatch"))
    nx,ny,nz=length.(coordinates); I=Int[]; J=Int[]; V=Float64[]; b=zeros(n)
    hs=ntuple(d -> coordinates[d][2]-coordinates[d][1], 3); w=geometry.laplace_weights
    src=zeros(n); for (coef,p) in zip(form.source_coefficients,ordered_sources); src .+= coef .* p.values end
    for ix in 1:nx, iy in 1:ny, iz in 1:nz
        k=_fr_index(ix,iy,iz,nx,ny,nz)
        if _fr_boundary(ix,iy,iz,nx,ny,nz)
            push!(I,k);push!(J,k);push!(V,1.0);b[k]=boundary_payload.values[k]
        else
            diag=form.beta - 2form.alpha*sum(w[d]/hs[d]^2 for d in 1:3)
            push!(I,k);push!(J,k);push!(V,diag); b[k]=-(src[k]+form.constant)
            for (d,(dx,dy,dz)) in enumerate(((1,0,0),(0,1,0),(0,0,1)))
                q=w[d]*form.alpha/hs[d]^2
                for s in (-1,1)
                    jx, jy, jz = ix+s*dx, iy+s*dy, iz+s*dz
                    j=_fr_index(jx,jy,jz,nx,ny,nz)
                    if _fr_boundary(jx,jy,jz,nx,ny,nz)
                        b[k] -= q * boundary_payload.values[j]
                    else
                        push!(I,k);push!(J,j);push!(V,q)
                    end
                end
            end
        end
    end
    A=sparse(I,J,V,n,n); own=Tuple((form.residual_state_ref,k) for k in 1:n)
    boundary_indices=Tuple(k for ix in 1:nx for iy in 1:ny for iz in 1:nz if _fr_boundary(ix,iy,iz,nx,ny,nz) for k in (_fr_index(ix,iy,iz,nx,ny,nz),))
    body=(m=size(A,1),n=size(A,2),colptr=Tuple(A.colptr),rowval=Tuple(A.rowval),nzval=Tuple(A.nzval),rhs=Tuple(b),
        ownership=own,boundary_values=boundary_payload.values,boundary_indices=boundary_indices,form_hash=form.form_hash,geometry_hash=geometry.geometry_hash,grid_hash=_fr_grid_hash(grid),
        protocol_hash=protocol.protocol_hash,source_hashes=Tuple(p.content_hash for p in ordered_sources),boundary_hash=boundary_payload.content_hash)
    ResidualAssemblyV4(_FR_TOKEN,n,Tuple(A.colptr),Tuple(A.rowval),Tuple(A.nzval),Tuple(b),boundary_payload.values,boundary_indices,own,form.form_hash,geometry.geometry_hash,_fr_grid_hash(grid),protocol.protocol_hash,
        Tuple(p.content_hash for p in ordered_sources),boundary_payload.content_hash,canonical_hash(body))
end

struct FieldSolveResultV4
    status::Symbol
    solution::Tuple{Vararg{Float64}}
    residual_norm::Union{Nothing,Float64}
    boundary_mismatch::Union{Nothing,Float64}
    backward_error::Union{Nothing,Float64}
    factorization_status::Symbol
    conditioning_estimate::Nothing
    conditioning_status::Symbol
    reason::Union{Nothing,String}
    assembly_hash::Digest256
    protocol_hash::Digest256
    result_hash::Digest256
    function FieldSolveResultV4(token::typeof(_FR_TOKEN), args...)
        token === _FR_TOKEN || throw(ArgumentError("sealed field solve result"))
        new(args...)
    end
end
canonical_hash(x::FieldSolveResultV4)=x.result_hash
FieldSolveResultV4(args...) = throw(ArgumentError("field solve result is sealed"))

function solve_field_residual_kernel(assembly::ResidualAssemblyV4, protocol::StructuredGridProtocolV4)
    A = nothing; rhs = Float64[]
    u=Float64[]; status=:numerical_fail; reason=nothing; factorization_status=:failed
    _fr_protocol_integrity(protocol) == protocol.protocol_hash || throw(ArgumentError("protocol integrity mismatch"))
    _fr_assembly_integrity(assembly) == assembly.assembly_hash || throw(ArgumentError("assembly integrity mismatch"))
    assembly.protocol_hash == protocol.protocol_hash || throw(ArgumentError("assembly protocol binding mismatch"))
    try
        A = _fr_matrix(assembly); rhs = collect(assembly.rhs)
        F = lu(A); factorization_status=:success
        u=Vector{Float64}(F\rhs)
        all(isfinite,u) || throw(ArgumentError("nonfinite solution"))
        r=A*u-rhs; rn=norm(r,Inf); be=rn/(opnorm(A,Inf)*norm(u,Inf)+norm(rhs,Inf)+eps())
        boundary_mismatch = maximum(abs(u[k]-assembly.boundary_values[k]) for k in assembly.boundary_indices)
        if rn <= protocol.abs_tol + protocol.rel_tol*max(norm(assembly.rhs,Inf),1.0) &&
           be <= protocol.abs_tol + protocol.rel_tol && boundary_mismatch <= protocol.abs_tol + protocol.rel_tol
            status=:converged
        else
            reason="residual_tolerance"
        end
        body=(status=status,solution=Tuple(u),residual_norm=rn,boundary_mismatch=boundary_mismatch,backward_error=be,factorization_status=factorization_status,
            conditioning_status=:unknown_not_computed,reason=reason,assembly_hash=assembly.assembly_hash,protocol_hash=protocol.protocol_hash)
        return FieldSolveResultV4(_FR_TOKEN,status,Tuple(u),rn,boundary_mismatch,be,factorization_status,nothing,:unknown_not_computed,reason,assembly.assembly_hash,protocol.protocol_hash,canonical_hash(body))
    catch e
        reason=sprint(showerror,e); body=(status=:numerical_fail,solution=Tuple(u),residual_norm=nothing,boundary_mismatch=nothing,backward_error=nothing,
            factorization_status=factorization_status,conditioning_status=:unknown_not_computed,reason=reason,assembly_hash=assembly.assembly_hash,protocol_hash=protocol.protocol_hash)
        FieldSolveResultV4(_FR_TOKEN,:numerical_fail,Tuple(u),nothing,nothing,nothing,factorization_status,nothing,:unknown_not_computed,reason,assembly.assembly_hash,protocol.protocol_hash,canonical_hash(body))
    end
end
