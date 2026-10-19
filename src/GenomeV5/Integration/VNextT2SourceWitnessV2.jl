"""Concrete source witness precursor for the future VNEXT T2 rebinding.

This additive module deliberately stops before formal T1/T2 integration.  It
retains the current concrete ``CandidateStatePackageV5`` payload together with
the current source/declaration carriers, parent commitments, G3 child authority
state and feedback authority state.  The formal-T1 slot is a typed absence: no
digest supplied by a caller can turn this precursor into a formal T1 binding.

The checker always receives the independently owned producer inputs again.  A
witness is therefore checked against the current package, source records and
authority commitments, rather than accepted because its own hashes agree with
one another.
"""

const VNEXT_T2_SOURCE_WITNESS_SCHEMA_ID_V2 =
    "GenomeV5/Integration/VNextT2SourceWitnessV2"
const VNEXT_T2_SOURCE_WITNESS_SCHEMA_VERSION_V2 = "v2"
const VNEXT_T2_SOURCE_WITNESS_PROFILE_V2 =
    "concrete-source-witness-precursor-v2"
const VNEXT_T2_SOURCE_WITNESS_LAYERS_V2 = (:G1, :G2, :G3)
const VNEXT_T2_SOURCE_WITNESS_CHILDREN_V2 =
    (:realization, :control, :binding)
const VNEXT_T2_SOURCE_WITNESS_FORMAL_CONSUMERS_V2 =
    (:e0, :gi1a, :e1, :e2, :up2)

_vnext_t2_sw_zero_counts_v2() =
    (e0=0, gi1a=0, e1=0, e2=0, up2=0)

function _vnext_t2_sw_sha256_v2(bytes)
    Digest256(bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes)))))
end

function _vnext_t2_sw_unique!(items::Vector{Symbol})
    unique!(items)
    items
end

"""Typed proof that this precursor has not been bound to formal T1."""
struct VNextT2FormalT1PendingV2
    status::Symbol
    resolution::Symbol
    formal_t1_accepted::Bool
    package_hash::Nothing
    semantic_identity_hash::Nothing
    bundle_hash::Nothing
    reload_adapter_receipt_hash::Nothing
    formal_consumer_counts::NamedTuple
    reasons::Tuple{Vararg{Symbol}}
    function VNextT2FormalT1PendingV2()
        counts = _vnext_t2_sw_zero_counts_v2()
        new(:typed_absent, :terminal_deferred, false, nothing, nothing, nothing,
            nothing, counts,
            (:formal_t1_not_yet_accepted,
             :formal_t1_reload_adapter_not_observed,
             :formal_t2_consumers_not_executed))
    end
end

semantic_view(x::VNextT2FormalT1PendingV2) = (
    status=x.status, resolution=x.resolution,
    formal_t1_accepted=x.formal_t1_accepted,
    package_hash=x.package_hash,
    semantic_identity_hash=x.semantic_identity_hash,
    bundle_hash=x.bundle_hash,
    reload_adapter_receipt_hash=x.reload_adapter_receipt_hash,
    formal_consumer_counts=x.formal_consumer_counts,
    reasons=x.reasons)

"""One concrete layer joined to its current source/declaration carriers."""
struct VNextT2LayerSourceLinkV2{C}
    layer::Symbol
    candidate_ref::QualifiedRefV1
    component::C
    source_record::VNextT0LocalPresentDeclarationV1
    source_ref::QualifiedRefV1
    declaration_ref::QualifiedRefV1
    source_sha256::Digest256
    declaration_sha256::Digest256
    semantic_body_sha256::Digest256
    source_locator_sha256::Digest256
    factory_receipt_sha256::Digest256
    declaration_receipt_sha256::Digest256
    source_identity_hash::Digest256
    declaration_identity_hash::Digest256
    source_axes::NTuple{4,QualifiedRefV1}
    component_contract_ref::GenomeContractRef
    component_hash::Digest256
    component_payload_hash::Digest256
    component_axes::NamedTuple
    package_component_identity::NamedTuple
    link_hash::Digest256
end

function _vnext_t2_sw_layer_body_v2(layer, candidate_ref, record,
        component_contract_ref, component_hash, component_payload_hash,
        component_axes, package_component_identity;
        source_ref=record.source_ref,
        declaration_ref=record.declaration_ref,
        source_sha256=record.source_bytes.sha256,
        declaration_sha256=record.declaration_bytes.sha256,
        semantic_body_sha256=record.semantic_body.bytes.sha256,
        source_locator_sha256=nothing,
        factory_receipt_sha256=nothing,
        declaration_receipt_sha256=nothing,
        source_identity_hash=record.source_identity_hash,
        declaration_identity_hash=record.declaration_identity_hash,
        source_axes=record.axes,
        component=nothing)
    locator_bytes = Vector{UInt8}(codeunits(canonical_json(record.source_locator)))
    factory_bytes = Vector{UInt8}(codeunits(canonical_json(record.factory_receipt)))
    declaration_receipt_bytes =
        Vector{UInt8}(codeunits(canonical_json(record.declaration_receipt)))
    locator_sha = source_locator_sha256 === nothing ?
        _vnext_t2_sw_sha256_v2(locator_bytes) : source_locator_sha256
    factory_sha = factory_receipt_sha256 === nothing ?
        _vnext_t2_sw_sha256_v2(factory_bytes) : factory_receipt_sha256
    declaration_receipt_sha = declaration_receipt_sha256 === nothing ?
        _vnext_t2_sw_sha256_v2(declaration_receipt_bytes) :
        declaration_receipt_sha256
    component_object_hash = component === nothing ? component_payload_hash :
        canonical_hash(component)
    (schema_id=VNEXT_T2_SOURCE_WITNESS_SCHEMA_ID_V2,
     schema_version=VNEXT_T2_SOURCE_WITNESS_SCHEMA_VERSION_V2,
     kind=:layer_source_link,
     layer=layer,
     candidate_ref=candidate_ref,
     source_record_hash=canonical_hash(record),
     source_ref=source_ref,
     declaration_ref=declaration_ref,
     source_sha256=source_sha256,
     declaration_sha256=declaration_sha256,
     semantic_body_sha256=semantic_body_sha256,
     source_locator_sha256=locator_sha,
     factory_receipt_sha256=factory_sha,
     declaration_receipt_sha256=declaration_receipt_sha,
     source_identity_hash=source_identity_hash,
     declaration_identity_hash=declaration_identity_hash,
     source_axes=source_axes,
     component_contract_ref=component_contract_ref,
     component_hash=component_hash,
     component_payload_hash=component_payload_hash,
     component_object_hash=component_object_hash,
     component_axes=component_axes,
     package_component_identity=package_component_identity)
end

semantic_view(x::VNextT2LayerSourceLinkV2) = merge(
    _vnext_t2_sw_layer_body_v2(x.layer, x.candidate_ref, x.source_record,
        x.component_contract_ref, x.component_hash,
        x.component_payload_hash, x.component_axes,
        x.package_component_identity;
        source_ref=x.source_ref,
        declaration_ref=x.declaration_ref,
        source_sha256=x.source_sha256,
        declaration_sha256=x.declaration_sha256,
        semantic_body_sha256=x.semantic_body_sha256,
        source_locator_sha256=x.source_locator_sha256,
        factory_receipt_sha256=x.factory_receipt_sha256,
        declaration_receipt_sha256=x.declaration_receipt_sha256,
        source_identity_hash=x.source_identity_hash,
        declaration_identity_hash=x.declaration_identity_hash,
        source_axes=x.source_axes,
        component=x.component),
    (link_hash=x.link_hash, concrete_component_carried=true,
     concrete_source_record_carried=true))

