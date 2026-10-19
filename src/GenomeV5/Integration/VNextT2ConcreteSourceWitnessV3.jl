"""Lossless native-declaration source witness for the future VNEXT T2 path.

This precursor reconstructs the current G1 diffusion, G2 metric-boundary and
G3 source-feedback declarations from the actual T0 semantic carriers.  It also
retains the complete current editable G3 child state.  State history ids and
the latest operation commitment are carried by those states; operation bodies
and receipts remain external replay evidence.  It deliberately has no formal
T1 identity and invokes no formal T2 consumer.

Freshness comes from the independent arguments supplied again to
`validate_vnext_t2_concrete_source_witness_v3`; a stored hash is never treated
as a substitute for source, declaration or child-state content.
"""

const VNEXT_T2_CONCRETE_SOURCE_WITNESS_SCHEMA_ID_V3 =
    "GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3"
const VNEXT_T2_CONCRETE_SOURCE_WITNESS_SCHEMA_VERSION_V3 = "v3"
const VNEXT_T2_CONCRETE_SOURCE_WITNESS_PROFILE_V3 =
    "native-concrete-source-witness-precursor-v3"
const VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3 = (:G1, :G2, :G3)
const _VNEXT_T2_V3_TRACE_ENABLED =
    get(ENV, "VNEXT_T2_SOURCE_WITNESS_TRACE", "0") == "1"
const _VNEXT_T2_V3_TRACE_EPOCH_NS = time_ns()

function _vnext_t2_v3_trace(stage::AbstractString; bytes=nothing)
    _VNEXT_T2_V3_TRACE_ENABLED || return nothing
    elapsed_ms = div(time_ns() - _VNEXT_T2_V3_TRACE_EPOCH_NS, 1_000_000)
    bytes_text = bytes === nothing ? "" : " bytes=$(bytes)"
    println("V3_STAGE stage=", stage, " elapsed_ms=", elapsed_ms, bytes_text)
    flush(stdout)
    nothing
end

_vnext_t2_v3_zero_counts() = (e0=0, gi1a=0, e1=0, e2=0, n10=0)

function _vnext_t2_v3_sha256(bytes::AbstractVector{UInt8})
    Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(bytes))))
end

_vnext_t2_v3_bytes(x) = Vector{UInt8}(codeunits(canonical_json(x)))

function _vnext_t2_v3_canonical_equal(a, b)
    try
        canonical_json(a) == canonical_json(b)
    catch
        false
    end
end

function _vnext_t2_v3_unique(xs::Vector{Symbol})
    unique!(xs)
    Tuple(xs)
end

"""Typed proof that the source precursor has not observed formal T1."""
struct VNextT2FormalT1PendingV3
    status::Symbol
    resolution::Symbol
    formal_t1_accepted::Bool
    package_hash::Nothing
    semantic_identity_hash::Nothing
    bundle_hash::Nothing
    reload_adapter_receipt_hash::Nothing
    formal_consumer_counts::NamedTuple
    reasons::Tuple{Vararg{Symbol}}
    function VNextT2FormalT1PendingV3()
        new(:typed_absent, :terminal_deferred, false, nothing, nothing, nothing,
            nothing, _vnext_t2_v3_zero_counts(),
            (:formal_t1_not_yet_accepted,
             :formal_t1_reload_adapter_not_observed,
             :formal_t2_consumers_not_executed))
    end
end

semantic_view(x::VNextT2FormalT1PendingV3) = (
    status=x.status, resolution=x.resolution,
    formal_t1_accepted=x.formal_t1_accepted,
    package_hash=x.package_hash,
    semantic_identity_hash=x.semantic_identity_hash,
    bundle_hash=x.bundle_hash,
    reload_adapter_receipt_hash=x.reload_adapter_receipt_hash,
    formal_consumer_counts=x.formal_consumer_counts,
    reasons=x.reasons)
canonical_json(x::VNextT2FormalT1PendingV3) = canonical_json(semantic_view(x))

"""Current child commitments, projected without equating initial and current source hashes."""
struct VNextT2G3CurrentStateProjectionV3
    candidate_ref::QualifiedRefV1
    parent_g3_declaration_ref::QualifiedRefV1
    parent_g3_declaration_hash::Digest256
    realization::VNextG3BindingChildExpectedCommitmentV1
    control::VNextG3BindingChildExpectedCommitmentV1
    projection_hash::Digest256
end

function _vnext_t2_v3_current_projection_body(x::VNextT2G3CurrentStateProjectionV3)
    (domain="vnext-t2-g3-current-state-projection-v3",
     candidate_ref=x.candidate_ref,
     parent_g3_declaration_ref=x.parent_g3_declaration_ref,
     parent_g3_declaration_hash=x.parent_g3_declaration_hash,
     realization=x.realization, control=x.control)
end
semantic_view(x::VNextT2G3CurrentStateProjectionV3) =
    merge(_vnext_t2_v3_current_projection_body(x),
        (projection_hash=x.projection_hash,))
canonical_json(x::VNextT2G3CurrentStateProjectionV3) = canonical_json(semantic_view(x))

"""Versioned bridge for actual current child state, including valid edit history."""
struct VNextT2ConcreteG3BridgeV3
    status::Symbol
    resolution::Symbol
    self_consistency::Bool
    authority_verified::Bool
    projection::Union{Nothing,VNextT2G3CurrentStateProjectionV3}
    binding_state::Union{Nothing,G3BindingStateV2}
    errors::Tuple{Vararg{Symbol}}
    reasons::Tuple{Vararg{Symbol}}
end
semantic_view(x::VNextT2ConcreteG3BridgeV3) = (
    status=x.status, resolution=x.resolution,
    self_consistency=x.self_consistency,
    authority_verified=x.authority_verified, projection=x.projection,
    binding_state=x.binding_state, errors=x.errors, reasons=x.reasons)
canonical_json(x::VNextT2ConcreteG3BridgeV3) = canonical_json(semantic_view(x))

"""Distinct source, semantic, declaration, carrier, component and axis identities."""
struct VNextT2ConcreteLayerIdentityV3
    layer::Symbol
    source_file_sha256::Digest256
    native_source_payload_hash::Digest256
    semantic_body_hash::Digest256
    semantic_body_sha256::Digest256
    native_declaration_hash::Digest256
    declaration_sha256::Digest256
    source_identity_hash::Digest256
    declaration_identity_hash::Digest256
    source_carrier_hash::Digest256
    declaration_component_hash::Digest256
    factory_content_identity::Digest256
    source_axes::NTuple{4,QualifiedRefV1}
    factory_axes::NTuple{4,QualifiedRefV1}
    identity_hash::Digest256
end

function _vnext_t2_v3_layer_identity_body(x::VNextT2ConcreteLayerIdentityV3)
    (domain="vnext-t2-concrete-layer-identity-v3", layer=x.layer,
     source_file_sha256=x.source_file_sha256,
     native_source_payload_hash=x.native_source_payload_hash,
     semantic_body_hash=x.semantic_body_hash,
     semantic_body_sha256=x.semantic_body_sha256,
     native_declaration_hash=x.native_declaration_hash,
     declaration_sha256=x.declaration_sha256,
     source_identity_hash=x.source_identity_hash,
     declaration_identity_hash=x.declaration_identity_hash,
     source_carrier_hash=x.source_carrier_hash,
     declaration_component_hash=x.declaration_component_hash,
     factory_content_identity=x.factory_content_identity,
     source_axes=x.source_axes, factory_axes=x.factory_axes)
end
semantic_view(x::VNextT2ConcreteLayerIdentityV3) =
    merge(_vnext_t2_v3_layer_identity_body(x), (identity_hash=x.identity_hash,))
canonical_json(x::VNextT2ConcreteLayerIdentityV3) = canonical_json(semantic_view(x))

struct VNextT2ConcreteG1DeclarationV3
    record::VNextT0LocalPresentDeclarationV1
    declaration::G1DiffusionDeclarationV1
    identity::VNextT2ConcreteLayerIdentityV3
end
semantic_view(x::VNextT2ConcreteG1DeclarationV3) =
    (record=x.record, declaration=x.declaration, identity=x.identity)
canonical_json(x::VNextT2ConcreteG1DeclarationV3) = canonical_json(semantic_view(x))

struct VNextT2ConcreteG2DeclarationV3
    record::VNextT0LocalPresentDeclarationV1
    candidate_envelope::VNextT0LocalG2CandidateEnvelopeV1
    declaration::G2MBDeclarationV1
    identity::VNextT2ConcreteLayerIdentityV3
end
semantic_view(x::VNextT2ConcreteG2DeclarationV3) =
    (record=x.record, candidate_envelope=x.candidate_envelope,
     declaration=x.declaration, identity=x.identity)
canonical_json(x::VNextT2ConcreteG2DeclarationV3) = canonical_json(semantic_view(x))

struct VNextT2ConcreteG3DeclarationV3
    record::VNextT0LocalPresentDeclarationV1
    source_ref::QualifiedRefV1
    declaration::G3SFDeclarationV1
    identity::VNextT2ConcreteLayerIdentityV3
end
semantic_view(x::VNextT2ConcreteG3DeclarationV3) =
    (record=x.record, source_ref=x.source_ref,
     declaration=x.declaration, identity=x.identity)
canonical_json(x::VNextT2ConcreteG3DeclarationV3) = canonical_json(semantic_view(x))

struct VNextT2ConcreteG3ChildrenV3
    t0_children::NTuple{3,VNextT0LocalChildV1}
    expected_commitment::VNextG3BindingAuthorityExpectedCommitmentV1
    realization_state::G3RealizationSourceStateV1
    control_payload::G3ControlSourcePayloadV1
    control_state::G3ControlStateV1
    binding_state::G3BindingStateV2
    identity_hash::Digest256
end

function _vnext_t2_v3_children_body(x::VNextT2ConcreteG3ChildrenV3)
    (domain="vnext-t2-concrete-g3-children-v3",
     t0_children=x.t0_children,
     expected_commitment=x.expected_commitment,
     realization_state=x.realization_state,
     control_payload=x.control_payload,
     control_state=x.control_state,
     binding_state=x.binding_state)
end
semantic_view(x::VNextT2ConcreteG3ChildrenV3) =
    merge(_vnext_t2_v3_children_body(x), (identity_hash=x.identity_hash,))
canonical_json(x::VNextT2ConcreteG3ChildrenV3) = canonical_json(semantic_view(x))

struct VNextT2ConcreteFeedbackV3
    t0_feedback::Tuple{Vararg{VNextT0LocalFeedbackV1}}
    g3_targets::Tuple{Vararg{G3SFFeedbackTargetV1}}
    binding_links::Tuple{Vararg{G3BindingLinkV1}}
    identity_hash::Digest256
end

function _vnext_t2_v3_feedback_body(x::VNextT2ConcreteFeedbackV3)
    (domain="vnext-t2-concrete-feedback-v3",
     t0_feedback=x.t0_feedback, g3_targets=x.g3_targets,
     binding_links=x.binding_links)
end
semantic_view(x::VNextT2ConcreteFeedbackV3) =
    merge(_vnext_t2_v3_feedback_body(x), (identity_hash=x.identity_hash,))
canonical_json(x::VNextT2ConcreteFeedbackV3) = canonical_json(semantic_view(x))

"""Physical joins are diagnosed separately from lossless source materialization."""
struct VNextT2SourceCouplingDiagnosticsV3
    status::Symbol
    resolution::Symbol
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    diagnostic_hash::Digest256
end

function _vnext_t2_v3_coupling_body(x::VNextT2SourceCouplingDiagnosticsV3)
    (domain="vnext-t2-source-coupling-diagnostics-v3", status=x.status,
     resolution=x.resolution, errors=x.errors, gaps=x.gaps)
end
semantic_view(x::VNextT2SourceCouplingDiagnosticsV3) =
    merge(_vnext_t2_v3_coupling_body(x), (diagnostic_hash=x.diagnostic_hash,))
canonical_json(x::VNextT2SourceCouplingDiagnosticsV3) = canonical_json(semantic_view(x))

struct VNextT2ConcreteSourceManifestV3
    candidate_ref::QualifiedRefV1
    t0_bundle_hash::Digest256
    t0_transport_hash::Digest256
    t0_recheck_output_hash::Digest256
    parent_bundle_hash::Digest256
    g3_expected_commitment_hash::Digest256
    g1_identity_hash::Digest256
    g2_identity_hash::Digest256
    g3_identity_hash::Digest256
    children_identity_hash::Digest256
    feedback_identity_hash::Digest256
    source_bundle_hash::Digest256
    manifest_hash::Digest256
end

function _vnext_t2_v3_manifest_body(x::VNextT2ConcreteSourceManifestV3)
    (domain="vnext-t2-concrete-source-manifest-v3",
     candidate_ref=x.candidate_ref,
     t0_bundle_hash=x.t0_bundle_hash,
     t0_transport_hash=x.t0_transport_hash,
     t0_recheck_output_hash=x.t0_recheck_output_hash,
     parent_bundle_hash=x.parent_bundle_hash,
     g3_expected_commitment_hash=x.g3_expected_commitment_hash,
     g1_identity_hash=x.g1_identity_hash,
     g2_identity_hash=x.g2_identity_hash,
     g3_identity_hash=x.g3_identity_hash,
     children_identity_hash=x.children_identity_hash,
     feedback_identity_hash=x.feedback_identity_hash,
     source_bundle_hash=x.source_bundle_hash)
end

function _vnext_t2_v3_recheck_output_body(x)
    if hasproperty(x, :declarations)
        return (domain="vnext-t2-concrete-source-recheck-output-v3",
            candidate_ref=x.candidate_ref, declarations=x.declarations,
            feedback=x.feedback, children=x.children, bundle_hash=x.bundle_hash)
    end
    (domain="vnext-t2-concrete-source-recheck-output-v3",
     candidate_ref=x.candidate_ref, g1=x.g1, g2=x.g2, g3=x.g3,
     feedback=x.feedback, children=x.children, bundle_hash=x.bundle_hash)
end
semantic_view(x::VNextT2ConcreteSourceManifestV3) =
    merge(_vnext_t2_v3_manifest_body(x), (manifest_hash=x.manifest_hash,))
canonical_json(x::VNextT2ConcreteSourceManifestV3) = canonical_json(semantic_view(x))

