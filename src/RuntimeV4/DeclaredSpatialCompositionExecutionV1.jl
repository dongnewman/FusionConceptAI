"""Declared spatial composition execution, UP2/UP3 additive vertical slice.

This file is deliberately self contained.  It implements a small, declared
one-dimensional finite-volume execution seam: an old two-cell state is
transferred to a new four-cell geometry by measure overlap, typed ports are
matched into unique producer edges, and one assembled linear system is solved.
The result is a software screen only.  It is not a provider, mesh backend,
trusted receipt, registry, UP/R/L4, or acceptance path.
"""

using LinearAlgebra
using SHA

const DSC_SCHEMA_V1 = "fusionconceptai:runtime-v4:declared-spatial-composition-execution-v1"
const DSC_REVISION_V1 = "up2-up3-declared-spatial-composition-v1"
const DSC_CLAIM_CEILING_V1 = :screen_only
const DSC_STATUSES_V1 = (:ready, :fail_closed, :terminal_deferred, :numerical_fail)

_dsc_hash(x) = bytes2hex(sha256(codeunits(repr(x))))
_dsc_text(x, field) = begin
    s = strip(String(x)); isempty(s) && throw(ArgumentError("$field cannot be empty")); s
end
_dsc_float(x, field) = begin
    y = Float64(x); isfinite(y) || throw(ArgumentError("$field must be finite")); y
end
_dsc_result(status, code, detail; residual=0.0, kwargs...) =
    merge((valid=status === :ready, status=status, code=code, detail=String(detail),
        residual=Float64(residual)), kwargs)

"A one-dimensional geometry.  Labels are diagnostic and never part of its hash."
struct DeclaredSpatialGeometryV1
    geometry_ref::String
    edges::Vector{Float64}
    cell_labels::Vector{String}
    geometry_hash::String
    function DeclaredSpatialGeometryV1(geometry_ref, edges; cell_labels=nothing,
                                      geometry_hash=nothing)
        e = Float64.(collect(edges)); length(e) >= 2 || throw(ArgumentError("geometry needs edges"))
        labs = cell_labels === nothing ? ["cell-$i" for i in 1:length(e)-1] : String.(collect(cell_labels))
        length(labs) == length(e)-1 || throw(ArgumentError("cell label count mismatch"))
        key = (edges=Tuple(e),)
        digest = geometry_hash === nothing ? _dsc_hash(key) : String(geometry_hash)
        new(_dsc_text(geometry_ref, "geometry_ref"), e, labs, digest)
    end
end

"Dirichlet and Neumann boundary declarations; :missing is an intentional gap."
struct DeclaredSpatialBoundaryV1
    left_kind::Symbol
    left_value::Float64
    right_kind::Symbol
    right_value::Float64
    function DeclaredSpatialBoundaryV1(left_kind, left_value, right_kind, right_value)
        left_kind in (:dirichlet, :neumann, :missing) || throw(ArgumentError("invalid left BC"))
        right_kind in (:dirichlet, :neumann, :missing) || throw(ArgumentError("invalid right BC"))
        new(left_kind, Float64(left_value), right_kind, Float64(right_value))
    end
end

"Cell-centred K and source declarations.  Validation, rather than construction, classifies nonfinite K."
struct DeclaredSpatialFieldV1
    k_cells::Vector{Float64}
    source::Vector{Float64}
    k_hash::String
    source_hash::String
    function DeclaredSpatialFieldV1(k_cells, source; k_hash=nothing, source_hash=nothing)
        k = Float64.(collect(k_cells)); f = Float64.(collect(source))
        kh = k_hash === nothing ? _dsc_hash((k=Tuple(k),)) : String(k_hash)
        fh = source_hash === nothing ? _dsc_hash((source=Tuple(f),)) : String(source_hash)
        new(k, f, kh, fh)
    end
end

