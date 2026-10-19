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
using SparseArrays

const DCM_SCHEMA_V1 = "fusionconceptai:runtime-v4:declared-cross-mesh-conservative-transfer-v1"
const DCM_REVISION_V1 = "up2-cross-mesh-conservative-transfer-v1-r1"
const DCM_CLAIM_CEILING_V1 = :screen_only
const DCM_STATUSES_V1 = (:ready, :fail_closed, :terminal_deferred, :numerical_fail)
const DCM_GEOMETRY_TOL_V1 = 1e-12
const DCM_CONSERVATION_TOL_V1 = 1e-12
const DCM_B02_SUGGESTED_SCALED_DEFECT_V1 = 1e-10 # recommended protocol only; not frozen for this campaign

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
        local_defects = Tuple(target_mesh.cells[j].measure*y[j] -
            sum(overlap[i,j]*x[i] for i in axes(overlap,1))
            for j in axes(overlap,2))
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
                if target_mesh.cells[q].lower < face < target_mesh.cells[q].upper;
                init=0.0)
            signed = sum(overlap[i,q]*x[i] for i in axes(overlap,1), q in eachindex(target_mesh.cells)
                if target_mesh.cells[q].lower < face < target_mesh.cells[q].upper;
                init=0.0)
            orientation_sign = accounts.source.orientation === :minus ? 1.0 : -1.0
            orientation_sign * (crossing - signed)
        end for j in 1:max(0,length(source_mesh.cells)-1))
        global_defect = target_total-source_total
        all(isfinite, (source_total,target_total,global_defect)) ||
            return _dcm_fail_transfer(:nonfinite_derived,input,source_mesh,target_mesh; status=:numerical_fail)
        abs(global_defect) <= DCM_CONSERVATION_TOL_V1 ||
            return _dcm_fail_transfer(:conservation_defect,input,source_mesh,target_mesh)
        hashes = _dcm_actual_hashes(input)
        body = (status=:ready,code=:conservative_cross_mesh_transfer,candidate=hashes.candidate_ref,
            source_hash=hashes.source_hash,body_hash=hashes.body_hash,bundle_hash=hashes.bundle_hash,
            source_mesh=source_mesh_hash,target_mesh=target_mesh_hash,
            source_total=source_total,target_total=target_total,local_defects=local_defects,
            interface=interface,
            interface_faces=interface_faces,interface_orientations=interface_orientations,
            global_defect=global_defect,source_coverage=source_coverage,target_coverage=target_coverage,
            overlap=overlap,proportions=overlap ./ reshape([c.measure for c in target_mesh.cells],1,:),state=Tuple(y))
        DeclaredCrossMeshTransferReceiptV1(:ready,:conservative_cross_mesh_transfer,hashes.candidate_ref,
            hashes.source_hash,hashes.body_hash,hashes.bundle_hash,source_mesh_hash,target_mesh_hash,
            source_total,target_total,local_defects,interface,global_defect,source_coverage,target_coverage,
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
    matrix_det = n == 1 ? A[1,1] : LinearAlgebra.det(A)
    isfinite(matrix_det) && abs(matrix_det)>1e-14 || return DeclaredCrossMeshDiffusionReceiptV1(:numerical_fail,:singular_matrix,A,b,nothing,Inf,1,_dcm_safe_hash((A=A,b=b)))
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
            return DeclaredCrossMeshExecutionOutcomeV1(DCM_SCHEMA_V1,DCM_REVISION_V1,transfer.status,transfer.code,false,DCM_CLAIM_CEILING_V1,true,false,false,false,true,transfer.candidate_ref,transfer.source_hash,transfer.body_hash,transfer.bundle_hash,transfer.source_mesh_hash,transfer.target_mesh_hash,transfer,d,0,0,0,_dcm_safe_hash((; transfer=transfer.receipt_hash)))
        end
        diffusion=_dcm_diffusion_kernel_v1(target_mesh,transfer.transferred_state,left_boundary,right_boundary)
        status=diffusion.status; code=diffusion.code
        h=_dcm_hash((status=status,code=code,transfer=transfer.receipt_hash,diffusion=diffusion.receipt_hash))
        DeclaredCrossMeshExecutionOutcomeV1(DCM_SCHEMA_V1,DCM_REVISION_V1,status,code,false,DCM_CLAIM_CEILING_V1,true,false,false,false,true,transfer.candidate_ref,transfer.source_hash,transfer.body_hash,transfer.bundle_hash,transfer.source_mesh_hash,transfer.target_mesh_hash,transfer,diffusion,0,0,diffusion.solver_invocations,h)
    catch err
        _dcm_invalid_outcome(occursin("candidate",lowercase(string(err))) ? :candidate_mismatch : :program_exception,input)
    end
end

"""Locate a point on an R-major, Z-fast tensor grid and return Q1 weights."""
function _dcm_q1_location_v1(Raxis, Zaxis, R, Z)
    nr, nz = length(Raxis), length(Zaxis)
    nr >= 2 && nz >= 2 || throw(ArgumentError("axisymmetric source grid needs at least 2x2 nodes"))
    all(i -> Raxis[i+1] > Raxis[i], 1:nr-1) || throw(ArgumentError("R axis must increase"))
    all(j -> Zaxis[j+1] > Zaxis[j], 1:nz-1) || throw(ArgumentError("Z axis must increase"))
    Raxis[1] <= R <= Raxis[end] && Zaxis[1] <= Z <= Zaxis[end] ||
        throw(ArgumentError("target point lies outside source geometry"))
    i = min(searchsortedlast(Raxis, R), nr-1)
    j = min(searchsortedlast(Zaxis, Z), nz-1)
    a = (R-Raxis[i])/(Raxis[i+1]-Raxis[i]); b = (Z-Zaxis[j])/(Zaxis[j+1]-Zaxis[j])
    ids = ((i-1)*nz+j, (i-1)*nz+j+1, i*nz+j, i*nz+j+1)
    w = ((1-a)*(1-b), (1-a)*b, a*(1-b), a*b)
    ids, w
end

function _dcm_axis_derivative_v1(f, axis, i, j, nr, nz, along_R)
    count = along_R ? nr : nz; k = along_R ? i : j
    count >= 2 || throw(ArgumentError("derivative axis needs at least two nodes"))
    lo, hi = k == 1 ? (1,2) : k == count ? (count-1,count) : (k-1,k+1)
    if along_R
        f_lo=f[(lo-1)*nz+j]; f_hi=f[(hi-1)*nz+j]
    else
        f_lo=f[(i-1)*nz+lo]; f_hi=f[(i-1)*nz+hi]
    end
    (f_hi-f_lo)/(axis[hi]-axis[lo])
end

function _dcm_trap_weights_v1(axis)
    n=length(axis); w=zeros(Float64,n)
    for i in 1:n-1
        h=axis[i+1]-axis[i]
        w[i]+=h/2; w[i+1]+=h/2
    end
    w
end

function _dcm_pressure_integral_v1(Raxis,Zaxis,mask,p)
    weights=_dcm_volume_weights_v1(Raxis,Zaxis)
    sum(mask[k] ? weights[k]*p[k] : 0.0 for k in eachindex(weights))
end

function _dcm_volume_weights_v1(Raxis,Zaxis)
    nr,nz=length(Raxis),length(Zaxis)
    nr>=2 && nz>=2 || throw(ArgumentError("axisymmetric finite-volume axes need at least two points"))
    radial=zeros(Float64,nr)
    for i in 1:nr
        lo=i==1 ? Raxis[1] : (Raxis[i-1]+Raxis[i])/2
        hi=i==nr ? Raxis[nr] : (Raxis[i]+Raxis[i+1])/2
        lo>0 && hi>lo || throw(ArgumentError("invalid radial control volume"))
        radial[i]=pi*(hi^2-lo^2)
    end
    vertical=zeros(Float64,nz)
    for j in 1:nz
        lo=j==1 ? Zaxis[1] : (Zaxis[j-1]+Zaxis[j])/2
        hi=j==nz ? Zaxis[nz] : (Zaxis[j]+Zaxis[j+1])/2
        hi>lo || throw(ArgumentError("invalid vertical control volume"))
        vertical[j]=hi-lo
    end
    Float64[radial[i]*vertical[j] for i in 1:nr,j in 1:nz] |> vec
end

"""Euclidean active-set projection onto one weighted integral and p >= 0."""
function _dcm_nonnegative_integral_projection_v1(p,weights,total)
    length(p)==length(weights) || throw(DimensionMismatch("pressure projection weights"))
    all(isfinite,p) && all(isfinite,weights) && all(>(0),weights) && isfinite(total) && total>=0 ||
        throw(ArgumentError("invalid pressure projection data"))
    out=Float64.(p); free=trues(length(out)); iterations=0
    for _ in 1:length(out)+1
        iterations+=1
        ids=findall(free)
        if isempty(ids)
            abs(total)<=eps(Float64) &&
                return (values=out,iterations=iterations,active=Tuple(findall(.!free)),defect=0.0)
            throw(ArgumentError("nonnegative pressure conservation constraint is infeasible"))
        end
        denom=sum(abs2,weights[ids]); denom>0 || throw(ArgumentError("pressure projection has zero free weight"))
        lambda=(total-dot(weights[.!free],out[.!free])-dot(weights[ids],out[ids]))/denom
        trial=out[ids].+lambda.*weights[ids]
        bad=findall(x->x<0.0,trial)
        if isempty(bad)
            out[ids]=trial
            defect=dot(weights,out)-total
            return (values=out,iterations=iterations,active=Tuple(findall(.!free)),defect=defect)
        end
        # Clamp one most-negative component per pass, preserving deterministic active-set order.
        local_bad=bad[argmin(trial[bad])]; out[ids[local_bad]]=0.0; free[ids[local_bad]]=false
    end
    throw(ArgumentError("pressure active-set projection did not terminate"))
end

function _dcm_derivative_matrix_v1(axis,nr,nz,along_R)
    n=nr*nz; rows=Int[]; cols=Int[]; vals=Float64[]
    for i in 1:nr,j in 1:nz
        k=(i-1)*nz+j
        ids,denom=if along_R
            lo=max(1,i-1); hi=min(nr,i+1); ((lo-1)*nz+j,(hi-1)*nz+j),axis[hi]-axis[lo]
        else
            lo=max(1,j-1); hi=min(nz,j+1); ((i-1)*nz+lo,(i-1)*nz+hi),axis[hi]-axis[lo]
        end
        push!(rows,k);push!(cols,ids[1]);push!(vals,-1/denom)
        push!(rows,k);push!(cols,ids[2]);push!(vals,1/denom)
    end
    sparse(rows,cols,vals,n,n)
end

function _dcm_psi_current_row_v1(Raxis,Zaxis,mask,mu0)
    nr,nz=length(Raxis),length(Zaxis); n=nr*nz
    Dr=_dcm_derivative_matrix_v1(Raxis,nr,nz,true); Dz=_dcm_derivative_matrix_v1(Zaxis,nr,nz,false)
    invR=spdiagm(0=>repeat(1.0 ./ Raxis,inner=nz))
    wr=_dcm_trap_weights_v1(Raxis); wz=_dcm_trap_weights_v1(Zaxis)
    w=Float64[mask[(i-1)*nz+j] ? wr[i]*wz[j] : 0.0 for i in 1:nr,j in 1:nz] |> vec
    vec(transpose(w)*(Dz*(-invR*Dz)-Dr*(invR*Dr))/mu0)
end

"""Bounded FD audit of the exact native profile/pressure residual Jacobian."""
function declared_native_profile_fd_probe_v1(profile_evaluator,data,state,evaluated;columns=nothing)
    y=Float64.(collect(state)); J=evaluated.jacobian
    cols=columns===nothing ? unique(filter(c->1<=c<=length(y),
        [1,2,3,4,4*div(length(y),4),length(y)])) : Int.(collect(columns))
    isempty(cols) && throw(ArgumentError("FD probe needs at least one state column"))
    rows=NamedTuple[]
    for c in cols
        1<=c<=length(y) || throw(BoundsError(y,c))
        h=cbrt(eps(Float64))*(1+abs(y[c]))
        yp=copy(y);ym=copy(y);yp[c]+=h;ym[c]-=h
        ep=profile_evaluator(data,Tuple(yp));em=profile_evaluator(data,Tuple(ym))
        ep.status===:evaluated_full_native_F_and_core_pressure_rows &&
            em.status===:evaluated_full_native_F_and_core_pressure_rows ||
            throw(ArgumentError("native residual FD perturbation failed at state column $c"))
        length(ep.residual)==length(evaluated.residual) && length(em.residual)==length(evaluated.residual) &&
            all(isfinite,ep.residual) && all(isfinite,em.residual) ||
            throw(ArgumentError("native residual FD perturbation returned invalid residual values"))
        fd=(Float64.(ep.residual).-Float64.(em.residual))./(2h)
        analytic=Float64.(J[:,c]);delta=fd.-analytic
        push!(rows,(column=c,step=h,max_abs_difference=maximum(abs,delta),
            relative_l2_difference=norm(delta)/max(norm(fd),norm(analytic),eps(Float64)),
            fd_l2=norm(fd),jacobian_column_l2=norm(analytic)))
    end
    (status=:evaluated_native_profile_residual_jacobian_fd,columns=Tuple(rows),
        acceptance=:diagnostic_only_fd_tolerance_unfrozen)
end

"""Call the existing global CoupledMHD assembly and solve interfaces.

This adapter builds no model, closures, or acceptance policy. Missing physical
closures remain the solver's typed-absent result.
"""
function declared_axisymmetric_global_consumer_v1(solver_module, model, state,
        policy; expected_candidate_hash)
    try
        expected_candidate_hash isa AbstractString &&
            occursin(r"^[0-9a-f]{64}$", expected_candidate_hash) ||
            throw(ArgumentError("an explicit candidate SHA-256 is required"))
        hasproperty(model, :candidate_hash) &&
            String(model.candidate_hash) == expected_candidate_hash ||
            throw(ArgumentError("global consumer candidate identity mismatch"))
        state_vector = vec(Float64.(collect(state)))
        !isempty(state_vector) && all(isfinite, state_vector) ||
            throw(ArgumentError("global consumer state must be nonempty and finite"))
        isdefined(solver_module, :assemble_coupled_mhd_global_v1) &&
            isdefined(solver_module, :solve_coupled_mhd_global_v1) ||
            throw(ArgumentError("existing global MHD assembly/solve API is unavailable"))
        assemble = getproperty(solver_module, :assemble_coupled_mhd_global_v1)(model, state_vector)
        solved = getproperty(solver_module, :solve_coupled_mhd_global_v1)(model, state_vector, policy)
        (status=assemble.status === :assembled ?
                (solved.status === :converged ? :evaluated_screen_only : solved.status) : assemble.status,
            invocation=:existing_inhouse_coupled_mhd_global_assembly_and_solve_v1,
            candidate_hash=expected_candidate_hash,
            state_dofs=length(state_vector),
            remapped_state_sha256=_dcm_hash(Tuple(state_vector)),
            model_hash=hasproperty(model,:model_hash) ? model.model_hash : nothing,
            policy_hash=hasproperty(policy,:policy_hash) ? policy.policy_hash : nothing,
            policy_acceptance_ref=hasproperty(policy,:acceptance_ref) ? policy.acceptance_ref : nothing,
            assembly_status=assemble.status,
            assembly_missing_closures=hasproperty(assemble,:missing_closures) ? assemble.missing_closures : (),
            solver_status=solved.status,
            solver_missing_closures=hasproperty(solved,:missing_closures) ? solved.missing_closures : (),
            physical_authority=false, engineering_authority=false,
            acceptance=:diagnostics_only_campaign_budget_unfrozen)
    catch err
        (status=:fail_closed, invocation=:existing_inhouse_coupled_mhd_global_assembly_and_solve_v1,
            reason=sprint(showerror,err), physical_authority=false,
            acceptance=:not_evaluated)
    end
end

function _dcm_toroidal_current_v1(Raxis,Zaxis,mask,Br,Bz,mu0)
    wr=_dcm_trap_weights_v1(Raxis); wz=_dcm_trap_weights_v1(Zaxis); nr=length(Raxis);nz=length(Zaxis)
    J= zeros(Float64,nr*nz)
    for i in 1:nr,j in 1:nz
        k=(i-1)*nz+j
        dBr_dZ=_dcm_axis_derivative_v1(Br,Zaxis,i,j,nr,nz,false)
        dBz_dR=_dcm_axis_derivative_v1(Bz,Raxis,i,j,nr,nz,true)
        J[k]=(dBr_dZ-dBz_dR)/mu0
    end
    # Axisymmetric toroidal plasma current is I_p = integral(J_phi dR dz).
    # The 2πR Jacobian belongs to volume/energy integrals and would give A·m,
    # not amperes, for this meridional current integral.
    integral=sum(mask[(i-1)*nz+j] ?
        wr[i]*wz[j]*J[(i-1)*nz+j] : 0.0
        for i in 1:nr,j in 1:nz)
    (density=J,integral_A=integral)
end

function _dcm_axisymmetric_divergence_v1(Raxis,Zaxis,Br,Bz)
    nr=length(Raxis);nz=length(Zaxis);div=zeros(Float64,nr*nz)
    for i in 1:nr,j in 1:nz
        k=(i-1)*nz+j
        div[k]=_dcm_axis_derivative_v1(Br,Raxis,i,j,nr,nz,true)+Br[k]/Raxis[i]+
            _dcm_axis_derivative_v1(Bz,Zaxis,i,j,nr,nz,false)
    end
    (max_abs_T_per_m=maximum(abs,div),RMS_T_per_m=sqrt(sum(abs2,div)/length(div)),values=div)
end

function _dcm_axisymmetric_production_divB_v1(Raxis,Zaxis,Br,Bz)
    nr=length(Raxis);nz=length(Zaxis)
    nr>=3 && nz>=3 || return (status=:typed_absent,reason=:no_five_point_interior,rows=())
    rows=NamedTuple[]
    for i in 2:nr-1,j in 2:nz-1
        k=(i-1)*nz+j
        # Use each row's own neighbor coordinates, as
        # CandidateCoupledPhysicsV4._ccp_axisymmetric_mhd_stencil does; a
        # global mean spacing hides near-uniform grid defects.
        dr=(Raxis[i+1]-Raxis[i-1])/2;dz=(Zaxis[j+1]-Zaxis[j-1])/2
        divB=(Br[k+nz]-Br[k-nz])/(2dr)+Br[k]/Raxis[i]+(Bz[k+1]-Bz[k-1])/(2dz)
        R,Z=Raxis[i],Zaxis[j]
        points=((R,Z),(Raxis[i-1],Z),(Raxis[i+1],Z),
            (R,Zaxis[j-1]),(R,Zaxis[j+1]))
        tol=32eps(Float64)*max(1.0,maximum(abs,Iterators.flatten(points)))
        production_stencil_accepted=all(point->point[1]>0,points) && dr>tol && dz>tol &&
            abs(points[2][1]-(R-dr))<=tol && abs(points[3][1]-(R+dr))<=tol &&
            abs(points[2][2]-Z)<=tol && abs(points[3][2]-Z)<=tol &&
            abs(points[4][1]-R)<=tol && abs(points[5][1]-R)<=tol &&
            abs(points[4][2]-(Z-dz))<=tol && abs(points[5][2]-(Z+dz))<=tol
        push!(rows,(i=i,j=j,flat_index=k,dr_m=dr,dz_m=dz,
            production_stencil_accepted=production_stencil_accepted,divB_T_per_m=divB))
    end
    (status=:evaluated,operator=:five_point_centered_cylindrical_divB,
        production_stencil_accepted=all(row.production_stencil_accepted for row in rows),
        rows=Tuple(rows))
end

"""
    declared_axisymmetric_remesh_v1(domain, state, Rtarget, Ztarget, target_mask;
        candidate_identity, profile_evaluator)

Remap the production axisymmetric `(Br,D-or-Bphi,Bz,psi)` nodal state and
pressure onto an explicitly supplied target R/Z tensor mesh, then invoke the
caller-supplied original profile/current residual evaluator on the rebuilt
profile data.  The callback is required: this routine never represents a
remap-only result as a physics evaluation.  It preserves the source candidate
identity as metadata, requires an explicit target mask, and reports only a
screen-only remesh/evaluation receipt.
"""
function declared_axisymmetric_remesh_v1(domain, state, Rtarget, Ztarget,
        target_mask; candidate_identity, gauge_anchor, expected_native_field_model_id,
        profile_evaluator, coupled_mhd_consumer=nothing)
    try
        nr, nz = Int(domain.dynamic_geometry_data.nr), Int(domain.dynamic_geometry_data.nz)
        n = nr*nz; x = Float64.(collect(state))
        length(domain.mask) == n && length(domain.pressure_dofs) == n && length(x) == domain.ndof ||
            throw(ArgumentError("source state/domain dimensions disagree"))
        expected_source_dofs=4n+count(identity,domain.mask)+
            (domain.vary_profile_coefficients ? 2 : 0)+(domain.dynamic_profile_span ? 2 : 0)
        expected_source_dofs==domain.ndof ||
            throw(ArgumentError("source state DOF layout omits profile or dynamic-span coordinates"))
        domain.dynamic_profile_span && length(domain.span_columns)!=2 &&
            throw(ArgumentError("dynamic profile span must retain both source endpoint DOFs"))
        hasproperty(domain,:native_field_model_id) &&
            domain.native_field_model_id === expected_native_field_model_id ||
            throw(ArgumentError("native field model does not match the declared source provider"))
        all(k -> domain.mask[k] ? (domain.pressure_dofs[k] > 0 && domain.pressure_dofs[k] <= length(x)) : domain.pressure_dofs[k] == 0, 1:n) ||
            throw(ArgumentError("source pressure DOFs do not match the declared core mask"))
        Rs = Float64.(collect(domain.dynamic_geometry_data.Raxis))
        Zs = Float64.(collect(domain.dynamic_geometry_data.Zaxis))
        length(Rs) == nr && length(Zs) == nz || throw(ArgumentError("source axis dimensions disagree"))
        Rt, Zt = Float64.(collect(Rtarget)), Float64.(collect(Ztarget))
        nt = length(Rt)*length(Zt)
        length(Rt) >= 2 && length(Zt) >= 2 &&
            all(i -> Rt[i+1] > Rt[i], 1:length(Rt)-1) &&
            all(j -> Zt[j+1] > Zt[j], 1:length(Zt)-1) ||
            throw(ArgumentError("target R/Z axes must be strictly increasing with at least two nodes"))
        length(target_mask) == nt && all(v -> v isa Bool, target_mask) ||
            throw(ArgumentError("an explicit Boolean target mask is required"))
        all(isfinite, x) && all(isfinite, Rt) && all(isfinite, Zt) ||
            throw(ArgumentError("source state or target axes are nonfinite"))
        target_ncore = count(identity, target_mask)
        target_ncore > 0 || throw(ArgumentError("target core mask is empty"))
        target_boundary = unique(vcat(collect(1:length(Zt)),
            collect((length(Rt)-1)*length(Zt)+1:length(Rt)*length(Zt)),
            [ (i-1)*length(Zt)+1 for i in eachindex(Rt) ],
            [ i*length(Zt) for i in eachindex(Rt) ]))
        all(k -> !target_mask[k], target_boundary) ||
            throw(ArgumentError("target core mask touches the declared rectangular boundary"))
        span = _ccp_full_native_profile_span(domain, x)
        hasproperty(gauge_anchor,:R_m) && hasproperty(gauge_anchor,:Z_m) &&
            hasproperty(gauge_anchor,:psi_Wb_per_rad) ||
            throw(ArgumentError("explicit (R_m,Z_m,psi_Wb_per_rad) gauge anchor required"))
        u, v = domain.vary_profile_coefficients ?
            (x[domain.coefficient_columns[1]], x[domain.coefficient_columns[2]]) : domain.accepted_coefficients
        keep_dynamic_span = domain.dynamic_profile_span
        keep_dynamic_span && !domain.vary_profile_coefficients &&
            throw(ArgumentError("dynamic profile span requires dynamic profile coefficients"))
        y = zeros(Float64, 4nt + target_ncore + (domain.vary_profile_coefficients ? 2 : 0) +
            (keep_dynamic_span ? 2 : 0))
        tdofs = zeros(Int, nt); trows = zeros(Int, nt); pressure_index = 0
        for i in eachindex(Rt), j in eachindex(Zt)
            k = (i-1)*length(Zt)+j
            ids, w = _dcm_q1_location_v1(Rs, Zs, Rt[i], Zt[j])
            # Transfer psi and the toroidal-coordinate state. Rebuild Br/Bz
            # from the target psi derivatives below so div(B)=0 remains tied
            # to the same axisymmetric flux function.
            for (q, col) in enumerate((2,4))
                y[4k-4+col] = sum(w[a]*x[4ids[a]-4+col] for a in 1:4)
            end
            if target_mask[k]
                pressure_index += 1
                shape = _ccp_full_native_profile_shape(y[4k], span.axis, span.boundary)
                p = u*shape.integral/domain.law.Raxis_m
                isfinite(p) && p >= 0 || throw(DomainError(p, "remapped pressure is outside physical range"))
                tdofs[k] = 4nt + pressure_index
                trows[k] = nt + pressure_index
                y[tdofs[k]] = p
            end
        end
        source_anchor_ids, source_anchor_w = _dcm_q1_location_v1(Rs,Zs,
            Float64(gauge_anchor.R_m),Float64(gauge_anchor.Z_m))
        target_anchor_ids, target_anchor_w = _dcm_q1_location_v1(Rt,Zt,
            Float64(gauge_anchor.R_m),Float64(gauge_anchor.Z_m))
        source_anchor_psi=sum(source_anchor_w[q]*x[4source_anchor_ids[q]] for q in 1:4)
        target_anchor_psi=sum(target_anchor_w[q]*y[4target_anchor_ids[q]] for q in 1:4)
        isapprox(source_anchor_psi,Float64(gauge_anchor.psi_Wb_per_rad);rtol=0,atol=1e-12) ||
            throw(ArgumentError("declared gauge anchor differs from source-state interpolation"))
        source_Br=x[1:4:4n]; source_Bz=x[3:4:4n]
        source_current=_dcm_toroidal_current_v1(Rs,Zs,domain.mask,source_Br,source_Bz,domain.law.mu0_N_per_A2)
        target_gauge_row=zeros(Float64,nt)
        for q in 1:4; target_gauge_row[target_anchor_ids[q]]+=target_anchor_w[q]; end
        target_current_row=_dcm_psi_current_row_v1(Rt,Zt,target_mask,domain.law.mu0_N_per_A2)
        psi0=Float64[y[4k] for k in 1:nt]
        Cpsi=vcat(reshape(target_gauge_row,1,:),reshape(target_current_row,1,:))
        bpsi=Float64[gauge_anchor.psi_Wb_per_rad,source_current.integral_A]
        psi_weights=_dcm_volume_weights_v1(Rt,Zt)
        row_scales=Float64[norm(view(Cpsi,i,:)) for i in axes(Cpsi,1)]
        all(>(0),row_scales) || throw(ArgumentError("gauge/current projection constraint has a zero row"))
        Cscaled=Cpsi ./ reshape(row_scales,:,1);bscaled=bpsi ./ row_scales
        gram=Cscaled*Diagonal(1.0 ./ psi_weights)*transpose(Cscaled)
        rank(gram)==2 || throw(ArgumentError("gauge/current projection constraints are rank deficient"))
        multipliers=gram\(Cscaled*psi0-bscaled)
        psi_projected=psi0 .- (1.0 ./ psi_weights).*(transpose(Cscaled)*multipliers)
        gauge_shift=Float64(gauge_anchor.psi_Wb_per_rad)-target_anchor_psi
        for k in 1:nt; y[4k]=psi_projected[k]; end
        gauge_defect=dot(target_gauge_row,psi_projected)-Float64(gauge_anchor.psi_Wb_per_rad)
        current_constraint_defect=dot(target_current_row,psi_projected)-source_current.integral_A
        for i in eachindex(Rt), j in eachindex(Zt)
            k=(i-1)*length(Zt)+j; R=Rt[i]
            R>0 || throw(ArgumentError("axisymmetric R coordinates must be positive"))
            dpsi_dZ=_dcm_axis_derivative_v1(view(y,4:4:4nt),Zt,i,j,length(Rt),length(Zt),false)
            dpsi_dR=_dcm_axis_derivative_v1(view(y,4:4:4nt),Rt,i,j,length(Rt),length(Zt),true)
            y[4k-3]=-dpsi_dZ/R
            y[4k-1]=dpsi_dR/R
        end
        src_p=zeros(Float64,n); target_p=zeros(Float64,nt)
        for k in 1:n
            if domain.mask[k]
                src_p[k]=x[domain.pressure_dofs[k]]
                isfinite(src_p[k]) && src_p[k]>=0 ||
                    throw(DomainError(src_p[k],"source pressure must be finite and nonnegative"))
            end
        end
        for k in 1:nt
            target_mask[k] && (target_p[k]=y[tdofs[k]])
        end
        source_pressure_total=_dcm_pressure_integral_v1(Rs,Zs,domain.mask,src_p)
        target_pressure_preconstraint=_dcm_pressure_integral_v1(Rt,Zt,target_mask,target_p)
        isfinite(source_pressure_total) && isfinite(target_pressure_preconstraint) &&
            source_pressure_total>=0 && target_pressure_preconstraint>=0 ||
            throw(DomainError((source_pressure_total,target_pressure_preconstraint),"pressure integral constraint is infeasible"))
        volume_weights=_dcm_volume_weights_v1(Rt,Zt)
        core_ids=findall(identity,target_mask)
        p_projection=_dcm_nonnegative_integral_projection_v1(target_p[core_ids],
            volume_weights[core_ids],source_pressure_total)
        for (q,k) in enumerate(core_ids); y[tdofs[k]]=p_projection.values[q]; target_p[k]=p_projection.values[q]; end
        pressure_scale=1.0
        target_pressure_total=_dcm_pressure_integral_v1(Rt,Zt,target_mask,target_p)
        new_law = keep_dynamic_span ? domain.law : merge(domain.law,
            (psi_axis_wb_per_rad=span.axis+gauge_shift,
             psi_boundary_wb_per_rad=span.boundary+gauge_shift))
        target_Br=y[1:4:4nt]; target_Bz=y[3:4:4nt]
        target_current=_dcm_toroidal_current_v1(Rt,Zt,target_mask,target_Br,target_Bz,new_law.mu0_N_per_A2)
        source_divB=_dcm_axisymmetric_divergence_v1(Rs,Zs,source_Br,source_Bz)
        target_divB=_dcm_axisymmetric_divergence_v1(Rt,Zt,target_Br,target_Bz)
        source_production_divB=_dcm_axisymmetric_production_divB_v1(Rs,Zs,source_Br,source_Bz)
        target_production_divB=_dcm_axisymmetric_production_divB_v1(Rt,Zt,target_Br,target_Bz)
        compare_stencils(production,diagnostic)=if production.status===:evaluated
            delta=Float64[production.rows[k].divB_T_per_m-
                diagnostic.values[production.rows[k].flat_index] for k in eachindex(production.rows)]
            (status=production.production_stencil_accepted ? :compared_same_interior :
                    :diagnostic_only_native_stencil_rejected,
                native_stencil_accepted=production.production_stencil_accepted,rows=length(delta),
                max_abs_difference_T_per_m=maximum(abs,delta),
                RMS_difference_T_per_m=sqrt(sum(abs2,delta)/length(delta)))
        else
            (status=:typed_absent,reason=production.reason,rows=0,
                native_stencil_accepted=false,
                max_abs_difference_T_per_m=nothing,RMS_difference_T_per_m=nothing)
        end
        ccols = domain.vary_profile_coefficients ? (4nt+target_ncore+1, 4nt+target_ncore+2) : domain.coefficient_columns
        if domain.vary_profile_coefficients
            y[ccols[1]] = u; y[ccols[2]] = v
        end
        span_cols = keep_dynamic_span ? (4nt+target_ncore+3,4nt+target_ncore+4) : ()
        keep_dynamic_span && (y[span_cols[1]]=span.axis+gauge_shift;
            y[span_cols[2]]=span.boundary+gauge_shift)
        interp_native(values) = begin
            length(values)==n || throw(ArgumentError("saved native geometry field does not match the source mesh"))
            out=zeros(Float64,nt)
            for i in eachindex(Rt),j in eachindex(Zt)
                k=(i-1)*length(Zt)+j
                ids,w=_dcm_q1_location_v1(Rs,Zs,Rt[i],Zt[j])
                out[k]=sum(w[a]*values[ids[a]] for a in 1:4)
            end
            out
        end
        tdyn = merge(domain.dynamic_geometry_data, (Raxis=Rt, nz=length(Zt), nr=length(Rt),
            Zaxis=Zt, n=nt, ndof=length(y), mask=Tuple(target_mask), pressure_dofs=Tuple(tdofs),
            support_psi=keep_dynamic_span ? interp_native(domain.dynamic_geometry_data.support_psi) : nothing,
            anchor_psi=Float64[y[4k] for k in 1:nt],
            Dr=_ccp_native_spline_derivative(Rt),Dz=_ccp_native_spline_derivative(Zt),
            plasma_reference=keep_dynamic_span ? interp_native(domain.dynamic_geometry_data.plasma_reference) : Float64[],
            pf_native_psi_Wb_per_rad=domain.native_field_model_id===:plasma_spline_plus_exact_pf_potential_jet_v1 ?
                (keep_dynamic_span ? interp_native(domain.dynamic_geometry_data.pf_native_psi_Wb_per_rad) : nothing) : nothing,
            dynamic_profile_span=keep_dynamic_span,span_columns=span_cols,
            profile_axis_Wb_per_rad=span.axis+gauge_shift,
            profile_boundary_Wb_per_rad=span.boundary+gauge_shift))
        target_domain = merge(domain, (n=nt, ndof=length(y), mask=Tuple(target_mask),
            pressure_dofs=Tuple(tdofs), law=new_law, dynamic_profile_span=keep_dynamic_span,
            span_columns=span_cols, coefficient_columns=ccols, dynamic_geometry_data=tdyn))
        if keep_dynamic_span
            tdyn=merge(tdyn,(toroidal_geometry_domain=target_domain,))
            target_domain=merge(target_domain,(dynamic_geometry_data=tdyn,))
        end
        target_data = (domain=target_domain, R=repeat(Rt, inner=length(Zt)),
            pressure_rows=trows, nrows=nt+target_ncore)
        expected_target_dofs=4nt+target_ncore+(domain.vary_profile_coefficients ? 2 : 0)+
            (keep_dynamic_span ? 2 : 0)
        expected_target_dofs==length(y) || throw(ArgumentError("target remesh dropped an explicit state coordinate"))
        evaluated = profile_evaluator(target_data, Tuple(y))
        hasproperty(evaluated,:status) &&
            evaluated.status===:evaluated_full_native_F_and_core_pressure_rows ||
            throw(ArgumentError("downstream native profile/current-pressure consumer did not return its evaluated status"))
        hasproperty(evaluated,:residual) && hasproperty(evaluated,:jacobian) ||
            throw(ArgumentError("downstream native consumer omitted residual or Jacobian"))
        length(evaluated.residual)==target_data.nrows &&
            size(evaluated.jacobian)==(target_data.nrows,length(y)) ||
            throw(ArgumentError("downstream native consumer residual/Jacobian dimensions do not cover the remapped state"))
        all(isfinite,evaluated.residual) && all(isfinite,nonzeros(evaluated.jacobian)) ||
            throw(ArgumentError("downstream native consumer returned nonfinite residual/Jacobian values"))
        fd_columns=Int[4*core_ids[1]-2,tdofs[core_ids[1]]]
        domain.vary_profile_coefficients && push!(fd_columns,ccols[1])
        fd_probe=declared_native_profile_fd_probe_v1(profile_evaluator,target_data,Tuple(y),evaluated;
            columns=fd_columns)
        consumer_receipt=(status=evaluated.status,
            invocation=:original_candidate_native_profile_and_pressure_residual_evaluator,
            consumed_state_sha256=_dcm_hash(Tuple(y)),residual_sha256=_dcm_hash(Tuple(evaluated.residual)),
            residual_inf_norm=norm(evaluated.residual,Inf),residual_count=length(evaluated.residual),
            jacobian_size=size(evaluated.jacobian),jacobian_nnz=nnz(evaluated.jacobian),
            finite_difference_jacobian_probe=fd_probe,
            solver_execution=:not_executed,acceptance=:diagnostics_only_thresholds_unfrozen)
        coupled_mhd_receipt = if coupled_mhd_consumer === nothing
            (status=:typed_absent,
                invocation=:existing_inhouse_coupled_mhd_global_assembly_and_solve_v1,
                reason=:original_global_model_and_frozen_policy_not_supplied,
                physical_authority=false,acceptance=:not_evaluated)
        else
            hasproperty(coupled_mhd_consumer,:solver_module) &&
                hasproperty(coupled_mhd_consumer,:model) &&
                hasproperty(coupled_mhd_consumer,:policy) &&
                hasproperty(coupled_mhd_consumer,:expected_candidate_hash) ||
                throw(ArgumentError("global consumer bundle requires solver module, existing model, policy, and candidate hash"))
            hasproperty(candidate_identity,:candidate_hash) &&
                String(candidate_identity.candidate_hash)==String(coupled_mhd_consumer.expected_candidate_hash) ||
                throw(ArgumentError("global consumer candidate hash differs from the remeshed candidate identity"))
            declared_axisymmetric_global_consumer_v1(coupled_mhd_consumer.solver_module,
                coupled_mhd_consumer.model,Tuple(y),coupled_mhd_consumer.policy;
                expected_candidate_hash=coupled_mhd_consumer.expected_candidate_hash)
        end
        receipt_body = (schema="DeclaredAxisymmetricRemeshV1", candidate_identity=candidate_identity,
            source_shape=(nr,nz), target_shape=(length(Rt),length(Zt)),
            state_layout=(source_ndof=domain.ndof,target_ndof=length(y),
                dynamic_profile_span_preserved=domain.dynamic_profile_span==target_domain.dynamic_profile_span,
                source_span_columns=domain.span_columns,target_span_columns=span_cols,
                target_profile_columns=ccols),
            source_axes=(Rs,Zs), target_axes=(Rt,Zt), source_mask=Tuple(domain.mask),
            target_mask=Tuple(target_mask), state_coordinate=domain.toroidal_coordinate,
            psi_unit="Wb/rad", toroidal_unit=domain.toroidal_coordinate === :native_F_defect_T_m_v1 ? "T m" : "T",
            pressure_unit="Pa", source_state_hash=_dcm_hash(Tuple(x)), target_state_hash=_dcm_hash(Tuple(y)),
            projection=(method=:weighted_minimum_change_equality_projection,
                psi_constraints=(:explicit_gauge_anchor,:source_plasma_current),
                psi_gauge_defect_Wb_per_rad=gauge_defect,
                psi_current_defect_A=current_constraint_defect,
                pressure_constraint=:axisymmetric_volume_integral_with_nonnegative_active_set,
                pressure_active_set_iterations=p_projection.iterations,
                pressure_active_zero_count=length(p_projection.active),
                pressure_constraint_defect_J=p_projection.defect,
                static_mesh_edit=true,physical_reconnection_inferred=false,
                acceptance=:constraints_enforced_but_campaign_tolerances_unfrozen),
            gauge_anchor=(R_m=gauge_anchor.R_m,Z_m=gauge_anchor.Z_m,
                psi_Wb_per_rad=gauge_anchor.psi_Wb_per_rad,source_interpolated_psi=source_anchor_psi,
                target_interpolated_psi=target_anchor_psi+gauge_shift,shift_Wb_per_rad=gauge_shift,
                status=:equality_constraint_enforced_by_projection,
                acceptance=:campaign_gauge_tolerance_unfrozen),
            pressure_volume_energy=(source_J=source_pressure_total,
                target_preconstraint_J=target_pressure_preconstraint,
                target_J=target_pressure_total,integrand="2pi*R*p dR dZ",scale=pressure_scale,
                relative_defect=(target_pressure_total-source_pressure_total)/max(abs(source_pressure_total),eps(Float64)),
                positivity=:source_and_target_pressure_checked_nonnegative,
                projection_defect_J=p_projection.defect,
                suggested_B02_scaled_defect_limit=DCM_B02_SUGGESTED_SCALED_DEFECT_V1,
                suggested_B02_diagnostic_only=abs(target_pressure_total-source_pressure_total)/
                    max(abs(source_pressure_total),eps(Float64))<=DCM_B02_SUGGESTED_SCALED_DEFECT_V1,
                acceptance=:conservation_equality_enforced_campaign_tolerance_unfrozen),
            plasma_current=(source_A=source_current.integral_A,target_A=target_current.integral_A,
                absolute_defect_A=target_current.integral_A-source_current.integral_A,
                relative_defect=abs(target_current.integral_A-source_current.integral_A)/
                    max(abs(source_current.integral_A),eps(Float64)),
                integrand="J_phi dR dZ",source_scope=:curl_B_phi_of_Br_Bz_trapezoid_core,
                target_scope=:curl_B_phi_of_psi_derived_Br_Bz_trapezoid_core,
                constraint_defect_A=current_constraint_defect,
                suggested_B02_scaled_defect_limit=DCM_B02_SUGGESTED_SCALED_DEFECT_V1,
                suggested_B02_diagnostic_only=abs(target_current.integral_A-source_current.integral_A)/
                    max(abs(source_current.integral_A),eps(Float64))<=DCM_B02_SUGGESTED_SCALED_DEFECT_V1,
                acceptance=:current_equality_enforced_campaign_tolerance_unfrozen),
            magnetic_flux=(source_axis_minus_boundary_Wb_per_rad=span.delta,
                target_axis_minus_boundary_Wb_per_rad=span.delta,
                source_enclosed_poloidal_flux_Wb=2pi*span.delta,
                target_enclosed_poloidal_flux_Wb=2pi*span.delta,
                target_gauge_anchor_error_Wb_per_rad=target_anchor_psi+gauge_shift-gauge_anchor.psi_Wb_per_rad),
            source_divergence=(max_abs_T_per_m=source_divB.max_abs_T_per_m,
                RMS_T_per_m=source_divB.RMS_T_per_m,
                diagnostic_operator=:axisymmetric_tensor_derivative_on_RZ_chart,
                production_mhd_operator=:CandidateCoupledPhysicsV4__ccp_axisymmetric_mhd_stencil,
                production_stencil=source_production_divB,
                production_stencil_consistency=compare_stencils(source_production_divB,source_divB),
                acceptance=:diagnostics_only_divB_budget_unfrozen),
            target_divergence=(max_abs_T_per_m=target_divB.max_abs_T_per_m,
                RMS_T_per_m=target_divB.RMS_T_per_m,field_relation=:Br_minus_dpsi_dZ_over_R_Bz_dpsi_dR_over_R,
                diagnostic_operator=:axisymmetric_tensor_derivative_on_RZ_chart,
                production_mhd_operator=:CandidateCoupledPhysicsV4__ccp_axisymmetric_mhd_stencil,
                production_stencil=target_production_divB,
                production_stencil_consistency=compare_stencils(target_production_divB,target_divB),
                acceptance=:diagnostics_only_divB_budget_unfrozen),
            evaluator_status=hasproperty(evaluated,:status) ? evaluated.status : :unknown,
            evaluator_residual_hash=_dcm_hash(Tuple(evaluated.residual)),
            downstream_consumer=consumer_receipt,
            coupled_mhd_global_consumer=coupled_mhd_receipt)
        (status=:evaluated_screen_only, claim_ceiling=:screen_only, accepted=false,
            formal_up2_credit=false, formal_up_credit=false, candidate_identity=candidate_identity,
            state=Tuple(y), domain=target_domain, evaluator_data=target_data, evaluation=evaluated,
            receipt=merge(receipt_body, (receipt_hash=_dcm_hash(receipt_body),)))
    catch err
        (status=:fail_closed, claim_ceiling=:screen_only, accepted=false,
            formal_up2_credit=false, code=:axisymmetric_remesh_rejected,
            detail=sprint(showerror, err), candidate_identity=candidate_identity)
    end
end