struct VNextT2ConcreteSourceWitnessV3
    schema_id::String
    schema_version::String
    profile::String
    candidate_ref::QualifiedRefV1
    g1::VNextT2ConcreteG1DeclarationV3
    g2::VNextT2ConcreteG2DeclarationV3
    g3::VNextT2ConcreteG3DeclarationV3
    t0_transport::VNextT0LocalTransportV1
    t0_recheck::Any
    parent_bundle::PresentT0LocalParentBaselineBundleV1
    children::VNextT2ConcreteG3ChildrenV3
    feedback::VNextT2ConcreteFeedbackV3
    coupling::VNextT2SourceCouplingDiagnosticsV3
    manifest::VNextT2ConcreteSourceManifestV3
    formal_t1::VNextT2FormalT1PendingV3
    source_status::Symbol
    resolution::Symbol
    formal_node_accepted::Bool
    gaps::Tuple{Vararg{Symbol}}
    witness_hash::Digest256
end

function _vnext_t2_v3_witness_body(x::VNextT2ConcreteSourceWitnessV3)
    (schema_id=x.schema_id, schema_version=x.schema_version, profile=x.profile,
     candidate_ref=x.candidate_ref, g1=x.g1, g2=x.g2, g3=x.g3,
     t0_transport=x.t0_transport,
     t0_recheck=_vnext_t2_v3_recheck_output_body(x.t0_recheck),
     parent_bundle=x.parent_bundle, children=x.children,
     feedback=x.feedback, coupling=x.coupling, manifest=x.manifest,
     formal_t1=x.formal_t1, source_status=x.source_status,
     resolution=x.resolution, formal_node_accepted=x.formal_node_accepted,
     gaps=x.gaps)
end
semantic_view(x::VNextT2ConcreteSourceWitnessV3) =
    merge(_vnext_t2_v3_witness_body(x), (witness_hash=x.witness_hash,))
canonical_json(x::VNextT2ConcreteSourceWitnessV3) = canonical_json(semantic_view(x))

struct VNextT2ConcreteSourceWitnessResultV3
    status::Symbol
    resolution::Symbol
    source_ready::Bool
    witness::Union{Nothing,VNextT2ConcreteSourceWitnessV3}
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
end
semantic_view(x::VNextT2ConcreteSourceWitnessResultV3) =
    (status=x.status, resolution=x.resolution, source_ready=x.source_ready,
     witness=x.witness, errors=x.errors, gaps=x.gaps)
canonical_json(x::VNextT2ConcreteSourceWitnessResultV3) = canonical_json(semantic_view(x))

function _vnext_t2_v3_result(status, resolution, witness, errors, gaps)
    es = _vnext_t2_v3_unique(Symbol[errors...])
    gs = _vnext_t2_v3_unique(Symbol[gaps...])
    VNextT2ConcreteSourceWitnessResultV3(status, resolution,
        status === :source_ready && witness !== nothing, witness, es, gs)
end

function _vnext_t2_v3_required_fields(body, fields)
    all(field -> hasproperty(body, field), fields)
end

function _vnext_t2_v3_exact_bytes(value, carrier::VNextT0LocalBytesV1)
    bytes = _vnext_t2_v3_bytes(value)
    bytes == carrier.bytes && carrier.sha256 == _vnext_t2_v3_sha256(bytes)
end

function _vnext_t2_v3_projection_matches(body, expected, extension_fields)
    expected_fields = propertynames(expected)
    body_fields = propertynames(body)
    allowed_fields = (expected_fields..., extension_fields...)
    Set(expected_fields) ⊆ Set(body_fields) &&
        Set(body_fields) ⊆ Set(allowed_fields) || return false
    all(field -> _vnext_t2_v3_canonical_equal(getproperty(body, field),
        getproperty(expected, field)), expected_fields)
end

function _vnext_t2_v3_authored_input_matches(input, frozen_context)
    frozen_context === nothing && return false
    try
        propertynames(input) == (:logical_path, :byte_count, :sha256, :bytes) ||
            return false
        source = if frozen_context isa AbstractString
            NativeGitReadCompatibilityV1.current_source(frozen_context,
                input.logical_path)
        else
            NativeGitReadCompatibilityV1.frozen_source(frozen_context,
                input.logical_path)
        end
        source === nothing && return false
        hasproperty(source, :role) && source.role in
            ("fixture_data", "test_fixture", "synthetic_fixture") && return false
        input.byte_count == source.byte_count == length(source.bytes) || return false
        input.sha256 == Digest256(source.sha256) || return false
        input.bytes isa AbstractVector{UInt8} && input.bytes == source.bytes &&
            input.sha256 == _vnext_t2_v3_sha256(input.bytes)
    catch
        false
    end
end

function _vnext_t2_v3_materialize_g1(record, errors; frozen_context=nothing, g2_record=nothing)
    body = record.semantic_body.body
    fields = (:candidate_ref, :source_ref, :source_version, :source_payload,
        :source_hash, :u, :K, :f, :operators, :closure_ref,
        :applicability_ref, :applicability_domain, :ownership,
        :negative_controls)
    _vnext_t2_v3_required_fields(body, fields) ||
        (push!(errors, :g1_semantic_body_shape_invalid); return nothing)
    declaration = try
        g1_diffusion_declaration_v1(body.candidate_ref, body.source_ref,
            body.source_version, body.source_hash, body.u, body.K, body.f,
            body.operators, body.closure_ref, body.applicability_ref,
            body.applicability_domain, body.negative_controls;
            ownership=body.ownership, source_payload=body.source_payload)
    catch
        push!(errors, :g1_declaration_reconstruction_failed)
        return nothing
    end
    status, _ = try g1_diffusion_validate(declaration) catch; (:program_exception, ()) end
    status === :valid || push!(errors, :g1_declaration_validation_failed)
    declaration.candidate_ref == record.candidate_ref ||
        push!(errors, :g1_candidate_mismatch)
    declaration.source_ref == record.source_ref || push!(errors, :g1_source_ref_mismatch)
    expected_body = _g1d_declaration_body(declaration)
    source_kind = try
        _vnext_current_source_g1_typed_source_kind_v1(declaration)
    catch
        push!(errors, :g1_source_expression_schema_invalid)
        :invalid
    end
    if declaration.u.source_expression == _VNEXT_CURRENT_G1_THERMAL_U_SOURCE_MARKER_V1 ||
            source_kind === :candidate_ast
        if !(g2_record isa VNextT0LocalPresentDeclarationV1 &&
             g2_record.layer === :G2 && g2_record.candidate_ref == record.candidate_ref)
            push!(errors, :g1_thermal_source_g2_record_missing)
        elseif !hasproperty(body, :value) ||
                !hasproperty(body.value, :g1_typed_source_field_program)
            push!(errors, :g1_thermal_source_program_missing)
        else
            rebuilt_program = try
                _vnext_current_source_g1_thermal_program_v1(record.candidate_ref,
                    declaration, record.declaration_ref, g2_record)
            catch
                push!(errors, :g1_thermal_source_program_reconstruction_failed)
                nothing
            end
            if rebuilt_program !== nothing
                _vnext_t2_v3_canonical_equal(
                    body.value.g1_typed_source_field_program, rebuilt_program) ||
                    push!(errors, :g1_thermal_source_program_mismatch)
                expected_body = merge(expected_body,
                    (value=(g1_typed_source_field_program=rebuilt_program,),))
            end
        end
    end
    _vnext_t2_v3_projection_matches(body, expected_body,
        (:authored_builder_input, :authored_expression_input)) ||
        push!(errors, :g1_semantic_projection_mismatch)
    if frozen_context !== nothing
        (hasproperty(body, :authored_builder_input) &&
         hasproperty(body, :authored_expression_input)) ||
            push!(errors, :g1_authored_inputs_missing)
    end
    hasproperty(body, :authored_builder_input) &&
        !_vnext_t2_v3_authored_input_matches(body.authored_builder_input,
            frozen_context) && push!(errors, :g1_authored_builder_input_mismatch)
    hasproperty(body, :authored_expression_input) &&
        !_vnext_t2_v3_authored_input_matches(body.authored_expression_input,
            frozen_context) && push!(errors, :g1_authored_expression_input_mismatch)
    _vnext_t2_v3_exact_bytes(body, record.semantic_body.bytes) ||
        push!(errors, :g1_semantic_bytes_mismatch)
    _vnext_t2_v3_exact_bytes(declaration, record.declaration_bytes) ||
        push!(errors, :g1_declaration_bytes_mismatch)
    declaration
end

function _vnext_t2_v3_materialize_g2(record, errors; frozen_context=nothing)
    body = record.semantic_body.body
    fields = (:candidate_ref, :candidate_envelope, :contract_ref, :source,
        :schema_hash, :canonicalization_hash, :profile_hash, :declaration_hash)
    _vnext_t2_v3_required_fields(body, fields) ||
        (push!(errors, :g2_semantic_body_shape_invalid); return nothing)
    body.candidate_envelope isa VNextT0LocalG2CandidateEnvelopeV1 ||
        (push!(errors, :g2_candidate_envelope_type_invalid); return nothing)
    body.source isa G2MBSourceV1 ||
        (push!(errors, :g2_source_type_invalid); return nothing)
    body.contract_ref isa GenomeContractRef ||
        (push!(errors, :g2_contract_ref_type_invalid); return nothing)
    envelope = body.candidate_envelope
    envelope.candidate_ref == record.candidate_ref == body.candidate_ref ||
        push!(errors, :g2_candidate_envelope_mismatch)
    envelope.contract_ref == body.contract_ref ||
        push!(errors, :g2_candidate_envelope_contract_mismatch)
    body.source.candidate_ref == body.contract_ref ||
        push!(errors, :g2_schema_contract_identity_mismatch)
    body.source.source_ref == envelope.source_ref == record.source_ref ||
        push!(errors, :g2_source_ref_mismatch)
    body.source.source_hash == envelope.source_hash ||
        push!(errors, :g2_source_hash_mismatch)
    declaration = try g2mb_declaration_v1(body.contract_ref, body.source) catch
        push!(errors, :g2_declaration_reconstruction_failed)
        return nothing
    end
    admission = try g2mb_admit(declaration.source) catch; nothing end
    admission === nothing && push!(errors, :g2_declaration_validation_exception)
    admission === nothing || admission.status in (:valid, :terminal_deferred) ||
        push!(errors, :g2_declaration_validation_failed)
    expected_body = (candidate_ref=body.candidate_ref,
        candidate_envelope=envelope, contract_ref=declaration.contract_ref,
        source=declaration.source, schema_hash=declaration.schema_hash,
        canonicalization_hash=declaration.canonicalization_hash,
        profile_hash=declaration.profile_hash,
        declaration_hash=declaration.declaration_hash)
    _vnext_t2_v3_projection_matches(body, expected_body,
        (:authored_builder_input,)) ||
        push!(errors, :g2_semantic_projection_mismatch)
    frozen_context !== nothing && !hasproperty(body, :authored_builder_input) &&
        push!(errors, :g2_authored_input_missing)
    hasproperty(body, :authored_builder_input) &&
        !_vnext_t2_v3_authored_input_matches(body.authored_builder_input,
            frozen_context) && push!(errors, :g2_authored_builder_input_mismatch)
    _vnext_t2_v3_exact_bytes(body, record.semantic_body.bytes) ||
        push!(errors, :g2_semantic_bytes_mismatch)
    _vnext_t2_v3_exact_bytes(declaration, record.declaration_bytes) ||
        push!(errors, :g2_declaration_bytes_mismatch)
    declaration
end

"""Rebuild the candidate G3 semantic body in an isolated module from frozen inputs.

The candidate builders contain the owner crosswalk and ledger projection rules;
reusing them avoids treating an embedded typed view as its own proof. This is
only needed for source bodies that carry the newer typed ledger view.
"""
function _vnext_t2_v3_frozen_source_module(; minimum_compiler::Bool=false)
    parent_module = @__MODULE__
    rebuild_module = Module(gensym(:VNextG3FrozenSourceRebuild), true, true)
    Core.eval(rebuild_module, :(import SHA))
    Core.eval(rebuild_module, :(const __v3_parent = $parent_module))
    bindings = Expr[]
    for name in names(parent_module; all=true, imported=true)
        name in (:Base, :Core, :Main, :eval, :include, :__init__, :__v3_parent,
            :UP4_R2_IDENTITY, :up4_r2_g3_child_design_source_v1,
            :up4_r2_build_g3_design) &&
            continue
        Base.isidentifier(String(name)) || continue
        isdefined(rebuild_module, name) && continue
        push!(bindings, Expr(:const, Expr(:(=), name,
            Expr(:., :__v3_parent, QuoteNode(name)))))
    end
    isempty(bindings) || Core.eval(rebuild_module, Expr(:block, bindings...))
    minimum_compiler && Core.eval(rebuild_module,
        :(Base.Experimental.@compiler_options compile=min infer=no))
    rebuild_module
end

"""Rebuild the authored G3 child design from its exact, hash-pinned source bytes.

This shared source parser returns the real typed design, including explicit
account owners and owner/account membership. Callers must compare its identity,
path and ledger fields to their candidate/package bindings.
"""
function vnext_t2_v3_rebuild_g3_child_design_source_v1(
        carrier::VNextT0LocalBytesV1, expected_sha256::Digest256,
        source_path::AbstractString; candidate_id=nothing, scenario_id=nothing,
        re_enable_threshold_kelvin=nothing, minimum_compiler::Bool=false)
    path = replace(String(source_path), '\\' => '/')
    isempty(path) && throw(ArgumentError("G3 child source path is empty"))
    isabspath(path) && throw(ArgumentError("G3 child source path must be relative"))
    any(part -> part == "..", split(path, '/'; keepempty=false)) &&
        throw(ArgumentError("G3 child source path escapes frozen root"))
    carrier.sha256 == expected_sha256 &&
        carrier.sha256 == _vnext_t2_v3_sha256(carrier.bytes) ||
        throw(ArgumentError("G3 child source hash does not match its pin"))
    rebuild_module = _vnext_t2_v3_frozen_source_module(; minimum_compiler=minimum_compiler)
    Base.include_string(rebuild_module, String(copy(carrier.bytes)), path)
    isdefined(rebuild_module, :up4_r2_g3_child_design_source_v1) ||
        throw(ArgumentError("G3 child source builder API is incomplete"))
    child_factory=getfield(rebuild_module,:up4_r2_g3_child_design_source_v1)
    explicit_factory_invocation=candidate_id!==nothing || scenario_id!==nothing ||
        re_enable_threshold_kelvin!==nothing
    design=if explicit_factory_invocation
        candidate_id!==nothing && scenario_id!==nothing ||
            throw(ArgumentError("explicit G3 child factory invocation needs candidate and scenario IDs"))
        Base.invokelatest(child_factory;candidate_id=String(candidate_id),
            scenario_id=String(scenario_id),source_path=path,
            re_enable_threshold_kelvin=re_enable_threshold_kelvin)
    else
        Base.invokelatest(child_factory)
    end
    design.source_path == path ||
        throw(ArgumentError("rebuilt G3 child source path mismatch"))
    design