"A typed port.  port_ref/component_ref are labels; account, quantity and unit are semantic."
struct DeclaredSpatialPortV1
    port_ref::String
    direction::Symbol
    quantity::Symbol
    unit::String
    account::String
    role::Symbol
    ledger_sign::Int
    magnitude::Float64
    payload::Any
    function DeclaredSpatialPortV1(port_ref, direction, quantity, unit, account;
                                   role=:aux, ledger_sign=nothing, magnitude=0.0, payload=nothing)
        direction in (:input, :output) || throw(ArgumentError("port direction must be input/output"))
        q = Symbol(quantity); r = Symbol(role)
        sign = ledger_sign === nothing ? (direction === :output ? 1 : -1) : Int(ledger_sign)
        sign in (-1, 1) || throw(ArgumentError("ledger sign must be +/-1"))
        direction === :output && sign != 1 && throw(ArgumentError("output sign must be +1"))
        direction === :input && sign != -1 && throw(ArgumentError("input sign must be -1"))
        new(_dsc_text(port_ref, "port_ref"), direction, q, _dsc_text(unit, "unit"),
            _dsc_text(account, "account"), r, sign, Float64(magnitude), payload)
    end
end

struct DeclaredSpatialComponentV1
    component_ref::String
    ports::Tuple{Vararg{DeclaredSpatialPortV1}}
    function DeclaredSpatialComponentV1(component_ref, ports)
        ps = Tuple(ports); all(p -> p isa DeclaredSpatialPortV1, ps) ||
            throw(ArgumentError("component ports must be typed"))
        new(_dsc_text(component_ref, "component_ref"), ps)
    end
end

struct DeclaredSpatialCompositionV1
    components::Tuple{Vararg{DeclaredSpatialComponentV1}}
    plan_ref::String
    function DeclaredSpatialCompositionV1(components; plan_ref="declared-composition")
        cs = Tuple(components); isempty(cs) && throw(ArgumentError("composition is empty"))
        all(c -> c isa DeclaredSpatialComponentV1, cs) || throw(ArgumentError("components must be typed"))
        new(cs, _dsc_text(plan_ref, "plan_ref"))
    end
end

"The problem intentionally carries no external/provider receipt."
struct DeclaredSpatialCaseV1
    old_geometry::DeclaredSpatialGeometryV1
    new_geometry::DeclaredSpatialGeometryV1
    old_state::Vector{Float64}
    field::DeclaredSpatialFieldV1
    boundary::Union{Nothing,DeclaredSpatialBoundaryV1}
    composition::DeclaredSpatialCompositionV1
    case_ref::String
    function DeclaredSpatialCaseV1(old_geometry, new_geometry, old_state, field,
                                   boundary, composition; case_ref="declared-case")
        old_geometry isa DeclaredSpatialGeometryV1 && new_geometry isa DeclaredSpatialGeometryV1 ||
            throw(ArgumentError("case geometries must be typed"))
        field isa DeclaredSpatialFieldV1 && composition isa DeclaredSpatialCompositionV1 ||
            throw(ArgumentError("case field/composition must be typed"))
        new(old_geometry, new_geometry, Float64.(collect(old_state)), field,
            boundary, composition, _dsc_text(case_ref, "case_ref"))
    end
end

"Canonical semantic projections exclude display labels and mutable container identity."
function _dsc_canonical_payload(x)
    if x isa AbstractArray
        return Tuple(_dsc_canonical_payload(y) for y in x)
    elseif x isa NamedTuple
        return Tuple((k, _dsc_canonical_payload(getproperty(x, k))) for k in keys(x))
    elseif x isa Tuple
        return Tuple(_dsc_canonical_payload(y) for y in x)
    end
    x
end
semantic_view(g::DeclaredSpatialGeometryV1) = (edges=Tuple(g.edges),)
semantic_view(b::DeclaredSpatialBoundaryV1) = (left_kind=b.left_kind, left_value=b.left_value,
    right_kind=b.right_kind, right_value=b.right_value)
semantic_view(f::DeclaredSpatialFieldV1) = (k=Tuple(f.k_cells), source=Tuple(f.source))
semantic_view(p::DeclaredSpatialPortV1) = (direction=p.direction, quantity=p.quantity,
    unit=p.unit, account=p.account, role=p.role, ledger_sign=p.ledger_sign,
    magnitude=p.magnitude, payload=_dsc_canonical_payload(p.payload))