"""Checked T0 recheck projection without copying its legacy large tuple snapshot."""
struct VNextT2T0RecheckLinkV2
    candidate_ref::QualifiedRefV1
    checked_output::VNextAuthorityRecheckLocalCheckedPresentV1
    t0_bundle_hash::Digest256
    canonical_transport_sha256::Digest256
    output_hash::Digest256
    link_hash::Digest256
end

semantic_view(x::VNextT2T0RecheckLinkV2) = (
    candidate_ref=x.candidate_ref,
    t0_bundle_hash=x.t0_bundle_hash,
    canonical_transport_sha256=x.canonical_transport_sha256,
    output_hash=x.output_hash,
    checked_output_content_hash=canonical_hash(x.checked_output),
    link_hash=x.link_hash,
    checked_output_carried=true)

"""Current G1/G2 parent commitments derived from the same concrete records."""
struct VNextT2ParentAuthorityLinkV2
    candidate_ref::QualifiedRefV1
    parent_bundle::PresentT0LocalParentBaselineBundleV1
    g1_authority_commitment::Digest256
    g2_authority_commitment::Digest256
    parent_bundle_hash::Digest256
    link_hash::Digest256
end

semantic_view(x::VNextT2ParentAuthorityLinkV2) = (
    candidate_ref=x.candidate_ref,
    g1_authority_commitment=x.g1_authority_commitment,
    g2_authority_commitment=x.g2_authority_commitment,
    parent_bundle_hash=x.parent_bundle_hash,
    parent_bundle_content_hash=canonical_hash(x.parent_bundle),
    link_hash=x.link_hash,
    concrete_parent_bundle_carried=true)

"""Current checked G3 commitment and the actual present binding state."""
struct VNextT2G3AuthorityLinkV2
    candidate_ref::QualifiedRefV1
    expected_commitment::VNextG3BindingAuthorityExpectedCommitmentV1
    binding_state::G3BindingStateV2
    commitment_hash::Digest256
    binding_state_hash::Digest256
    link_hash::Digest256
end

semantic_view(x::VNextT2G3AuthorityLinkV2) = (
    candidate_ref=x.candidate_ref,
    commitment_hash=x.commitment_hash,
    binding_state_hash=x.binding_state_hash,
    expected_commitment_content_hash=canonical_hash(x.expected_commitment),
    binding_state_content_hash=canonical_hash(x.binding_state),
    link_hash=x.link_hash,
    expected_commitment_carried=true,
    concrete_binding_state_carried=true)

"""Per-child view which preserves T0 absence independently of later authority."""
struct VNextT2ChildAuthorityLinkV2{T,A}
    kind::Symbol
    transport_child::T
    package_child_ref::NamedTuple
    authority_value::A
    transport_status::Symbol
    authority_status::Symbol
    resolution::Symbol
    link_hash::Digest256
end

semantic_view(x::VNextT2ChildAuthorityLinkV2) = (
    kind=x.kind, package_child_ref=x.package_child_ref,
    transport_status=x.transport_status,
    authority_status=x.authority_status,
    resolution=x.resolution,
    transport_child_hash=canonical_hash(x.transport_child),
    authority_hash=canonical_hash(x.authority_value),
    link_hash=x.link_hash,
    concrete_transport_child_carried=true,
    concrete_authority_value_carried=true)

"""Per-layer feedback join across package, T0 semantic body and G3 bridge."""
struct VNextT2FeedbackAuthorityLinkV2{P,T,S,B}
    target_layer::Symbol
    package_feedback::P
    transport_feedback::T
    semantic_target::S
    bridge_link::B
    target_source_ref::QualifiedRefV1
    target_declaration_ref::QualifiedRefV1
    authority_status::Symbol
    resolution::Symbol
    link_hash::Digest256
end

semantic_view(x::VNextT2FeedbackAuthorityLinkV2) = (
    target_layer=x.target_layer,
    target_source_ref=x.target_source_ref,
    target_declaration_ref=x.target_declaration_ref,
    authority_status=x.authority_status,
    resolution=x.resolution,
    package_feedback_hash=canonical_hash(x.package_feedback),
    transport_feedback_hash=canonical_hash(x.transport_feedback),
    semantic_target_hash=canonical_hash(x.semantic_target),
    bridge_link_hash=canonical_hash(x.bridge_link),
    link_hash=x.link_hash,
    package_feedback_carried=true,
    transport_feedback_carried=true,
    semantic_target_carried=true,
    bridge_link_carried=true)

"""Concrete precursor payload consumed later by the formal T2 integrator."""
struct VNextT2SourceWitnessV2{G1T,G2T,G3T}
    schema_id::String
    schema_version::String
    profile::String
    candidate_ref::QualifiedRefV1
    concrete_package::CandidateStatePackageV5{G1T,G2T,G3T}
    g1::VNextT2LayerSourceLinkV2{G1T}
    g2::VNextT2LayerSourceLinkV2{G2T}
    g3::VNextT2LayerSourceLinkV2{G3T}
    t0_recheck::VNextT2T0RecheckLinkV2
    parent_authority::VNextT2ParentAuthorityLinkV2
    g3_authority::VNextT2G3AuthorityLinkV2
    child_links::Tuple
    feedback_links::Tuple
    source_bundle_hash::Digest256
    concrete_package_hash::Digest256
    source_identity_hash::Digest256
    formal_t1::VNextT2FormalT1PendingV2
    formal_consumer_counts::NamedTuple
    source_status::Symbol
    resolution::Symbol
    formal_node_accepted::Bool
    gaps::Tuple{Vararg{Symbol}}
    witness_hash::Digest256
end

function _vnext_t2_sw_witness_body_v2(candidate_ref, package_hash,
        g1, g2, g3, t0_recheck, parent_authority, g3_authority,
        child_links, feedback_links, source_bundle_hash, source_identity_hash,
        formal_t1, formal_consumer_counts, source_status, resolution,
        formal_node_accepted, gaps)
    (schema_id=VNEXT_T2_SOURCE_WITNESS_SCHEMA_ID_V2,
     schema_version=VNEXT_T2_SOURCE_WITNESS_SCHEMA_VERSION_V2,
     profile=VNEXT_T2_SOURCE_WITNESS_PROFILE_V2,
     candidate_ref=candidate_ref,
     concrete_package_hash=package_hash,
     layer_link_hashes=(g1=g1.link_hash, g2=g2.link_hash, g3=g3.link_hash),
     t0_recheck_hash=t0_recheck.link_hash,
     parent_authority_hash=parent_authority.link_hash,
     g3_authority_hash=g3_authority.link_hash,
     child_link_hashes=Tuple(x.link_hash for x in child_links),
     feedback_link_hashes=Tuple(x.link_hash for x in feedback_links),
     source_bundle_hash=source_bundle_hash,
     source_identity_hash=source_identity_hash,
     formal_t1=formal_t1,
     formal_consumer_counts=formal_consumer_counts,
     source_status=source_status,
     resolution=resolution,
     formal_node_accepted=formal_node_accepted,
     gaps=gaps)
end