end

function _vnext_t2_v3_rebuild_authored_g3_semantic_body(record, body,
        frozen_context, children; g3_factory_invocation=nothing)
    hasproperty(body, :authored_typed_ledger_source) ||
        throw(ArgumentError("typed G3 ledger view is absent"))
    hasproperty(body, :authored_child_design_input) ||
        throw(ArgumentError("frozen G3 child input is absent"))
    child_input = body.authored_child_design_input
    child_input isa VNextT0LocalBytesV1 &&
        child_input.sha256 == _vnext_t2_v3_sha256(child_input.bytes) ||
        throw(ArgumentError("frozen G3 child input carrier is invalid"))
    binding_children = Tuple(child for child in children if
        hasproperty(child, :kind) && child.kind === :binding)
    length(binding_children) == 1 ||
        throw(ArgumentError("G3 binding child locator is absent or ambiguous"))
    binding_child = only(binding_children)
    binding_child isa VNextT0LocalChildPresentV1 &&
        binding_child.candidate_ref == record.candidate_ref &&
        binding_child.layer === :G3 &&
        binding_child.source_bytes.bytes == child_input.bytes &&
        binding_child.source_bytes.sha256 == child_input.sha256 ||
        throw(ArgumentError("G3 binding child source does not match semantic carrier"))

    builder_path = String(record.source_locator.source_path)
    child_path = String(binding_child.source_locator.source_path)
    identity_path = replace(joinpath(dirname(builder_path), "identity.jl"), '\\' => '/')

    # Current-source records already carry bytes read and checked by the T0
    # source boundary.  Rebuild from those typed carriers in an isolated module;
    # the frozen branch below remains byte-for-byte equivalent to its prior
    # behavior and continues to use the independent manifest reader.
    if frozen_context isa AbstractString
        hasproperty(body, :authored_builder_input) ||
            throw(ArgumentError("current G3 builder carrier is absent"))
        hasproperty(body, :authored_identity_input) ||
            throw(ArgumentError("current G3 identity carrier is absent"))
        builder_input = body.authored_builder_input
        identity_input = body.authored_identity_input
        builder_input isa VNextT0LocalBytesV1 &&
            builder_input.bytes == record.source_bytes.bytes &&
            builder_input.sha256 == record.source_bytes.sha256 &&
            builder_input.sha256 == _vnext_t2_v3_sha256(builder_input.bytes) &&
            length(builder_input.bytes) == record.source_locator.source_size &&
            builder_input.sha256 == record.source_locator.source_sha256 ||
            throw(ArgumentError("current G3 builder carrier differs from T0 source bytes or locator"))
        identity_input isa VNextT0LocalBytesV1 &&
            identity_input.sha256 == _vnext_t2_v3_sha256(identity_input.bytes) ||
            throw(ArgumentError("current G3 identity carrier is invalid"))
        current_entry(path, label) = begin
            entry = NativeGitReadCompatibilityV1.current_source(frozen_context, path)
            entry.byte_count == length(entry.bytes) &&
                entry.sha256 == bytes2hex(SHA.sha256(entry.bytes)) ||
                throw(ArgumentError("current G3 $label source bytes changed"))
            entry
        end
        live_builder = current_entry(builder_path, "builder")
        live_identity = current_entry(identity_path, "identity")
        live_child = current_entry(child_path, "child")
        live_builder.bytes == builder_input.bytes &&
            live_identity.bytes == identity_input.bytes &&
            live_child.bytes == child_input.bytes ||
            throw(ArgumentError("current G3 carriers differ from live source files"))
        builder_path == record.source_locator.source_path &&
            identity_path == replace(joinpath(dirname(builder_path), "identity.jl"), '\\' => '/') ||
            throw(ArgumentError("current G3 builder/identity carrier paths differ from T0 locator"))
        minimum_compiler = get(ENV, "FCA_G3_WITNESS_MIN_COMPILE", "") == "1"
        if g3_factory_invocation===nothing
            rebuilt_child=vnext_t2_v3_rebuild_g3_child_design_source_v1(
                child_input,binding_child.source_locator.source_sha256,child_path;
                minimum_compiler=minimum_compiler)
        else
            g3_factory_invocation.source_path==child_path ||
                throw(ArgumentError("current G3 manifest factory path differs from child locator"))
            rebuilt_child=vnext_t2_v3_rebuild_g3_child_design_source_v1(
                child_input,binding_child.source_locator.source_sha256,child_path;
                candidate_id=g3_factory_invocation.candidate_id,
                scenario_id=g3_factory_invocation.scenario_id,
                re_enable_threshold_kelvin=g3_factory_invocation.re_enable_threshold_kelvin,
                minimum_compiler=minimum_compiler)
        end
        rebuild_module = _vnext_t2_v3_frozen_source_module(; minimum_compiler=minimum_compiler)
        Base.include_string(rebuild_module, String(copy(identity_input.bytes)), identity_path)
        Base.include_string(rebuild_module, String(copy(builder_input.bytes)), builder_path)
        isdefined(rebuild_module, :UP4_R2_IDENTITY) &&
            isdefined(rebuild_module, :up4_r2_build_g3_design) ||
            throw(ArgumentError("current G3 candidate builder API is incomplete"))
        identity = getfield(rebuild_module, :UP4_R2_IDENTITY)
        rebuilt_child.candidate_id == identity.candidate_id &&
            rebuilt_child.scenario_id == identity.scenario_id &&
            identity.candidate_ref == body.candidate_ref ||
            throw(ArgumentError("current G3 builder candidate identity mismatch"))
        rebuilt = Base.invokelatest(getfield(rebuild_module,
            :up4_r2_build_g3_design), rebuilt_child;
            source_file_sha256=binding_child.source_locator.source_sha256.value)
        rebuilt.candidate_ref == body.candidate_ref &&
            rebuilt.source_ref == body.source_ref &&
            hasproperty(rebuilt.semantic_body, :authored_typed_ledger_source) ||
            throw(ArgumentError("current G3 builder output identity or typed view mismatch"))
        _vnext_t2_v3_canonical_equal(rebuilt.semantic_body.authored_typed_ledger_source,
            body.authored_typed_ledger_source) ||
            throw(ArgumentError("current authored typed G3 ledger differs from reconstruction"))
        _vnext_t2_v3_canonical_equal(rebuilt.child_design_source, rebuilt_child) ||
            throw(ArgumentError("current G3 child design reconstruction mismatch"))
        return rebuilt
    end

    source_entry(path, label) = begin
        entry = NativeGitReadCompatibilityV1.frozen_source(frozen_context, path)
        entry === nothing && throw(ArgumentError("frozen G3 $label is absent"))
        entry.bytes isa AbstractVector{UInt8} && !isempty(entry.bytes) ||
            throw(ArgumentError("frozen G3 $label bytes are invalid"))
        entry.role in ("fixture_data", "test_fixture", "synthetic_fixture") &&
            throw(ArgumentError("frozen G3 $label has fixture provenance"))
        entry.sha256 == bytes2hex(SHA.sha256(Vector{UInt8}(entry.bytes))) ||
            throw(ArgumentError("frozen G3 $label hash mismatch"))
        entry.byte_count == length(entry.bytes) ||
            throw(ArgumentError("frozen G3 $label byte count mismatch"))
        entry
    end
    identity_entry = source_entry(identity_path, "identity source")
    builder_entry = source_entry(builder_path, "builder source")
    child_entry = source_entry(child_path, "child source")
    child_entry.bytes == child_input.bytes == binding_child.source_bytes.bytes &&
        child_entry.sha256 == child_input.sha256.value ==
            binding_child.source_bytes.sha256.value &&
        child_entry.byte_count == binding_child.source_locator.source_size &&
        binding_child.source_locator.source_sha256 == child_input.sha256 ||
        throw(ArgumentError("frozen G3 child source differs from semantic carrier"))
    if g3_factory_invocation===nothing
        child_design=vnext_t2_v3_rebuild_g3_child_design_source_v1(
            child_input,binding_child.source_locator.source_sha256,child_path)
    else
        g3_factory_invocation.source_path==child_path ||
            throw(ArgumentError("frozen G3 manifest factory path differs from child locator"))
        child_design=vnext_t2_v3_rebuild_g3_child_design_source_v1(
            child_input,binding_child.source_locator.source_sha256,child_path;
            candidate_id=g3_factory_invocation.candidate_id,
            scenario_id=g3_factory_invocation.scenario_id,
            re_enable_threshold_kelvin=g3_factory_invocation.re_enable_threshold_kelvin)
    end
    rebuild_module = _vnext_t2_v3_frozen_source_module()
    Base.include_string(rebuild_module, String(copy(identity_entry.bytes)), identity_path)
    Base.include_string(rebuild_module, String(copy(builder_entry.bytes)), builder_path)
    isdefined(rebuild_module, :UP4_R2_IDENTITY) &&
        isdefined(rebuild_module, :up4_r2_build_g3_design) ||
        throw(ArgumentError("frozen G3 candidate builder API is incomplete"))

    identity = getfield(rebuild_module, :UP4_R2_IDENTITY)
    child_design.candidate_id == identity.candidate_id &&
        child_design.scenario_id == identity.scenario_id &&
        identity.candidate_ref == body.candidate_ref ||
        throw(ArgumentError("frozen G3 builder candidate identity mismatch"))
    rebuilt = Base.invokelatest(getfield(rebuild_module,
        :up4_r2_build_g3_design), child_design;
        source_file_sha256=child_entry.sha256)
    rebuilt.candidate_ref == body.candidate_ref &&
        rebuilt.source_ref == body.source_ref &&
        hasproperty(rebuilt.semantic_body, :authored_typed_ledger_source) ||
        throw(ArgumentError("frozen G3 builder output identity or typed view mismatch"))
    _vnext_t2_v3_canonical_equal(rebuilt.semantic_body.authored_typed_ledger_source,
        body.authored_typed_ledger_source) ||
        throw(ArgumentError("authored typed G3 ledger differs from frozen reconstruction"))
    _vnext_t2_v3_canonical_equal(rebuilt.child_design_source, child_design) ||
        throw(ArgumentError("frozen G3 child design reconstruction mismatch"))
    rebuilt
end

function _vnext_t2_v3_materialize_g3(record, errors; frozen_context=nothing,
        children=(), g3_factory_invocation=nothing)
    body = record.semantic_body.body
    fields = (:candidate_ref, :source_ref, :source_id, :owner_scope,
        :endpoints, :law, :ledger_entries, :ledger_closure,
        :feedback_targets, :upstream_authority)
    _vnext_t2_v3_required_fields(body, fields) ||
        (push!(errors, :g3_semantic_body_shape_invalid); return nothing)
    declaration = try
        g3_sf_declaration_v1(body.candidate_ref, body.source_id,
            body.owner_scope, body.endpoints, body.law, body.ledger_entries,
            body.ledger_closure, body.feedback_targets, body.upstream_authority)
    catch
        push!(errors, :g3_declaration_reconstruction_failed)
        return nothing
    end
    status, _ = try g3_sf_validate_v1(declaration) catch; (:program_exception, ()) end
    status === :valid || push!(errors, :g3_declaration_validation_failed)
    declaration.candidate_ref == record.candidate_ref ||
        push!(errors, :g3_candidate_mismatch)
    body.source_ref == record.source_ref || push!(errors, :g3_source_ref_mismatch)
    expected_body = merge(_g3sf_body(declaration), (source_ref=body.source_ref,))
    g3_frozen_rebuild = nothing
    if hasproperty(body, :authored_typed_ledger_source)
        g3_frozen_rebuild = try
            if g3_factory_invocation===nothing
                _vnext_t2_v3_rebuild_authored_g3_semantic_body(record, body,
                    frozen_context, children)
            else
                _vnext_t2_v3_rebuild_authored_g3_semantic_body(record, body,
                    frozen_context, children;
                    g3_factory_invocation=g3_factory_invocation)
            end
        catch
            push!(errors, :g3_authored_typed_ledger_reconstruction_failed)
            nothing
        end
        if g3_frozen_rebuild !== nothing
            expected_body = g3_frozen_rebuild.semantic_body
            _vnext_t2_v3_canonical_equal(g3_frozen_rebuild.declaration, declaration) ||
                push!(errors, :g3_frozen_builder_declaration_mismatch)
        end
    end
    has_child_design = hasproperty(body, :authored_child_design)
    has_child_input = hasproperty(body, :authored_child_design_input)
    current_authored = frozen_context isa AbstractString &&
        hasproperty(body, :authored_builder_input) &&
        hasproperty(body, :authored_identity_input)
    extension_fields = current_authored ?
        (:authored_child_design, :authored_child_design_input,
         :authored_builder_input, :authored_identity_input) :
        (:authored_child_design, :authored_child_design_input)
    _vnext_t2_v3_projection_matches(body, expected_body, extension_fields) ||
        push!(errors, :g3_semantic_projection_mismatch)
    frozen_context !== nothing && !(has_child_design && has_child_input) &&
        push!(errors, :g3_authored_child_inputs_missing)
    if has_child_design || has_child_input
        valid_child = try
            child_design = body.authored_child_design
            child_input = body.authored_child_design_input
            child_input isa VNextT0LocalBytesV1 &&
                child_input.sha256 == _vnext_t2_v3_sha256(child_input.bytes) &&
                (if current_authored
                    g3_frozen_rebuild !== nothing &&
                        _vnext_t2_v3_canonical_equal(child_design,
                            g3_frozen_rebuild.child_design_source)
                else
                    design_fields = (:schema, :design_scope, :candidate_id, :scenario_id,
                        :geometry, :control_design, :realization, :control)
                    propertynames(child_design) == design_fields &&
                        child_design.schema == "up4-r2-g3-child-design-source-v1" &&
                        child_design.design_scope == "candidate_design_only"
                end)
        catch
            false
        end
        valid_child || push!(errors, :g3_authored_child_design_input_mismatch)
        if has_child_design && g3_frozen_rebuild !== nothing
            source_design = g3_frozen_rebuild.child_design_source
            expected_design = current_authored ? source_design :
                (schema=source_design.schema, design_scope=source_design.design_scope,
                 candidate_id=source_design.candidate_id, scenario_id=source_design.scenario_id,
                 geometry=source_design.geometry, control_design=source_design.control_design,
                 realization=source_design.realization, control=source_design.control)
            _vnext_t2_v3_canonical_equal(body.authored_child_design,
                expected_design) ||
                push!(errors, :g3_authored_child_design_reconstruction_mismatch)
        end
        binding_children = Tuple(child for child in children if
            hasproperty(child, :kind) && child.kind === :binding)
        child_source_matches = try
            if length(binding_children) == 1
                child = only(binding_children)
                child isa VNextT0LocalChildPresentV1 &&
                    child.source_bytes.bytes == body.authored_child_design_input.bytes &&
                    child.source_bytes.sha256 == body.authored_child_design_input.sha256 &&
                    _vnext_t2_v3_canonical_equal(child.body.child_design,
                        body.authored_child_design)
            else
                false
            end
        catch
            false
        end
        child_source_matches || push!(errors, :g3_authored_child_source_binding_mismatch)
    end
    _vnext_t2_v3_exact_bytes(body, record.semantic_body.bytes) ||
        push!(errors, :g3_semantic_bytes_mismatch)
    _vnext_t2_v3_exact_bytes(declaration, record.declaration_bytes) ||
        push!(errors, :g3_declaration_bytes_mismatch)
    declaration
