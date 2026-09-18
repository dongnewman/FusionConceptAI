"""Declared G1/G2/G3 diffusion execution, R4.

This is an additive, candidate-bound local execution seam.  It consumes the
typed G1 diffusion, G2 metric/boundary, G3 source/feedback declarations and a
VNext local transport bundle.  It intentionally supports only the declared
diagonal-affine G1 expression subset and a structured 1-D local mesh derived
from the actual G2 chart/mesh declaration.  No provider, mesh backend, DESC or
registry is called here.

The result is screen-only software evidence.  In particular, a solved sparse
system is never promoted to physical, UP or R credit.
"""

using SparseArrays

const DGD_SCHEMA_V1 = "fusionconceptai:runtime-v4:declared-g123-diffusion-execution-v1"
const DGD_REVISION_V1 = "up2-exec-declared-g123-diffusion-v1-r21"
const DGD_CLAIM_CEILING_V1 = :screen_only
const DGD_STATUSES_V1 = (:ready, :fail_closed, :terminal_deferred, :numerical_fail)
const DGD_ALLOWED_U_EXPRESSIONS_V1 = (
    "u_candidate(x)=x1+x2+x3", "u(x)=x1+x2+x3")
const DGD_ALLOWED_F_EXPRESSIONS_V1 = ("f_candidate(x)=1", "f(x)=1")

_dgd_text(x, field) = begin
    s = String(x); isempty(strip(s)) && throw(ArgumentError("$field cannot be empty")); s
end
_dgd_digest(x, field) = x isa Digest256 ? x : throw(ArgumentError("$field must be Digest256"))
_dgd_finite(x, field) = begin
    y = Float64(x); isfinite(y) || throw(ArgumentError("$field must be finite")); y
end
_dgd_hash(x) = canonical_hash(x)

"""Reconstruct semantic bodies from declaration fields, never from a hash field."""
_dgd_g1_body(x::G1DiffusionDeclarationV1) = _g1d_declaration_body(x)
_dgd_g2_body(candidate::QualifiedRefV1, x::G2MBDeclarationV1) =
    (candidate_ref=candidate,
     candidate_envelope=VNextT0LocalG2CandidateEnvelopeV1(candidate, x.contract_ref,
         x.source.source_ref, x.source.source_hash),
     contract_ref=x.contract_ref, source=x.source, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash, profile_hash=x.profile_hash,
     declaration_hash=canonical_hash((contract_ref=x.contract_ref, source=x.source,
         schema_hash=x.schema_hash, canonicalization_hash=x.canonicalization_hash,
         profile_hash=x.profile_hash)))
_dgd_g3_body(x::G3SFDeclarationV1, source_ref::QualifiedRefV1) =
    merge(_g3sf_body(x), (source_ref=source_ref,))

function _dgd_body_from_bundle(bundle::VNextT0LocalTransportV1, layer::Symbol)
    matches = findall(x -> x isa VNextT0LocalPresentDeclarationV1 && x.layer === layer,
        bundle.declarations)
    length(matches) == 1 || throw(ArgumentError("bundle layer cardinality mismatch:$layer"))
    bundle.declarations[first(matches)].semantic_body.body
end

function _dgd_record_integrity(record::VNextT0LocalPresentDeclarationV1,
        candidate::QualifiedRefV1, declaration::Any)
    record.candidate_ref == candidate || throw(ArgumentError("bundle candidate mismatch"))
    record.semantic_body.bytes.sha256 == _vnl_t0_sha(record.semantic_body.bytes.bytes) ||
        throw(ArgumentError("bundle semantic bytes hash mismatch"))
    record.semantic_body.bytes.bytes == Vector{UInt8}(codeunits(canonical_json(record.semantic_body.body))) ||
        throw(ArgumentError("bundle semantic bytes mismatch"))
    record.source_bytes.sha256 == _vnl_t0_sha(record.source_bytes.bytes) ||
        throw(ArgumentError("bundle source bytes hash mismatch"))
    record.declaration_bytes.sha256 == _vnl_t0_sha(record.declaration_bytes.bytes) ||
        throw(ArgumentError("bundle declaration bytes hash mismatch"))
    record.declaration_bytes.bytes == Vector{UInt8}(codeunits(canonical_json(declaration))) ||
        throw(ArgumentError("bundle declaration bytes differ from typed declaration"))
    record.source_identity_hash == canonical_hash((kind=:source, ref=record.source_ref,
        bytes_sha256=record.source_bytes.sha256)) || throw(ArgumentError("bundle source identity mismatch"))
    record.declaration_identity_hash == canonical_hash((kind=:declaration, ref=record.declaration_ref,
        bytes_sha256=record.declaration_bytes.sha256)) || throw(ArgumentError("bundle declaration identity mismatch"))
    for receipt in (record.factory_receipt, record.declaration_receipt)
        receipt.candidate_ref == candidate || throw(ArgumentError("bundle receipt candidate mismatch"))
        receipt.layer == record.layer || throw(ArgumentError("bundle receipt layer mismatch"))
        receipt.source_ref == record.source_ref || throw(ArgumentError("bundle receipt source mismatch"))
        receipt.declaration_ref == record.declaration_ref || throw(ArgumentError("bundle receipt declaration mismatch"))
        receipt.status === :present || throw(ArgumentError("bundle receipt status mismatch"))
        receipt.factory_result.candidate_ref == candidate || throw(ArgumentError("factory receipt candidate mismatch"))
        receipt.factory_result.layer == record.layer || throw(ArgumentError("factory receipt layer mismatch"))
        receipt.factory_result.source_ref == record.source_ref || throw(ArgumentError("factory receipt source mismatch"))
        receipt.factory_result.declaration_ref == record.declaration_ref || throw(ArgumentError("factory receipt declaration mismatch"))
        expected_receipt_bytes = _vnl_t0_factory_result_bytes(receipt.factory_result)
        receipt.bytes.bytes == expected_receipt_bytes.bytes ||
            throw(ArgumentError("factory receipt envelope bytes mismatch"))
        receipt.bytes.sha256 == expected_receipt_bytes.sha256 ||
            throw(ArgumentError("factory receipt envelope hash mismatch"))
        receipt.factory_result.source_bytes.bytes == record.source_bytes.bytes ||
            throw(ArgumentError("factory receipt source bytes mismatch"))
        receipt.factory_result.source_bytes.sha256 == record.source_bytes.sha256 ||
            throw(ArgumentError("factory receipt source hash mismatch"))
        receipt.factory_result.source_bytes.bytes == record.declaration_receipt.factory_result.source_bytes.bytes ||
            throw(ArgumentError("declaration receipt source bytes mismatch"))
        receipt.factory_result.source_bytes.sha256 == record.declaration_receipt.factory_result.source_bytes.sha256 ||
            throw(ArgumentError("declaration receipt source hash mismatch"))
        receipt.factory_result.declaration_bytes.bytes == record.declaration_bytes.bytes ||
            throw(ArgumentError("factory receipt declaration bytes mismatch"))
        receipt.factory_result.declaration_bytes.sha256 == record.declaration_bytes.sha256 ||
            throw(ArgumentError("factory receipt declaration bytes mismatch"))
        receipt.factory_result.declaration_bytes.bytes == record.declaration_receipt.factory_result.declaration_bytes.bytes ||
            throw(ArgumentError("declaration receipt declaration bytes mismatch"))
        receipt.factory_result.declaration_bytes.sha256 == record.declaration_receipt.factory_result.declaration_bytes.sha256 ||
            throw(ArgumentError("declaration receipt declaration hash mismatch"))
        receipt.factory_result_hash == canonical_hash(receipt.factory_result) ||
            throw(ArgumentError("factory receipt identity mismatch"))
    end
    true