semantic_view(x::VNextT2SourceWitnessV2) = merge(
    _vnext_t2_sw_witness_body_v2(x.candidate_ref,
        x.concrete_package_hash, x.g1, x.g2, x.g3, x.t0_recheck,
        x.parent_authority, x.g3_authority, x.child_links,
        x.feedback_links, x.source_bundle_hash, x.source_identity_hash,
        x.formal_t1, x.formal_consumer_counts, x.source_status,
        x.resolution, x.formal_node_accepted, x.gaps),
    (witness_hash=x.witness_hash,
     concrete_candidate_state_package_v5_carried=true))

struct VNextT2SourceWitnessBuildResultV2
    status::Symbol
    resolution::Symbol
    local_producer_valid::Bool
    formal_node_accepted::Bool
    witness::Union{Nothing,VNextT2SourceWitnessV2}
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    formal_consumer_counts::NamedTuple
end

semantic_view(x::VNextT2SourceWitnessBuildResultV2) = (
    status=x.status, resolution=x.resolution,
    local_producer_valid=x.local_producer_valid,
    formal_node_accepted=x.formal_node_accepted,
    witness=x.witness, errors=x.errors, gaps=x.gaps,
    formal_consumer_counts=x.formal_consumer_counts)

struct VNextT2SourceWitnessValidationV2
    status::Symbol
    resolution::Symbol
    local_witness_valid::Bool
    formal_node_accepted::Bool
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    observed_witness_hash::Union{Nothing,Digest256}
    expected_witness_hash::Union{Nothing,Digest256}
    formal_consumer_counts::NamedTuple
end

semantic_view(x::VNextT2SourceWitnessValidationV2) = (
    status=x.status, resolution=x.resolution,
    local_witness_valid=x.local_witness_valid,
    formal_node_accepted=x.formal_node_accepted,
    errors=x.errors, gaps=x.gaps,
    observed_witness_hash=x.observed_witness_hash,
    expected_witness_hash=x.expected_witness_hash,
    formal_consumer_counts=x.formal_consumer_counts)

function _vnext_t2_sw_component_v2(package, layer::Symbol)
    layer === :G1 && return package.g1
    layer === :G2 && return package.g2
    layer === :G3 && return package.g3
    throw(ArgumentError("source witness layer invalid"))
end

function _vnext_t2_sw_component_identity_v2(package, layer::Symbol)
    id = package.component_identity
    layer === :G1 && return (
        contract_ref=id.g1_ref, genome_hash=id.g1_genome_hash,
        candidate_binding=id.g1_candidate_binding)
    layer === :G2 && return (
        contract_ref=id.g2_ref, genome_hash=id.g2_genome_hash,
        candidate_binding=id.g2_candidate_binding)
    layer === :G3 && return (
        contract_ref=id.g3_ref, genome_hash=id.g3_genome_hash,
        candidate_ref=id.g3_candidate_ref, child_refs=id.g3_child_refs,
        feedback=id.feedback)
    throw(ArgumentError("source witness layer invalid"))
end

function _vnext_t2_sw_record_map_v2(transport, errors)
    out = Dict{Symbol,VNextT0LocalPresentDeclarationV1}()
    for item in transport.declarations
        if !(item isa VNextT0LocalPresentDeclarationV1)
            push!(errors, :source_witness_layer_material_absent)
            continue
        end
        item.layer in VNEXT_T2_SOURCE_WITNESS_LAYERS_V2 ||
            (push!(errors, :source_witness_unknown_layer); continue)
        haskey(out, item.layer) &&
            push!(errors, :source_witness_duplicate_layer)
        out[item.layer] = item
    end
    for layer in VNEXT_T2_SOURCE_WITNESS_LAYERS_V2
        haskey(out, layer) || push!(errors, :source_witness_layer_material_absent)
    end
    out
end

function _vnext_t2_sw_package_errors_v2(package)
    errors = Symbol[]
    package.structural_status === :valid ||
        push!(errors, :source_witness_concrete_package_invalid)
    package.claim_ceiling === none ||
        push!(errors, :source_witness_concrete_package_claim_invalid)
    try
        _v5_package_identity_valid(package.candidate_ref, package.g1, package.g2,
            package.g2_binding, package.g3, package.version_axes,
            package.component_identity, package.migration_receipt;
            require_candidate=true) ||
            push!(errors, :source_witness_component_identity_mismatch)
    catch
        push!(errors, :source_witness_component_identity_mismatch)
    end
    for layer in VNEXT_T2_SOURCE_WITNESS_LAYERS_V2
        component = _vnext_t2_sw_component_v2(package, layer)
        _v5_component_type_valid(component, layer) ||
            push!(errors, :source_witness_concrete_component_type_invalid)
        _v5_contract_ref(component) isa GenomeContractRef ||
            push!(errors, :source_witness_component_contract_ref_missing)
        getproperty(component, :candidate_hash) isa Digest256 ||
            push!(errors, :source_witness_component_hash_missing)
        expected_axes = getproperty(package.version_axes,
            layer === :G1 ? :g1 : layer === :G2 ? :g2 : :g3)
        _v5_axis_identity(_v5_axes(component)) == expected_axes ||
            push!(errors, :source_witness_component_axis_mismatch)
    end
    _vnext_t2_sw_unique!(errors)
end

function _vnext_t2_sw_transport_errors_v2(transport, candidate_ref, records)
    errors = Symbol[]
    transport.candidate_ref == candidate_ref ||
        push!(errors, :source_witness_candidate_mismatch)
    transport.status === :valid ||
        push!(errors, :source_witness_t0_status_invalid)
    isempty(transport.errors) ||
        push!(errors, :source_witness_t0_errors_present)
    try
        vnext_t0_local_bundle_hash_recompute_v1(transport) ==
            transport.bundle_hash ||
            push!(errors, :source_witness_t0_bundle_mismatch)
    catch
        push!(errors, :source_witness_t0_bundle_mismatch)
    end
    for layer in VNEXT_T2_SOURCE_WITNESS_LAYERS_V2
        haskey(records, layer) || continue
        record = records[layer]
        append!(errors, _vnl_t0_errors(record, candidate_ref))
        record.source_bytes.sha256 ==
            _vnext_t2_sw_sha256_v2(record.source_bytes.bytes) ||
            push!(errors, :source_witness_source_carrier_mismatch)
        record.declaration_bytes.sha256 ==
            _vnext_t2_sw_sha256_v2(record.declaration_bytes.bytes) ||
            push!(errors, :source_witness_declaration_carrier_mismatch)
        record.semantic_body.bytes.sha256 ==
            _vnext_t2_sw_sha256_v2(record.semantic_body.bytes.bytes) ||
            push!(errors, :source_witness_semantic_carrier_mismatch)
        record.source_identity_hash == canonical_hash((kind=:source,
            ref=record.source_ref,
            bytes_sha256=record.source_bytes.sha256)) ||
            push!(errors, :source_witness_source_identity_mismatch)
        record.declaration_identity_hash == canonical_hash((kind=:declaration,
            ref=record.declaration_ref,
            bytes_sha256=record.declaration_bytes.sha256)) ||
            push!(errors, :source_witness_declaration_identity_mismatch)
        body = record.semantic_body.body
        hasproperty(body, :candidate_ref) ||
            push!(errors, :source_witness_semantic_candidate_missing)
        hasproperty(body, :candidate_ref) && body.candidate_ref != candidate_ref &&
            push!(errors, :source_witness_semantic_candidate_mismatch)
    end
    for kind in VNEXT_T2_SOURCE_WITNESS_CHILDREN_V2
        matches = Tuple(x for x in transport.children if x.kind === kind)
        length(matches) == 1 || push!(errors,
            isempty(matches) ? :source_witness_child_missing :
            :source_witness_child_duplicate)
        isempty(matches) || append!(errors,
            _vnl_t0_child_errors(first(matches), candidate_ref, kind))
    end
    append!(errors, _vnl_t0_feedback_errors(transport.feedback,
        candidate_ref, transport.declarations))
    _vnext_t2_sw_unique!(errors)