end

function _vnext_t2_v3_native_source_hash(layer, declaration)
    layer === :G1 && return declaration.source_hash
    layer === :G2 && return declaration.source.source_hash
    canonical_hash((domain="vnext-t2-g3-native-source-payload-v3",
        source_id=declaration.source_id, owner_scope=declaration.owner_scope,
        endpoints=declaration.endpoints, law=declaration.law,
        ledger_entries=declaration.ledger_entries,
        ledger_closure=declaration.ledger_closure,
        feedback_targets=declaration.feedback_targets,
        upstream_authority=declaration.upstream_authority))
end

function _vnext_t2_v3_declaration_hash(layer, declaration)
    layer === :G1 && return declaration.declaration_hash
    layer === :G2 && return declaration.declaration_hash
    declaration.declaration_hash
end

function _vnext_t2_v3_layer_identity(layer, record, declaration)
    draft = VNextT2ConcreteLayerIdentityV3(layer,
        record.source_bytes.sha256,
        _vnext_t2_v3_native_source_hash(layer, declaration),
        canonical_hash(record.semantic_body.body),
        record.semantic_body.bytes.sha256,
        _vnext_t2_v3_declaration_hash(layer, declaration),
        record.declaration_bytes.sha256,
        record.source_identity_hash,
        record.declaration_identity_hash,
        canonical_hash(record),
        canonical_hash(declaration),
        record.factory_receipt.factory_result.content_identity,
        record.axes, record.factory_receipt.factory_axes,
        Digest256(repeat("0", 64)))
    VNextT2ConcreteLayerIdentityV3(draft.layer, draft.source_file_sha256,
        draft.native_source_payload_hash, draft.semantic_body_hash,
        draft.semantic_body_sha256, draft.native_declaration_hash,
        draft.declaration_sha256, draft.source_identity_hash,
        draft.declaration_identity_hash, draft.source_carrier_hash,
        draft.declaration_component_hash, draft.factory_content_identity,
        draft.source_axes, draft.factory_axes,
        canonical_hash(_vnext_t2_v3_layer_identity_body(draft)))
end

function _vnext_t2_v3_snapshot_matches(snapshot, value)
    bytes_snapshot = if snapshot isa Tuple
        snapshot
    elseif isdefined(@__MODULE__, :VNextT1CanonicalBytesV2) &&
            snapshot isa getfield(@__MODULE__, :VNextT1CanonicalBytesV2)
        hasproperty(snapshot, :encoding) && snapshot.encoding === :base64 ||
            return false
        hasproperty(snapshot, :sha256) || return false
        isdefined(@__MODULE__, :copy_bytes) &&
            isdefined(@__MODULE__, :_vnext_ar_v2_sha) || return false
        copied = try
            getfield(@__MODULE__, :copy_bytes)(snapshot)
        catch
            return false
        end
        try
            snapshot.sha256 == getfield(@__MODULE__, :_vnext_ar_v2_sha)(copied) ||
                return false
        catch
            return false
        end
        copied
    else
        return false
    end
    bytes_snapshot === nothing && return false
    # V1 carries its legacy tuple snapshot; V2's canonical byte carrier stores
    # canonical_json(transport) directly. Compare the same transport in both
    # cases so V2 bytes are not mistaken for the older bundle-body projection.
    text = canonical_json(value)
    bytes = codeunits(text)
    length(bytes_snapshot) == length(bytes) || return false
    for i in eachindex(bytes)
        try
            UInt8(bytes_snapshot[i]) == bytes[i] || return false
        catch
            return false
        end
    end
    true
end

function _vnext_t2_v3_is_v2_recheck(recheck)
    isdefined(@__MODULE__, :VNextAuthorityRecheckLocalV2Result) || return false
    recheck isa getfield(@__MODULE__, :VNextAuthorityRecheckLocalV2Result)
end

function _vnext_t2_v3_v2_checked_type()
    isdefined(@__MODULE__, :VNextAuthorityRecheckLocalV2Checked) || return nothing
    getfield(@__MODULE__, :VNextAuthorityRecheckLocalV2Checked)
end

function _vnext_t2_v3_record_map(transport, errors)
    records = Dict{Symbol,VNextT0LocalPresentDeclarationV1}()
    for record in transport.declarations
        record isa VNextT0LocalPresentDeclarationV1 || continue
        record.layer in VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3 ||
            (push!(errors, :source_layer_invalid); continue)
        haskey(records, record.layer) && push!(errors, :source_layer_duplicate)
        records[record.layer] = record
    end
    for layer in VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3
        haskey(records, layer) || push!(errors, Symbol(lowercase(String(layer)) * "_material_absent"))
    end
    records
end

function _vnext_t2_v3_validate_realization_intrinsic(state, errors)
    rebuilt_state = try
        G3RealizationSourceStateV1(state.key, state.payload,
            state.source_content_hash, state.initial_source_content_hash,
            state.state_status, state.absence_reason, state.absence_content_hash,
            state.missing_slots, state.initial_state_hash, state.state_hash,
            state.operation_hash, state.contract_admission,
            state.physical_resolution, state.operation_history)
    catch
        push!(errors, :realization_state_invalid)
        nothing
    end
    rebuilt_state === nothing || _vnext_t2_v3_canonical_equal(rebuilt_state, state) ||
        push!(errors, :realization_state_reconstruction_mismatch)
    state.state_status === :present || return
    payload = state.payload
    payload isa G3RealizationSourcePayloadV1 ||
        (push!(errors, :realization_payload_missing); return)
    isempty(_g3rce_payload_valid(payload)) ||
        push!(errors, :realization_payload_validator_failed)
    rebuilt_body = try
        b = payload.body
        G3RealizationSourceBodyV1(b.source_id, b.owner_scope, b.ports,
            b.source_power, b.field_power, b.return_power, b.heat_power,
            b.capacity, b.capacity_unit, b.closure_residual, b.components,
            b.material_domains, b.manufacturing_domains, b.ledger_accounts,
            b.ledger_entries, b.ledger_closures)
    catch
        push!(errors, :realization_body_invalid)
        nothing
    end
    rebuilt_body === nothing || _vnext_t2_v3_canonical_equal(rebuilt_body, payload.body) ||
        push!(errors, :realization_body_reconstruction_mismatch)
    rebuilt_payload = try
        g3_realization_source_payload_v1(payload.key,
            payload.parent_g3_declaration_ref, payload.body,
            payload.source_record; source_uri=payload.source_uri,
            source_version=payload.source_version,
            child_contract_ref=payload.child_contract_ref)
    catch
        push!(errors, :realization_payload_invalid)
        nothing
    end
    rebuilt_payload === nothing || _vnext_t2_v3_canonical_equal(rebuilt_payload, payload) ||
        push!(errors, :realization_payload_reconstruction_mismatch)
    state.key == payload.key || push!(errors, :realization_state_key_mismatch)
    state.source_content_hash == payload.source_content_hash ||
        push!(errors, :realization_source_content_hash_mismatch)
    state.initial_state_hash == _g3rce_initial_hash(state.key, :present,
        state.initial_source_content_hash, nothing, ()) ||
        push!(errors, :realization_initial_state_hash_mismatch)
    state.state_hash == _g3rce_state_hash(state.key, :present,
        state.source_content_hash, nothing, state.operation_hash,
        state.operation_history, ()) || push!(errors, :realization_state_hash_mismatch)
    length(unique(state.operation_history)) == length(state.operation_history) ||
        push!(errors, :realization_operation_history_duplicate)
    isempty(state.operation_history) &&
        state.operation_hash != G3_REALIZATION_CHILD_EDIT_ZERO_DIGEST_V1 &&
        push!(errors, :realization_operation_hash_mismatch)
end

function _vnext_t2_v3_validate_realization(state, candidate, parent_ref,
        parent_hash, errors)
    _vnext_t2_v3_validate_realization_intrinsic(state, errors)
    state.state_status === :present ||
        (push!(errors, :realization_state_not_present); return)
    payload = state.payload
    payload isa G3RealizationSourcePayloadV1 || return
    state.key.candidate_ref == candidate || push!(errors, :realization_candidate_mismatch)
    payload.parent_g3_declaration_ref == parent_ref ||
        push!(errors, :realization_parent_ref_mismatch)
    state.key.parent_g3_declaration_hash == parent_hash ||
        push!(errors, :realization_parent_hash_mismatch)
end

function _vnext_t2_v3_validate_control_payload_intrinsic(payload, errors)
    rebuilt_payload = try
        G3ControlSourcePayloadV1(payload.key,
            payload.parent_g3_declaration_ref, payload.parent_g3_declaration_hash,
            payload.child_contract_ref, payload.child_contract_identity_hash,
            payload.source_uri, payload.source_version, payload.body,
            payload.source_record, payload.source_content_hash)
    catch
        push!(errors, :control_payload_invalid)
        nothing
    end
    rebuilt_payload === nothing || _vnext_t2_v3_canonical_equal(rebuilt_payload, payload) ||
        push!(errors, :control_payload_reconstruction_mismatch)
    isempty(_g3ce_validate_body(payload.body)) || push!(errors, :control_source_body_invalid)
end

function _vnext_t2_v3_validate_control_state_intrinsic(state, errors)
    state.editable_body === nothing || isempty(_g3ce_validate_body(state.editable_body)) ||
        push!(errors, :control_editable_body_invalid)
    rebuilt_state = try
        G3ControlStateV1(state.key, state.source_payload_ref,
            state.editable_body, state.initial_source_content_hash,
            state.state_status, state.absence_reason, state.absence_content_hash,
            state.missing_slots, state.initial_state_hash,
            state.current_state_hash, state.last_operation_hash,
            state.contract_admission, state.physical_resolution,
            state.operation_history)
    catch
        push!(errors, :control_state_invalid)
        nothing
    end
    rebuilt_state === nothing || _vnext_t2_v3_canonical_equal(rebuilt_state, state) ||
        push!(errors, :control_state_reconstruction_mismatch)
end

function _vnext_t2_v3_validate_control_pair(payload, state, errors)
    state.state_status === :present ||
        (push!(errors, :control_state_not_present); return)
    expected_ref = try _g3ce_payload_ref(payload) catch; nothing end
    expected_ref === nothing && push!(errors, :control_payload_ref_invalid)
    expected_ref === nothing || _g3ce_payload_ref_equal(expected_ref,
        state.source_payload_ref) || push!(errors, :control_payload_ref_mismatch)
    state.key == payload.key || push!(errors, :control_state_key_mismatch)
end

function _vnext_t2_v3_validate_control(payload, state, candidate,
        parent_ref, parent_hash, errors)
    _vnext_t2_v3_validate_control_payload_intrinsic(payload, errors)
    _vnext_t2_v3_validate_control_state_intrinsic(state, errors)
    _vnext_t2_v3_validate_control_pair(payload, state, errors)
    state.key.candidate_ref == candidate || push!(errors, :control_candidate_mismatch)
    payload.parent_g3_declaration_ref == parent_ref ||
        push!(errors, :control_parent_ref_mismatch)
    state.key.parent_g3_declaration_hash == parent_hash ||
        push!(errors, :control_parent_hash_mismatch)
end

function _vnext_t2_v3_child_info_matches(info, expected)
    fields = (:child_kind, :candidate_ref, :parent_g3_declaration_ref,
        :parent_g3_declaration_hash, :child_ref, :contract_ref,
        :source_record_ref, :source_record_hash, :source_content_hash,
        :child_identity_hash, :state_hash)
    all(getproperty(info, field) == getproperty(expected, field) for field in fields)
end

function _vnext_t2_v3_realization_current_commitment(state,
        candidate, parent_ref, parent_hash)
    payload = state.payload
    child_ref = QualifiedRefV1("local://GenomeV5/G3/realization:" *
        String(state.key.child_id), "v1")
    source_ref = QualifiedRefV1(payload.source_record.source_uri,
        payload.source_record.source_version)
    VNextG3BindingChildExpectedCommitmentV1(:realization, candidate,
        parent_ref, parent_hash, child_ref, payload.child_contract_ref,
        source_ref, payload.source_record.source_record_hash,
        payload.source_content_hash, payload.child_contract_identity_hash,
        state.state_hash)
end

function _vnext_t2_v3_control_current_commitment(payload, state,
        candidate, parent_ref, parent_hash)
    child_ref = QualifiedRefV1("local://GenomeV5/G3/control:" *
        String(state.key.child_id), "v1")
    source_ref = QualifiedRefV1(payload.source_record.record_uri,
        payload.source_record.record_version)
    VNextG3BindingChildExpectedCommitmentV1(:control, candidate,
        parent_ref, parent_hash, child_ref, payload.child_contract_ref,
        source_ref, payload.source_record.source_record_hash,
        payload.source_content_hash, payload.child_contract_identity_hash,
        state.current_state_hash)