end

function _dgd_hashes_from_actual(candidate::QualifiedRefV1,
        g1::G1DiffusionDeclarationV1, g2::G2MBDeclarationV1, g3::G3SFDeclarationV1,
        bundle::VNextT0LocalTransportV1)
    # Recompute the bundle identity itself before reading any semantic body.
    recomputed_bundle = vnext_t0_local_bundle_hash_recompute_v1(bundle)
    recomputed_bundle == bundle.bundle_hash || throw(ArgumentError("bundle_hash_mismatch"))
    for layer in (:G1, :G2, :G3)
        i = findfirst(x -> x isa VNextT0LocalPresentDeclarationV1 && x.layer === layer,
            bundle.declarations)
        i === nothing && throw(ArgumentError("bundle layer missing:$layer"))
        declaration = layer === :G1 ? g1 : layer === :G2 ? g2 : g3
        _dgd_record_integrity(bundle.declarations[i], candidate, declaration)
    end
    g3_record = bundle.declarations[findfirst(x -> x isa VNextT0LocalPresentDeclarationV1 && x.layer === :G3,
        bundle.declarations)]
    expected = (_dgd_g1_body(g1), _dgd_g2_body(candidate, g2),
        _dgd_g3_body(g3, g3_record.source_ref))
    actual = Tuple(_dgd_body_from_bundle(bundle, layer) for layer in (:G1, :G2, :G3))
    all(canonical_json(actual[i]) == canonical_json(expected[i]) for i in 1:3) ||
        throw(ArgumentError("bundle semantic body differs from reconstructed declaration"))
    DeclaredG123HashSetV1(candidate, _dgd_hash(expected[1]), _dgd_hash(expected[2]),
        _dgd_hash(expected[3]), recomputed_bundle)
end

struct DeclaredG123HashSetV1
    candidate_ref::QualifiedRefV1
    g1_body_hash::Digest256
    g2_body_hash::Digest256
    g3_body_hash::Digest256
    bundle_hash::Digest256
end

struct DeclaredG123InputV1
    candidate_ref::QualifiedRefV1
    g1::G1DiffusionDeclarationV1
    g2::G2MBDeclarationV1
    g3::G3SFDeclarationV1
    bundle::VNextT0LocalTransportV1
    hashes::DeclaredG123HashSetV1
end

"""Expose real G2/G3 admission receipts without inventing mesh execution.

The G2 declaration permits only `:declared` and `:not_executed` mesh states;
its admission resolution and gaps are therefore the capability evidence for a
missing mesh authority.  G3 is dispatched independently so its feedback
authority result is observed even when G2 is deferred.
"""
function dgd_admission_dispatch_v1(input::DeclaredG123InputV1, layer::Symbol)
    layer === :G2 && begin
        a = g2mb_admit(input.g2.source)
        return (layer=:G2, status=a.resolution, admission_status=a.status,
            resolution=a.resolution,
            code=a.resolution === :resolved ? :g2_admission_resolved :
                :g2_admission_terminal_deferred, gaps=a.gaps)
    end
    layer === :G3 && begin
        a = g3_sf_admit_v1(input.g3)
        return (layer=:G3, status=a.resolution, admission_status=a.status,
            resolution=a.resolution,
            code=a.resolution === :resolved ? :g3_admission_resolved :
                :g3_admission_terminal_deferred, gaps=a.gaps)
    end
    throw(ArgumentError("unsupported admission layer"))
end