end

function _vnext_t2_sw_recheck_errors_v2(recheck, transport, records)
    errors = Symbol[]
    recheck.status === :local_checked_present ||
        push!(errors, :source_witness_t0_recheck_not_present)
    recheck.resolution === :resolved ||
        push!(errors, :source_witness_t0_recheck_not_resolved)
    recheck.output isa VNextAuthorityRecheckLocalCheckedPresentV1 ||
        push!(errors, :source_witness_t0_recheck_output_invalid)
    recheck.prior_bundle_sha256 == transport.bundle_hash ||
        push!(errors, :source_witness_t0_recheck_bundle_mismatch)
    _vnext_t2_sw_snapshot_matches_v2(recheck.prior_bundle_bytes,
        canonical_json(transport)) ||
        push!(errors, :source_witness_t0_recheck_snapshot_mismatch)
    if recheck.output isa VNextAuthorityRecheckLocalCheckedPresentV1
        out = recheck.output
        out.candidate_ref == transport.candidate_ref ||
            push!(errors, :source_witness_t0_recheck_candidate_mismatch)
        out.bundle_hash == transport.bundle_hash ||
            push!(errors, :source_witness_t0_recheck_bundle_mismatch)
        for (layer, field) in ((:G1, :g1), (:G2, :g2), (:G3, :g3))
            canonical_json(getproperty(out, field)) ==
                canonical_json(records[layer]) ||
                push!(errors, :source_witness_t0_recheck_record_mismatch)
        end
        canonical_json(out.children) == canonical_json(transport.children) ||
            push!(errors, :source_witness_t0_recheck_child_mismatch)
        canonical_json(out.feedback) == canonical_json(transport.feedback) ||
            push!(errors, :source_witness_t0_recheck_feedback_mismatch)
    end
    _vnext_t2_sw_unique!(errors)
end

"""Compare a legacy tuple snapshot without materializing another huge tuple type."""
function _vnext_t2_sw_snapshot_matches_v2(snapshot, text::String)
    Base.@nospecialize snapshot
    snapshot isa Tuple || return false
    length(snapshot) == ncodeunits(text) || return false
    @inbounds for i in 1:ncodeunits(text)
        snapshot[i] isa UInt8 || return false
        snapshot[i] == codeunit(text, i) || return false
    end
    true
end

function _vnext_t2_sw_parent_errors_v2(parent_result, candidate_ref, records)
    errors = Symbol[]
    parent_result.status === :present ||
        push!(errors, :source_witness_parent_authority_absent)
    parent_result.resolution === :resolved ||
        push!(errors, :source_witness_parent_authority_unresolved)
    parent_result.output isa PresentT0LocalParentBaselineBundleV1 ||
        push!(errors, :source_witness_parent_bundle_invalid)
    if parent_result.output isa PresentT0LocalParentBaselineBundleV1
        out = parent_result.output
        g1_commitment = t0_parent_authority_commitment_v1(records[:G1])
        g2_commitment = t0_parent_authority_commitment_v1(records[:G2])
        out.candidate_ref == candidate_ref ||
            push!(errors, :source_witness_parent_candidate_mismatch)
        verify_present_t0_local_parent_bundle_v1(out,
            g1_commitment, g2_commitment) ||
            push!(errors, :source_witness_parent_commitment_mismatch)
        parent_result.output_hash == canonical_hash(out) ||
            push!(errors, :source_witness_parent_output_hash_mismatch)
    end
    _vnext_t2_sw_unique!(errors)
end

function _vnext_t2_sw_g3_errors_v2(expected, bridge, recheck,
        transport)
    errors = Symbol[]
    out = recheck.output
    out isa VNextAuthorityRecheckLocalCheckedPresentV1 ||
        return [:source_witness_g3_recheck_output_invalid]
    expected.candidate_ref == transport.candidate_ref ||
        push!(errors, :source_witness_g3_expected_candidate_mismatch)
    expected.bundle_hash == transport.bundle_hash ||
        push!(errors, :source_witness_g3_expected_bundle_mismatch)
    expected.g3_declaration_ref == out.g3.declaration_ref ||
        push!(errors, :source_witness_g3_expected_declaration_mismatch)
    expected.g3_declaration_identity_hash == out.g3.declaration_identity_hash ||
        push!(errors, :source_witness_g3_expected_identity_mismatch)
    vnext_g3_binding_expected_commitment_hash_v1(expected) ==
        expected.commitment_hash ||
        push!(errors, :source_witness_g3_commitment_hash_mismatch)
    bridge.status === :local_checked_present ||
        push!(errors, :source_witness_g3_authority_absent)
    bridge.resolution === :resolved ||
        push!(errors, :source_witness_g3_authority_unresolved)
    bridge.self_consistency ||
        push!(errors, :source_witness_g3_self_consistency_failed)
    bridge.authority_verified ||
        push!(errors, :source_witness_g3_authority_unverified)
    bridge.binding_state isa G3BindingStateV2 ||
        push!(errors, :source_witness_g3_binding_state_missing)
    if bridge.binding_state isa G3BindingStateV2
        state = bridge.binding_state
        isempty(_g3be2_validate_state(state)) ||
            push!(errors, :source_witness_g3_binding_state_invalid)
        state.source_payload.key.candidate_ref == transport.candidate_ref ||
            push!(errors, :source_witness_g3_binding_candidate_mismatch)
        state.source_payload.key.parent_g3_declaration_ref ==
            expected.g3_declaration_ref ||
            push!(errors, :source_witness_g3_binding_parent_ref_mismatch)
        state.source_payload.key.parent_g3_declaration_hash ==
            expected.g3_declaration_identity_hash ||
            push!(errors, :source_witness_g3_binding_parent_hash_mismatch)
        state.source_payload.source_record.evidence_receipt.content_hash ==
            expected.commitment_hash ||
            push!(errors, :source_witness_g3_authority_receipt_mismatch)
        canonical_json(state.source_payload.realization_slot) ==
            canonical_json(expected.realization) ||
            push!(errors, :source_witness_g3_realization_commitment_mismatch)
        canonical_json(state.source_payload.control_slot) ==
            canonical_json(expected.control) ||
            push!(errors, :source_witness_g3_control_commitment_mismatch)
    end
    _vnext_t2_sw_unique!(errors)
end

