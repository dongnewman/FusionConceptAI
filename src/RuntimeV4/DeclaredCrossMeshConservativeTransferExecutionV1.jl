"""Candidate-bound UP2 cross-mesh conservative transfer, V1.

This is an additive execution slice.  It consumes a real
`DeclaredG123InputV1`, derives a two-cell source and four-cell target mesh,
transfers a cell-integrated field by geometric overlap, and then runs a small
one-dimensional diffusion kernel on the target mesh.  The slice has no
registry or provider entry point and never changes an existing receipt.

The result is deliberately screen-only software evidence: `accepted` and both
UP/R credits are always false.  A mesh hash is bound to the real candidate,
source, declaration-body, and transport-bundle hashes; a display-only hash is
never accepted at this boundary.
"""

using LinearAlgebra

const DCM_SCHEMA_V1 = "fusionconceptai:runtime-v4:declared-cross-mesh-conservative-transfer-v1"
const DCM_REVISION_V1 = "up2-cross-mesh-conservative-transfer-v1-r1"
const DCM_CLAIM_CEILING_V1 = :screen_only
const DCM_STATUSES_V1 = (:ready, :fail_closed, :terminal_deferred, :numerical_fail)
const DCM_GEOMETRY_TOL_V1 = 1e-12
const DCM_CONSERVATION_TOL_V1 = 1e-12

_dcm_text(x, field) = begin
    x isa AbstractString || throw(ArgumentError("$field must be a string"))
    y = strip(String(x)); isempty(y) && throw(ArgumentError("$field cannot be empty")); y
end
_dcm_finite(x, field) = begin
    y = Float64(x); isfinite(y) || throw(ArgumentError("$field must be finite")); y
end
function _dcm_hash(x)
    isdefined(@__MODULE__, :canonical_hash) ||
        throw(ArgumentError("canonical authority unavailable"))
    try
        string(canonical_hash(x))
    catch
        throw(ArgumentError("canonical authority failure"))
    end
end
_dcm_safe_hash(x) = try _dcm_hash(x) catch; "" end

"A cell is an oriented one-dimensional control volume owned by one authority."
struct DeclaredCrossMeshCellV1
    cell_ref::String
    lower::Float64
    upper::Float64
    measure::Float64
    owner_ref::String
end

struct DeclaredCrossMeshIdentityV1
    candidate_ref::Any
    source_hash::String
    body_hash::String
    bundle_hash::String
    axis_hashes::NTuple{3,String}
end

struct DeclaredCrossMeshV1
    side::Symbol
    mesh_ref::String
    space_ref::String
    cells::Tuple{Vararg{DeclaredCrossMeshCellV1}}
    dof_ownership::Tuple{Vararg{String}}
    identity::DeclaredCrossMeshIdentityV1
    mesh_hash::String
end

struct DeclaredCrossMeshUnitV1
    name::String
    exponents::NTuple{7,Int}
    scale_to_si::Float64
end

struct DeclaredCrossMeshAccountV1
    account_ref::String
    side::Symbol
    unit::DeclaredCrossMeshUnitV1
    orientation::Symbol
    owner_ref::String
end

struct DeclaredCrossMeshAccountsV1
    source::DeclaredCrossMeshAccountV1
    target::DeclaredCrossMeshAccountV1
    external::Union{Nothing,DeclaredCrossMeshAccountV1}
    return_account::Union{Nothing,DeclaredCrossMeshAccountV1}
end

struct DeclaredCrossMeshTransferReceiptV1
    status::Symbol
    code::Symbol
    candidate_ref::Any
    source_hash::String
    body_hash::String
    bundle_hash::String
    source_mesh_hash::String
    target_mesh_hash::String
    source_integrated_total::Float64
    target_integrated_total::Float64
    local_defects::Tuple{Vararg{Float64}}
    interface_defects::Tuple{Vararg{Float64}}
    global_defect::Float64
    source_overlap_coverage::Float64
    target_overlap_coverage::Float64
    overlap_lengths::Matrix{Float64}
    overlap_proportions::Matrix{Float64}
    interface_faces::Tuple{Vararg{String}}
    interface_orientations::Tuple{Vararg{Symbol}}
    transferred_state::Union{Nothing,Tuple{Vararg{Float64}}}
    receipt_hash::String
end