semantic_view(c::DeclaredSpatialComponentV1) =
    Tuple(sort([semantic_view(p) for p in c.ports], by=repr))
semantic_view(c::DeclaredSpatialCompositionV1) =
    Tuple(sort([semantic_view(x) for x in c.components], by=repr))
canonical_hash(g::DeclaredSpatialGeometryV1) = _dsc_hash(semantic_view(g))
canonical_hash(b::DeclaredSpatialBoundaryV1) = _dsc_hash(semantic_view(b))
canonical_hash(f::DeclaredSpatialFieldV1) = _dsc_hash(semantic_view(f))
canonical_hash(p::DeclaredSpatialPortV1) = _dsc_hash(semantic_view(p))
canonical_hash(c::DeclaredSpatialComponentV1) = _dsc_hash(semantic_view(c))
canonical_hash(c::DeclaredSpatialCompositionV1) = _dsc_hash(semantic_view(c))
_dsc_geometry_key(g::DeclaredSpatialGeometryV1) = semantic_view(g)
_dsc_expected_geometry_hash(g::DeclaredSpatialGeometryV1) = canonical_hash(g)
_dsc_boundary_hash(b::DeclaredSpatialBoundaryV1) =
    canonical_hash(b)
_dsc_expected_k_hash(f::DeclaredSpatialFieldV1) = _dsc_hash((k=Tuple(f.k_cells),))
_dsc_expected_source_hash(f::DeclaredSpatialFieldV1) = _dsc_hash((source=Tuple(f.source),))
_dsc_port_key(p::DeclaredSpatialPortV1) =
    (p.direction, p.quantity, p.unit, p.account, p.role, p.ledger_sign, p.magnitude,
     _dsc_canonical_payload(p.payload))

function validate_declared_geometry(g::DeclaredSpatialGeometryV1)
    e = g.edges
    length(e) >= 2 && all(isfinite, e) && all(diff(e) .> 0.0) ||
        return _dsc_result(:fail_closed, :invalid_geometry, "edges must be finite and strictly increasing")
    g.geometry_hash == _dsc_expected_geometry_hash(g) ||
        return _dsc_result(:fail_closed, :geometry_hash_mismatch, "geometry hash is not derived from edges")
    _dsc_result(:ready, :valid_geometry, "geometry is ordered and digest-valid")
end

function validate_declared_boundary(b)
    b isa DeclaredSpatialBoundaryV1 || return _dsc_result(:fail_closed, :missing_boundary, "boundary declaration is absent")
    b.left_kind !== :missing && b.right_kind !== :missing ||
        return _dsc_result(:fail_closed, :missing_boundary, "both boundary declarations are required")
    all(isfinite, (b.left_value, b.right_value)) ||
        return _dsc_result(:fail_closed, :nonfinite_boundary, "boundary value is nonfinite")
    _dsc_result(:ready, :valid_boundary, "boundary declaration is complete")
end

function validate_declared_field_hashes(f::DeclaredSpatialFieldV1)
    f.k_hash == _dsc_expected_k_hash(f) ||
        return _dsc_result(:fail_closed, :k_hash_mismatch, "K hash is not derived from declared K")
    f.source_hash == _dsc_expected_source_hash(f) ||
        return _dsc_result(:fail_closed, :source_hash_mismatch, "source hash is not derived from declared source")
    _dsc_result(:ready, :valid_field_hashes, "K/source hashes are canonical and declaration-bound")
end