function _vnext_t2_sw_feedback_maps_v2(package, transport, records,
        bridge, errors)
    package_feedback = _v5_feedback(package.g3)
    semantic_body = records[:G3].semantic_body.body
    hasproperty(semantic_body, :feedback_targets) ||
        push!(errors, :source_witness_feedback_semantic_targets_missing)
    semantic_targets = hasproperty(semantic_body, :feedback_targets) ?
        Tuple(semantic_body.feedback_targets) : ()
    bridge_links = bridge.binding_state isa G3BindingStateV2 ?
        bridge.binding_state.editable_body.links : ()
    maps = Dict{Symbol,Any}()
    for layer in (:G1, :G2)
        ps = Tuple(x for x in package_feedback if x.target_layer === layer)
        ts = Tuple(x for x in transport.feedback if x.target_layer === layer)
        ss = Tuple(x for x in semantic_targets if x.target_layer === layer)
        bs = Tuple(x for x in bridge_links if x.target_layer === layer)
        all(length(xs) == 1 for xs in (ps, ts, ss, bs)) || begin
            push!(errors, :source_witness_feedback_linkage_arity_mismatch)
            continue
        end
        p, t, s, b = first(ps), first(ts), first(ss), first(bs)
        expected_component = layer === :G1 ? package.g1 : package.g2
        p.target_contract_ref == _v5_contract_ref(expected_component) ||
            push!(errors, :source_witness_package_feedback_target_mismatch)
        target_record = records[layer]
        (t.target_ref == target_record.source_ref ||
         t.target_ref == target_record.declaration_ref) ||
            push!(errors, :source_witness_transport_feedback_target_mismatch)
        t.candidate_ref == package.candidate_ref ||
            push!(errors, :source_witness_feedback_candidate_mismatch)
        s.authority.candidate_ref == package.candidate_ref ||
            push!(errors, :source_witness_feedback_authority_candidate_mismatch)
        s.authority.layer === layer ||
            push!(errors, :source_witness_feedback_authority_layer_mismatch)
        fields = (:target_layer, :target_path, :quantity, :unit, :direction,
            :sign, :source_id, :owner_scope, :authority)
        all(getproperty(s, f) == getproperty(b, f) for f in fields) ||
            push!(errors, :source_witness_feedback_bridge_mismatch)
        maps[layer] = (package=p, transport=t, semantic=s, bridge=b,
            target_record=target_record)
    end
    maps
end

function _vnext_t2_sw_validate_inputs_v2(package, transport, recheck,
        parent_result, g3_expected, g3_bridge)
    errors = Symbol[]
    append!(errors, _vnext_t2_sw_package_errors_v2(package))
    records = _vnext_t2_sw_record_map_v2(transport, errors)
    if length(records) == 3
        append!(errors, _vnext_t2_sw_transport_errors_v2(
            transport, package.candidate_ref, records))
        append!(errors, _vnext_t2_sw_recheck_errors_v2(
            recheck, transport, records))
        append!(errors, _vnext_t2_sw_parent_errors_v2(
            parent_result, package.candidate_ref, records))
        append!(errors, _vnext_t2_sw_g3_errors_v2(
            g3_expected, g3_bridge, recheck, transport))
        _vnext_t2_sw_feedback_maps_v2(package, transport, records,
            g3_bridge, errors)
    end
    _vnext_t2_sw_unique!(errors), records
end

function _vnext_t2_sw_layer_link_v2(package, record, layer)
    component = _vnext_t2_sw_component_v2(package, layer)
    component_ref = _v5_contract_ref(component)
    component_hash = component.candidate_hash
    component_payload_hash = canonical_hash(component)
    component_axes = getproperty(package.version_axes,
        layer === :G1 ? :g1 : layer === :G2 ? :g2 : :g3)
    package_identity = _vnext_t2_sw_component_identity_v2(package, layer)
    body = _vnext_t2_sw_layer_body_v2(layer, package.candidate_ref,
        record, component_ref, component_hash, component_payload_hash,
        component_axes, package_identity)
    VNextT2LayerSourceLinkV2(layer, package.candidate_ref, component,
        record, record.source_ref, record.declaration_ref,
        record.source_bytes.sha256, record.declaration_bytes.sha256,
        record.semantic_body.bytes.sha256,
        _vnext_t2_sw_sha256_v2(
            Vector{UInt8}(codeunits(canonical_json(record.source_locator)))),
        _vnext_t2_sw_sha256_v2(
            Vector{UInt8}(codeunits(canonical_json(record.factory_receipt)))),
        _vnext_t2_sw_sha256_v2(Vector{UInt8}(codeunits(
            canonical_json(record.declaration_receipt)))),
        record.source_identity_hash, record.declaration_identity_hash,
        record.axes, component_ref, component_hash,
        component_payload_hash, component_axes, package_identity,
        canonical_hash(body))
end

function _vnext_t2_sw_recheck_link_v2(recheck, transport)
    canonical_bytes = Vector{UInt8}(codeunits(canonical_json(transport)))
    canonical_sha = _vnext_t2_sw_sha256_v2(canonical_bytes)
    output_hash = canonical_hash(recheck.output)
    body = (kind=:t0_recheck_link, candidate_ref=transport.candidate_ref,
        t0_bundle_hash=transport.bundle_hash,
        canonical_transport_sha256=canonical_sha,
        output_hash=output_hash)
    VNextT2T0RecheckLinkV2(transport.candidate_ref, recheck.output,
        transport.bundle_hash, canonical_sha, output_hash,
        canonical_hash(body))
end

function _vnext_t2_sw_parent_link_v2(parent_result, records)
    bundle = parent_result.output
    g1 = t0_parent_authority_commitment_v1(records[:G1])
    g2 = t0_parent_authority_commitment_v1(records[:G2])
    body = (kind=:parent_authority_link,
        candidate_ref=bundle.candidate_ref,
        g1_authority_commitment=g1,
        g2_authority_commitment=g2,
        parent_bundle_hash=bundle.bundle_hash)
    VNextT2ParentAuthorityLinkV2(bundle.candidate_ref, bundle, g1, g2,
        bundle.bundle_hash, canonical_hash(body))
end

function _vnext_t2_sw_g3_link_v2(expected, bridge)
    state = bridge.binding_state
    body = (kind=:g3_authority_link,
        candidate_ref=expected.candidate_ref,
        commitment_hash=expected.commitment_hash,
        binding_state_hash=state.state_hash)
    VNextT2G3AuthorityLinkV2(expected.candidate_ref, expected, state,
        expected.commitment_hash, state.state_hash, canonical_hash(body))
end

function _vnext_t2_sw_child_links_v2(package, transport, expected, bridge)
    package_refs = package.component_identity.g3_child_refs
    state = bridge.binding_state
    out = Any[]
    for kind in VNEXT_T2_SOURCE_WITNESS_CHILDREN_V2
        child = only(Tuple(x for x in transport.children if x.kind === kind))
        package_ref = getproperty(package_refs, kind)
        authority = kind === :realization ? expected.realization :
            kind === :control ? expected.control : state
        transport_status = child isa VNextT0LocalChildPresentV1 ?
            :present : child.status
        authority_status = :present
        resolution = transport_status === :present ? :resolved :
            :terminal_deferred
        body = (kind=:child_authority_link, child_kind=kind,
            transport_child_hash=canonical_hash(child),
            package_child_ref=package_ref,
            authority_hash=canonical_hash(authority),
            transport_status=transport_status,
            authority_status=authority_status,
            resolution=resolution)
        push!(out, VNextT2ChildAuthorityLinkV2(kind, child, package_ref,
            authority, transport_status, authority_status, resolution,
            canonical_hash(body)))
    end
    Tuple(out)
end