end

function vnext_t2_g3_current_state_projection_v3(candidate::QualifiedRefV1,
        parent_ref::QualifiedRefV1, parent_hash::Digest256,
        realization_state::G3RealizationSourceStateV1,
        control_payload::G3ControlSourcePayloadV1,
        control_state::G3ControlStateV1)
    errors = Symbol[]
    _vnext_t2_v3_validate_realization(realization_state, candidate,
        parent_ref, parent_hash, errors)
    _vnext_t2_v3_validate_control(control_payload, control_state, candidate,
        parent_ref, parent_hash, errors)
    isempty(errors) || throw(ArgumentError(
        "current G3 child state is invalid: " * join(String.(unique(errors)), ",")))
    realization = _vnext_t2_v3_realization_current_commitment(
        realization_state, candidate, parent_ref, parent_hash)
    control = _vnext_t2_v3_control_current_commitment(control_payload,
        control_state, candidate, parent_ref, parent_hash)
    draft = VNextT2G3CurrentStateProjectionV3(candidate, parent_ref,
        parent_hash, realization, control, Digest256(repeat("0", 64)))
    VNextT2G3CurrentStateProjectionV3(draft.candidate_ref,
        draft.parent_g3_declaration_ref,
        draft.parent_g3_declaration_hash, draft.realization, draft.control,
        canonical_hash(_vnext_t2_v3_current_projection_body(draft)))
end

"""Adapt the shared G3 authority bridge into the V3 witness projection."""
function vnext_concrete_source_witness_g3_bridge_v1(
        recheck,
        expected::VNextG3BindingAuthorityExpectedCommitmentV1,
        local_bridge::VNextG3BindingAuthorityBridgeLocalResultV1,
        realization_state::G3RealizationSourceStateV1,
        control_payload::G3ControlSourcePayloadV1,
        control_state::G3ControlStateV1,
        key::G3BindingChildKeyV2; initial_links=())
    try
        recheck.status === :typed_absent && return VNextT2ConcreteG3BridgeV3(
            :typed_absent, :terminal_deferred, false, false, nothing,
            nothing, (), (:t0_typed_absent,))
        recheck.status === :fail_closed && return VNextT2ConcreteG3BridgeV3(
            :fail_closed, :none, false, false, nothing, nothing,
            (:t0_fail_closed,), ())
        consistency = vnext_g3_binding_self_consistency_v1(recheck)
        consistency.ok || return VNextT2ConcreteG3BridgeV3(:fail_closed,
            :none, false, false, nothing, nothing, consistency.errors,
            (:self_consistency_failed,))
        expected.commitment_hash ==
            vnext_g3_binding_expected_commitment_hash_v1(expected) ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, true,
                false, nothing, nothing,
                (:expected_commitment_hash_mismatch,), ())
        reconstructed = vnext_g3_binding_authority_bridge_local_v1(recheck,
            expected, realization_state, control_state, key;
            initial_links=initial_links)
        _vnext_t2_v3_canonical_equal(local_bridge, reconstructed) ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, false,
                false, nothing, nothing,
                (:g3_local_bridge_reconstruction_mismatch,), ())
        if local_bridge.status === :typed_absent
            return VNextT2ConcreteG3BridgeV3(:typed_absent,
                :terminal_deferred, false, false, nothing, nothing,
                local_bridge.errors, local_bridge.reasons)
        elseif local_bridge.status === :fail_closed
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none,
                local_bridge.self_consistency,
                local_bridge.authority_verified, nothing, nothing,
                local_bridge.errors, local_bridge.reasons)
        end
        (local_bridge.status === :local_checked_present &&
            local_bridge.resolution === :resolved &&
            local_bridge.self_consistency && local_bridge.authority_verified &&
            isempty(local_bridge.errors) && isempty(local_bridge.reasons) &&
            local_bridge.binding_state isa G3BindingStateV2) ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none,
                false, false, nothing, nothing,
                (:g3_local_bridge_status_invalid,), ())
        projection = vnext_t2_g3_current_state_projection_v3(
            expected.candidate_ref, expected.g3_declaration_ref,
            expected.g3_declaration_identity_hash, realization_state,
            control_payload, control_state)
        _vnext_t2_v3_child_info_matches(projection.realization,
            expected.realization) || return VNextT2ConcreteG3BridgeV3(
                :fail_closed, :none, true, false, projection, nothing,
                (:realization_expected_commitment_mismatch,), ())
        _vnext_t2_v3_child_info_matches(projection.control,
            expected.control) || return VNextT2ConcreteG3BridgeV3(
                :fail_closed, :none, true, false, projection, nothing,
                (:control_expected_commitment_mismatch,), ())
        VNextT2ConcreteG3BridgeV3(:local_checked_present, :resolved,
            true, true, projection, local_bridge.binding_state, (), ())
    catch
        VNextT2ConcreteG3BridgeV3(:program_exception, :none, false, false,
            nothing, nothing, (:g3_source_bridge_adapter_exception,), ())
    end
end

"""Build the shared local G3 authority result and adapt it for V3 witness use."""
function vnext_concrete_source_witness_g3_bridge_v1(
        recheck,
        expected::VNextG3BindingAuthorityExpectedCommitmentV1,
        realization_state::G3RealizationSourceStateV1,
        control_payload::G3ControlSourcePayloadV1,
        control_state::G3ControlStateV1,
        key::G3BindingChildKeyV2; initial_links=())
    local_bridge = vnext_g3_binding_authority_bridge_local_v1(recheck,
        expected, realization_state, control_state, key;
        initial_links=initial_links)
    vnext_concrete_source_witness_g3_bridge_v1(recheck, expected,
        local_bridge, realization_state, control_payload, control_state,
        key; initial_links=initial_links)
end

function vnext_t2_concrete_g3_bridge_v3(
        recheck::VNextAuthorityRecheckLocalResultV1,
        expected::VNextG3BindingAuthorityExpectedCommitmentV1,
        realization_state::G3RealizationSourceStateV1,
        control_payload::G3ControlSourcePayloadV1,
        control_state::G3ControlStateV1,
        key::G3BindingChildKeyV2; initial_links=())
    try
        recheck.status === :typed_absent && return VNextT2ConcreteG3BridgeV3(
            :typed_absent, :terminal_deferred, false, false, nothing, nothing,
            (), (:t0_typed_absent,))
        recheck.status === :fail_closed && return VNextT2ConcreteG3BridgeV3(
            :fail_closed, :none, false, false, nothing, nothing,
            (:t0_fail_closed,), ())
        consistency = vnext_g3_binding_self_consistency_v1(recheck)
        consistency.ok || return VNextT2ConcreteG3BridgeV3(:fail_closed,
            :none, false, false, nothing, nothing, consistency.errors,
            (:self_consistency_failed,))
        output = recheck.output
        expected.commitment_hash ==
            vnext_g3_binding_expected_commitment_hash_v1(expected) ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, true,
                false, nothing, nothing,
                (:expected_commitment_hash_mismatch,), ())
        expected.candidate_ref == output.candidate_ref ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, true,
                false, nothing, nothing, (:expected_candidate_mismatch,), ())
        expected.bundle_hash == output.bundle_hash ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, true,
                false, nothing, nothing, (:expected_bundle_hash_mismatch,), ())
        expected.g3_declaration_ref == output.g3.declaration_ref ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, true,
                false, nothing, nothing, (:expected_g3_declaration_ref_mismatch,), ())
        expected.g3_declaration_identity_hash == output.g3.declaration_identity_hash ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, true,
                false, nothing, nothing, (:expected_g3_identity_hash_mismatch,), ())
        key.candidate_ref == expected.candidate_ref ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, true,
                false, nothing, nothing, (:key_candidate_mismatch,), ())
        key.parent_g3_declaration_ref == expected.g3_declaration_ref ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, true,
                false, nothing, nothing, (:key_parent_ref_mismatch,), ())
        key.parent_g3_declaration_hash == expected.g3_declaration_identity_hash ||
            return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, true,
                false, nothing, nothing, (:key_parent_hash_mismatch,), ())
        child_errors = Symbol[]
        _vnext_t2_v3_validate_realization(realization_state,
            expected.candidate_ref, expected.g3_declaration_ref,
            expected.g3_declaration_identity_hash, child_errors)
        _vnext_t2_v3_validate_control(control_payload, control_state,
            expected.candidate_ref, expected.g3_declaration_ref,
            expected.g3_declaration_identity_hash, child_errors)
        isempty(child_errors) || return VNextT2ConcreteG3BridgeV3(
            :fail_closed, :none, true, false, nothing, nothing,
            Tuple(unique(child_errors)), ())
        projection = vnext_t2_g3_current_state_projection_v3(
            expected.candidate_ref, expected.g3_declaration_ref,
            expected.g3_declaration_identity_hash, realization_state,
            control_payload, control_state)
        _vnext_t2_v3_child_info_matches(projection.realization,
            expected.realization) || return VNextT2ConcreteG3BridgeV3(
                :fail_closed, :none, true, false, projection, nothing,
                (:realization_expected_commitment_mismatch,), ())
        _vnext_t2_v3_child_info_matches(projection.control,
            expected.control) || return VNextT2ConcreteG3BridgeV3(
                :fail_closed, :none, true, false, projection, nothing,
                (:control_expected_commitment_mismatch,), ())
        realization_slot = _vnext_g3binding_present_slot(projection.realization)
        control_slot = _vnext_g3binding_present_slot(projection.control)
        payload = g3_binding_v2_source_payload(key, initial_links;
            realization_slot=realization_slot, control_slot=control_slot,
            complete=true, source_hash=expected.commitment_hash)
        binding = g3_binding_v2_admit(payload)
        binding.state_status === :present || return VNextT2ConcreteG3BridgeV3(
            :fail_closed, :none, true, false, projection, nothing,
            (:v3_present_admission_failed,), ())
        VNextT2ConcreteG3BridgeV3(:local_checked_present, :resolved,
            true, true, projection, binding, (), ())
    catch
        VNextT2ConcreteG3BridgeV3(:program_exception, :none, false, false,
            nothing, nothing, (:v3_bridge_program_exception,), ())
    end
end

function vnext_t2_concrete_g3_bridge_v3(
        recheck, expected::VNextG3BindingAuthorityExpectedCommitmentV1,
        realization_state::G3RealizationSourceStateV1,
        control_payload::G3ControlSourcePayloadV1,
        control_state::G3ControlStateV1, key::G3BindingChildKeyV2;
        initial_links=())
    _vnext_t2_v3_is_v2_recheck(recheck) ||
        return VNextT2ConcreteG3BridgeV3(:fail_closed, :none, false, false,
            nothing, nothing, (:t0_recheck_type_invalid,), ())
    vnext_concrete_source_witness_g3_bridge_v1(recheck, expected,
        realization_state, control_payload, control_state, key;
        initial_links=initial_links)
end

function _vnext_t2_v3_binding_links(declaration::G3SFDeclarationV1)
    Tuple(G3BindingLinkV1(target.target_id, target.target_layer,
        target.target_path, target.quantity, target.unit, target.direction,
        target.sign, target.source_id, target.owner_scope, target.authority)
        for target in declaration.feedback_targets)
end

function _vnext_t2_v3_validate_feedback(t0_feedback, declaration, records, errors)
    targets = declaration.feedback_targets
    target_ids = Tuple(target.target_id for target in targets)
    feedback_ids = Tuple(item.target_id for item in t0_feedback)
    Set(target_ids) == Set(feedback_ids) || push!(errors, :feedback_target_set_mismatch)
    for target in targets
        matches = Tuple(item for item in t0_feedback if item.target_id == target.target_id)
        length(matches) == 1 || (push!(errors, :feedback_target_arity_mismatch); continue)
        item = only(matches)
        item.target_layer == target.target_layer || push!(errors, :feedback_target_layer_mismatch)
        record = get(records, target.target_layer, nothing)
        record === nothing && (push!(errors, :feedback_target_material_missing); continue)
        item.target_ref == record.source_ref || push!(errors, :feedback_target_ref_mismatch)
        item.candidate_ref == declaration.candidate_ref ||
            push!(errors, :feedback_candidate_mismatch)
        target.authority.candidate_ref == declaration.candidate_ref ||
            push!(errors, :feedback_target_authority_candidate_mismatch)
        (target.authority.status === :missing &&
         target.authority.source_ref === nothing) ||
            push!(errors, :feedback_target_authority_not_missing)
        body = item.body
        body_fields = (:candidate_ref, :source_ref, :declaration_ref, :target_ref,
            :feedback_targets, :source_g3_ref, :source_g3_declaration_ref, :target)
        valid_body = try
            propertynames(body) == body_fields &&
                body.candidate_ref == declaration.candidate_ref &&
                body.source_ref == record.source_ref &&
                body.declaration_ref == record.declaration_ref &&
                body.target_ref == record.source_ref &&
                body.feedback_targets isa Tuple &&
                length(body.feedback_targets) == 1 &&
                _vnext_t2_v3_canonical_equal(only(body.feedback_targets), target) &&
                body.source_g3_ref == records[:G3].source_ref &&
                body.source_g3_declaration_ref == records[:G3].declaration_ref &&
                _vnext_t2_v3_canonical_equal(body.target, target) &&
                _vnext_t2_v3_canonical_equal(item.body_hash, canonical_hash(body))
        catch
            false
        end
        valid_body || push!(errors, :feedback_body_projection_mismatch)
    end
end

function _vnext_t2_v3_coupling(g3::G3SFDeclarationV1,
        realization::G3RealizationSourceStateV1)
    errors = Symbol[]
    gaps = Symbol[:g1_g2_coordinate_pullback_missing,
        :g1_g3_feedback_conversion_missing,
        :g2_thermal_target_material_missing]
    body = realization.payload.body
    values = try g3_sf_evaluate_v1(g3, body.source_power) catch; nothing end
    if values === nothing
        push!(errors, :g3_source_law_evaluation_failed)
    else
        (body.source_power == values.source_power &&
         body.field_power == values.field_power &&
         body.return_power == values.return_power &&
         body.heat_power == values.heat_power) ||
            push!(errors, :g3_source_law_realization_allocation_mismatch)
    end
    source_endpoint = findfirst(endpoint -> endpoint.role === :source, g3.endpoints)
    if source_endpoint === nothing
        push!(errors, :g3_source_endpoint_missing)
    else
        unit = g3.endpoints[source_endpoint].unit
        (body.capacity_unit == unit && all(port -> port.unit == unit, body.ports)) ||
            push!(errors, :g3_source_law_realization_unit_mismatch)
    end
    status = isempty(errors) ? :declared_consistent : :fail_closed
    resolution = isempty(errors) ? :terminal_deferred : :none
    draft = VNextT2SourceCouplingDiagnosticsV3(status, resolution,
        Tuple(unique(errors)), Tuple(unique(gaps)), Digest256(repeat("0", 64)))
    VNextT2SourceCouplingDiagnosticsV3(draft.status, draft.resolution,
        draft.errors, draft.gaps,
        canonical_hash(_vnext_t2_v3_coupling_body(draft)))