"Build unique producer edges.  No component or port label enters the returned semantic hash."
function auto_typed_port_edges(c::DeclaredSpatialCompositionV1)
    outputs = DeclaredSpatialPortV1[]; inputs = DeclaredSpatialPortV1[]
    for component in c.components, p in component.ports
        p.direction === :output ? push!(outputs, p) : push!(inputs, p)
    end
    edges = NamedTuple[]
    for input in inputs
        same = [p for p in outputs if p.account == input.account && p.quantity == input.quantity]
        compatible = [p for p in same if p.unit == input.unit]
        length(compatible) > 1 && return _dsc_result(:fail_closed, :duplicate_producer,
            "more than one producer matches $(input.account)")
        isempty(compatible) && !isempty(same) && return _dsc_result(:fail_closed, :unit_mismatch,
            "producer/input units differ for $(input.account)")
        isempty(compatible) && return _dsc_result(:fail_closed,
            input.account == "field" ? :missing_return : :missing_producer,
            "input has no unique producer for $(input.account)")
        producer = first(compatible)
        push!(edges, (producer=producer, consumer=input, account=input.account,
                      quantity=input.quantity, unit=input.unit))
    end
    required = ("source", "boundary", "field")
    accounts = Set(e.account for e in edges)
    "boundary" in accounts || return _dsc_result(:fail_closed, :missing_boundary, "boundary port edge is absent")
    "field" in accounts || return _dsc_result(:fail_closed, :missing_return, "field return edge is absent")
    "source" in accounts || return _dsc_result(:fail_closed, :missing_producer, "source port edge is absent")
    totals = Dict{Tuple{String,Symbol,String},Float64}()
    for p in (outputs..., inputs...)
        key = (p.account, p.quantity, p.unit)
        totals[key] = get(totals, key, 0.0) + p.ledger_sign * p.magnitude
    end
    ledger = sum(abs, values(totals))
    isfinite(ledger) || return _dsc_result(:fail_closed, :nonfinite_ledger, "ledger is nonfinite")
    ledger <= 1e-12 || return _dsc_result(:fail_closed, :ledger_mismatch,
        "typed account ledger does not close", residual=ledger)
    semantic_edges = sort([(_dsc_port_key(e.producer), _dsc_port_key(e.consumer)) for e in edges], by=repr)
    _dsc_result(:ready, :edges_generated, "typed unique-producer edges generated",
        residual=ledger, edges=Tuple(edges), ledger_residual=ledger,
        composition_hash=_dsc_hash(Tuple(semantic_edges)),
        edge_payload_hash=_dsc_hash(Tuple((_dsc_canonical_payload(e.producer.payload),
            _dsc_canonical_payload(e.consumer.payload)) for e in edges)))
end

"Conservative old-to-new cell-average transfer using geometric overlap lengths."
function measure_overlap_transfer(old_geometry::DeclaredSpatialGeometryV1,
                                 new_geometry::DeclaredSpatialGeometryV1, old_state)
    vo = validate_declared_geometry(old_geometry); vo.valid || return merge(vo, (transfer=nothing,))
    vn = validate_declared_geometry(new_geometry); vn.valid || return merge(vn, (transfer=nothing,))
    old = Float64.(collect(old_state)); no = length(old_geometry.edges)-1; nn = length(new_geometry.edges)-1
    length(old) == no || return _dsc_result(:fail_closed, :state_size_mismatch, "old state does not match old geometry", transfer=nothing)
    all(isfinite, old) || return _dsc_result(:fail_closed, :nonfinite_state, "old state is nonfinite", transfer=nothing)
    overlap = zeros(Float64, nn, no)
    for j in 1:nn, i in 1:no
        overlap[j, i] = max(0.0, min(new_geometry.edges[j+1], old_geometry.edges[i+1]) -
            max(new_geometry.edges[j], old_geometry.edges[i]))
    end
    new_volumes = diff(new_geometry.edges); old_volumes = diff(old_geometry.edges)
    all(sum(overlap[j, :]) ≈ new_volumes[j] for j in 1:nn) ||
        return _dsc_result(:terminal_deferred, :nonoverlap, "new geometry is not fully covered by old geometry", transfer=nothing)
    all(sum(overlap[:, i]) ≈ old_volumes[i] for i in 1:no) ||
        return _dsc_result(:terminal_deferred, :nonoverlap, "old geometry is not fully covered by new geometry", transfer=nothing)
    state = [sum(overlap[j, i] * old[i] for i in 1:no) / new_volumes[j] for j in 1:nn]
    old_total = sum(old[i] * old_volumes[i] for i in 1:no)
    new_total = sum(state[j] * new_volumes[j] for j in 1:nn)
    residual = abs(new_total - old_total)
    transfer_key = (old_geometry=_dsc_expected_geometry_hash(old_geometry),
        new_geometry=_dsc_expected_geometry_hash(new_geometry), old_state=Tuple(old),
        new_state=Tuple(state), overlap=Tuple(vec(overlap)))
    _dsc_result(:ready, :measure_overlap_transfer, "measure-overlap transfer is conservative",
        residual=residual, transfer=(old_state=Tuple(old), new_state=Tuple(state),
            overlap=overlap, old_total=old_total, new_total=new_total,
            conservation_residual=residual, transfer_hash=_dsc_hash(transfer_key)))