"""The body hashes are recomputed from the actual declaration objects.

`expected_hashes` is optional only for callers that already have an immutable
identity receipt.  If supplied, every byte-level hash must match; no hash is
accepted as a label or display-only assertion.
"""
function dgd_input_v1(candidate::QualifiedRefV1, g1::G1DiffusionDeclarationV1,
        g2::G2MBDeclarationV1, g3::G3SFDeclarationV1,
        bundle::VNextT0LocalTransportV1; expected_hashes=nothing)
    candidate.version == "v5" || throw(ArgumentError("candidate_ref must use v5"))
    g1.candidate_ref == candidate || throw(ArgumentError("G1 candidate mismatch"))
    g3.candidate_ref == candidate || throw(ArgumentError("G3 candidate mismatch"))
    bundle.candidate_ref == candidate || throw(ArgumentError("bundle candidate mismatch"))
    hashes = _dgd_hashes_from_actual(candidate, g1, g2, g3, bundle)
    if expected_hashes !== nothing
        expected_hashes isa DeclaredG123HashSetV1 || throw(ArgumentError("expected hashes must be typed"))
        (expected_hashes.candidate_ref == hashes.candidate_ref &&
         expected_hashes.g1_body_hash == hashes.g1_body_hash &&
         expected_hashes.g2_body_hash == hashes.g2_body_hash &&
         expected_hashes.g3_body_hash == hashes.g3_body_hash &&
         expected_hashes.bundle_hash == hashes.bundle_hash) ||
            throw(ArgumentError("declared hash identity mismatch"))
    end
    DeclaredG123InputV1(candidate, g1, g2, g3, bundle, hashes)
end

struct DGDCompileReceiptV1
    status::Symbol
    code::Symbol
    candidate_ref::QualifiedRefV1
    g1_body_hash::Digest256
    g2_body_hash::Digest256
    g3_body_hash::Digest256
    bundle_hash::Digest256
    expression_subset::Symbol
    g2_admission_status::Symbol
    g2_resolution::Symbol
    g3_admission_status::Symbol
    g3_resolution::Symbol
    provider_calls::Int
    mesh_calls::Int
    receipt_hash::Digest256
end

struct DGDLocalMeshV1
    chart_ref::QualifiedRefV1
    mesh_ref::QualifiedRefV1
    cells::NTuple{3,Int}
    basis::Symbol
    quadrature_points::Tuple
    quadrature_weights::Tuple
    faces::Tuple
    execution_status::Symbol
    bounds::NTuple{3,NTuple{2,Float64}}
    reference_nodes::Tuple{Vararg{NTuple{3,Float64}}}
    physical_nodes::Tuple{Vararg{NTuple{3,Float64}}}
    spacing::Float64
    mesh_hash::Digest256
end

struct DGDTransferReceiptV1
    status::Symbol
    code::Symbol
    source_mesh_hash::Digest256
    target_mesh_hash::Digest256
    old_state::NTuple{2,Float64}
    new_state::NTuple{2,Float64}
    overlap::NTuple{2,Float64}
    weights::NTuple{2,Float64}
    conservation_residual::Float64
    receipt_hash::Digest256
end

struct DGDCompositionReceiptV1
    status::Symbol
    code::Symbol
    candidate_ref::QualifiedRefV1
    g1_body_hash::Digest256
    g2_body_hash::Digest256
    g3_body_hash::Digest256
    source_power::Float64
    field_power::Float64
    return_power::Float64
    heat_power::Float64
    energy_residual::Float64
    ledger_residual::Float64
    provider_calls::Int
    mesh_calls::Int
    receipt_hash::Digest256
end

struct DGDNumericalReceiptV1
    status::Symbol
    code::Symbol
    matrix::NTuple{2,NTuple{2,Float64}}
    rhs::NTuple{2,Float64}
    solution::Union{Nothing,NTuple{2,Float64}}
    residual_norm::Float64
    solver_calls::Int
    receipt_hash::Digest256
end

struct DGDAggregateReceiptV1
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    screen_only::Bool
    formal_up_credit::Bool
    formal_r_credit::Bool
    candidate_ref::QualifiedRefV1
    compile::DGDCompileReceiptV1
    transfer::DGDTransferReceiptV1
    composition::DGDCompositionReceiptV1
    numerical::Union{Nothing,DGDNumericalReceiptV1}
    provider_calls::Int
    mesh_calls::Int
    solver_calls::Int
    receipt_hash::Digest256
end

# Every DGD identity-bearing struct has an explicit non-recursive semantic
# view.  Computed identity fields are deliberately excluded from their own
# canonical body; nested DGD receipts then hash through these views rather
# than falling back to an undefined generic serializer.
semantic_view(x::DeclaredG123HashSetV1) =
    (candidate_ref=x.candidate_ref, g1_body_hash=x.g1_body_hash,
     g2_body_hash=x.g2_body_hash, g3_body_hash=x.g3_body_hash,
     bundle_hash=x.bundle_hash)
canonical_json(x::DeclaredG123HashSetV1) = canonical_json(semantic_view(x))

semantic_view(x::DeclaredG123InputV1) =
    (candidate_ref=x.candidate_ref, g1=x.g1, g2=x.g2, g3=x.g3,
     bundle=x.bundle, hashes=x.hashes)
canonical_json(x::DeclaredG123InputV1) = canonical_json(semantic_view(x))

semantic_view(x::DGDCompileReceiptV1) =
    (status=x.status, code=x.code, candidate_ref=x.candidate_ref,
     g1_body_hash=x.g1_body_hash, g2_body_hash=x.g2_body_hash,
     g3_body_hash=x.g3_body_hash, bundle_hash=x.bundle_hash,
     expression_subset=x.expression_subset, g2_admission_status=x.g2_admission_status,
     g2_resolution=x.g2_resolution, g3_admission_status=x.g3_admission_status,
     g3_resolution=x.g3_resolution, provider_calls=x.provider_calls,
     mesh_calls=x.mesh_calls)
canonical_json(x::DGDCompileReceiptV1) = canonical_json(semantic_view(x))