struct DeclaredCrossMeshDiffusionReceiptV1
    status::Symbol
    code::Symbol
    matrix::Union{Nothing,Matrix{Float64}}
    rhs::Union{Nothing,Vector{Float64}}
    solution::Union{Nothing,Vector{Float64}}
    residual_norm::Float64
    solver_invocations::Int
    receipt_hash::String
end

struct DeclaredCrossMeshExecutionOutcomeV1
    schema::String
    revision::String
    status::Symbol
    code::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    screen_only::Bool
    formal_up2_credit::Bool
    formal_up_credit::Bool
    formal_r_credit::Bool
    no_up2::Bool
    candidate_ref::Any
    source_hash::String
    body_hash::String
    bundle_hash::String
    source_mesh_hash::String
    target_mesh_hash::String
    transfer::DeclaredCrossMeshTransferReceiptV1
    diffusion::DeclaredCrossMeshDiffusionReceiptV1
    provider_calls::Int
    mesh_calls::Int
    solver_invocations::Int
    receipt_hash::String
end

function DeclaredCrossMeshUnitV1(name, exponents=(0,0,0,0,0,0,0); scale_to_si=1.0)
    raw = Tuple(exponents); length(raw) == 7 || throw(ArgumentError("unit rank must be seven"))
    all(x -> x isa Integer, raw) || throw(ArgumentError("unit exponents must be integers"))
    scale = _dcm_finite(scale_to_si, "unit scale_to_si")
    scale > 0.0 || throw(ArgumentError("unit scale_to_si must be positive"))
    DeclaredCrossMeshUnitV1(_dcm_text(name, "unit name"), ntuple(i -> Int(raw[i]), 7),
        scale)
end

function DeclaredCrossMeshCellV1(cell_ref, lower, upper; measure=nothing, owner_ref)
    lo, hi = _dcm_finite(lower, "cell lower"), _dcm_finite(upper, "cell upper")
    hi > lo || throw(ArgumentError("cell measure must be positive"))
    # Keep an explicitly supplied zero/nonfinite measure representable so the
    # executable boundary can return a typed numerical_fail receipt instead
    # of throwing before the negative dispatch is observed.
    m = measure === nothing ? hi - lo : Float64(measure)
    DeclaredCrossMeshCellV1(_dcm_text(cell_ref, "cell_ref"), lo, hi, m,
        _dcm_text(owner_ref, "owner_ref"))
end

function _dcm_actual_hashes(input)
    hasproperty(input, :candidate_ref) && hasproperty(input, :hashes) ||
        throw(ArgumentError("declared G123 input is missing identity hashes"))
    # Re-run the existing byte-level admission when it is available.  This is
    # what prevents a hand-edited body hash from becoming a new identity.
    if isdefined(@__MODULE__, :dgd_input_v1) && all(hasproperty(input, f) for f in (:g1,:g2,:g3,:bundle))
        checked = dgd_input_v1(input.candidate_ref, input.g1, input.g2, input.g3, input.bundle)
        h0, h1 = input.hashes, checked.hashes
        (h0.candidate_ref == h1.candidate_ref &&
         h0.g1_body_hash == h1.g1_body_hash && h0.g2_body_hash == h1.g2_body_hash &&
         h0.g3_body_hash == h1.g3_body_hash && h0.bundle_hash == h1.bundle_hash) ||
            throw(ArgumentError("declared body/bundle hash mismatch"))
    end
    h = input.hashes
    for f in (:g1_body_hash, :g2_body_hash, :g3_body_hash, :bundle_hash)
        hasproperty(h, f) || throw(ArgumentError("missing hash field:$f"))
    end
    records = if hasproperty(input, :bundle) && hasproperty(input.bundle, :declarations)
        sort([r for r in input.bundle.declarations if hasproperty(r, :source_bytes)], by=r -> String(getproperty(r, :layer)))
    else
        Any[]
    end
    length(records) == 3 || throw(ArgumentError("axis/source declaration cardinality mismatch"))
    all(hasproperty(r, :axes) for r in records) || throw(ArgumentError("axis hashes missing"))
    layers = Tuple(getproperty(r, :layer) for r in records)
    layers == (:G1, :G2, :G3) || throw(ArgumentError("axis layer identity mismatch"))
    axis_hashes = Tuple(_dcm_hash(getproperty(r, :axes)) for r in records)
    source_hash = if !isempty(records)
        _dcm_hash(Tuple((layer=getproperty(r,:layer), source_ref=getproperty(r,:source_ref),
            source_sha256=getproperty(r,:source_bytes).sha256) for r in records))
    else
        _dcm_hash((g1=h.g1_body_hash, g2=h.g2_body_hash, g3=h.g3_body_hash))
    end
    body_hash = _dcm_hash((g1=h.g1_body_hash, g2=h.g2_body_hash, g3=h.g3_body_hash))
    (candidate_ref=input.candidate_ref, source_hash=source_hash, body_hash=body_hash,
        bundle_hash=string(h.bundle_hash), axis_hashes=axis_hashes)