function _vnext_t2_sw_feedback_links_v2(package, transport, records, bridge)
    errors = Symbol[]
    maps = _vnext_t2_sw_feedback_maps_v2(package, transport, records,
        bridge, errors)
    isempty(errors) || throw(ArgumentError(
        "source witness feedback linkage invalid"))
    out = Any[]
    for layer in (:G1, :G2)
        row = maps[layer]
        authority = row.semantic.authority
        authority_status = authority.status === :actual ? :present :
            :typed_absent
        resolution = authority_status === :present ? :resolved :
            :terminal_deferred
        body = (kind=:feedback_authority_link, target_layer=layer,
            package_feedback_hash=canonical_hash(row.package),
            transport_feedback_hash=canonical_hash(row.transport),
            semantic_target_hash=canonical_hash(row.semantic),
            bridge_link_hash=canonical_hash(row.bridge),
            target_source_ref=row.target_record.source_ref,
            target_declaration_ref=row.target_record.declaration_ref,
            authority_status=authority_status, resolution=resolution)
        push!(out, VNextT2FeedbackAuthorityLinkV2(layer, row.package,
            row.transport, row.semantic, row.bridge,
            row.target_record.source_ref, row.target_record.declaration_ref,
            authority_status, resolution, canonical_hash(body)))
    end
    Tuple(out)
end

function _vnext_t2_sw_construct_v2(package, transport, recheck,
        parent_result, g3_expected, g3_bridge, records)
    g1 = _vnext_t2_sw_layer_link_v2(package, records[:G1], :G1)
    g2 = _vnext_t2_sw_layer_link_v2(package, records[:G2], :G2)
    g3 = _vnext_t2_sw_layer_link_v2(package, records[:G3], :G3)
    t0_recheck = _vnext_t2_sw_recheck_link_v2(recheck, transport)
    parent_authority = _vnext_t2_sw_parent_link_v2(parent_result, records)
    g3_authority = _vnext_t2_sw_g3_link_v2(g3_expected, g3_bridge)
    child_links = _vnext_t2_sw_child_links_v2(package, transport,
        g3_expected, g3_bridge)
    feedback_links = _vnext_t2_sw_feedback_links_v2(package, transport,
        records, g3_bridge)
    source_identity_hash = canonical_hash((kind=:source_identity,
        candidate_ref=package.candidate_ref,
        t0_bundle_hash=transport.bundle_hash,
        concrete_package_hash=package.candidate_hash,
        layer_links=(g1.link_hash, g2.link_hash, g3.link_hash),
        parent_authority=parent_authority.link_hash,
        g3_authority=g3_authority.link_hash,
        child_links=Tuple(x.link_hash for x in child_links),
        feedback_links=Tuple(x.link_hash for x in feedback_links)))
    formal_t1 = VNextT2FormalT1PendingV2()
    counts = _vnext_t2_sw_zero_counts_v2()
    gaps = (:formal_t1_not_yet_accepted,
        :formal_t1_reload_adapter_not_observed,
        :formal_t2_consumers_not_executed,
        :t0_g3_children_typed_absent,
        :g3_feedback_authority_typed_absent)
    body = _vnext_t2_sw_witness_body_v2(package.candidate_ref,
        package.candidate_hash, g1, g2, g3, t0_recheck,
        parent_authority, g3_authority, child_links, feedback_links,
        transport.bundle_hash, source_identity_hash, formal_t1, counts,
        :source_ready, :terminal_deferred, false, gaps)
    VNextT2SourceWitnessV2(VNEXT_T2_SOURCE_WITNESS_SCHEMA_ID_V2,
        VNEXT_T2_SOURCE_WITNESS_SCHEMA_VERSION_V2,
        VNEXT_T2_SOURCE_WITNESS_PROFILE_V2, package.candidate_ref, package,
        g1, g2, g3, t0_recheck, parent_authority, g3_authority,
        child_links, feedback_links, transport.bundle_hash,
        package.candidate_hash, source_identity_hash, formal_t1, counts,
        :source_ready, :terminal_deferred, false, gaps,
        canonical_hash(body))
end

function _vnext_t2_sw_typed_absent_result_v2(reasons)
    gaps = Tuple(unique(Symbol(x) for x in reasons))
    VNextT2SourceWitnessBuildResultV2(:typed_absent,
        :terminal_deferred, false, false, nothing, (), gaps,
        _vnext_t2_sw_zero_counts_v2())
end

function _vnext_t2_sw_fail_result_v2(errors)
    codes = Tuple(_vnext_t2_sw_unique!(Symbol[x for x in errors]))
    VNextT2SourceWitnessBuildResultV2(:fail_closed, :none, false,
        false, nothing, codes, (), _vnext_t2_sw_zero_counts_v2())
end

"""Build only the concrete source precursor; never bind or call formal T2."""
function prepare_vnext_t2_source_witness_v2(
        package::CandidateStatePackageV5,
        transport::VNextT0LocalTransportV1,
        recheck::VNextAuthorityRecheckLocalResultV1,
        parent_result,
        g3_expected,
        g3_bridge)
    any(x -> x isa VNextT0LocalAbsentDeclarationV1,
        transport.declarations) &&
        return _vnext_t2_sw_typed_absent_result_v2(
            (:source_witness_layer_material_absent,))
    recheck.status === :typed_absent &&
        return _vnext_t2_sw_typed_absent_result_v2(
            isempty(recheck.reasons) ?
                (:source_witness_t0_recheck_absent,) : recheck.reasons)
    parent_result isa T0LocalParentBaselineBindResultV1 ||
        return _vnext_t2_sw_fail_result_v2(
            (:source_witness_parent_result_type_invalid,))
    g3_expected isa VNextG3BindingAuthorityExpectedCommitmentV1 ||
        return _vnext_t2_sw_fail_result_v2(
            (:source_witness_g3_expected_type_invalid,))
    g3_bridge isa VNextG3BindingAuthorityBridgeLocalResultV1 ||
        return _vnext_t2_sw_fail_result_v2(
            (:source_witness_g3_bridge_type_invalid,))
    errors, records = _vnext_t2_sw_validate_inputs_v2(package, transport,
        recheck, parent_result, g3_expected, g3_bridge)
    isempty(errors) || return _vnext_t2_sw_fail_result_v2(errors)
    witness = try
        _vnext_t2_sw_construct_v2(package, transport, recheck,
            parent_result, g3_expected, g3_bridge, records)
    catch
        return _vnext_t2_sw_fail_result_v2(
            (:source_witness_construction_exception,))
    end
    VNextT2SourceWitnessBuildResultV2(:source_ready,
        :terminal_deferred, true, false, witness, (), witness.gaps,
        witness.formal_consumer_counts)
end

function _vnext_t2_sw_same_v2(observed, expected)
    typeof(observed) === typeof(expected) || return false
    try
        canonical_json(observed) == canonical_json(expected)
    catch
        observed == expected
    end
end

function _vnext_t2_sw_compare_fields_v2(observed, expected, prefix::String,
        errors)
    typeof(observed) === typeof(expected) || begin
        push!(errors, Symbol(prefix * "_type_mismatch"))
        return
    end
    for field in fieldnames(typeof(expected))
        _vnext_t2_sw_same_v2(getfield(observed, field),
            getfield(expected, field)) ||
            push!(errors, Symbol(prefix * "_" * String(field) * "_mismatch"))
    end
end