end

_dsc_harmonic(a, b) = (a > 0.0 && b > 0.0) ? 2.0*a*b/(a+b) : NaN

function _dsc_edge(edges, account)
    i = findfirst(e -> e.account == account, edges)
    i === nothing ? nothing : edges[i]
end

function _dsc_edge_payload(edge, fallback, n, field)
    edge === nothing && throw(ArgumentError("missing typed $field edge"))
    p = edge.producer.payload
    p === nothing && throw(ArgumentError("typed $field edge has no numerical payload"))
    if p isa AbstractVector
        v = Float64.(collect(p)); length(v) == n || throw(ArgumentError("typed $field payload size mismatch")); v
    elseif p isa Number
        fill(Float64(p), n)
    else
        throw(ArgumentError("typed $field payload is not numerical"))
    end
end

function _dsc_boundary_payload(edge, b::DeclaredSpatialBoundaryV1)
    edge === nothing && throw(ArgumentError("missing typed boundary edge"))
    p = edge.producer.payload
    p isa Tuple && length(p) == 2 || throw(ArgumentError("typed boundary payload must be a pair"))
    left, right = Float64(p[1]), Float64(p[2])
    all(isfinite, (left, right)) || throw(ArgumentError("typed boundary payload is nonfinite"))
    (left * edge.producer.magnitude, right * edge.producer.magnitude)
end