end

function _vnext_t2_v3_missing_inputs(transport, recheck, parent, expected,
        bridge, realization_state, control_payload, control_state, binding_key)
    gaps = Symbol[]
    any(record -> record isa VNextT0LocalAbsentDeclarationV1,
        transport.declarations) && push!(gaps, :source_declaration_material_absent)
    recheck.status === :typed_absent && push!(gaps, :t0_recheck_typed_absent)
    parent.status === :typed_absent && push!(gaps, :parent_authority_typed_absent)
    expected === nothing && push!(gaps, :g3_expected_commitment_absent)
    bridge === nothing && push!(gaps, :g3_binding_bridge_absent)
    realization_state === nothing && push!(gaps, :g3_realization_state_absent)
    control_payload === nothing && push!(gaps, :g3_control_payload_absent)
    control_state === nothing && push!(gaps, :g3_control_state_absent)
    binding_key === nothing && push!(gaps, :g3_binding_key_absent)
    Tuple(unique(gaps))
end

"""Validate all observable upstream material before classifying missing inputs."""
function _vnext_t2_v3_known_input_errors(transport, recheck, parent;
        frozen_context=nothing)
    errors = Symbol[]
    (recheck isa VNextAuthorityRecheckLocalResultV1 ||
        _vnext_t2_v3_is_v2_recheck(recheck)) ||
        return (:t0_recheck_type_invalid,)
    transport.status === :valid || push!(errors, :t0_transport_status_invalid)
    isempty(transport.errors) || push!(errors, :t0_transport_errors_present)
    try
        vnext_t0_local_bundle_hash_recompute_v1(transport) == transport.bundle_hash ||
            push!(errors, :t0_bundle_hash_mismatch)
    catch
        push!(errors, :t0_bundle_hash_recompute_failed)
    end
    for record in transport.declarations
        if record isa VNextT0LocalPresentDeclarationV1
            append!(errors, _vnl_t0_errors(record, transport.candidate_ref;
                frozen_context=frozen_context))
        elseif record isa VNextT0LocalAbsentDeclarationV1
            append!(errors, _vnl_t0_absent_errors(record, transport.candidate_ref))
        else
            push!(errors, :t0_declaration_type_invalid)
        end
    end
    layer_map = Dict{Symbol,Any}()
    for record in transport.declarations
        hasproperty(record, :layer) || continue
        haskey(layer_map, record.layer) && push!(errors, :t0_declaration_layer_duplicate)
        layer_map[record.layer] = record
    end
    all(haskey(layer_map, layer) for layer in VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3) ||
        push!(errors, :t0_declaration_layer_set_invalid)
    append!(errors, _vnl_t0_feedback_errors(transport.feedback,
        transport.candidate_ref, transport.declarations))
    for kind in (:realization, :control, :binding)
        matches = Tuple(child for child in transport.children if child.kind === kind)
        length(matches) == 1 || (push!(errors, :t0_child_arity_invalid); continue)
        append!(errors, _vnl_t0_child_errors(only(matches),
            transport.candidate_ref, kind;
            frozen_context=frozen_context))
    end
    recheck.status in (:local_checked_present, :typed_absent) ||
        push!(errors, recheck.status === :fail_closed ?
            :t0_recheck_fail_closed : :t0_recheck_status_invalid)
    recheck.accepted == false || push!(errors, :t0_recheck_acceptance_claim_invalid)
    recheck.claim_ceiling === :contract_only ||
        push!(errors, :t0_recheck_claim_ceiling_invalid)
    isempty(recheck.errors) || push!(errors, :t0_recheck_errors_present)
    recheck.prior_bundle_sha256 == transport.bundle_hash ||
        push!(errors, :t0_recheck_bundle_hash_mismatch)
    _vnext_t2_v3_snapshot_matches(recheck.prior_bundle_bytes, transport) ||
        push!(errors, :t0_recheck_snapshot_mismatch)
    if recheck.status === :local_checked_present
        recheck.resolution === :resolved ||
            push!(errors, :t0_recheck_resolution_invalid)
        isempty(recheck.reasons) || push!(errors, :t0_recheck_reasons_present)
        if _vnext_t2_v3_is_v2_recheck(recheck)
            checked_type = _vnext_t2_v3_v2_checked_type()
            output = recheck.output
            output isa checked_type || push!(errors, :t0_recheck_output_type_invalid)
            if output isa checked_type
                output.candidate_ref == transport.candidate_ref ||
                    push!(errors, :t0_recheck_candidate_mismatch)
                output.bundle_hash == transport.bundle_hash ||
                    push!(errors, :t0_recheck_bundle_hash_mismatch)
                output.g3_children_deferred === false ||
                    push!(errors, :t0_recheck_g3_children_deferred_invalid)
                _vnext_t2_v3_canonical_equal(output.declarations,
                    transport.declarations) ||
                    push!(errors, :t0_recheck_record_mismatch)
                _vnext_t2_v3_canonical_equal(output.feedback, transport.feedback) ||
                    push!(errors, :t0_recheck_feedback_mismatch)
                _vnext_t2_v3_canonical_equal(output.children, transport.children) ||
                    push!(errors, :t0_recheck_children_mismatch)
            end
            consistency = try
                vnext_g3_binding_self_consistency_v1(recheck)
            catch
                (ok=false, errors=(:t0_recheck_self_consistency_exception,))
            end
            consistency.ok || append!(errors, consistency.errors)
        elseif recheck.output isa VNextAuthorityRecheckLocalCheckedPresentV1
            output = recheck.output
            output.candidate_ref == transport.candidate_ref ||
                push!(errors, :t0_recheck_candidate_mismatch)
            output.bundle_hash == transport.bundle_hash ||
                push!(errors, :t0_recheck_bundle_hash_mismatch)
            if all(haskey(layer_map, layer) for layer in
                    VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3)
                for layer in VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3
                    observed = getproperty(output, Symbol(lowercase(String(layer))))
                    _vnext_t2_v3_canonical_equal(observed, layer_map[layer]) ||
                        push!(errors, :t0_recheck_record_mismatch)
                end
            end
            _vnext_t2_v3_canonical_equal(output.feedback, transport.feedback) ||
                push!(errors, :t0_recheck_feedback_mismatch)
            _vnext_t2_v3_canonical_equal(output.children, transport.children) ||
                push!(errors, :t0_recheck_children_mismatch)
        else
            push!(errors, :t0_recheck_output_type_invalid)
        end
    elseif recheck.status === :typed_absent
        recheck.resolution === :terminal_deferred ||
            push!(errors, :t0_recheck_resolution_invalid)
        if _vnext_t2_v3_is_v2_recheck(recheck)
            output = recheck.output
            if output isa getfield(@__MODULE__, :VNextAuthorityRecheckLocalV2TypedAbsent)
                output.candidate_ref == transport.candidate_ref ||
                    push!(errors, :t0_recheck_candidate_mismatch)
                output.bundle_hash == transport.bundle_hash ||
                    push!(errors, :t0_recheck_bundle_hash_mismatch)
                _vnext_t2_v3_canonical_equal(output.reasons, recheck.reasons) ||
                    push!(errors, :t0_recheck_reason_mismatch)
                consistency = try
                    vnext_g3_binding_self_consistency_v1(recheck)
                catch
                    (ok=false, errors=(:t0_recheck_self_consistency_exception,))
                end
                consistency.ok || append!(errors, consistency.errors)
            else
                push!(errors, :t0_recheck_output_type_invalid)
            end
        elseif recheck.output isa VNextAuthorityRecheckLocalTypedAbsentV1
            output = recheck.output
            output.candidate_ref == transport.candidate_ref ||
                push!(errors, :t0_recheck_candidate_mismatch)
            output.bundle_hash == transport.bundle_hash ||
                push!(errors, :t0_recheck_bundle_hash_mismatch)
            output.g3_children_deferred ||
                push!(errors, :t0_recheck_g3_children_deferred_invalid)
            _vnext_t2_v3_canonical_equal(output.reasons, recheck.reasons) ||
                push!(errors, :t0_recheck_reason_mismatch)
            expected_reasons = Symbol[]
            for layer in VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3
                record = get(layer_map, layer, nothing)
                record isa VNextT0LocalAbsentDeclarationV1 &&
                    push!(expected_reasons, record.reason)
            end
            get(layer_map, :G1, nothing) isa VNextT0LocalPresentDeclarationV1 ||
                push!(expected_reasons, :g1_material_absent)
            get(layer_map, :G2, nothing) isa VNextT0LocalPresentDeclarationV1 ||
                push!(expected_reasons, :g2_material_absent)
            get(layer_map, :G3, nothing) isa VNextT0LocalPresentDeclarationV1 ||
                push!(expected_reasons, :g3_feedback_material_absent)
            Tuple(unique(expected_reasons)) == recheck.reasons ||
                push!(errors, :t0_recheck_reason_mismatch)
        else
            push!(errors, :t0_recheck_output_type_invalid)
        end
    end
    parent.status in (:present, :typed_absent) ||
        push!(errors, parent.status === :fail_closed ?
            :parent_authority_fail_closed : :parent_authority_status_invalid)
    if all(haskey(layer_map, layer) for layer in (:G1, :G2))
        fresh_parent = bind_local_parent_baseline_from_t0_v1(
            T0LocalParentBaselineInputV1(transport.candidate_ref,
                (layer_map[:G1], layer_map[:G2]));
            frozen_context=frozen_context)
        _vnext_t2_v3_canonical_equal(fresh_parent, parent) ||
            push!(errors, :parent_authority_reconstruction_mismatch)
    end
    Tuple(unique(errors))
end

"""Validate every supplied optional input before classifying another as missing."""
function _vnext_t2_v3_optional_input_errors(transport, expected, bridge,
        realization_state, control_payload, control_state, binding_key)
    errors = Symbol[]
    g3_matches = Tuple(record for record in transport.declarations
        if record isa VNextT0LocalPresentDeclarationV1 && record.layer === :G3)
    g3_record = length(g3_matches) == 1 ? only(g3_matches) : nothing

    if expected !== nothing
        expected.commitment_hash ==
            vnext_g3_binding_expected_commitment_hash_v1(expected) ||
            push!(errors, :g3_expected_commitment_hash_mismatch)
        expected.candidate_ref == transport.candidate_ref ||
            push!(errors, :g3_expected_candidate_mismatch)
        expected.bundle_hash == transport.bundle_hash ||
            push!(errors, :g3_expected_bundle_hash_mismatch)
        if g3_record !== nothing
            expected.g3_declaration_ref == g3_record.declaration_ref ||
                push!(errors, :g3_expected_declaration_ref_mismatch)
            expected.g3_declaration_identity_hash ==
                g3_record.declaration_identity_hash ||
                push!(errors, :g3_expected_declaration_hash_mismatch)
        end
    end

    if binding_key !== nothing
        binding_key.child_kind === :binding ||
            push!(errors, :g3_binding_key_kind_mismatch)
        binding_key.candidate_ref == transport.candidate_ref ||
            push!(errors, :g3_binding_key_candidate_mismatch)
        if g3_record !== nothing
            binding_key.parent_g3_declaration_ref == g3_record.declaration_ref ||
                push!(errors, :g3_binding_key_parent_ref_mismatch)
            binding_key.parent_g3_declaration_hash ==
                g3_record.declaration_identity_hash ||
                push!(errors, :g3_binding_key_parent_hash_mismatch)
        end
    end

    if realization_state !== nothing
        local_errors = Symbol[]
        try
            if g3_record === nothing
                _vnext_t2_v3_validate_realization_intrinsic(
                    realization_state, local_errors)
                realization_state.key.candidate_ref == transport.candidate_ref ||
                    push!(local_errors, :realization_candidate_mismatch)
            else
                _vnext_t2_v3_validate_realization(realization_state,
                    transport.candidate_ref, g3_record.declaration_ref,
                    g3_record.declaration_identity_hash, local_errors)
            end
        catch
            push!(local_errors, :realization_state_invalid)
        end
        append!(errors, local_errors)
        if isempty(local_errors) && expected !== nothing && g3_record !== nothing
            current = _vnext_t2_v3_realization_current_commitment(
                realization_state, transport.candidate_ref,
                g3_record.declaration_ref, g3_record.declaration_identity_hash)
            _vnext_t2_v3_child_info_matches(current, expected.realization) ||
                push!(errors, :realization_expected_commitment_mismatch)
        end
    end

    control_local_errors = Symbol[]
    if control_payload !== nothing
        try
            _vnext_t2_v3_validate_control_payload_intrinsic(
                control_payload, control_local_errors)
            control_payload.key.candidate_ref == transport.candidate_ref ||
                push!(control_local_errors, :control_candidate_mismatch)
            if g3_record !== nothing
                control_payload.parent_g3_declaration_ref ==
                    g3_record.declaration_ref ||
                    push!(control_local_errors, :control_parent_ref_mismatch)
                control_payload.parent_g3_declaration_hash ==
                    g3_record.declaration_identity_hash ||
                    push!(control_local_errors, :control_parent_hash_mismatch)
            end
        catch
            push!(control_local_errors, :control_payload_invalid)
        end
    end
    if control_state !== nothing
        try
            _vnext_t2_v3_validate_control_state_intrinsic(
                control_state, control_local_errors)
            control_state.key.candidate_ref == transport.candidate_ref ||
                push!(control_local_errors, :control_candidate_mismatch)
            if g3_record !== nothing
                control_state.key.parent_g3_declaration_hash ==
                    g3_record.declaration_identity_hash ||
                    push!(control_local_errors, :control_parent_hash_mismatch)
            end
        catch
            push!(control_local_errors, :control_state_invalid)
        end
    end
    if control_payload !== nothing && control_state !== nothing &&
            isempty(control_local_errors)
        try
            _vnext_t2_v3_validate_control_pair(control_payload, control_state,
                control_local_errors)
        catch
            push!(control_local_errors, :control_state_invalid)
        end
        if isempty(control_local_errors) && expected !== nothing &&
                g3_record !== nothing
            current = _vnext_t2_v3_control_current_commitment(control_payload,
                control_state, transport.candidate_ref,
                g3_record.declaration_ref, g3_record.declaration_identity_hash)
            _vnext_t2_v3_child_info_matches(current, expected.control) ||
                push!(errors, :control_expected_commitment_mismatch)
        end
    end
    append!(errors, control_local_errors)

    if bridge !== nothing
        if bridge.status === :local_checked_present
            bridge.resolution === :resolved ||
                push!(errors, :g3_bridge_resolution_invalid)
            bridge.self_consistency && bridge.authority_verified ||
                push!(errors, :g3_bridge_authority_invalid)
            isempty(bridge.errors) && isempty(bridge.reasons) ||
                push!(errors, :g3_bridge_diagnostics_present)
            if bridge.projection isa VNextT2G3CurrentStateProjectionV3
                bridge.projection.projection_hash == canonical_hash(
                    _vnext_t2_v3_current_projection_body(bridge.projection)) ||
                    push!(errors, :g3_bridge_projection_hash_mismatch)
                bridge.projection.candidate_ref == transport.candidate_ref ||
                    push!(errors, :g3_bridge_projection_candidate_mismatch)
                if g3_record !== nothing
                    bridge.projection.parent_g3_declaration_ref ==
                        g3_record.declaration_ref ||
                        push!(errors, :g3_bridge_projection_parent_ref_mismatch)
                    bridge.projection.parent_g3_declaration_hash ==
                        g3_record.declaration_identity_hash ||
                        push!(errors, :g3_bridge_projection_parent_hash_mismatch)
                end
            else
                push!(errors, :g3_bridge_projection_missing)
            end
            if bridge.binding_state isa G3BindingStateV2
                isempty(_g3be2_validate_state(bridge.binding_state)) ||
                    push!(errors, :g3_binding_state_invalid)
                bridge.binding_state.source_payload.key.candidate_ref ==
                    transport.candidate_ref ||
                    push!(errors, :g3_bridge_binding_candidate_mismatch)
                if g3_record !== nothing
                    bridge.binding_state.source_payload.key.parent_g3_declaration_ref ==
                        g3_record.declaration_ref ||
                        push!(errors, :g3_bridge_binding_parent_ref_mismatch)
                    bridge.binding_state.source_payload.key.parent_g3_declaration_hash ==
                        g3_record.declaration_identity_hash ||
                        push!(errors, :g3_bridge_binding_parent_hash_mismatch)
                end
                binding_key === nothing ||
                    bridge.binding_state.source_payload.key == binding_key ||
                    push!(errors, :g3_binding_key_mismatch)
            else
                push!(errors, :g3_binding_state_missing)
            end
        elseif bridge.status === :typed_absent
            (bridge.resolution === :terminal_deferred &&
             !bridge.self_consistency && !bridge.authority_verified &&
             bridge.projection === nothing && bridge.binding_state === nothing &&
             isempty(bridge.errors)) || push!(errors, :g3_bridge_absence_invalid)
        else
            push!(errors, :g3_bridge_status_invalid)
        end
    end
    Tuple(unique(errors))
