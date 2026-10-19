"""Candidate-bound, replay-bound G3 → spatial closure adapter (V1).

This is an isolated adapter boundary, not a provider or solver.  It revalidates
the supplied G3 source declaration and source bytes, re-runs the G3 material
projection from its typed inputs, and only emits a spatial closure when the
upstream contracts actually contain the required spatial fields.  The current
G3SF V1/G3MFP V3 contracts do not contain those fields, so their honest result
is `typed_absent` with no zero-filled spatial values.
"""

const G3_SPATIAL_AUTHORITY_ADAPTER_V1_REVISION = "g3-spatial-authority-adapter-v1"
const G3_SPATIAL_AUTHORITY_ADAPTER_V1_GAPS = (
    "g3_source_density_vector_A_m2_absent",
    "g3_return_current_spatial_distribution_and_circuit_path_absent",
    "g2_outer_boundary_B_out_T_samples_and_face_orientation_absent",
    "g3_outer_sheet_current_K_outer_A_m_and_surface_support_absent",
    "g2_full_volume_and_boundary_support_map_not_bound_by_heat_only_projection",
    "spatial_consumer_has_no_G3_current_or_B_out_K_outer_input_contract",
)

struct G3SpatialAuthorityAdapterRequestV1
    candidate_ref::QualifiedRefV1
    source_declaration::Union{Nothing,G3SFDeclarationV1}
    source_operating_point::Union{Nothing,G3MFPSourceOperatingPointV3}
    heat_endpoint_witness::Union{Nothing,G3MFPHeatEndpointWitnessV3}
    heat_allocation::Union{Nothing,G3MFPHeatAllocationReceiptV3}
    conductivity_selections::Tuple{Vararg{G3MFPConductivityTensorSelectionV3}}
    expected_material_receipt::Union{Nothing,G3MFPProjectionReceiptV3}
    g1_source_bytes::Union{Nothing,Vector{UInt8}}
    g2_source_bytes::Union{Nothing,Vector{UInt8}}
end

function G3SpatialAuthorityAdapterRequestV1(candidate_ref::Any, source_declaration::Any=nothing;
        source_operating_point::Any=nothing, heat_endpoint_witness::Any=nothing,
        heat_allocation::Any=nothing, conductivity_selections::Any=(),
        expected_material_receipt::Any=nothing, g1_source_bytes::Any=nothing,
        g2_source_bytes::Any=nothing)
    candidate_ref isa QualifiedRefV1 || throw(ArgumentError("candidate_ref must be QualifiedRefV1"))
    source_declaration === nothing || source_declaration isa G3SFDeclarationV1 ||
        throw(ArgumentError("source_declaration must be G3SFDeclarationV1 or nothing"))
    source_operating_point === nothing || source_operating_point isa G3MFPSourceOperatingPointV3 ||
        throw(ArgumentError("source_operating_point must be G3MFPSourceOperatingPointV3 or nothing"))
    heat_endpoint_witness === nothing || heat_endpoint_witness isa G3MFPHeatEndpointWitnessV3 ||
        throw(ArgumentError("heat_endpoint_witness must be G3MFPHeatEndpointWitnessV3 or nothing"))
    heat_allocation === nothing || heat_allocation isa G3MFPHeatAllocationReceiptV3 ||
        throw(ArgumentError("heat_allocation must be G3MFPHeatAllocationReceiptV3 or nothing"))
    conductivity_selections isa Tuple || throw(ArgumentError("conductivity_selections must be an immutable tuple"))
    all(x -> x isa G3MFPConductivityTensorSelectionV3, conductivity_selections) ||
        throw(ArgumentError("conductivity_selections contains an invalid typed value"))
    expected_material_receipt === nothing || expected_material_receipt isa G3MFPProjectionReceiptV3 ||
        throw(ArgumentError("expected_material_receipt must be G3MFPProjectionReceiptV3 or nothing"))
    for (name, bytes) in (("g1_source_bytes", g1_source_bytes), ("g2_source_bytes", g2_source_bytes))
        bytes === nothing || bytes isa AbstractVector{UInt8} ||
            throw(ArgumentError("$name must be Vector{UInt8} or nothing"))
    end
    G3SpatialAuthorityAdapterRequestV1(candidate_ref, source_declaration,
        source_operating_point, heat_endpoint_witness, heat_allocation,
        Tuple(conductivity_selections), expected_material_receipt,
        g1_source_bytes === nothing ? nothing : Vector{UInt8}(g1_source_bytes),
        g2_source_bytes === nothing ? nothing : Vector{UInt8}(g2_source_bytes))
end

struct G3SpatialAuthorityAdapterReceiptV1
    candidate_ref::QualifiedRefV1
    request_hash::Digest256
    source_declaration_hash::Union{Nothing,Digest256}
    material_projection::Union{Nothing,G3MFPProjectionReceiptV3}
    status::Symbol
    resolution::Symbol
    mapped_spatial_closure::Nothing
    claim_ceiling::Symbol
    physical_status::Symbol
    gaps::Tuple{Vararg{String}}
    errors::Tuple{Vararg{String}}
    compiler_calls::Int
    provider_calls::Int
    mesh_calls::Int
    solver_calls::Int
    physical_evidence::Bool
    receipt_hash::Digest256