end

function declared_cross_mesh_identity_v1(input)
    x = _dcm_actual_hashes(input)
    DeclaredCrossMeshIdentityV1(x.candidate_ref, x.source_hash, x.body_hash, x.bundle_hash,
        x.axis_hashes)
end

function _dcm_mesh_body(mesh::DeclaredCrossMeshV1)
    (side=mesh.side, mesh_ref=mesh.mesh_ref, space_ref=mesh.space_ref,
        cells=Tuple((c.cell_ref,c.lower,c.upper,c.measure,c.owner_ref) for c in mesh.cells),
        dof_ownership=mesh.dof_ownership, candidate_ref=mesh.identity.candidate_ref,
        source_hash=mesh.identity.source_hash, body_hash=mesh.identity.body_hash,
        bundle_hash=mesh.identity.bundle_hash, axis_hashes=mesh.identity.axis_hashes)
end

function declared_cross_mesh_v1(identity::DeclaredCrossMeshIdentityV1, side, mesh_ref,
        space_ref, edges; owners=nothing, cell_measures=nothing)
    side in (:source, :target) || throw(ArgumentError("mesh side must be source or target"))
    e = Tuple(_dcm_finite(v, "mesh edge") for v in edges)
    length(e) >= 2 && all(e[i+1] > e[i] for i in 1:length(e)-1) ||
        throw(ArgumentError("mesh edges must be strictly increasing"))
    n = length(e)-1
    owner_tuple = owners === nothing ? Tuple("owner:" * String(side) for _ in 1:n) : Tuple(String.(owners))
    length(owner_tuple) == n || throw(ArgumentError("DOF ownership cardinality mismatch"))
    cells = Tuple(begin
        cmeasure = cell_measures === nothing ? e[i+1]-e[i] : cell_measures[i]
        DeclaredCrossMeshCellV1("cell:" * String(side) * ":" * string(i), e[i], e[i+1];
            measure=cmeasure, owner_ref=owner_tuple[i])
    end for i in 1:n)
    mesh = DeclaredCrossMeshV1(side, _dcm_text(mesh_ref,"mesh_ref"),
        _dcm_text(space_ref,"space_ref"), cells, owner_tuple, identity, "")
    DeclaredCrossMeshV1(mesh.side, mesh.mesh_ref, mesh.space_ref, mesh.cells,
        mesh.dof_ownership, mesh.identity, _dcm_hash(_dcm_mesh_body(mesh)))
end

function _dcm_identity_match(input, identity::DeclaredCrossMeshIdentityV1)
    actual = _dcm_actual_hashes(input)
    identity.candidate_ref == actual.candidate_ref || return false, :candidate_mismatch
    identity.source_hash == actual.source_hash || return false, :source_hash_mismatch
    identity.body_hash == actual.body_hash || return false, :body_hash_mismatch
    identity.bundle_hash == actual.bundle_hash || return false, :bundle_hash_mismatch
    identity.axis_hashes == actual.axis_hashes || return false, :axis_hash_mismatch
    true, :identity_bound
end

_dcm_mesh_recompute(mesh::DeclaredCrossMeshV1) = _dcm_hash(_dcm_mesh_body(mesh))

_dcm_unit_equal(a,b) = a.name == b.name && a.exponents == b.exponents &&
    isequal(a.scale_to_si,b.scale_to_si)

_dcm_valid_unit(u) = isfinite(u.scale_to_si) && u.scale_to_si > 0.0
_dcm_valid_measure(c::DeclaredCrossMeshCellV1) =
    isfinite(c.measure) && c.measure > 0.0 &&
    isapprox(c.measure, c.upper - c.lower; rtol=0.0, atol=DCM_GEOMETRY_TOL_V1)