"Assemble -d/dx(K du/dx)=f with cell-centred finite volumes and centred face fluxes."
function assemble_declared_spatial_fv(g::DeclaredSpatialGeometryV1,
                                      field::DeclaredSpatialFieldV1,
                                      b::DeclaredSpatialBoundaryV1; edges=nothing)
    vg = validate_declared_geometry(g); vg.valid || return merge(vg, (assembly=nothing,))
    vb = validate_declared_boundary(b); vb.valid || return merge(vb, (assembly=nothing,))
    n = length(g.edges)-1; length(field.k_cells) == n && length(field.source) == n ||
        return _dsc_result(:fail_closed, :field_size_mismatch, "K/source size does not match geometry", assembly=nothing)
    all(isfinite, field.k_cells) && all(>(0.0), field.k_cells) ||
        return _dsc_result(:fail_closed, :nonfinite_K, "K must be finite and positive", assembly=nothing)
    all(isfinite, field.source) || return _dsc_result(:fail_closed, :nonfinite_source, "source is nonfinite", assembly=nothing)
    fh = validate_declared_field_hashes(field); fh.valid || return merge(fh, (assembly=nothing,))
    composition_hash = edges === nothing ? "unbound" : _dsc_hash(sort([
        (_dsc_port_key(e.producer), _dsc_port_key(e.consumer)) for e in edges], by=repr))
    if edges !== nothing
        required_accounts = Set(("source", "boundary", "field"))
        actual_accounts = Set(e.account for e in edges)
        issubset(required_accounts, actual_accounts) ||
            return _dsc_result(:fail_closed, :composition_gap,
                "assembled joint system is missing a declared typed edge", assembly=nothing)
    end
    source_edge = edges === nothing ? nothing : _dsc_edge(edges, "source")
    boundary_edge = edges === nothing ? nothing : _dsc_edge(edges, "boundary")
    field_edge = edges === nothing ? nothing : _dsc_edge(edges, "field")
    effective_source = edges === nothing ? copy(field.source) :
        _dsc_edge_payload(source_edge, field.source, n, "source") .* source_edge.producer.magnitude
    effective_boundary = edges === nothing ? (b.left_value, b.right_value) : _dsc_boundary_payload(boundary_edge, b)
    coupling_gain = edges === nothing ? 1.0 : field_edge.producer.magnitude
    if edges !== nothing
        source_payload = _dsc_edge_payload(source_edge, field.source, n, "source")
        all(isapprox(source_payload[i], field.source[i]; atol=1e-12, rtol=0.0) for i in 1:n) ||
            return _dsc_result(:fail_closed, :source_payload_mismatch,
                "typed source payload differs from declared field source", assembly=nothing)
        expected_boundary = (b.left_value * boundary_edge.producer.magnitude,
            b.right_value * boundary_edge.producer.magnitude)
        all(isapprox(effective_boundary[i], expected_boundary[i]; atol=1e-12, rtol=0.0) for i in 1:2) ||
            return _dsc_result(:fail_closed, :boundary_payload_mismatch,
                "typed boundary payload differs from declared boundary", assembly=nothing)
    end
    isfinite(coupling_gain) && coupling_gain > 0.0 ||
        return _dsc_result(:fail_closed, :invalid_coupling_gain, "field coupling magnitude must be finite and positive", assembly=nothing)
    all(isfinite, effective_source) && all(isfinite, effective_boundary) ||
        return _dsc_result(:fail_closed, :nonfinite_derived, "typed edge payload is nonfinite", assembly=nothing)
    A = zeros(Float64, n, n); rhs = effective_source .* diff(g.edges)
    centers = (g.edges[1:end-1] .+ g.edges[2:end]) ./ 2
    face_t = zeros(Float64, n+1); face_k = zeros(Float64, n+1)
    for i in 1:n-1
        xface = g.edges[i+1]
        dleft = xface - centers[i]; dright = centers[i+1] - xface
        face_t[i+1] = 1.0 / (dleft / field.k_cells[i] + dright / field.k_cells[i+1])
        face_k[i+1] = face_t[i+1] * (centers[i+1]-centers[i])
        A[i,i] += face_t[i+1]; A[i+1,i+1] += face_t[i+1]
        A[i,i+1] -= face_t[i+1]; A[i+1,i] -= face_t[i+1]
    end
    if b.left_kind === :dirichlet
        face_k[1] = field.k_cells[1]; face_t[1] = face_k[1] / (centers[1]-g.edges[1]); A[1,1] += face_t[1]; rhs[1] += face_t[1]*effective_boundary[1]
    elseif b.left_kind === :neumann
        rhs[1] += effective_boundary[1]
    end
    if b.right_kind === :dirichlet
        face_k[end] = field.k_cells[end]; face_t[end] = face_k[end] / (g.edges[end]-centers[end]); A[end,end] += face_t[end]; rhs[end] += face_t[end]*effective_boundary[2]
    elseif b.right_kind === :neumann
        rhs[end] += effective_boundary[2]
    end
    A .*= coupling_gain; rhs .*= coupling_gain
    all(isfinite, A) && all(isfinite, rhs) || return _dsc_result(:numerical_fail, :nonfinite_derived, "assembled matrix/RHS is nonfinite", assembly=nothing)
    ah = _dsc_hash((geometry=_dsc_expected_geometry_hash(g), composition=composition_hash,
        k=Tuple(field.k_cells), k_hash=field.k_hash, source=Tuple(effective_source),
        source_hash=field.source_hash, boundary=_dsc_boundary_hash(b),
        boundary_payload=effective_boundary, coupling_gain=coupling_gain,
        matrix=Tuple(vec(A)), rhs=Tuple(rhs)))
    _dsc_result(:ready, :finite_volume_assembled, "variable-K centered finite-volume system assembled",
        assembly=(matrix=A, rhs=rhs, centers=centers, face_conductivity=face_k,
            face_positions=g.edges[2:end-1], cell_conductivity=copy(field.k_cells),
            face_transmissibility=face_t,
            assembly_hash=ah, composition_hash=composition_hash,
            k_hash=field.k_hash, source_hash=field.source_hash,
            boundary_hash=_dsc_boundary_hash(b)))
end