end

function _g3sp_digest_bytes_v1(bytes::Vector{UInt8})
    Digest256(bytes2hex(SHA.sha256(bytes)))
end

function _g3sp_request_hash_v1(request::G3SpatialAuthorityAdapterRequestV1)
    declaration = request.source_declaration
    source = request.source_operating_point
    heat = request.heat_endpoint_witness
    allocation = request.heat_allocation
    expected = request.expected_material_receipt
    canonical_hash((domain=G3_SPATIAL_AUTHORITY_ADAPTER_V1_REVISION,
        candidate_ref=request.candidate_ref,
        source_declaration_hash=declaration === nothing ? nothing : declaration.declaration_hash,
        source_operating_point_hash=source === nothing ? nothing : source.record_hash,
        heat_endpoint_witness_hash=heat === nothing ? nothing : heat.record_hash,
        heat_allocation_hash=allocation === nothing ? nothing : allocation.receipt_hash,
        conductivity_selection_hashes=Tuple(x.selection_hash for x in request.conductivity_selections),
        expected_material_receipt_hash=expected === nothing ? nothing : expected.receipt_hash,
        g1_source_bytes=request.g1_source_bytes === nothing ? nothing :
            (bytes=length(request.g1_source_bytes), sha256=_g3sp_digest_bytes_v1(request.g1_source_bytes)),
        g2_source_bytes=request.g2_source_bytes === nothing ? nothing :
            (bytes=length(request.g2_source_bytes), sha256=_g3sp_digest_bytes_v1(request.g2_source_bytes))))
end

function _g3sp_receipt_v1(request::G3SpatialAuthorityAdapterRequestV1, projection,
        status::Symbol, gaps, errors)
    resolution = status === :fail_closed ? :fail_closed : :terminal_deferred
    declaration_hash = request.source_declaration === nothing ? nothing :
        request.source_declaration.declaration_hash
    request_hash = _g3sp_request_hash_v1(request)
    gap_tuple = Tuple(sort!(unique!(String.(collect(gaps)))))
    error_tuple = Tuple(sort!(unique!(String.(collect(errors)))))
    body = _g3sp_receipt_content_v1(request.candidate_ref, request_hash,
        declaration_hash, projection, status, resolution, gap_tuple, error_tuple)
    G3SpatialAuthorityAdapterReceiptV1(request.candidate_ref, request_hash,
        declaration_hash, projection, status, resolution, nothing, :contract_only,
        :unknown, gap_tuple, error_tuple, 0, 0, 0, 0, false, canonical_hash(body))
end

function _g3sp_receipt_content_v1(candidate_ref, request_hash, declaration_hash,
        projection, status, resolution, gaps, errors)
    (revision=G3_SPATIAL_AUTHORITY_ADAPTER_V1_REVISION,
     candidate_ref=candidate_ref, request_hash=request_hash,
     source_declaration_hash=declaration_hash,
     material_projection_hash=projection === nothing ? nothing : projection.receipt_hash,
     status=status, resolution=resolution, mapped_spatial_closure=nothing,
     claim_ceiling=:contract_only, physical_status=:unknown,
     gaps=gaps, errors=errors, compiler_calls=0, provider_calls=0,
     mesh_calls=0, solver_calls=0, physical_evidence=false)
end

function semantic_view(receipt::G3SpatialAuthorityAdapterReceiptV1)
    merge(_g3sp_receipt_content_v1(receipt.candidate_ref, receipt.request_hash,
        receipt.source_declaration_hash, receipt.material_projection, receipt.status,
        receipt.resolution, receipt.gaps, receipt.errors),
        (receipt_hash=receipt.receipt_hash,))
end

function canonical_hash(receipt::G3SpatialAuthorityAdapterReceiptV1)
    canonical_hash(_g3sp_receipt_content_v1(receipt.candidate_ref, receipt.request_hash,
        receipt.source_declaration_hash, receipt.material_projection, receipt.status,
        receipt.resolution, receipt.gaps, receipt.errors))
end

function _g3sp_authority_source_gaps_v1(declaration::G3SFDeclarationV1, request)
    gaps = String[]
    expected_layers = (:G1, :G2)
    authority_by_layer = Dict(a.layer => a for a in declaration.upstream_authority)
    for layer in expected_layers
        authority = get(authority_by_layer, layer, nothing)
        bytes = layer === :G1 ? request.g1_source_bytes : request.g2_source_bytes
        if authority === nothing || authority.status !== :actual
            bytes === nothing || return (gaps,
                ["upstream_source_bytes_without_actual_authority:" * String(layer)])
            push!(gaps, "same_candidate_actual_upstream_authority_missing:" * String(layer))
            continue
        end
        authority.candidate_ref == request.candidate_ref ||
            return (gaps, ["upstream_candidate_mismatch:" * String(layer)])
        if bytes === nothing
            push!(gaps, "upstream_source_bytes_not_supplied:" * String(layer))
            continue
        end
        length(bytes) == authority.source_bytes ||
            return (gaps, ["upstream_source_byte_count_mismatch:" * String(layer)])
        _g3sp_digest_bytes_v1(bytes) == authority.source_sha256 ||
            return (gaps, ["upstream_source_sha256_mismatch:" * String(layer)])
        expected_contract_hash = g3_sf_authority_content_hash_v1(layer,
            authority.candidate_ref, authority.contract_ref, authority.source_ref,
            authority.source_bytes, authority.source_sha256)
        authority.contract_hash == expected_contract_hash ||
            return (gaps, ["upstream_authority_content_hash_mismatch:" * String(layer)])
    end
    (gaps, String[])