function _vnext_t2_sw_compare_layer_v2(observed, expected, errors)
    _vnext_t2_sw_compare_fields_v2(observed, expected,
        "source_witness_layer_" * lowercase(String(expected.layer)), errors)
    record = observed.source_record
    observed.layer == record.layer ||
        push!(errors, :source_witness_layer_record_layer_mismatch)
    observed.candidate_ref == record.candidate_ref ||
        push!(errors, :source_witness_layer_record_candidate_mismatch)
    observed.source_ref == record.source_ref ||
        push!(errors, :source_witness_layer_source_ref_mismatch)
    observed.declaration_ref == record.declaration_ref ||
        push!(errors, :source_witness_layer_declaration_ref_mismatch)
    observed.source_sha256 == record.source_bytes.sha256 ||
        push!(errors, :source_witness_layer_source_sha_mismatch)
    observed.declaration_sha256 == record.declaration_bytes.sha256 ||
        push!(errors, :source_witness_layer_declaration_sha_mismatch)
    observed.semantic_body_sha256 == record.semantic_body.bytes.sha256 ||
        push!(errors, :source_witness_layer_semantic_sha_mismatch)
    observed.source_locator_sha256 == _vnext_t2_sw_sha256_v2(
        Vector{UInt8}(codeunits(canonical_json(record.source_locator)))) ||
        push!(errors, :source_witness_layer_source_locator_sha_mismatch)
    observed.factory_receipt_sha256 == _vnext_t2_sw_sha256_v2(
        Vector{UInt8}(codeunits(canonical_json(record.factory_receipt)))) ||
        push!(errors, :source_witness_layer_factory_receipt_sha_mismatch)
    observed.declaration_receipt_sha256 == _vnext_t2_sw_sha256_v2(
        Vector{UInt8}(codeunits(canonical_json(record.declaration_receipt)))) ||
        push!(errors, :source_witness_layer_declaration_receipt_sha_mismatch)
    observed.source_identity_hash == record.source_identity_hash ||
        push!(errors, :source_witness_layer_source_identity_mismatch)
    observed.declaration_identity_hash == record.declaration_identity_hash ||
        push!(errors, :source_witness_layer_declaration_identity_mismatch)
    observed.source_axes == record.axes ||
        push!(errors, :source_witness_layer_source_axes_mismatch)
    component = observed.component
    observed.component_contract_ref == _v5_contract_ref(component) ||
        push!(errors, :source_witness_layer_component_ref_mismatch)
    observed.component_hash == component.candidate_hash ||
        push!(errors, :source_witness_layer_component_hash_mismatch)
    observed.component_payload_hash == canonical_hash(component) ||
        push!(errors, :source_witness_layer_component_payload_hash_mismatch)
    observed.component_axes == _v5_axis_identity(_v5_axes(component)) ||
        push!(errors, :source_witness_layer_component_axes_mismatch)
    body = _vnext_t2_sw_layer_body_v2(observed.layer,
        observed.candidate_ref, record, observed.component_contract_ref,
        observed.component_hash, observed.component_payload_hash,
        observed.component_axes, observed.package_component_identity;
        source_ref=observed.source_ref,
        declaration_ref=observed.declaration_ref,
        source_sha256=observed.source_sha256,
        declaration_sha256=observed.declaration_sha256,
        semantic_body_sha256=observed.semantic_body_sha256,
        source_locator_sha256=observed.source_locator_sha256,
        factory_receipt_sha256=observed.factory_receipt_sha256,
        declaration_receipt_sha256=observed.declaration_receipt_sha256,
        source_identity_hash=observed.source_identity_hash,
        declaration_identity_hash=observed.declaration_identity_hash,
        source_axes=observed.source_axes,
        component=component)
    observed.link_hash == canonical_hash(body) ||
        push!(errors, :source_witness_layer_link_self_hash_mismatch)
end

function _vnext_t2_sw_compare_recheck_v2(observed, expected, errors)
    _vnext_t2_sw_compare_fields_v2(observed, expected,
        "source_witness_t0_recheck", errors)
    observed.output_hash == canonical_hash(observed.checked_output) ||
        push!(errors, :source_witness_t0_recheck_output_hash_mismatch)
    observed.candidate_ref == observed.checked_output.candidate_ref ||
        push!(errors, :source_witness_t0_recheck_candidate_mismatch)
    observed.t0_bundle_hash == observed.checked_output.bundle_hash ||
        push!(errors, :source_witness_t0_recheck_bundle_mismatch)
    body = (kind=:t0_recheck_link, candidate_ref=observed.candidate_ref,
        t0_bundle_hash=observed.t0_bundle_hash,
        canonical_transport_sha256=observed.canonical_transport_sha256,
        output_hash=observed.output_hash)
    observed.link_hash == canonical_hash(body) ||
        push!(errors, :source_witness_t0_recheck_link_self_hash_mismatch)
end

function _vnext_t2_sw_compare_parent_v2(observed, expected, errors)
    _vnext_t2_sw_compare_fields_v2(observed, expected,
        "source_witness_parent_authority", errors)
    observed.candidate_ref == observed.parent_bundle.candidate_ref ||
        push!(errors, :source_witness_parent_candidate_mismatch)
    observed.parent_bundle_hash == observed.parent_bundle.bundle_hash ||
        push!(errors, :source_witness_parent_bundle_hash_mismatch)
    body = (kind=:parent_authority_link,
        candidate_ref=observed.candidate_ref,
        g1_authority_commitment=observed.g1_authority_commitment,
        g2_authority_commitment=observed.g2_authority_commitment,
        parent_bundle_hash=observed.parent_bundle_hash)
    observed.link_hash == canonical_hash(body) ||
        push!(errors, :source_witness_parent_link_self_hash_mismatch)
end

function _vnext_t2_sw_compare_g3_v2(observed, expected, errors)
    _vnext_t2_sw_compare_fields_v2(observed, expected,
        "source_witness_g3_authority", errors)
    observed.candidate_ref == observed.expected_commitment.candidate_ref ||
        push!(errors, :source_witness_g3_candidate_mismatch)
    observed.commitment_hash == observed.expected_commitment.commitment_hash ||
        push!(errors, :source_witness_g3_commitment_hash_mismatch)
    observed.binding_state_hash == observed.binding_state.state_hash ||
        push!(errors, :source_witness_g3_binding_state_hash_mismatch)
    body = (kind=:g3_authority_link,
        candidate_ref=observed.candidate_ref,
        commitment_hash=observed.commitment_hash,
        binding_state_hash=observed.binding_state_hash)
    observed.link_hash == canonical_hash(body) ||
        push!(errors, :source_witness_g3_link_self_hash_mismatch)
end

function _vnext_t2_sw_compare_child_v2(observed, expected, errors)
    _vnext_t2_sw_compare_fields_v2(observed, expected,
        "source_witness_child_" * String(expected.kind), errors)
    body = (kind=:child_authority_link, child_kind=observed.kind,
        transport_child_hash=canonical_hash(observed.transport_child),
        package_child_ref=observed.package_child_ref,
        authority_hash=canonical_hash(observed.authority_value),
        transport_status=observed.transport_status,
        authority_status=observed.authority_status,
        resolution=observed.resolution)
    observed.link_hash == canonical_hash(body) ||
        push!(errors, :source_witness_child_link_self_hash_mismatch)
end