function _dsc_solve(A::Matrix{Float64}, rhs::Vector{Float64})
    n = length(rhs); n == size(A,1) == size(A,2) || return (nothing, Inf, :invalid_system)
    all(isfinite, A) && all(isfinite, rhs) || return (nothing, Inf, :nonfinite_derived)
    rank(A) < n && return (nothing, norm(A * zeros(n) - rhs, Inf), :singular_matrix)
    x = A \ rhs; residual = norm(A*x-rhs, Inf)
    isfinite(residual) || return (nothing, Inf, :nonfinite_derived)
    (x, residual, :joint_linear_solved)
end

function _dsc_interface_flux_residual(assembly, solution)
    nfaces = length(solution) - 1
    residuals = Float64[]
    for i in 1:nfaces
        xface = assembly.face_positions[i]
        dleft = xface - assembly.centers[i]
        dright = assembly.centers[i+1] - xface
        kleft = assembly.cell_conductivity[i]
        kright = assembly.cell_conductivity[i+1]
        wleft = kleft / dleft
        wright = kright / dright
        uface = (wleft * solution[i] + wright * solution[i+1]) / (wleft + wright)
        left_flux = -kleft * (uface - solution[i]) / dleft
        right_flux = -kright * (solution[i+1] - uface) / dright
        push!(residuals, left_flux - right_flux)
    end
    isempty(residuals) ? 0.0 : maximum(abs.(residuals))
end

"Manufactured MMS order for the same centred finite-volume operator (independent of composition)."
function declared_spatial_mms_refinement(; levels=(8, 16, 32))
    errors = Float64[]
    for n in levels
        g = DeclaredSpatialGeometryV1("mms-$n", collect(range(0.0, 1.0; length=n+1)))
        f = DeclaredSpatialFieldV1(ones(n), [pi^2*sin(pi*((g.edges[i]+g.edges[i+1])/2)) for i in 1:n])
        b = DeclaredSpatialBoundaryV1(:dirichlet, 0.0, :dirichlet, 0.0)
        a = assemble_declared_spatial_fv(g, f, b); a.valid || return NaN
        x, _, code = _dsc_solve(a.assembly.matrix, a.assembly.rhs); code === :joint_linear_solved || return NaN
        exact = [sin(pi*((g.edges[i]+g.edges[i+1])/2)) for i in 1:n]
        push!(errors, norm(x-exact)/sqrt(n))
    end
    length(errors) >= 2 || return NaN
    log(errors[end-1]/errors[end]) / log(Float64(levels[end])/levels[end-1])
end

function _dsc_failure(status, code, detail; kwargs...)
    merge((status=status, code=code, detail=String(detail), accepted=false,
        claim_ceiling=DSC_CLAIM_CEILING_V1, formal_up_credit=false,
        formal_r_credit=false, formal_l4_credit=false, provider_calls=0,
        solver_invocations=0, receipt_hash=_dsc_hash((status=status, code=code, detail=detail))), kwargs)
end