end

function _vnext_t2_v3_validate_inputs(transport, recheck, parent, expected,
        bridge, realization_state, control_payload, control_state, binding_key;
        frozen_context=nothing, g3_factory_invocation=nothing)
    errors = Symbol[]
    append!(errors, _vnext_t2_v3_known_input_errors(transport, recheck, parent;
        frozen_context=frozen_context))
    !isempty(errors) && return (kind=:fail_closed,
        errors=Tuple(unique(errors)), gaps=(), material=nothing)
    append!(errors, _vnext_t2_v3_optional_input_errors(transport, expected,
        bridge, realization_state, control_payload, control_state, binding_key))
    !isempty(errors) && return (kind=:fail_closed,
        errors=Tuple(unique(errors)), gaps=(), material=nothing)
    gaps = _vnext_t2_v3_missing_inputs(transport, recheck, parent, expected,
        bridge, realization_state, control_payload, control_state, binding_key)
    !isempty(gaps) && return (kind=:typed_absent, errors=(), gaps=gaps, material=nothing)

    transport.status === :valid || push!(errors, :t0_transport_status_invalid)
    isempty(transport.errors) || push!(errors, :t0_transport_errors_present)
    try
        vnext_t0_local_bundle_hash_recompute_v1(transport) == transport.bundle_hash ||
            push!(errors, :t0_bundle_hash_mismatch)
    catch
        push!(errors, :t0_bundle_hash_recompute_failed)
    end
    records = _vnext_t2_v3_record_map(transport, errors)
    if length(records) == 3
        for layer in VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3
            append!(errors, _vnl_t0_errors(records[layer], transport.candidate_ref;
                frozen_context=frozen_context))
        end
        append!(errors, _vnl_t0_feedback_errors(transport.feedback,
            transport.candidate_ref, transport.declarations))
        for kind in (:realization, :control, :binding)
            matches = Tuple(child for child in transport.children if child.kind === kind)
            length(matches) == 1 || (push!(errors, :t0_child_arity_invalid); continue)
            child = only(matches)
            append!(errors, _vnl_t0_child_errors(child, transport.candidate_ref,
                kind; frozen_context=frozen_context))
            _vnext_t2_v3_is_v2_recheck(recheck) ||
                child isa VNextT0LocalChildAbsentV1 ||
                push!(errors, :t0_child_present_forbidden)
        end
    end

    recheck.status === :local_checked_present || push!(errors, :t0_recheck_status_invalid)
    recheck.resolution === :resolved || push!(errors, :t0_recheck_resolution_invalid)
    recheck.accepted == false || push!(errors, :t0_recheck_acceptance_claim_invalid)
    if _vnext_t2_v3_is_v2_recheck(recheck)
        checked_type = _vnext_t2_v3_v2_checked_type()
        recheck.output isa checked_type || push!(errors, :t0_recheck_output_type_invalid)
        if recheck.output isa checked_type && length(records) == 3
            output = recheck.output
            output.candidate_ref == transport.candidate_ref ||
                push!(errors, :t0_recheck_candidate_mismatch)
            output.bundle_hash == transport.bundle_hash == recheck.prior_bundle_sha256 ||
                push!(errors, :t0_recheck_bundle_hash_mismatch)
            output.g3_children_deferred === false ||
                push!(errors, :t0_recheck_g3_children_deferred_invalid)
            _vnext_t2_v3_canonical_equal(output.declarations,
                transport.declarations) || push!(errors, :t0_recheck_record_mismatch)
            _vnext_t2_v3_canonical_equal(output.feedback, transport.feedback) ||
                push!(errors, :t0_recheck_feedback_mismatch)
            _vnext_t2_v3_canonical_equal(output.children, transport.children) ||
                push!(errors, :t0_recheck_children_mismatch)
        end
    else
        recheck.output isa VNextAuthorityRecheckLocalCheckedPresentV1 ||
            push!(errors, :t0_recheck_output_type_invalid)
    end
    if !_vnext_t2_v3_is_v2_recheck(recheck) &&
            recheck.output isa VNextAuthorityRecheckLocalCheckedPresentV1 && length(records) == 3
        output = recheck.output
        output.candidate_ref == transport.candidate_ref ||
            push!(errors, :t0_recheck_candidate_mismatch)
        output.bundle_hash == transport.bundle_hash == recheck.prior_bundle_sha256 ||
            push!(errors, :t0_recheck_bundle_hash_mismatch)
        for layer in VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3
            _vnext_t2_v3_canonical_equal(getproperty(output, Symbol(lowercase(String(layer)))),
                records[layer]) || push!(errors, :t0_recheck_record_mismatch)
        end
        _vnext_t2_v3_canonical_equal(output.feedback, transport.feedback) ||
            push!(errors, :t0_recheck_feedback_mismatch)
        _vnext_t2_v3_canonical_equal(output.children, transport.children) ||
            push!(errors, :t0_recheck_children_mismatch)
    end
    _vnext_t2_v3_snapshot_matches(recheck.prior_bundle_bytes, transport) ||
        push!(errors, :t0_recheck_snapshot_mismatch)

    g1 = length(records) == 3 ? _vnext_t2_v3_materialize_g1(records[:G1], errors;
        frozen_context=frozen_context, g2_record=records[:G2]) : nothing
    g2 = length(records) == 3 ? _vnext_t2_v3_materialize_g2(records[:G2], errors;
        frozen_context=frozen_context) : nothing
    g3 = if length(records)!=3
        nothing
    elseif g3_factory_invocation===nothing
        _vnext_t2_v3_materialize_g3(records[:G3], errors;
            frozen_context=frozen_context, children=transport.children)
    else
        _vnext_t2_v3_materialize_g3(records[:G3], errors;
            frozen_context=frozen_context, children=transport.children,
            g3_factory_invocation=g3_factory_invocation)
    end

    if length(records) == 3
        for layer in VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3
            record = records[layer]
            for receipt in (record.factory_receipt, record.declaration_receipt)
                fr = receipt.factory_result
                fr.source_bytes.bytes == record.source_bytes.bytes ||
                    push!(errors, :factory_source_bytes_mismatch)
                fr.declaration_bytes.bytes == record.declaration_bytes.bytes ||
                    push!(errors, :factory_declaration_bytes_mismatch)
                fr.axes == receipt.factory_axes || push!(errors, :factory_axes_mismatch)
            end
        end
    end

    parent.status === :present || push!(errors, :parent_authority_status_invalid)
    parent.resolution === :resolved || push!(errors, :parent_authority_resolution_invalid)
    parent.output isa PresentT0LocalParentBaselineBundleV1 ||
        push!(errors, :parent_authority_output_type_invalid)
    if length(records) == 3 && parent.output isa PresentT0LocalParentBaselineBundleV1
        fresh_parent = bind_local_parent_baseline_from_t0_v1(
            T0LocalParentBaselineInputV1(transport.candidate_ref,
                (records[:G1], records[:G2]));
            frozen_context=frozen_context)
        _vnext_t2_v3_canonical_equal(fresh_parent, parent) ||
            push!(errors, :parent_authority_reconstruction_mismatch)
        verify_present_t0_local_parent_bundle_v1(parent.output,
            t0_parent_authority_commitment_v1(records[:G1]),
            t0_parent_authority_commitment_v1(records[:G2])) ||
            push!(errors, :parent_authority_commitment_mismatch)
    end

    if g3 !== nothing
        expected.candidate_ref == transport.candidate_ref ||
            push!(errors, :g3_expected_candidate_mismatch)
        expected.bundle_hash == transport.bundle_hash ||
            push!(errors, :g3_expected_bundle_hash_mismatch)
        expected.g3_declaration_ref == records[:G3].declaration_ref ||
            push!(errors, :g3_expected_declaration_ref_mismatch)
        expected.g3_declaration_identity_hash == records[:G3].declaration_identity_hash ||
            push!(errors, :g3_expected_declaration_hash_mismatch)
        expected.commitment_hash == vnext_g3_binding_expected_commitment_hash_v1(expected) ||
            push!(errors, :g3_expected_commitment_hash_mismatch)
        _vnext_t2_v3_validate_realization(realization_state,
            transport.candidate_ref, records[:G3].declaration_ref,
            records[:G3].declaration_identity_hash, errors)
        _vnext_t2_v3_validate_control(control_payload, control_state,
            transport.candidate_ref, records[:G3].declaration_ref,
            records[:G3].declaration_identity_hash, errors)
        projection = try
            vnext_t2_g3_current_state_projection_v3(
                transport.candidate_ref, records[:G3].declaration_ref,
                records[:G3].declaration_identity_hash, realization_state,
                control_payload, control_state)
        catch
            push!(errors, :g3_current_state_projection_invalid)
            nothing
        end
        if projection isa VNextT2G3CurrentStateProjectionV3
            _vnext_t2_v3_child_info_matches(projection.realization,
                expected.realization) ||
                push!(errors, :realization_expected_commitment_mismatch)
            _vnext_t2_v3_child_info_matches(projection.control, expected.control) ||
                push!(errors, :control_expected_commitment_mismatch)
        end

        bridge.status === :local_checked_present || push!(errors, :g3_bridge_status_invalid)
        bridge.resolution === :resolved || push!(errors, :g3_bridge_resolution_invalid)
        bridge.self_consistency && bridge.authority_verified ||
            push!(errors, :g3_bridge_authority_invalid)
        isempty(bridge.errors) && isempty(bridge.reasons) ||
            push!(errors, :g3_bridge_diagnostics_present)
        bridge.projection isa VNextT2G3CurrentStateProjectionV3 ||
            push!(errors, :g3_bridge_projection_missing)
        bridge.projection isa VNextT2G3CurrentStateProjectionV3 &&
            projection isa VNextT2G3CurrentStateProjectionV3 &&
            !_vnext_t2_v3_canonical_equal(bridge.projection, projection) &&
            push!(errors, :g3_bridge_projection_mismatch)
        bridge.binding_state isa G3BindingStateV2 ||
            push!(errors, :g3_binding_state_missing)
        if bridge.binding_state isa G3BindingStateV2
            binding = bridge.binding_state
            isempty(_g3be2_validate_state(binding)) ||
                push!(errors, :g3_binding_state_invalid)
            binding.source_payload.key == binding_key ||
                push!(errors, :g3_binding_key_mismatch)
            links = _vnext_t2_v3_binding_links(g3)
            _vnext_t2_v3_canonical_equal(binding.source_payload.initial_links, links) ||
                push!(errors, :g3_binding_initial_links_mismatch)
            fresh_bridge = vnext_t2_concrete_g3_bridge_v3(recheck,
                expected, realization_state, control_payload, control_state,
                binding_key; initial_links=links)
            fresh_bridge.binding_state isa G3BindingStateV2 ||
                push!(errors, :g3_bridge_reconstruction_failed)
            if fresh_bridge.binding_state isa G3BindingStateV2
                fresh = fresh_bridge.binding_state
                _vnext_t2_v3_canonical_equal(binding.source_payload,
                    fresh.source_payload) || push!(errors, :g3_binding_source_payload_mismatch)
                binding.binding_child_identity_hash == fresh.binding_child_identity_hash ||
                    push!(errors, :g3_binding_child_identity_mismatch)
                binding.initial_body_hash == fresh.initial_body_hash ||
                    push!(errors, :g3_binding_initial_body_hash_mismatch)
                binding.initial_source_state_hash == fresh.initial_source_state_hash ||
                    push!(errors, :g3_binding_initial_source_hash_mismatch)
            end
            _vnext_t2_v3_validate_feedback(transport.feedback, g3, records, errors)
        end
    end

    unique!(errors)
    material = isempty(errors) ? (records=records, g1=g1, g2=g2, g3=g3) : nothing
    (kind=isempty(errors) ? :present : :fail_closed,
     errors=Tuple(errors), gaps=(), material=material)