function _dcm_fail_transfer(code, input, source_mesh, target_mesh; status=:fail_closed)
    hashes = try _dcm_actual_hashes(input) catch; (candidate_ref=nothing,source_hash="",body_hash="",bundle_hash="",axis_hashes=("","","")) end
    source_mesh_hash = _dcm_safe_hash(try _dcm_mesh_body(source_mesh) catch; source_mesh.mesh_hash end)
    target_mesh_hash = _dcm_safe_hash(try _dcm_mesh_body(target_mesh) catch; target_mesh.mesh_hash end)
    h = _dcm_safe_hash((status=status,code=code,source_mesh=source_mesh_hash,target_mesh=target_mesh_hash))
    DeclaredCrossMeshTransferReceiptV1(status, code, hashes.candidate_ref, hashes.source_hash,
        hashes.body_hash, hashes.bundle_hash, source_mesh_hash, target_mesh_hash,
        0.0, 0.0, (), (), status === :numerical_fail ? Inf : 0.0, 0.0, 0.0,
        zeros(0,0), zeros(0,0), (), (), nothing, h)
end

function _dcm_transfer_impl_v1(input, identity::DeclaredCrossMeshIdentityV1,
        source_mesh::DeclaredCrossMeshV1, target_mesh::DeclaredCrossMeshV1,
        source_state; accounts=nothing)
    ok, code = _dcm_identity_match(input, identity)
        ok || return _dcm_fail_transfer(code, input, source_mesh, target_mesh)
        source_mesh_hash = _dcm_mesh_recompute(source_mesh)
        target_mesh_hash = _dcm_mesh_recompute(target_mesh)
        source_mesh.mesh_hash == source_mesh_hash && target_mesh.mesh_hash == target_mesh_hash ||
            return _dcm_fail_transfer(:mesh_hash_mismatch,input,source_mesh,target_mesh)
        source_mesh.side === :source && target_mesh.side === :target ||
            return _dcm_fail_transfer(:mesh_side_mismatch,input,source_mesh,target_mesh)
        source_mesh.space_ref == target_mesh.space_ref ||
            return _dcm_fail_transfer(:space_mismatch,input,source_mesh,target_mesh)
        source_mesh.identity == target_mesh.identity ||
            return _dcm_fail_transfer(:mesh_identity_mismatch,input,source_mesh,target_mesh)
        x = Tuple(Float64(v) for v in source_state)
        length(x) == length(source_mesh.cells) || return _dcm_fail_transfer(:state_shape_mismatch,input,source_mesh,target_mesh)
        all(isfinite,x) || return _dcm_fail_transfer(:nonfinite_state,input,source_mesh,target_mesh; status=:numerical_fail)
        accounts === nothing && return _dcm_fail_transfer(:missing_external_return_account,input,source_mesh,target_mesh; status=:terminal_deferred)
        accounts isa DeclaredCrossMeshAccountsV1 || return _dcm_fail_transfer(:account_type_mismatch,input,source_mesh,target_mesh)
        accounts.source.side === :source && accounts.target.side === :target ||
            return _dcm_fail_transfer(:orientation_mismatch,input,source_mesh,target_mesh)
        accounts.source.orientation === :minus && accounts.target.orientation === :plus ||
            return _dcm_fail_transfer(:orientation_mismatch,input,source_mesh,target_mesh)
        accounts.source.owner_ref in source_mesh.dof_ownership && accounts.target.owner_ref in target_mesh.dof_ownership ||
            return _dcm_fail_transfer(:owner_mismatch,input,source_mesh,target_mesh)
        _dcm_valid_unit(accounts.source.unit) && _dcm_valid_unit(accounts.target.unit) ||
            return _dcm_fail_transfer(:invalid_unit_scale,input,source_mesh,target_mesh)
        _dcm_unit_equal(accounts.source.unit,accounts.target.unit) ||
            return _dcm_fail_transfer(:unit_mismatch,input,source_mesh,target_mesh)
        accounts.external !== nothing && accounts.return_account !== nothing ||
            return _dcm_fail_transfer(:missing_external_return_account,input,source_mesh,target_mesh; status=:terminal_deferred)
        source_mesh.dof_ownership == Tuple(c.owner_ref for c in source_mesh.cells) ||
            return _dcm_fail_transfer(:owner_mismatch,input,source_mesh,target_mesh)
        target_mesh.dof_ownership == Tuple(c.owner_ref for c in target_mesh.cells) ||
            return _dcm_fail_transfer(:owner_mismatch,input,source_mesh,target_mesh)
        finite_positive_measures = all(isfinite(c.measure) && c.measure > 0.0 for c in source_mesh.cells) &&
            all(isfinite(c.measure) && c.measure > 0.0 for c in target_mesh.cells)
        finite_positive_measures || return _dcm_fail_transfer(:zero_or_nonfinite_measure,input,source_mesh,target_mesh; status=:numerical_fail)
        valid_measures = all(_dcm_valid_measure, source_mesh.cells) &&
            all(_dcm_valid_measure, target_mesh.cells)
        valid_measures || return _dcm_fail_transfer(:mismatched_measure,input,source_mesh,target_mesh)
        old_measure = sum(c.measure for c in source_mesh.cells)
        new_measure = sum(c.measure for c in target_mesh.cells)
        isfinite(old_measure) && isfinite(new_measure) && old_measure > 0 && new_measure > 0 ||
            return _dcm_fail_transfer(:zero_or_nonfinite_measure,input,source_mesh,target_mesh; status=:numerical_fail)
        overlap = zeros(Float64, length(source_mesh.cells), length(target_mesh.cells))
        for (i,sc) in enumerate(source_mesh.cells), (j,tc) in enumerate(target_mesh.cells)
            overlap[i,j] = max(0.0, min(sc.upper,tc.upper)-max(sc.lower,tc.lower))
        end
        source_coverage = sum(overlap) / old_measure
        target_coverage = sum(overlap) / new_measure
        all(isfinite,(source_coverage,target_coverage)) ||
            return _dcm_fail_transfer(:nonfinite_overlap,input,source_mesh,target_mesh; status=:numerical_fail)
        coverage_ok = isapprox(source_coverage, 1.0; rtol=0.0, atol=DCM_GEOMETRY_TOL_V1) &&
            isapprox(target_coverage, 1.0; rtol=0.0, atol=DCM_GEOMETRY_TOL_V1)
        coverage_ok || begin
            coverage_code = source_coverage > 1.0 + DCM_GEOMETRY_TOL_V1 ||
                target_coverage > 1.0 + DCM_GEOMETRY_TOL_V1 ?
                :overcovering_overlap : :noncovering_overlap
            return _dcm_fail_transfer(coverage_code,input,source_mesh,target_mesh;
                status=:terminal_deferred)
        end
        y = Float64[sum(overlap[i,j]*x[i] for i in axes(overlap,1))/target_mesh.cells[j].measure
            for j in axes(overlap,2)]
        source_total = sum(x[i]*source_mesh.cells[i].measure for i in eachindex(x))
        target_total = sum(y[j]*target_mesh.cells[j].measure for j in eachindex(y))
        local = Tuple(target_mesh.cells[j].measure*y[j] - sum(overlap[i,j]*x[i] for i in axes(overlap,1)) for j in axes(overlap,2))
        # Interface defects are signed account jumps at source cell boundaries.
        interface_faces = Tuple(string(source_mesh.cells[j].upper) * ":" *
            source_mesh.cells[j].owner_ref * "->" * source_mesh.cells[j+1].owner_ref
            for j in 1:max(0,length(source_mesh.cells)-1))
        interface_orientations = Tuple(accounts.source.orientation === :minus ? :minus_to_plus : :plus_to_minus
            for _ in 1:max(0,length(source_mesh.cells)-1))
        # Recompute each face defect from the geometric crossing target cells,
        # their owner pair, and the typed account orientation.  It is not a
        # cumulative sum of local defects and therefore remains an independent
        # interface witness.
        interface = Tuple(begin
            face = source_mesh.cells[j].upper
            crossing = sum(target_mesh.cells[q].measure*y[q]
                for q in eachindex(target_mesh.cells)
                if target_mesh.cells[q].lower < face < target_mesh.cells[q].upper)
            signed = sum(overlap[i,q]*x[i] for i in axes(overlap,1), q in eachindex(target_mesh.cells)
                if target_mesh.cells[q].lower < face < target_mesh.cells[q].upper)
            orientation_sign = accounts.source.orientation === :minus ? 1.0 : -1.0
            orientation_sign * (crossing - signed)
        end for j in 1:max(0,length(source_mesh.cells)-1))
        global = target_total-source_total
        all(isfinite, (source_total,target_total,global)) ||
            return _dcm_fail_transfer(:nonfinite_derived,input,source_mesh,target_mesh; status=:numerical_fail)
        abs(global) <= DCM_CONSERVATION_TOL_V1 ||
            return _dcm_fail_transfer(:conservation_defect,input,source_mesh,target_mesh)
        hashes = _dcm_actual_hashes(input)
        body = (status=:ready,code=:conservative_cross_mesh_transfer,candidate=hashes.candidate_ref,
            source_hash=hashes.source_hash,body_hash=hashes.body_hash,bundle_hash=hashes.bundle_hash,
            source_mesh=source_mesh_hash,target_mesh=target_mesh_hash,
            source_total=source_total,target_total=target_total,local=local,interface=interface,
            interface_faces=interface_faces,interface_orientations=interface_orientations,
            global=global,source_coverage=source_coverage,target_coverage=target_coverage,
            overlap=overlap,proportions=overlap ./ reshape([c.measure for c in target_mesh.cells],1,:),state=Tuple(y))
        DeclaredCrossMeshTransferReceiptV1(:ready,:conservative_cross_mesh_transfer,hashes.candidate_ref,
            hashes.source_hash,hashes.body_hash,hashes.bundle_hash,source_mesh_hash,target_mesh_hash,
            source_total,target_total,local,interface,global,source_coverage,target_coverage,
            overlap,overlap ./ reshape([c.measure for c in target_mesh.cells],1,:),interface_faces,
            interface_orientations,Tuple(y),_dcm_hash(body))