semantic_view(x::DGDLocalMeshV1) =
    (chart_ref=x.chart_ref, mesh_ref=x.mesh_ref, cells=x.cells, basis=x.basis,
     quadrature_points=x.quadrature_points, quadrature_weights=x.quadrature_weights,
     faces=x.faces, execution_status=x.execution_status, bounds=x.bounds,
     reference_nodes=x.reference_nodes, physical_nodes=x.physical_nodes,
     spacing=x.spacing)
canonical_json(x::DGDLocalMeshV1) = canonical_json(semantic_view(x))

semantic_view(x::DGDTransferReceiptV1) =
    (status=x.status, code=x.code, source_mesh_hash=x.source_mesh_hash,
     target_mesh_hash=x.target_mesh_hash, old_state=x.old_state, new_state=x.new_state,
     overlap=x.overlap, weights=x.weights, conservation_residual=x.conservation_residual)
canonical_json(x::DGDTransferReceiptV1) = canonical_json(semantic_view(x))

semantic_view(x::DGDCompositionReceiptV1) =
    (status=x.status, code=x.code, candidate_ref=x.candidate_ref,
     g1_body_hash=x.g1_body_hash, g2_body_hash=x.g2_body_hash,
     g3_body_hash=x.g3_body_hash, source_power=x.source_power,
     field_power=x.field_power, return_power=x.return_power, heat_power=x.heat_power,
     energy_residual=x.energy_residual, ledger_residual=x.ledger_residual,
     provider_calls=x.provider_calls, mesh_calls=x.mesh_calls)
canonical_json(x::DGDCompositionReceiptV1) = canonical_json(semantic_view(x))

semantic_view(x::DGDNumericalReceiptV1) =
    (status=x.status, code=x.code, matrix=x.matrix, rhs=x.rhs, solution=x.solution,
     residual_norm=x.residual_norm, solver_calls=x.solver_calls)
canonical_json(x::DGDNumericalReceiptV1) = canonical_json(semantic_view(x))

semantic_view(x::DGDAggregateReceiptV1) =
    (status=x.status, resolution=x.resolution, accepted=x.accepted,
     claim_ceiling=x.claim_ceiling, screen_only=x.screen_only,
     formal_up_credit=x.formal_up_credit, formal_r_credit=x.formal_r_credit,
     candidate_ref=x.candidate_ref, compile=x.compile, transfer=x.transfer,
     composition=x.composition, numerical=x.numerical, provider_calls=x.provider_calls,
     mesh_calls=x.mesh_calls, solver_calls=x.solver_calls)
canonical_json(x::DGDAggregateReceiptV1) = canonical_json(semantic_view(x))

_dgd_compile_receipt(status, code, input, subset;
        g2_status=:unknown, g2_resolution=:unknown, g3_status=:unknown, g3_resolution=:unknown) = begin
    body = (status=status, code=code, candidate_ref=input.candidate_ref,
        g1_body_hash=input.hashes.g1_body_hash, g2_body_hash=input.hashes.g2_body_hash,
        g3_body_hash=input.hashes.g3_body_hash, bundle_hash=input.hashes.bundle_hash,
        expression_subset=subset, g2_admission_status=g2_status, g2_resolution=g2_resolution,
        g3_admission_status=g3_status, g3_resolution=g3_resolution,
        provider_calls=0, mesh_calls=0)
    DGDCompileReceiptV1(status, code, input.candidate_ref, input.hashes.g1_body_hash,
        input.hashes.g2_body_hash, input.hashes.g3_body_hash, input.hashes.bundle_hash,
        subset, g2_status, g2_resolution, g3_status, g3_resolution, 0, 0, _dgd_hash(body))
end

function _dgd_bundle_body(input::DeclaredG123InputV1, layer::Symbol)
    record = findfirst(x -> x isa VNextT0LocalPresentDeclarationV1 && x.layer === layer,
        input.bundle.declarations)
    record === nothing && return nothing
    input.bundle.declarations[record].semantic_body.body
end

function _dgd_expression_subset(input::DeclaredG123InputV1)
    u = input.g1.u.source_expression
    f = input.g1.f.source_expression
    input.g1.K.expression isa G1DiffusionDiagonalAffineKFieldV1 || return false
    u in DGD_ALLOWED_U_EXPRESSIONS_V1 && f in DGD_ALLOWED_F_EXPRESSIONS_V1
end

function dgd_compile_v1(input::DeclaredG123InputV1)
    try
        isempty(input.bundle.errors) || return _dgd_compile_receipt(:fail_closed, :bundle_errors, input, :none)
        v1, e1 = g1_diffusion_validate(input.g1)
        v1 === :valid || return _dgd_compile_receipt(:fail_closed, :g1_declaration_invalid, input, :none)
        g2a = g2mb_admit(input.g2.source)
        g2a.status in (:valid, :terminal_deferred) ||
            return _dgd_compile_receipt(:fail_closed, :g2_declaration_invalid, input, :none)
        v3, e3 = g3_sf_validate_v1(input.g3)
        v3 === :valid || return _dgd_compile_receipt(:fail_closed, :g3_declaration_invalid, input, :none)
        g3a = g3_sf_admit_v1(input.g3)
        g3a.status in (:proposal, :terminal_deferred) ||
            return _dgd_compile_receipt(:fail_closed, :g3_admission_invalid, input, :none,
                g2_status=g2a.status, g2_resolution=g2a.resolution,
                g3_status=g3a.status, g3_resolution=g3a.resolution)
        for layer in (:G1, :G2, :G3)
            body = _dgd_bundle_body(input, layer)
            body === nothing && return _dgd_compile_receipt(:fail_closed, :bundle_layer_missing, input, :none)
            getproperty(body, :candidate_ref) == input.candidate_ref ||
                return _dgd_compile_receipt(:fail_closed, :bundle_candidate_mismatch, input, :none)
            canonical_hash(body) == getproperty(input.hashes, Symbol(lowercase(String(layer)), "_body_hash")) ||
                return _dgd_compile_receipt(:fail_closed, :bundle_body_hash_mismatch, input, :none)
        end
        _dgd_expression_subset(input) ||
            return _dgd_compile_receipt(:terminal_deferred, :unsupported_expression_subset, input, :none;
                g2_status=g2a.status, g2_resolution=g2a.resolution,
                g3_status=g3a.status, g3_resolution=g3a.resolution)
        code = (g2a.resolution === :resolved && g3a.resolution === :resolved) ?
            :declared_expression_subset_admitted : :declared_expression_subset_admitted_with_deferred_authority
        _dgd_compile_receipt(:ready, code, input, :diagonal_affine_static;
            g2_status=g2a.status, g2_resolution=g2a.resolution,
            g3_status=g3a.status, g3_resolution=g3a.resolution)
    catch
        _dgd_compile_receipt(:fail_closed, :program_exception, input, :none)
    end