function _vnext_t2_sw_compare_feedback_v2(observed, expected, errors)
    _vnext_t2_sw_compare_fields_v2(observed, expected,
        "source_witness_feedback_" * lowercase(String(expected.target_layer)),
        errors)
    body = (kind=:feedback_authority_link,
        target_layer=observed.target_layer,
        package_feedback_hash=canonical_hash(observed.package_feedback),
        transport_feedback_hash=canonical_hash(observed.transport_feedback),
        semantic_target_hash=canonical_hash(observed.semantic_target),
        bridge_link_hash=canonical_hash(observed.bridge_link),
        target_source_ref=observed.target_source_ref,
        target_declaration_ref=observed.target_declaration_ref,
        authority_status=observed.authority_status,
        resolution=observed.resolution)
    observed.link_hash == canonical_hash(body) ||
        push!(errors, :source_witness_feedback_link_self_hash_mismatch)
end

"""Rebuild expected linkage from independent current inputs and compare it."""
function validate_vnext_t2_source_witness_v2(
        witness::VNextT2SourceWitnessV2,
        package::CandidateStatePackageV5,
        transport::VNextT0LocalTransportV1,
        recheck::VNextAuthorityRecheckLocalResultV1,
        parent_result,
        g3_expected,
        g3_bridge)
    counts = _vnext_t2_sw_zero_counts_v2()
    built = prepare_vnext_t2_source_witness_v2(package, transport, recheck,
        parent_result, g3_expected, g3_bridge)
    if built.status === :typed_absent
        return VNextT2SourceWitnessValidationV2(:typed_absent,
            :terminal_deferred, false, false, (), built.gaps,
            witness.witness_hash, nothing, counts)
    elseif built.status !== :source_ready || built.witness === nothing
        return VNextT2SourceWitnessValidationV2(:fail_closed, :none,
            false, false, built.errors, (), witness.witness_hash, nothing,
            counts)
    end
    expected = built.witness
    errors = Symbol[]
    witness.schema_id == VNEXT_T2_SOURCE_WITNESS_SCHEMA_ID_V2 ||
        push!(errors, :source_witness_schema_id_mismatch)
    witness.schema_version == VNEXT_T2_SOURCE_WITNESS_SCHEMA_VERSION_V2 ||
        push!(errors, :source_witness_schema_version_mismatch)
    witness.profile == VNEXT_T2_SOURCE_WITNESS_PROFILE_V2 ||
        push!(errors, :source_witness_profile_mismatch)
    witness.candidate_ref == package.candidate_ref ||
        push!(errors, :source_witness_candidate_mismatch)
    witness.concrete_package_hash == package.candidate_hash ||
        push!(errors, :source_witness_package_hash_mismatch)
    canonical_json(witness.concrete_package) == canonical_json(package) ||
        push!(errors, :source_witness_concrete_package_mismatch)
    _vnext_t2_sw_compare_layer_v2(witness.g1, expected.g1, errors)
    _vnext_t2_sw_compare_layer_v2(witness.g2, expected.g2, errors)
    _vnext_t2_sw_compare_layer_v2(witness.g3, expected.g3, errors)
    _vnext_t2_sw_compare_recheck_v2(witness.t0_recheck,
        expected.t0_recheck, errors)
    _vnext_t2_sw_compare_parent_v2(witness.parent_authority,
        expected.parent_authority, errors)
    _vnext_t2_sw_compare_g3_v2(witness.g3_authority,
        expected.g3_authority, errors)
    length(witness.child_links) == length(expected.child_links) ||
        push!(errors, :source_witness_child_link_arity_mismatch)
    for i in 1:min(length(witness.child_links), length(expected.child_links))
        _vnext_t2_sw_compare_child_v2(witness.child_links[i],
            expected.child_links[i], errors)
    end
    length(witness.feedback_links) == length(expected.feedback_links) ||
        push!(errors, :source_witness_feedback_link_arity_mismatch)
    for i in 1:min(length(witness.feedback_links),
            length(expected.feedback_links))
        _vnext_t2_sw_compare_feedback_v2(witness.feedback_links[i],
            expected.feedback_links[i], errors)
    end
    witness.source_bundle_hash == expected.source_bundle_hash ||
        push!(errors, :source_witness_source_bundle_mismatch)
    witness.source_identity_hash == expected.source_identity_hash ||
        push!(errors, :source_witness_source_identity_mismatch)
    _vnext_t2_sw_same_v2(witness.formal_t1,
        VNextT2FormalT1PendingV2()) ||
        push!(errors, :source_witness_formal_t1_slot_not_pending)
    witness.formal_consumer_counts == counts ||
        push!(errors, :source_witness_formal_consumer_count_nonzero)
    witness.formal_node_accepted == false ||
        push!(errors, :source_witness_formal_acceptance_fabricated)
    witness.source_status == expected.source_status ||
        push!(errors, :source_witness_source_status_mismatch)
    witness.resolution == expected.resolution ||
        push!(errors, :source_witness_resolution_mismatch)
    witness.gaps == expected.gaps ||
        push!(errors, :source_witness_gaps_mismatch)
    source_identity = canonical_hash((kind=:source_identity,
        candidate_ref=witness.candidate_ref,
        t0_bundle_hash=witness.source_bundle_hash,
        concrete_package_hash=witness.concrete_package_hash,
        layer_links=(witness.g1.link_hash, witness.g2.link_hash,
            witness.g3.link_hash),
        parent_authority=witness.parent_authority.link_hash,
        g3_authority=witness.g3_authority.link_hash,
        child_links=Tuple(x.link_hash for x in witness.child_links),
        feedback_links=Tuple(x.link_hash for x in witness.feedback_links)))
    witness.source_identity_hash == source_identity ||
        push!(errors, :source_witness_source_identity_self_hash_mismatch)
    witness.concrete_package_hash == witness.concrete_package.candidate_hash ||
        push!(errors, :source_witness_concrete_package_hash_mismatch)
    witness_body = _vnext_t2_sw_witness_body_v2(witness.candidate_ref,
        witness.concrete_package_hash, witness.g1, witness.g2, witness.g3,
        witness.t0_recheck, witness.parent_authority, witness.g3_authority,
        witness.child_links, witness.feedback_links,
        witness.source_bundle_hash, witness.source_identity_hash,
        witness.formal_t1, witness.formal_consumer_counts,
        witness.source_status, witness.resolution,
        witness.formal_node_accepted, witness.gaps)
    witness.witness_hash == canonical_hash(witness_body) ||
        push!(errors, :source_witness_self_hash_mismatch)
    witness.witness_hash == expected.witness_hash ||
        push!(errors, :source_witness_hash_mismatch)
    _vnext_t2_sw_unique!(errors)
    isempty(errors) ?
        VNextT2SourceWitnessValidationV2(:source_ready,
            :terminal_deferred, true, false, (), expected.gaps,
            witness.witness_hash, expected.witness_hash, counts) :
        VNextT2SourceWitnessValidationV2(:fail_closed, :none,
            false, false, Tuple(errors), (), witness.witness_hash,
            expected.witness_hash, counts)
end

export VNextT2FormalT1PendingV2,
       VNextT2LayerSourceLinkV2,
       VNextT2T0RecheckLinkV2,
       VNextT2ParentAuthorityLinkV2,
       VNextT2G3AuthorityLinkV2,
       VNextT2ChildAuthorityLinkV2,
       VNextT2FeedbackAuthorityLinkV2,
       VNextT2SourceWitnessV2,
       VNextT2SourceWitnessBuildResultV2,
       VNextT2SourceWitnessValidationV2,
       prepare_vnext_t2_source_witness_v2,
       validate_vnext_t2_source_witness_v2