end

# Keep exception normalization at the public boundary so the transfer body has
# no open try block while its arithmetic is being edited or reviewed.
function declared_cross_mesh_transfer_v1(input, identity::DeclaredCrossMeshIdentityV1,
        source_mesh::DeclaredCrossMeshV1, target_mesh::DeclaredCrossMeshV1,
        source_state; accounts=nothing)
    try
        _dcm_transfer_impl_v1(input, identity, source_mesh, target_mesh, source_state;
            accounts=accounts)
    catch err
        error_text = lowercase(string(err))
        code = occursin("unit", error_text) ? :unit_mismatch :
            occursin("owner", error_text) ? :owner_mismatch : :transfer_program_exception
        status = occursin("nonfinite", error_text) || occursin("measure", error_text) ?
            :numerical_fail : :fail_closed
        _dcm_fail_transfer(code, input, source_mesh, target_mesh; status=status)
    end
end

function _dcm_diffusion_kernel_v1(mesh::DeclaredCrossMeshV1, state, left_boundary, right_boundary)
    n = length(mesh.cells); n == length(state) || return DeclaredCrossMeshDiffusionReceiptV1(:fail_closed,:state_shape_mismatch,nothing,nothing,nothing,Inf,0,_dcm_safe_hash(:state_shape_mismatch))
    all(isfinite, state) || return DeclaredCrossMeshDiffusionReceiptV1(:numerical_fail,:nonfinite_state,nothing,nothing,nothing,Inf,0,_dcm_safe_hash(:nonfinite_state))
    all(c.measure > 0 && isfinite(c.measure) for c in mesh.cells) || return DeclaredCrossMeshDiffusionReceiptV1(:numerical_fail,:zero_or_nonfinite_measure,nothing,nothing,nothing,Inf,0,_dcm_safe_hash(:zero_or_nonfinite_measure))
    all(_dcm_valid_measure, mesh.cells) || return DeclaredCrossMeshDiffusionReceiptV1(:fail_closed,:mismatched_measure,nothing,nothing,nothing,Inf,0,_dcm_safe_hash(:mismatched_measure))
    A=zeros(Float64,n,n); b=zeros(Float64,n); k=1.0
    for i in 1:n
        h=mesh.cells[i].measure
        if i == 1
            A[i,i]+=k/h; b[i]+=k*Float64(left_boundary)/h
        else
            g=k/(0.5*(mesh.cells[i-1].measure+h)); A[i,i]+=g; A[i,i-1]-=g
        end
        if i == n
            A[i,i]+=k/h; b[i]+=k*Float64(right_boundary)/h
        else
            g=k/(0.5*(h+mesh.cells[i+1].measure)); A[i,i]+=g; A[i,i+1]-=g
        end
        b[i]+=Float64(state[i])
    end
    (!all(isfinite,A) || !all(isfinite,b)) && return DeclaredCrossMeshDiffusionReceiptV1(:numerical_fail,:nonfinite_derived,A,b,nothing,Inf,1,_dcm_safe_hash(:nonfinite_derived))
    det = n == 1 ? A[1,1] : det(A)
    isfinite(det) && abs(det)>1e-14 || return DeclaredCrossMeshDiffusionReceiptV1(:numerical_fail,:singular_matrix,A,b,nothing,Inf,1,_dcm_safe_hash((A=A,b=b)))
    sol = A \ b; all(isfinite,sol) || return DeclaredCrossMeshDiffusionReceiptV1(:numerical_fail,:nonfinite_solution,A,b,nothing,Inf,1,_dcm_safe_hash((A=A,b=b)))
    residual=norm(A*sol-b)
    DeclaredCrossMeshDiffusionReceiptV1(:ready,:one_dimensional_diffusion_solved,A,b,sol,residual,1,_dcm_hash((A=A,b=b,solution=sol,residual=residual,mesh=mesh.mesh_hash)))