end

function _vnext_t2_v3_build(transport, recheck, parent, expected, bridge,
        realization_state, control_payload, control_state, material)
    records = material.records
    source_bytes = sum(length(records[layer].source_bytes.bytes) +
        length(records[layer].declaration_bytes.bytes)
        for layer in VNEXT_T2_CONCRETE_SOURCE_WITNESS_LAYERS_V3)
    _vnext_t2_v3_trace("build.begin"; bytes=source_bytes)
    _vnext_t2_v3_trace("build.g1_identity.begin")
    g1_identity = _vnext_t2_v3_layer_identity(:G1, records[:G1], material.g1)
    _vnext_t2_v3_trace("build.g1_identity.complete")
    _vnext_t2_v3_trace("build.g2_identity.begin")
    g2_identity = _vnext_t2_v3_layer_identity(:G2, records[:G2], material.g2)
    _vnext_t2_v3_trace("build.g2_identity.complete")
    _vnext_t2_v3_trace("build.g3_identity.begin")
    g3_identity = _vnext_t2_v3_layer_identity(:G3, records[:G3], material.g3)
    _vnext_t2_v3_trace("build.g3_identity.complete")
    g1 = VNextT2ConcreteG1DeclarationV3(records[:G1], material.g1, g1_identity)
    g2 = VNextT2ConcreteG2DeclarationV3(records[:G2],
        records[:G2].semantic_body.body.candidate_envelope,
        material.g2, g2_identity)
    g3 = VNextT2ConcreteG3DeclarationV3(records[:G3],
        records[:G3].semantic_body.body.source_ref, material.g3, g3_identity)

    children_draft = VNextT2ConcreteG3ChildrenV3(transport.children,
        expected, realization_state, control_payload, control_state,
        bridge.binding_state, Digest256(repeat("0", 64)))
    _vnext_t2_v3_trace("build.children_hash.begin")
    children_hash = canonical_hash(_vnext_t2_v3_children_body(children_draft))
    _vnext_t2_v3_trace("build.children_hash.complete")
    children = VNextT2ConcreteG3ChildrenV3(children_draft.t0_children,
        children_draft.expected_commitment, children_draft.realization_state,
        children_draft.control_payload, children_draft.control_state,
        children_draft.binding_state, children_hash)

    links = _vnext_t2_v3_binding_links(material.g3)
    feedback_draft = VNextT2ConcreteFeedbackV3(transport.feedback,
        material.g3.feedback_targets, links, Digest256(repeat("0", 64)))
    _vnext_t2_v3_trace("build.feedback_hash.begin")
    feedback_hash = canonical_hash(_vnext_t2_v3_feedback_body(feedback_draft))
    _vnext_t2_v3_trace("build.feedback_hash.complete")
    feedback = VNextT2ConcreteFeedbackV3(feedback_draft.t0_feedback,
        feedback_draft.g3_targets, feedback_draft.binding_links,
        feedback_hash)
    _vnext_t2_v3_trace("build.coupling.begin")
    coupling = _vnext_t2_v3_coupling(material.g3, realization_state)
    _vnext_t2_v3_trace("build.coupling.complete")

    _vnext_t2_v3_trace("build.source_bundle_hash.begin")
    source_bundle_hash = canonical_hash((
        domain="vnext-t2-concrete-source-bundle-v3",
        candidate_ref=transport.candidate_ref, g1=g1_identity.identity_hash,
        g2=g2_identity.identity_hash, g3=g3_identity.identity_hash,
        children=children.identity_hash, feedback=feedback.identity_hash))
    _vnext_t2_v3_trace("build.source_bundle_hash.complete")
    _vnext_t2_v3_trace("build.transport_hash.begin"; bytes=source_bytes)
    transport_hash = canonical_hash(transport)
    _vnext_t2_v3_trace("build.transport_hash.complete")
    _vnext_t2_v3_trace("build.recheck_hash.begin")
    recheck_hash = canonical_hash(
        _vnext_t2_v3_recheck_output_body(recheck.output))
    _vnext_t2_v3_trace("build.recheck_hash.complete")
    manifest_draft = VNextT2ConcreteSourceManifestV3(transport.candidate_ref,
        transport.bundle_hash, transport_hash, recheck_hash, parent.output.bundle_hash,
        expected.commitment_hash, g1_identity.identity_hash,
        g2_identity.identity_hash, g3_identity.identity_hash,
        children.identity_hash, feedback.identity_hash, source_bundle_hash,
        Digest256(repeat("0", 64)))
    _vnext_t2_v3_trace("build.manifest_hash.begin")
    manifest_hash = canonical_hash(_vnext_t2_v3_manifest_body(manifest_draft))
    _vnext_t2_v3_trace("build.manifest_hash.complete")
    manifest = VNextT2ConcreteSourceManifestV3(manifest_draft.candidate_ref,
        manifest_draft.t0_bundle_hash, manifest_draft.t0_transport_hash,
        manifest_draft.t0_recheck_output_hash, manifest_draft.parent_bundle_hash,
        manifest_draft.g3_expected_commitment_hash,
        manifest_draft.g1_identity_hash, manifest_draft.g2_identity_hash,
        manifest_draft.g3_identity_hash, manifest_draft.children_identity_hash,
        manifest_draft.feedback_identity_hash, manifest_draft.source_bundle_hash,
        manifest_hash)
    formal = VNextT2FormalT1PendingV3()
    gap_list = Symbol[:formal_t1_not_yet_accepted,
        :formal_t2_consumers_not_executed,
        :physical_coupling_not_resolved]
    !isempty(realization_state.operation_history) && push!(gap_list,
        :realization_full_operation_replay_evidence_not_carried)
    !isempty(control_state.operation_history) && push!(gap_list,
        :control_full_operation_replay_evidence_not_carried)
    gaps = Tuple(gap_list)
    draft = VNextT2ConcreteSourceWitnessV3(
        VNEXT_T2_CONCRETE_SOURCE_WITNESS_SCHEMA_ID_V3,
        VNEXT_T2_CONCRETE_SOURCE_WITNESS_SCHEMA_VERSION_V3,
        VNEXT_T2_CONCRETE_SOURCE_WITNESS_PROFILE_V3,
        transport.candidate_ref, g1, g2, g3, transport, recheck.output,
        parent.output, children, feedback, coupling, manifest, formal,
        :source_ready, :terminal_deferred, false, gaps,
        Digest256(repeat("0", 64)))
    _vnext_t2_v3_trace("build.witness_hash.begin")
    witness_hash = canonical_hash(_vnext_t2_v3_witness_body(draft))
    _vnext_t2_v3_trace("build.witness_hash.complete")
    witness = VNextT2ConcreteSourceWitnessV3(draft.schema_id, draft.schema_version,
        draft.profile, draft.candidate_ref, draft.g1, draft.g2, draft.g3,
        draft.t0_transport, draft.t0_recheck, draft.parent_bundle,
        draft.children, draft.feedback, draft.coupling, draft.manifest,
        draft.formal_t1, draft.source_status, draft.resolution,
        draft.formal_node_accepted, draft.gaps, witness_hash)
    _vnext_t2_v3_trace("build.complete")
    witness
end

"""Build a V3 native source witness without observing or invoking formal T1/T2."""
function prepare_vnext_t2_concrete_source_witness_v3(
        transport::VNextT0LocalTransportV1,
        recheck,
        parent::T0LocalParentBaselineBindResultV1,
        expected::Union{Nothing,VNextG3BindingAuthorityExpectedCommitmentV1},
        bridge::Union{Nothing,VNextT2ConcreteG3BridgeV3},
        realization_state::Union{Nothing,G3RealizationSourceStateV1},
        control_payload::Union{Nothing,G3ControlSourcePayloadV1},
        control_state::Union{Nothing,G3ControlStateV1},
        binding_key::Union{Nothing,G3BindingChildKeyV2};
        frozen_context=nothing, g3_factory_invocation=nothing)
    try
        checked = if g3_factory_invocation===nothing
            _vnext_t2_v3_validate_inputs(transport, recheck, parent,
                expected, bridge, realization_state, control_payload,
                control_state, binding_key; frozen_context=frozen_context)
        else
            _vnext_t2_v3_validate_inputs(transport, recheck, parent,
                expected, bridge, realization_state, control_payload,
                control_state, binding_key; frozen_context=frozen_context,
                g3_factory_invocation=g3_factory_invocation)
        end
        checked.kind === :typed_absent && return _vnext_t2_v3_result(
            :typed_absent, :terminal_deferred, nothing, (), checked.gaps)
        checked.kind === :fail_closed && return _vnext_t2_v3_result(
            :fail_closed, :none, nothing, checked.errors, ())
        witness = _vnext_t2_v3_build(transport, recheck, parent, expected,
            bridge, realization_state, control_payload, control_state,
            checked.material)
        _vnext_t2_v3_result(:source_ready, :terminal_deferred, witness, (),
            witness.gaps)
    catch
        _vnext_t2_v3_result(:program_exception, :none, nothing,
            (:vnext_t2_concrete_source_witness_program_exception,), ())
    end
end

"""Rebuild from independent current inputs and compare every carried field."""
function validate_vnext_t2_concrete_source_witness_v3(
        witness::VNextT2ConcreteSourceWitnessV3,
        transport::VNextT0LocalTransportV1,
        recheck,
        parent::T0LocalParentBaselineBindResultV1,
        expected::Union{Nothing,VNextG3BindingAuthorityExpectedCommitmentV1},
        bridge::Union{Nothing,VNextT2ConcreteG3BridgeV3},
        realization_state::Union{Nothing,G3RealizationSourceStateV1},
        control_payload::Union{Nothing,G3ControlSourcePayloadV1},
        control_state::Union{Nothing,G3ControlStateV1},
        binding_key::Union{Nothing,G3BindingChildKeyV2};
        frozen_context=nothing, g3_factory_invocation=nothing)
    prepared = if g3_factory_invocation===nothing
        prepare_vnext_t2_concrete_source_witness_v3(transport,
            recheck, parent, expected, bridge, realization_state,
            control_payload, control_state, binding_key;
            frozen_context=frozen_context)
    else
        prepare_vnext_t2_concrete_source_witness_v3(transport,
            recheck, parent, expected, bridge, realization_state,
            control_payload, control_state, binding_key;
            frozen_context=frozen_context,
            g3_factory_invocation=g3_factory_invocation)
    end
    prepared.source_ready || return prepared
    errors = Symbol[]
    witness.schema_id == VNEXT_T2_CONCRETE_SOURCE_WITNESS_SCHEMA_ID_V3 ||
        push!(errors, :witness_schema_id_mismatch)
    witness.schema_version == VNEXT_T2_CONCRETE_SOURCE_WITNESS_SCHEMA_VERSION_V3 ||
        push!(errors, :witness_schema_version_mismatch)
    witness.profile == VNEXT_T2_CONCRETE_SOURCE_WITNESS_PROFILE_V3 ||
        push!(errors, :witness_profile_mismatch)
    witness.witness_hash == canonical_hash(_vnext_t2_v3_witness_body(witness)) ||
        push!(errors, :witness_hash_mismatch)
    _vnext_t2_v3_canonical_equal(witness, prepared.witness) ||
        push!(errors, :witness_independent_reconstruction_mismatch)
    witness.formal_t1.formal_consumer_counts == _vnext_t2_v3_zero_counts() ||
        push!(errors, :formal_consumer_count_nonzero)
    witness.formal_node_accepted == false || push!(errors, :formal_acceptance_claim_invalid)
    isempty(errors) ? _vnext_t2_v3_result(:source_ready,
        :terminal_deferred, witness, (), witness.gaps) :
        _vnext_t2_v3_result(:fail_closed, :none, nothing, errors, ())
end

revalidate_vnext_t2_concrete_source_witness_v3(args...) =
    validate_vnext_t2_concrete_source_witness_v3(args...)

vnext_t2_concrete_source_witness_canonical_bytes_v3(
    witness::VNextT2ConcreteSourceWitnessV3) =
    Vector{UInt8}(codeunits(canonical_json(witness)))

vnext_t2_concrete_source_witness_hash_v3(
    witness::VNextT2ConcreteSourceWitnessV3) =
    canonical_hash(_vnext_t2_v3_witness_body(witness))

export VNEXT_T2_CONCRETE_SOURCE_WITNESS_SCHEMA_ID_V3,
       VNEXT_T2_CONCRETE_SOURCE_WITNESS_SCHEMA_VERSION_V3,
       VNEXT_T2_CONCRETE_SOURCE_WITNESS_PROFILE_V3,
       VNextT2FormalT1PendingV3, VNextT2G3CurrentStateProjectionV3,
       VNextT2ConcreteG3BridgeV3, VNextT2ConcreteLayerIdentityV3,
       VNextT2ConcreteG1DeclarationV3, VNextT2ConcreteG2DeclarationV3,
       VNextT2ConcreteG3DeclarationV3, VNextT2ConcreteG3ChildrenV3,
       VNextT2ConcreteFeedbackV3, VNextT2SourceCouplingDiagnosticsV3,
       VNextT2ConcreteSourceManifestV3, VNextT2ConcreteSourceWitnessV3,
       VNextT2ConcreteSourceWitnessResultV3,
       vnext_t2_g3_current_state_projection_v3,
       vnext_concrete_source_witness_g3_bridge_v1,
       vnext_t2_concrete_g3_bridge_v3,
       prepare_vnext_t2_concrete_source_witness_v3,
       validate_vnext_t2_concrete_source_witness_v3,
       revalidate_vnext_t2_concrete_source_witness_v3,
       vnext_t2_concrete_source_witness_canonical_bytes_v3,
       vnext_t2_concrete_source_witness_hash_v3