"Execute one complete declared composition path, with at most one linear solve."
function execute_declared_spatial_composition(case::DeclaredSpatialCaseV1)
    try
        vg1 = validate_declared_geometry(case.old_geometry); vg1.valid || return _dsc_failure(vg1.status, vg1.code, vg1.detail)
        vg2 = validate_declared_geometry(case.new_geometry); vg2.valid || return _dsc_failure(vg2.status, vg2.code, vg2.detail)
        transfer = measure_overlap_transfer(case.old_geometry, case.new_geometry, case.old_state)
        transfer.valid || return _dsc_failure(transfer.status, transfer.code, transfer.detail,
            transfer=transfer, conservation_residual=Inf)
        edges = auto_typed_port_edges(case.composition)
        edges.valid || return _dsc_failure(edges.status, edges.code, edges.detail,
            transfer=transfer, ledger_residual=edges.residual)
        bc = validate_declared_boundary(case.boundary)
        bc.valid || return _dsc_failure(bc.status, bc.code, bc.detail, transfer=transfer,
            edges=edges, ledger_residual=edges.residual)
        assembled = assemble_declared_spatial_fv(case.new_geometry, case.field, case.boundary;
            edges=edges.edges)
        assembled.valid || return _dsc_failure(assembled.status, assembled.code, assembled.detail,
            transfer=transfer, edges=edges, ledger_residual=edges.residual, assembly=assembled)
        if case.boundary.left_kind === :neumann && case.boundary.right_kind === :neumann
            return _dsc_failure(:numerical_fail, :pure_neumann_singular, "pure Neumann system has a constant nullspace",
                transfer=transfer, edges=edges, assembly=assembled.assembly,
                conservation_residual=transfer.residual, ledger_residual=edges.residual)
        end
        x, residual, code = _dsc_solve(assembled.assembly.matrix, assembled.assembly.rhs)
        code === :joint_linear_solved || return _dsc_failure(:numerical_fail, code, "joint solve failed",
            transfer=transfer, edges=edges, assembly=assembled.assembly, joint_residual=residual,
            conservation_residual=transfer.residual, ledger_residual=edges.residual)
        interface_residual = _dsc_interface_flux_residual(assembled.assembly, x)
        result_hash = _dsc_hash((solution=Tuple(x), residual=residual,
            assembly=assembled.assembly.assembly_hash, transfer=transfer.transfer.transfer_hash,
            edges=edges.composition_hash))
        _dsc_failure(:ready, :joint_linear_solved, "declared spatial composition solved",
            accepted=false, claim_ceiling=DSC_CLAIM_CEILING_V1, formal_up_credit=false,
            formal_r_credit=false, formal_l4_credit=false, provider_calls=0,
            solver_invocations=1, transfer=transfer.transfer, edges=edges.edges,
            solution=Tuple(x), joint_residual=residual,
            conservation_residual=transfer.residual, interface_flux_residual=interface_residual,
            ledger_residual=edges.residual, assembly=assembled.assembly,
            k_hash=case.field.k_hash, boundary_hash=assembled.assembly.boundary_hash,
            mms_order=declared_spatial_mms_refinement(), receipt_hash=result_hash)
    catch err
        _dsc_failure(:fail_closed, :program_exception, sprint(showerror, err))
    end
end

"Manufactured positive case used by the focused test and independent oracle."
function manufactured_declared_spatial_case(; k_cells=[1.0, 2.0, 1.5, 0.8],
                                             source=[1.0, 0.0, -0.5, 0.75],
                                             boundary=DeclaredSpatialBoundaryV1(:dirichlet, 0.0, :dirichlet, 1.0),
                                             plan=nothing)
    old = DeclaredSpatialGeometryV1("old-2", [0.0, 0.5, 1.0]; cell_labels=["a", "b"])
    new = DeclaredSpatialGeometryV1("new-4", [0.0, 0.25, 0.5, 0.75, 1.0];
        cell_labels=["w", "x", "y", "z"])
    p = if plan === nothing
        DeclaredSpatialCompositionV1((
        DeclaredSpatialComponentV1("source-component", (DeclaredSpatialPortV1("source-out", :output, :source, "src", "source"; role=:source, magnitude=1.0, payload=Float64.(source)),)),
        DeclaredSpatialComponentV1("source-consumer", (DeclaredSpatialPortV1("source-in", :input, :source, "src", "source"; role=:source, magnitude=1.0, payload=Float64.(source)),)),
        DeclaredSpatialComponentV1("boundary-component", (DeclaredSpatialPortV1("boundary-out", :output, :field, "u", "boundary"; role=:boundary, magnitude=1.0, payload=(boundary.left_value, boundary.right_value)),)),
        DeclaredSpatialComponentV1("boundary-consumer", (DeclaredSpatialPortV1("boundary-in", :input, :field, "u", "boundary"; role=:boundary, magnitude=1.0, payload=(boundary.left_value, boundary.right_value)),)),
        DeclaredSpatialComponentV1("solver", (DeclaredSpatialPortV1("field-out", :output, :field, "u", "field"; role=:field, magnitude=1.0),)),
        DeclaredSpatialComponentV1("return", (DeclaredSpatialPortV1("field-in", :input, :field, "u", "field"; role=:field, magnitude=1.0),))))
    else
        plan
    end
    DeclaredSpatialCaseV1(old, new, [0.25, 0.75],
        DeclaredSpatialFieldV1(k_cells, source), boundary, p)
end