end

function _dcm_invalid_outcome(code, input=nothing)
    c = input === nothing ? nothing : (hasproperty(input,:candidate_ref) ? input.candidate_ref : nothing)
    h = _dcm_safe_hash((status=:fail_closed,code=code,candidate=c))
    t = DeclaredCrossMeshTransferReceiptV1(:fail_closed,code,c,"","","","","",0.0,0.0,(),(),0.0,0.0,0.0,zeros(0,0),zeros(0,0),(),(),nothing,h)
    d = DeclaredCrossMeshDiffusionReceiptV1(:fail_closed,code,nothing,nothing,nothing,Inf,0,h)
    DeclaredCrossMeshExecutionOutcomeV1(DCM_SCHEMA_V1,DCM_REVISION_V1,:fail_closed,code,false,
        DCM_CLAIM_CEILING_V1,true,false,false,false,true,c,"","","","", "",t,d,0,0,0,h)
end

"Run transfer and then the existing algorithmic 1-D diffusion pattern."
function execute_declared_cross_mesh_v1(input, identity, source_mesh, target_mesh, source_state;
        accounts=nothing, left_boundary=0.0, right_boundary=1.0)
    try
        transfer=declared_cross_mesh_transfer_v1(input,identity,source_mesh,target_mesh,source_state;accounts=accounts)
        transfer.status === :ready || begin
            d=DeclaredCrossMeshDiffusionReceiptV1(transfer.status,transfer.code,nothing,nothing,nothing,Inf,0,_dcm_safe_hash(transfer.receipt_hash))
            return DeclaredCrossMeshExecutionOutcomeV1(DCM_SCHEMA_V1,DCM_REVISION_V1,transfer.status,transfer.code,false,DCM_CLAIM_CEILING_V1,true,false,false,false,true,transfer.candidate_ref,transfer.source_hash,transfer.body_hash,transfer.bundle_hash,transfer.source_mesh_hash,transfer.target_mesh_hash,transfer,d,0,0,0,_dcm_safe_hash((transfer=transfer.receipt_hash)))
        end
        diffusion=_dcm_diffusion_kernel_v1(target_mesh,transfer.transferred_state,left_boundary,right_boundary)
        status=diffusion.status; code=diffusion.code
        h=_dcm_hash((status=status,code=code,transfer=transfer.receipt_hash,diffusion=diffusion.receipt_hash))
        DeclaredCrossMeshExecutionOutcomeV1(DCM_SCHEMA_V1,DCM_REVISION_V1,status,code,false,DCM_CLAIM_CEILING_V1,true,false,false,false,true,transfer.candidate_ref,transfer.source_hash,transfer.body_hash,transfer.bundle_hash,transfer.source_mesh_hash,transfer.target_mesh_hash,transfer,diffusion,0,0,diffusion.solver_invocations,h)
    catch err
        _dcm_invalid_outcome(occursin("candidate",lowercase(string(err))) ? :candidate_mismatch : :program_exception,input)
    end
end