end

function dgd_local_mesh_v1(input::DeclaredG123InputV1)
    s = input.g2.source
    c = s.chart_map; m = s.mesh
    m.chart_ref == c.chart_ref || throw(ArgumentError("mesh_chart_ref_mismatch"))
    n = m.cells[1]
    n >= 2 || throw(ArgumentError("local mesh requires at least two interior cells"))
    refs = Tuple((Float64(i) / Float64(n + 1), 0.5, 0.5) for i in 1:n)
    phys = Tuple(begin p = g2mb_chart_map(c, (i // (n + 1), 1 // 2, 1 // 2));
        (Float64(p[1]), Float64(p[2]), Float64(p[3])) end for i in 1:n)
    spacing = n > 1 ? abs(phys[2][1] - phys[1][1]) : 1.0
    isfinite(spacing) && spacing > 0 || throw(ArgumentError("derived mesh spacing invalid"))
    image_bounds = g2mb_chart_image_bounds(c)
    bounds = ntuple(i -> (Float64(image_bounds[i][1]), Float64(image_bounds[i][2])), 3)
    qpoints = Tuple(ntuple(j -> Float64(p[j]), 3) for p in m.quadrature_points)
    qweights = Tuple(Float64(w) for w in m.quadrature_weights)
    body = (chart_ref=c.chart_ref, mesh_ref=m.mesh_ref, cells=m.cells, basis=m.basis,
        quadrature_points=qpoints, quadrature_weights=qweights,
        faces=s.faces, execution_status=m.execution_status, bounds=bounds,
        y_z_topology=(cells_y=m.cells[2], cells_z=m.cells[3], basis=m.basis),
        reference_nodes=refs, physical_nodes=phys, spacing=spacing)
    DGDLocalMeshV1(c.chart_ref, m.mesh_ref, m.cells, m.basis, qpoints, qweights,
        s.faces, m.execution_status, bounds, refs, phys, spacing, _dgd_hash(body))
end

function _dgd_transfer_failure(old_mesh::DGDLocalMeshV1, new_mesh::DGDLocalMeshV1,
        code::Symbol)
    body = (code=code, old_mesh=old_mesh.mesh_hash, new_mesh=new_mesh.mesh_hash)
    DGDTransferReceiptV1(:fail_closed, code, old_mesh.mesh_hash, new_mesh.mesh_hash,
        (0.0, 0.0), (0.0, 0.0), (0.0, 0.0), (0.0, 0.0), Inf, _dgd_hash(body))
end

function dgd_transfer_v1(old_mesh::DGDLocalMeshV1, new_mesh::DGDLocalMeshV1,
        old_state; overlap=nothing)
    try
        x = Tuple(Float64.(old_state)); length(x) == 2 || return _dgd_transfer_failure(old_mesh, new_mesh, :malformed_state_shape)
        all(isfinite, x) || return _dgd_transfer_failure(old_mesh, new_mesh, :nonfinite_state)
        old_lo, old_hi = old_mesh.bounds[1]
        new_lo, new_hi = new_mesh.bounds[1]
        old_hi > old_lo && new_hi > new_lo || return _dgd_transfer_failure(old_mesh, new_mesh, :malformed_mesh_bounds)
        ov = overlap === nothing ? (max(old_lo, new_lo), min(old_hi, new_hi)) : Tuple(Float64.(overlap))
        length(ov) == 2 || return _dgd_transfer_failure(old_mesh, new_mesh, :malformed_overlap_shape)
        all(isfinite, ov) || return _dgd_transfer_failure(old_mesh, new_mesh, :nonfinite_overlap)
        ov[2] > ov[1] || return DGDTransferReceiptV1(:terminal_deferred, :invalid_overlap,
            old_mesh.mesh_hash, new_mesh.mesh_hash, (x[1],x[2]), (0.0,0.0),
            (ov[1],ov[2]), (0.0,0.0), Inf,
            _dgd_hash((code=:invalid_overlap, old_mesh=old_mesh.mesh_hash,
                new_mesh=new_mesh.mesh_hash, overlap=ov)))
        overlap_fraction = clamp((ov[2] - ov[1]) / (old_hi - old_lo), 0.0, 1.0)
        # The same overlap fraction is used for both target DOFs, preserving
        # the old two-cell integral exactly while still binding the receipt to
        # the actual old/new geometric overlap.
        wt = (overlap_fraction, overlap_fraction)
        y = (wt[1] * x[1] + (1 - wt[1]) * x[2],
            (1 - wt[2]) * x[1] + wt[2] * x[2])
        residual = (y[1] + y[2]) - (x[1] + x[2])
        body = (old_mesh=old_mesh.mesh_hash, new_mesh=new_mesh.mesh_hash, old_state=x,
            new_state=y, overlap=(ov[1],ov[2]), weights=wt,
            conservation_residual=residual)
        DGDTransferReceiptV1(:ready, :conservative_overlap_transfer, old_mesh.mesh_hash,
            new_mesh.mesh_hash, (x[1],x[2]), y, (ov[1],ov[2]), wt, residual, _dgd_hash(body))
    catch
        _dgd_transfer_failure(old_mesh, new_mesh, :malformed_transfer_shape)
    end
end

function dgd_composition_admit_v1(input::DeclaredG123InputV1)
    try
        # Validate the typed G3 body before authority gates.  A malformed
        # ledger is a contradiction, not a missing-provider deferral.
        g3_status, g3_errors = g3_sf_validate_v1(input.g3)
        g3_status === :valid || begin
            ledger_error = any(occursin("ledger_", String(e)) for e in g3_errors)
            code = ledger_error ? :ledger_contradiction : :g3_declaration_invalid
            return DGDCompositionReceiptV1(:fail_closed, code,
                input.candidate_ref, input.hashes.g1_body_hash, input.hashes.g2_body_hash,
                input.hashes.g3_body_hash, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0,
                _dgd_hash((code=code, errors=g3_errors, hashes=input.hashes)))
        end
        s = input.g2.source
        g2a = g2mb_admit(s)
        authority_ok = g2a.status === :valid && g2a.resolution === :resolved
        authority_ok || return DGDCompositionReceiptV1(:terminal_deferred,
            :g2_admission_terminal_deferred,
            input.candidate_ref, input.hashes.g1_body_hash, input.hashes.g2_body_hash,
            input.hashes.g3_body_hash, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0,
            _dgd_hash((code=:g2_admission_terminal_deferred, status=g2a.status,
                resolution=g2a.resolution, gaps=g2a.gaps, hashes=input.hashes)))
        a = g3_sf_admit_v1(input.g3)
        (a.status === :proposal && a.resolution === :resolved) ||
            return DGDCompositionReceiptV1(:terminal_deferred, :g3_admission_terminal_deferred,
            input.candidate_ref, input.hashes.g1_body_hash, input.hashes.g2_body_hash,
            input.hashes.g3_body_hash, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0,
            _dgd_hash((code=:g3_admission_terminal_deferred, status=a.status,
                resolution=a.resolution, gaps=a.gaps)))
        value = g3_sf_evaluate_v1(input.g3, 120)
        body = (code=:typed_g3_ledger_composed, hashes=input.hashes,
            source=value.source_power, field=value.field_power, return_power=value.return_power,
            heat=value.heat_power, energy=value.energy_residual, ledger=value.ledger_residual)
        DGDCompositionReceiptV1(:ready, :typed_g3_ledger_composed, input.candidate_ref,
            input.hashes.g1_body_hash, input.hashes.g2_body_hash, input.hashes.g3_body_hash,
            Float64(value.source_power), Float64(value.field_power), Float64(value.return_power),
            Float64(value.heat_power), Float64(value.energy_residual), Float64(value.ledger_residual),
            0, 0, _dgd_hash(body))
    catch
        DGDCompositionReceiptV1(:fail_closed, :composition_type_or_ledger_error,
            input.candidate_ref, input.hashes.g1_body_hash, input.hashes.g2_body_hash,
            input.hashes.g3_body_hash, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0,
            _dgd_hash((code=:composition_type_or_ledger_error, candidate=input.candidate_ref)))
    end
end

function _dgd_scalar_source_values(input::DeclaredG123InputV1)
    expression = input.g1.f.source_expression
    expression in DGD_ALLOWED_F_EXPRESSIONS_V1 || return nothing
    (1.0, 1.0)
end

function _dgd_face_map(input::DeclaredG123InputV1)
    faces = input.g2.source.faces
    length(faces) == 6 || return nothing
    expected = (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)
    all(count(f -> f.face === key, faces) == 1 for key in expected) || return nothing
    Dict(f.face => f for f in faces)
end

function _dgd_rhs_from_g2_faces(input::DeclaredG123InputV1, mesh::DGDLocalMeshV1,
        k1, k3, source_values)
    fmap = _dgd_face_map(input); fmap === nothing && return nothing
    xlo, xhi = fmap[:x_min].value, fmap[:x_max].value
    h2 = mesh.spacing^2
    left = xlo.kind === :dirichlet ? Float64(xlo.value) * k1 / h2 :
        xlo.kind === :neumann ? -Float64(xlo.value) / mesh.spacing : NaN
    right = xhi.kind === :dirichlet ? Float64(xhi.value) * k3 / h2 :
        xhi.kind === :neumann ? Float64(xhi.value) / mesh.spacing : NaN
    # The reduced line model retains declared y/z face loads as a uniform
    # cross-section contribution.  Thus every declared face value enters RHS;
    # no face is silently discarded by the local reduction.
    side_load = sum(Float64(f.value.value) for key in (:y_min, :y_max, :z_min, :z_max)
        for f in (fmap[key],)) / Float64(mesh.cells[2] * mesh.cells[3])
    all(isfinite, (left, right, side_load)) || return nothing
    (source_values[1] + side_load + left, source_values[2] + side_load + right)
end

"""Extract one finite scalar from the declared diagonal-matrix K API result."""
function _dgd_k_scalar_sample_v1(value, label::Symbol)
    value isa Tuple && length(value) == 3 || return nothing
    all(row -> row isa Tuple && length(row) == 3, value) || return nothing
    entries = try
        Tuple(Float64(entry) for row in value for entry in row)
    catch
        return nothing
    end
    all(isfinite, entries) || return nothing
    all(iszero(value[i][j]) for i in 1:3 for j in 1:3 if i != j) || return nothing
    scalar = try Float64(value[1][1]) catch; return nothing end
    isfinite(scalar) || return nothing
    scalar
end

function dgd_numerical_solve_v1(input::DeclaredG123InputV1, mesh::DGDLocalMeshV1,
        transfer::DGDTransferReceiptV1)
    transfer.status === :ready || return nothing
    source_values = _dgd_scalar_source_values(input)
    source_values === nothing && return DGDNumericalReceiptV1(:terminal_deferred,
        :unsupported_expression_subset, ((0.0,0.0),(0.0,0.0)), (0.0,0.0), nothing,
        Inf, 0, _dgd_hash((code=:unsupported_expression_subset,)))
    k = input.g1.K.expression
    p1 = (0 // 1, 1 // 2, 1 // 2); pm = (1 // 2, 1 // 2, 1 // 2); p2 = (1 // 1, 1 // 2, 1 // 2)
    kval = (g1_diffusion_k_eval(k, p1), g1_diffusion_k_eval(k, pm), g1_diffusion_k_eval(k, p2))
    k1 = _dgd_k_scalar_sample_v1(kval[1], :x_min)
    k2 = _dgd_k_scalar_sample_v1(kval[2], :x_mid)
    k3 = _dgd_k_scalar_sample_v1(kval[3], :x_max)
    all(x -> x !== nothing, (k1, k2, k3)) || return DGDNumericalReceiptV1(
        :numerical_fail, :non_scalar_or_nonfinite_k_evaluation, ((0.0,0.0),(0.0,0.0)),
        (0.0,0.0), nothing, Inf, 0,
        _dgd_hash((code=:non_scalar_or_nonfinite_k_evaluation, samples=(k1,k2,k3))))
    isfinite(mesh.spacing) && mesh.spacing > 0 || return DGDNumericalReceiptV1(
        :numerical_fail, :singular_or_nonfinite_sparse_system, ((0.0,0.0),(0.0,0.0)),
        (0.0,0.0), nothing, Inf, 0,
        # Preserve a typed numerical failure without feeding NaN/Inf into the
        # canonical serializer.  The derived value is represented by a finite
        # status tag in the receipt identity body.
        _dgd_hash((code=:singular_or_nonfinite_sparse_system,
            spacing_status=:nonfinite, mesh_hash=mesh.mesh_hash)))
    h2 = mesh.spacing^2
    a = (k1 + k2) / h2; b = -k2 / h2; d = (k2 + k3) / h2
    rhs = _dgd_rhs_from_g2_faces(input, mesh, k1, k3, source_values)
    rhs === nothing && return DGDNumericalReceiptV1(:fail_closed, :g2_boundary_compilation_failed,
        ((a,b),(b,d)), (0.0,0.0), nothing, Inf, 0,
        _dgd_hash((code=:g2_boundary_compilation_failed, matrix=((a,b),(b,d)))))
    all(isfinite, (a, b, d)) || return DGDNumericalReceiptV1(:numerical_fail,
        :singular_or_nonfinite_sparse_system, ((a,b),(b,d)), rhs, nothing, Inf, 0,
        _dgd_hash((code=:singular_or_nonfinite_sparse_system, matrix=((a,b),(b,d)), rhs=rhs)))
    sparse_system = sparse([1, 1, 2, 2], [1, 2, 1, 2], [a, b, b, d], 2, 2)
    a, b, d = sparse_system[1, 1], sparse_system[1, 2], sparse_system[2, 2]
    det = a*d - b*b
    isfinite(det) && abs(det) > 1.0e-14 ||
        return DGDNumericalReceiptV1(:numerical_fail, :singular_or_nonfinite_sparse_system,
            ((a,b),(b,d)), rhs, nothing, Inf, 1,
            _dgd_hash((code=:singular_or_nonfinite_sparse_system, a=a,b=b,d=d,rhs=rhs)))
    solution = ((rhs[1]*d - b*rhs[2]) / det, (a*rhs[2] - b*rhs[1]) / det)
    all(isfinite, solution) || return DGDNumericalReceiptV1(:numerical_fail,
        :singular_or_nonfinite_sparse_system, ((a,b),(b,d)), rhs, nothing, Inf, 1,
        _dgd_hash((code=:singular_or_nonfinite_sparse_system, matrix=((a,b),(b,d)), rhs=rhs)))
    residual = (a*solution[1] + b*solution[2] - rhs[1], b*solution[1] + d*solution[2] - rhs[2])
    norm = sqrt(residual[1]^2 + residual[2]^2)
    body = (matrix=((a,b),(b,d)), rhs=rhs, solution=solution, residual_norm=norm,
        mesh_hash=mesh.mesh_hash, transfer_hash=transfer.receipt_hash)
    DGDNumericalReceiptV1(:ready, :bounded_sparse_diffusion_solved, ((a,b),(b,d)), rhs,
        solution, norm, 1, _dgd_hash(body))
end

# Public execution is a typed boundary: malformed candidate/body/bundle
# identities become fail-closed receipts.  The internal constructors above
# remain strict and may throw while assembling trusted typed inputs.
function _dgd_public_candidate(candidate)
    candidate isa QualifiedRefV1 && candidate.version == "v5" ? candidate :
        QualifiedRefV1("invalid://declared-g123/public-boundary", "v5")
end

function _dgd_public_error_code(err)
    msg = sprint(showerror, err)
    for (needle, code) in (
            ("bundle_hash_mismatch", :bundle_hash_mismatch),
            ("bundle semantic body differs", :bundle_body_hash_mismatch),
            ("bundle semantic bytes mismatch", :bundle_semantic_bytes_mismatch),
            ("bundle semantic bytes hash mismatch", :bundle_semantic_bytes_hash_mismatch),
            ("bundle declaration bytes differ", :declaration_bytes_mismatch),
            ("bundle declaration bytes hash mismatch", :declaration_bytes_hash_mismatch),
            ("bundle source bytes hash mismatch", :source_bytes_mismatch),
            ("bundle source identity", :source_identity_mismatch),
            ("bundle declaration identity", :declaration_identity_mismatch),
            ("factory receipt", :factory_receipt_mismatch),
            ("candidate mismatch", :candidate_mismatch),
            ("candidate_ref must use v5", :candidate_mismatch),
            ("g1_type_invalid", :g1_type_invalid),
            ("g2_type_invalid", :g2_type_invalid),
            ("g3_type_invalid", :g3_type_invalid),
            ("bundle_type_invalid", :bundle_type_invalid))
        occursin(needle, msg) && return code
    end
    :input_identity_mismatch
end

function _dgd_public_failure(candidate, code::Symbol)
    c = _dgd_public_candidate(candidate)
    h = digest256_text("dgd-public-failure:" * String(code))
    compile = DGDCompileReceiptV1(:fail_closed, code, c, h, h, h, h, :none,
        :unknown, :unknown, :unknown, :unknown, 0, 0,
        _dgd_hash((status=:fail_closed, code=code, candidate=c)))
    transfer = DGDTransferReceiptV1(:fail_closed, code, h, h, (0.0, 0.0),
        (0.0, 0.0), (0.0, 0.0), (0.0, 0.0), Inf,
        _dgd_hash((status=:fail_closed, code=code, candidate=c)))
    composition = DGDCompositionReceiptV1(:fail_closed, code, c, h, h, h,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0,
        _dgd_hash((status=:fail_closed, code=code, candidate=c)))
    DGDAggregateReceiptV1(:fail_closed, :fail_closed, false, DGD_CLAIM_CEILING_V1,
        true, false, false, c, compile, transfer, composition, nothing, 0, 0, 0,
        _dgd_hash((status=:fail_closed, code=code, candidate=c)))
end

"""Strict, typed public boundary for declared execution.

This wrapper is the only boundary used by negative dispatch tests.  It never
leaks candidate/body/bundle identity exceptions to a caller; malformed input
is represented by a fail-closed aggregate and a specific compile code.
"""
function dgd_execute_declared_v1(candidate, g1, g2, g3, bundle;
        old_state=(0.25, 0.75), overlap=nothing)
    try
        candidate isa QualifiedRefV1 || throw(ArgumentError("candidate_type_invalid"))
        g1 isa G1DiffusionDeclarationV1 || throw(ArgumentError("g1_type_invalid"))
        g2 isa G2MBDeclarationV1 || throw(ArgumentError("g2_type_invalid"))
        g3 isa G3SFDeclarationV1 || throw(ArgumentError("g3_type_invalid"))
        bundle isa VNextT0LocalTransportV1 || throw(ArgumentError("bundle_type_invalid"))
        input = dgd_input_v1(candidate, g1, g2, g3, bundle)
        dgd_execute_v1(input; old_state=old_state, overlap=overlap)
    catch err
        _dgd_public_failure(candidate, _dgd_public_error_code(err))
    end
end

function dgd_execute_v1(input::DeclaredG123InputV1; old_state=(0.25, 0.75),
        overlap=nothing)
    compile = dgd_compile_v1(input)
    compile.status !== :fail_closed || begin
        empty = DGDTransferReceiptV1(:terminal_deferred, :compile_not_ready,
            input.hashes.g2_body_hash, input.hashes.g2_body_hash, (0.0,0.0), (0.0,0.0),
            (0.0,1.0), (0.25,0.75), 0.0, _dgd_hash((code=:compile_not_ready,)))
        composition = dgd_composition_admit_v1(input)
        return DGDAggregateReceiptV1(:fail_closed, :fail_closed, false, DGD_CLAIM_CEILING_V1,
            true, false, false, input.candidate_ref, compile, empty, composition, nothing, 0, 0, 0,
            _dgd_hash((code=:compile_not_ready, compile=compile.receipt_hash)))
    end
    mesh = try dgd_local_mesh_v1(input) catch
        nothing
    end
    mesh === nothing && begin
        transfer = DGDTransferReceiptV1(:terminal_deferred, :mesh_derivation_failed,
            input.hashes.g2_body_hash, input.hashes.g2_body_hash, (0.0,0.0), (0.0,0.0),
            (0.0,1.0), (0.25,0.75), 0.0, _dgd_hash((code=:mesh_derivation_failed,)))
        composition = dgd_composition_admit_v1(input)
        return DGDAggregateReceiptV1(:terminal_deferred, :terminal_deferred, false,
            DGD_CLAIM_CEILING_V1, true, false, false, input.candidate_ref, compile, transfer,
            composition, nothing, 0, 0, 0, _dgd_hash((code=:mesh_derivation_failed,)))
    end
    transfer = dgd_transfer_v1(mesh, mesh, old_state; overlap=overlap)
    composition = dgd_composition_admit_v1(input)
    numerical = dgd_numerical_solve_v1(input, mesh, transfer)
    status = transfer.status !== :ready ? transfer.status :
        (composition.status !== :ready ? :terminal_deferred :
            (numerical === nothing ? :numerical_fail : numerical.status))
    resolution = status === :ready ? :local_screen_resolved : status
    solver_calls = numerical === nothing ? 0 : numerical.solver_calls
    body = (status=status, resolution=resolution, candidate=input.candidate_ref,
        hashes=input.hashes, compile=compile.receipt_hash, transfer=transfer.receipt_hash,
        composition=composition.receipt_hash, numerical=numerical === nothing ? nothing : numerical.receipt_hash)
    DGDAggregateReceiptV1(status, resolution, false, DGD_CLAIM_CEILING_V1, true, false, false,
        input.candidate_ref, compile, transfer, composition, numerical, 0, 0, solver_calls, _dgd_hash(body))
end