end

"""Revalidate G3 inputs and return a typed spatial-closure disposition.

The G3 material receipt is freshly recomputed from the raw typed G3 inputs.
When `expected_material_receipt` is supplied, its receipt hash must match the
fresh replay.  Current G3SF V1/G3MFP V3 contain no spatial `J_source`, return
current path, `B_out`, or `K_outer` values, so a valid replay still returns
`typed_absent` and `mapped_spatial_closure === nothing`.
"""
function g3_spatial_authority_adapter_v1(request::G3SpatialAuthorityAdapterRequestV1)
    gaps = String[]
    errors = String[]
    declaration = request.source_declaration
    if declaration === nothing
        append!(gaps, ("g3_source_declaration_missing", G3_SPATIAL_AUTHORITY_ADAPTER_V1_GAPS...))
        projection = g3_mfp_project_v3(nothing, nothing)
        append!(gaps, projection.gaps)
        return _g3sp_receipt_v1(request, projection, :typed_absent, gaps, errors)
    end
    if declaration.candidate_ref != request.candidate_ref
        push!(errors, "source_declaration_candidate_mismatch")
        return _g3sp_receipt_v1(request, nothing, :fail_closed, gaps, errors)
    end
    sf_status, sf_errors = g3_sf_validate_v1(declaration)
    if sf_status !== :valid
        append!(errors, Tuple("g3_source_declaration:" * String(e) for e in sf_errors))
        projection = g3_mfp_project_v3(declaration, request.source_operating_point;
            heat_endpoint_witness=request.heat_endpoint_witness,
            heat_allocation=request.heat_allocation,
            conductivity_selections=request.conductivity_selections)
        return _g3sp_receipt_v1(request, projection, :fail_closed, gaps, errors)
    end

    authority_gaps, authority_errors = _g3sp_authority_source_gaps_v1(declaration, request)
    append!(gaps, authority_gaps)
    append!(errors, authority_errors)

    projection = g3_mfp_project_v3(declaration, request.source_operating_point;
        heat_endpoint_witness=request.heat_endpoint_witness,
        heat_allocation=request.heat_allocation,
        conductivity_selections=request.conductivity_selections)
    if projection.candidate_ref !== nothing && projection.candidate_ref != request.candidate_ref
        push!(errors, "material_projection_candidate_mismatch")
    end
    if projection.receipt_hash != canonical_hash(_g3mfp3_receipt_content(projection))
        push!(errors, "material_projection_receipt_hash_mismatch")
    end
    if request.expected_material_receipt !== nothing
        expected = request.expected_material_receipt
        expected.receipt_hash == canonical_hash(_g3mfp3_receipt_content(expected)) ||
            push!(errors, "expected_material_receipt_hash_mismatch")
        expected.receipt_hash == projection.receipt_hash ||
            push!(errors, "material_projection_fresh_replay_mismatch")
    end
    if projection.status === :fail_closed || !isempty(errors)
        append!(errors, Tuple("g3_material_projection:" * String(e) for e in projection.errors))
        return _g3sp_receipt_v1(request, projection, :fail_closed, gaps, errors)
    end
    if projection.resolution !== :screen_only
        append!(gaps, projection.gaps)
        append!(gaps, ("g3_material_projection_not_screen_ready", G3_SPATIAL_AUTHORITY_ADAPTER_V1_GAPS...))
        return _g3sp_receipt_v1(request, projection, :typed_absent, gaps, errors)
    end
    if projection.accepted || projection.formal_up2_credit || projection.formal_r_credit ||
            projection.discovery_credit || projection.engineering_credit ||
            projection.physical_status !== :unknown
        push!(errors, "material_projection_claim_ceiling_violation")
        return _g3sp_receipt_v1(request, projection, :fail_closed, gaps, errors)
    end
    projection.input_provenance === :synthetic_local &&
        push!(gaps, "synthetic_material_inputs_are_not_spatial_authority")
    append!(gaps, G3_SPATIAL_AUTHORITY_ADAPTER_V1_GAPS)
    isempty(gaps) && push!(gaps, "spatial_closure_fields_unavailable_in_current_g3_contracts")
    _g3sp_receipt_v1(request, projection, :typed_absent, gaps, errors)
end

function g3_spatial_authority_adapter_v1(candidate_ref::Any, source_declaration::Any=nothing; kwargs...)
    request = G3SpatialAuthorityAdapterRequestV1(candidate_ref, source_declaration; kwargs...)
    g3_spatial_authority_adapter_v1(request)
end
