using Test
using Serialization

include(joinpath(@__DIR__, "fixture_helpers.jl"))

function v3_serialization_replace_ascii(value, original::AbstractString,
        replacement::AbstractString)
    ncodeunits(original) == ncodeunits(replacement) ||
        error(:serialization_replacement_length_mismatch)
    io = IOBuffer()
    Serialization.serialize(io, value)
    bytes = take!(io)
    needle = Vector{UInt8}(codeunits(original))
    changed = Vector{UInt8}(codeunits(replacement))
    hits = Int[]
    last = length(bytes) - length(needle) + 1
    for index in 1:max(last, 0)
        @views bytes[index:index + length(needle) - 1] == needle &&
            push!(hits, index)
    end
    length(hits) == 1 || error((:serialization_replacement_hit_count,
        original, length(hits)))
    copyto!(bytes, only(hits), changed, 1, length(changed))
    Serialization.deserialize(IOBuffer(bytes))
end

function v3_fields_equal_except(left, right, excluded::Symbol)
    typeof(left) === typeof(right) || return false
    all(field === excluded ||
        V3_G.canonical_json(getproperty(left, field)) ==
            V3_G.canonical_json(getproperty(right, field))
        for field in fieldnames(typeof(left)))
end

function v3_rehash_feedback(feedback;
        t0_feedback=feedback.t0_feedback,
        g3_targets=feedback.g3_targets,
        binding_links=feedback.binding_links)
    draft = V3_G.VNextT2ConcreteFeedbackV3(t0_feedback, g3_targets,
        binding_links, V3_G.Digest256(repeat("0", 64)))
    V3_G.VNextT2ConcreteFeedbackV3(t0_feedback, g3_targets, binding_links,
        V3_G.canonical_hash(V3_G._vnext_t2_v3_feedback_body(draft)))
end

function v3_rehash_children(children;
        t0_children=children.t0_children,
        expected_commitment=children.expected_commitment,
        realization_state=children.realization_state,
        control_payload=children.control_payload,
        control_state=children.control_state,
        binding_state=children.binding_state)
    draft = V3_G.VNextT2ConcreteG3ChildrenV3(t0_children,
        expected_commitment, realization_state, control_payload,
        control_state, binding_state, V3_G.Digest256(repeat("0", 64)))
    V3_G.VNextT2ConcreteG3ChildrenV3(t0_children, expected_commitment,
        realization_state, control_payload, control_state, binding_state,
        V3_G.canonical_hash(V3_G._vnext_t2_v3_children_body(draft)))
end

function v3_rehash_layer_identity(identity; kwargs...)
    values = Dict{Symbol,Any}(
        field => getproperty(identity, field) for field in fieldnames(typeof(identity)))
    for (field, value) in kwargs
        values[field] = value
    end
    draft = V3_G.VNextT2ConcreteLayerIdentityV3(
        values[:layer], values[:source_file_sha256],
        values[:native_source_payload_hash], values[:semantic_body_hash],
        values[:semantic_body_sha256], values[:native_declaration_hash],
        values[:declaration_sha256], values[:source_identity_hash],
        values[:declaration_identity_hash], values[:source_carrier_hash],
        values[:declaration_component_hash], values[:factory_content_identity],
        values[:source_axes], values[:factory_axes],
        V3_G.Digest256(repeat("0", 64)))
    V3_G.VNextT2ConcreteLayerIdentityV3(draft.layer,
        draft.source_file_sha256, draft.native_source_payload_hash,
        draft.semantic_body_hash, draft.semantic_body_sha256,
        draft.native_declaration_hash, draft.declaration_sha256,
        draft.source_identity_hash, draft.declaration_identity_hash,
        draft.source_carrier_hash, draft.declaration_component_hash,
        draft.factory_content_identity, draft.source_axes,
        draft.factory_axes,
        V3_G.canonical_hash(V3_G._vnext_t2_v3_layer_identity_body(draft)))
end

function v3_rehash_witness(witness;
        g1=witness.g1, g2=witness.g2, g3=witness.g3,
        t0_transport=witness.t0_transport,
        t0_recheck=witness.t0_recheck,
        parent_bundle=witness.parent_bundle,
        children=witness.children, feedback=witness.feedback,
        coupling=witness.coupling, formal_t1=witness.formal_t1,
        source_status=witness.source_status, resolution=witness.resolution,
        formal_node_accepted=witness.formal_node_accepted,
        gaps=witness.gaps)
    source_bundle_hash = V3_G.canonical_hash((
        domain="vnext-t2-concrete-source-bundle-v3",
        candidate_ref=witness.candidate_ref,
        g1=g1.identity.identity_hash, g2=g2.identity.identity_hash,
        g3=g3.identity.identity_hash, children=children.identity_hash,
        feedback=feedback.identity_hash))
    mdraft = V3_G.VNextT2ConcreteSourceManifestV3(witness.candidate_ref,
        t0_transport.bundle_hash, V3_G.canonical_hash(t0_transport),
        V3_G.canonical_hash(V3_G._vnext_t2_v3_recheck_output_body(t0_recheck)),
        parent_bundle.bundle_hash,
        children.expected_commitment.commitment_hash,
        g1.identity.identity_hash, g2.identity.identity_hash,
        g3.identity.identity_hash, children.identity_hash,
        feedback.identity_hash, source_bundle_hash,
        V3_G.Digest256(repeat("0", 64)))
    manifest = V3_G.VNextT2ConcreteSourceManifestV3(mdraft.candidate_ref,
        mdraft.t0_bundle_hash, mdraft.t0_transport_hash,
        mdraft.t0_recheck_output_hash, mdraft.parent_bundle_hash,
        mdraft.g3_expected_commitment_hash, mdraft.g1_identity_hash,
        mdraft.g2_identity_hash, mdraft.g3_identity_hash,
        mdraft.children_identity_hash, mdraft.feedback_identity_hash,
        mdraft.source_bundle_hash,
        V3_G.canonical_hash(V3_G._vnext_t2_v3_manifest_body(mdraft)))
    draft = V3_G.VNextT2ConcreteSourceWitnessV3(witness.schema_id,
        witness.schema_version, witness.profile, witness.candidate_ref,
        g1, g2, g3, t0_transport, t0_recheck, parent_bundle, children,
        feedback, coupling, manifest, formal_t1, source_status, resolution,
        formal_node_accepted, gaps, V3_G.Digest256(repeat("0", 64)))
    V3_G.VNextT2ConcreteSourceWitnessV3(draft.schema_id,
        draft.schema_version, draft.profile, draft.candidate_ref,
        draft.g1, draft.g2, draft.g3, draft.t0_transport,
        draft.t0_recheck, draft.parent_bundle, draft.children,
        draft.feedback, draft.coupling, draft.manifest, draft.formal_t1,
        draft.source_status, draft.resolution, draft.formal_node_accepted,
        draft.gaps, V3_G.canonical_hash(V3_G._vnext_t2_v3_witness_body(draft)))
end

v3_trace("focused.testset.begin")
@testset "VNext T2 concrete native source witness V3" begin
    chain = v3_chain()
    @test chain.built.status === :source_ready
    @test chain.built.source_ready
    witness = chain.witness
    @test witness isa V3_G.VNextT2ConcreteSourceWitnessV3
    @test !isempty(V3_G.canonical_json(witness))
    @test witness.witness_hash ==
        V3_G.vnext_t2_concrete_source_witness_hash_v3(witness)

    @test witness.g1.declaration isa V3_G.G1DiffusionDeclarationV1
    @test witness.g2.declaration isa V3_G.G2MBDeclarationV1
    @test witness.g3.declaration isa V3_G.G3SFDeclarationV1
    @test witness.g2.candidate_envelope.candidate_ref == witness.candidate_ref
    @test witness.g2.declaration.source.candidate_ref isa V3_G.GenomeContractRef
    @test witness.g2.candidate_envelope.contract_ref ==
        witness.g2.declaration.source.candidate_ref
    @test witness.g2.candidate_envelope.candidate_ref !=
        witness.g2.declaration.source.candidate_ref

    for layer in (:g1, :g2, :g3)
        carrier = getproperty(witness, layer)
        @test Vector{UInt8}(codeunits(V3_G.canonical_json(carrier.declaration))) ==
            carrier.record.declaration_bytes.bytes
        @test carrier.record.factory_receipt.factory_result.declaration_bytes.bytes ==
            carrier.record.declaration_bytes.bytes
        @test carrier.identity.source_file_sha256 == carrier.record.source_bytes.sha256
        @test carrier.identity.source_axes == carrier.record.axes
        @test carrier.identity.factory_axes == carrier.record.factory_receipt.factory_axes
        @test carrier.identity.identity_hash ==
            V3_G.canonical_hash(V3_G._vnext_t2_v3_layer_identity_body(
                carrier.identity))
    end

    @test witness.children.realization_state.payload.body ==
        chain.realization_state.payload.body
    @test witness.children.control_payload.body == chain.control_payload.body
    @test witness.children.control_state.editable_body ==
        chain.control_state.editable_body
    @test witness.children.binding_state.editable_body ==
        chain.bridge.binding_state.editable_body
    @test witness.feedback.g3_targets == witness.g3.declaration.feedback_targets
    @test witness.feedback.binding_links ==
        witness.children.binding_state.source_payload.initial_links
    recheck_projection =
        V3_G._vnext_t2_v3_recheck_output_body(chain.recheck.output)
    expected_recheck_projection = (
        domain="vnext-t2-concrete-source-recheck-output-v3",
        candidate_ref=chain.recheck.output.candidate_ref,
        g1=chain.recheck.output.g1,
        g2=chain.recheck.output.g2,
        g3=chain.recheck.output.g3,
        feedback=chain.recheck.output.feedback,
        children=chain.recheck.output.children,
        bundle_hash=chain.recheck.output.bundle_hash,
    )
    @test recheck_projection == expected_recheck_projection
    @test witness.manifest.t0_recheck_output_hash ==
        V3_G.canonical_hash(expected_recheck_projection)
    recheck_projection_mutations = (
        merge(recheck_projection, (candidate_ref=V3_G.QualifiedRefV1(
            "fusionconceptai://candidate/recheck-tamper", "v5"),)),
        merge(recheck_projection, (g1=chain.recheck.output.g2,)),
        merge(recheck_projection, (g2=chain.recheck.output.g1,)),
        merge(recheck_projection, (g3=chain.recheck.output.g1,)),
        merge(recheck_projection, (feedback=(),)),
        merge(recheck_projection, (children=reverse(chain.recheck.output.children),)),
        merge(recheck_projection, (bundle_hash=V3_G.digest256_text(
            "recheck-bundle-tamper"),)),
    )
    @test all(V3_G.canonical_hash(mutation) !=
        witness.manifest.t0_recheck_output_hash
        for mutation in recheck_projection_mutations)

    @test witness.formal_t1.status === :typed_absent
    @test witness.formal_t1.formal_t1_accepted == false
    @test witness.formal_t1.package_hash === nothing
    @test witness.formal_t1.semantic_identity_hash === nothing
    @test witness.formal_t1.bundle_hash === nothing
    @test witness.formal_t1.reload_adapter_receipt_hash === nothing
    @test witness.formal_t1.formal_consumer_counts ==
        (e0=0, gi1a=0, e1=0, e2=0, n10=0)
    @test witness.formal_node_accepted == false
    @test v3_validate(chain).status === :source_ready
    v3_trace("focused.baseline.complete")

    # The historical fixture is materializable source, but its explicitly
    # associated G3 child contradicts the 3/4,1/8,1/8 source law and units.
    @test witness.coupling.status === :fail_closed
    @test :g3_source_law_realization_allocation_mismatch in witness.coupling.errors
    @test :g3_source_law_realization_unit_mismatch in witness.coupling.errors
    coherent = v3_chain(coherent_g3_child=true)
    @test coherent.built.status === :source_ready
    @test coherent.witness.coupling.status === :declared_consistent
    @test isempty(coherent.witness.coupling.errors)
    @test coherent.witness.coupling.resolution === :terminal_deferred
    v3_trace("focused.coupling.complete")

    # Fixture-only V2 authority recheck: same-candidate present T0 G3 children
    # can feed the V3 source precursor. This does not represent R55 source
    # coverage and must leave formal T1 explicitly pending.
    v2_source = v3_v2_present_source_precursor(chain)
    v2_recheck = v2_source.recheck
    @test v2_recheck.status === :local_checked_present
    @test v2_recheck.resolution === :resolved
    @test v2_recheck.accepted == false
    @test v2_recheck.claim_ceiling === :contract_only
    @test v2_recheck.errors == ()
    @test v2_recheck.output isa V3_G.VNextAuthorityRecheckLocalV2Checked
    @test v2_recheck.output.candidate_ref == chain.transport.candidate_ref
    @test v2_recheck.output.bundle_hash == v2_source.transport.bundle_hash
    @test v2_recheck.output.g3_children_deferred == false
    @test all(child isa V3_G.VNextT0LocalChildPresentV1
        for child in v2_recheck.output.children)
    @test all(child.candidate_ref == chain.transport.candidate_ref
        for child in v2_recheck.output.children)
    @test v2_source.bridge.status === :local_checked_present
    v2_prepared = V3_G.prepare_vnext_t2_concrete_source_witness_v3(
        v2_source.transport, v2_recheck, chain.parent, v2_source.expected,
        v2_source.bridge, chain.realization_state, chain.control_payload,
        chain.control_state, chain.binding_key)
    @test v2_prepared.status === :source_ready
    @test v2_prepared.witness.candidate_ref == chain.transport.candidate_ref
    @test v2_prepared.witness.formal_t1.status === :typed_absent
    @test v2_prepared.witness.formal_t1.formal_t1_accepted == false
    @test v2_prepared.witness.formal_node_accepted == false

    foreign_candidate = V3_G.QualifiedRefV1(
        "fusionconceptai://candidate/v3-v2-recheck-foreign", "v5")
    wrong_candidate = V3_G.vnext_declaration_authority_recheck_local_v2(
        V3_G.VNextAuthorityRecheckLocalV2Input(foreign_candidate,
            v2_source.transport))
    @test wrong_candidate.status === :fail_closed
    @test wrong_candidate.errors == (:candidate_mismatch,)

    first_child = first(v2_source.transport.children)
    altered_body = merge(first_child.body, (contract=:tampered_body,))
    altered_child = V3_G.VNextT0LocalChildPresentV1(first_child.kind,
        first_child.candidate_ref, first_child.parent_layer,
        first_child.child_id, first_child.child_ref, first_child.source_ref,
        first_child.source_bytes, first_child.source_locator, altered_body,
        first_child.body_hash, first_child.identity_hash)
    altered_children = (altered_child, v2_source.transport.children[2],
        v2_source.transport.children[3])
    altered_body_hash = V3_G.canonical_hash(V3_G._vnl_t0_bundle_body_v1(
        v2_source.transport.candidate_ref, v2_source.transport.declarations,
        altered_children, v2_source.transport.feedback,
        v2_source.transport.frozen_source_authority))
    altered_transport = V3_G.VNextT0LocalTransportV1(
        v2_source.transport.candidate_ref, v2_source.transport.declarations,
        altered_children, v2_source.transport.feedback, altered_body_hash,
        :valid, (), (), v2_source.transport.frozen_source_authority)
    altered_recheck = V3_G.vnext_declaration_authority_recheck_local_v2(
        V3_G.VNextAuthorityRecheckLocalV2Input(
            v2_source.transport.candidate_ref, altered_transport))
    @test altered_recheck.status === :fail_closed
    @test altered_recheck.errors == (:child_body_hash_mismatch,)

    missing_child = V3_G.prepare_vnext_t2_concrete_source_witness_v3(
        v2_source.transport, v2_recheck, chain.parent, v2_source.expected,
        v2_source.bridge, nothing, chain.control_payload, chain.control_state,
        chain.binding_key)
    @test missing_child.status === :typed_absent
    @test :g3_realization_state_absent in missing_child.gaps
    v3_trace("focused.v2_source_precursor.complete")

    # A real source-payload replacement preserves the frozen initial identity,
    # binds the current state hash, and keeps its operation/receipt as external
    # replay evidence.  The witness states that it does not carry the full op.
    edited = v3_chain(edited_realization=true)
    @test edited.realization_edit_operation isa
        V3_G.G3RealizationReplaceSourcePayloadV1
    @test edited.realization_edit_receipt isa V3_G.G3RealizationOperationReceiptV1
    @test edited.realization_state.initial_state_hash ==
        edited.realization_initial_state.initial_state_hash
    @test edited.realization_state.initial_source_content_hash ==
        edited.realization_initial_state.source_content_hash
    @test edited.realization_state.source_content_hash !=
        edited.realization_state.initial_source_content_hash
    @test edited.realization_state.operation_history == ("v3-realization-edit",)
    @test edited.bridge.projection.realization.state_hash ==
        edited.realization_state.state_hash
    @test edited.expected.realization.state_hash ==
        edited.realization_state.state_hash
    @test edited.built.status === :source_ready
    @test v3_validate(edited).status === :source_ready
    @test :realization_full_operation_replay_evidence_not_carried in
        edited.witness.gaps
    v3_trace("focused.edited_realization.complete")

    # Serialization bypasses inner constructors.  The public bridge therefore
    # recomputes the independently supplied expected commitment before granting
    # authority, rather than trusting the deserialized saved hash.
    forged_expected_hash = V3_G.digest256_text("forged-expected-commitment")
    forged_expected = v3_serialization_replace_ascii(chain.expected,
        chain.expected.commitment_hash.value, forged_expected_hash.value)
    @test forged_expected.commitment_hash == forged_expected_hash
    @test v3_fields_equal_except(chain.expected, forged_expected,
        :commitment_hash)
    @test forged_expected.commitment_hash !=
        V3_G.vnext_g3_binding_expected_commitment_hash_v1(forged_expected)
    forged_bridge = V3_G.vnext_t2_concrete_g3_bridge_v3(chain.recheck,
        forged_expected, chain.realization_state, chain.control_payload,
        chain.control_state, chain.binding_key;
        initial_links=chain.witness.feedback.binding_links)
    @test forged_bridge.status === :fail_closed
    @test :expected_commitment_hash_mismatch in forged_bridge.errors
    v3_trace("focused.bridge_reload_negative.complete")

    # These same-length serialized field edits produce typed states that could
    # not pass the full public constructor.  Replaying that constructor in the
    # V3 validator is the discriminator; saved state/source hashes still match.
    invalid_admission = v3_serialization_replace_ascii(
        chain.realization_state, "declared_consistent", "invalid_admissionxx")
    @test invalid_admission.contract_admission === :invalid_admissionxx
    @test v3_fields_equal_except(chain.realization_state, invalid_admission,
        :contract_admission)
    invalid_admission_result =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(chain.transport,
            chain.recheck, chain.parent, chain.expected, nothing,
            invalid_admission, chain.control_payload, chain.control_state,
            chain.binding_key)
    @test invalid_admission_result.status === :fail_closed
    @test :realization_state_invalid in invalid_admission_result.errors
    invalid_physical = v3_serialization_replace_ascii(
        chain.realization_state, "unknown", "invalid")
    @test invalid_physical.physical_resolution === :invalid
    @test v3_fields_equal_except(chain.realization_state, invalid_physical,
        :physical_resolution)
    invalid_physical_result =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(chain.transport,
            chain.recheck, chain.parent, chain.expected, nothing,
            invalid_physical, chain.control_payload, chain.control_state,
            chain.binding_key)
    @test invalid_physical_result.status === :fail_closed
    @test :realization_state_invalid in invalid_physical_result.errors
    invalid_control = v3_serialization_replace_ascii(
        chain.control_state, "declared_consistent", "invalid_admissionxx")
    @test invalid_control.contract_admission === :invalid_admissionxx
    @test v3_fields_equal_except(chain.control_state, invalid_control,
        :contract_admission)
    invalid_control_result =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(chain.transport,
            chain.recheck, chain.parent, chain.expected, nothing,
            chain.realization_state, nothing, invalid_control,
            chain.binding_key)
    @test invalid_control_result.status === :fail_closed
    @test :control_state_invalid in invalid_control_result.errors
    @test_throws ArgumentError V3_G.G3RealizationSourceStateV1(
        chain.realization_state.key, chain.realization_state.payload,
        chain.realization_state.source_content_hash,
        chain.realization_state.initial_source_content_hash, :present,
        "forged-present-absence",
        V3_G.digest256_text("forged-present-absence"), (),
        chain.realization_state.initial_state_hash,
        chain.realization_state.state_hash,
        chain.realization_state.operation_hash,
        chain.realization_state.contract_admission,
        chain.realization_state.physical_resolution,
        chain.realization_state.operation_history)
    v3_trace("focused.intrinsic_negatives.complete")

    # Intrinsic state validation does not depend on present G3 material.  A
    # corrupt state still fails before source/bridge absence is classified.
    absent_g3 = V3_G.VNextT0LocalAbsentDeclarationV1(:G3,
        chain.transport.candidate_ref, :missing_material, :terminal_deferred)
    absent_admission = V3_G.vnext_declaration_transport_local_v1(
        chain.transport.candidate_ref,
        (chain.declarations[1], chain.declarations[2], absent_g3),
        chain.transport.children, ();
        frozen_contexts=Main._T0L_CONTEXTS)
    @test absent_admission.status === :valid
    absent_transport = absent_admission.transport
    absent_recheck = V3_G.vnext_declaration_authority_recheck_local_v1(
        V3_G.VNextAuthorityRecheckLocalInputV1(
            chain.transport.candidate_ref, absent_transport,
            absent_transport.declarations))
    @test absent_recheck.status === :typed_absent
    absent_with_invalid_state =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(absent_transport,
            absent_recheck, chain.parent, nothing, nothing,
            invalid_admission, nothing, nothing, nothing)
    @test absent_with_invalid_state.status === :fail_closed
    @test :realization_state_invalid in absent_with_invalid_state.errors

    # The payload/state join is intrinsic to the pair.  Same-candidate values
    # with independently valid but crossed source refs fail even without G3.
    alternate_control = v3_control_material(chain.transport.candidate_ref,
        chain.recheck.output.g3; variant=true)
    @test alternate_control.payload.key == chain.control_state.key
    @test !V3_G._g3ce_payload_ref_equal(
        V3_G.g3_control_source_payload_ref_v1(alternate_control.payload),
        chain.control_state.source_payload_ref)
    absent_with_crossed_control =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(absent_transport,
            absent_recheck, chain.parent, nothing, nothing, nothing,
            alternate_control.payload, chain.control_state, nothing)
    @test absent_with_crossed_control.status === :fail_closed
    @test :control_payload_ref_mismatch in absent_with_crossed_control.errors

    # Known contradictory T0 bytes/hash fail before an unrelated missing V3
    # bridge can classify the request as typed absent.
    tampered_transport = V3_G.VNextT0LocalTransportV1(
        chain.transport.candidate_ref, chain.transport.declarations,
        chain.transport.children, chain.transport.feedback,
        V3_G.digest256_text("tampered-t0-bundle"), chain.transport.status,
        chain.transport.errors, chain.transport.gaps)
    contradiction = V3_G.prepare_vnext_t2_concrete_source_witness_v3(
        tampered_transport, chain.recheck, chain.parent, nothing, nothing,
        nothing, nothing, nothing, nothing)
    @test contradiction.status === :fail_closed
    @test :t0_bundle_hash_mismatch in contradiction.errors

    # A valid but foreign realization state is an observable contradiction;
    # a missing bridge cannot downgrade it to typed absence.
    foreign_candidate = V3_G.QualifiedRefV1(
        "fusionconceptai://candidate/vnext-t2-source-foreign-child", "v5")
    foreign_chain = v3_chain(candidate=foreign_candidate)
    foreign_realization = foreign_chain.realization_state
    child_contradiction =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(chain.transport,
            chain.recheck, chain.parent, chain.expected, nothing,
            foreign_realization, chain.control_payload, chain.control_state,
            chain.binding_key)
    @test child_contradiction.status === :fail_closed
    @test :realization_candidate_mismatch in child_contradiction.errors
    bridge_contradiction =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(chain.transport,
            chain.recheck, chain.parent, chain.expected, foreign_chain.bridge,
            chain.realization_state, chain.control_payload,
            chain.control_state, nothing)
    @test bridge_contradiction.status === :fail_closed
    @test :g3_bridge_projection_candidate_mismatch in
        bridge_contradiction.errors
    @test :g3_bridge_binding_candidate_mismatch in bridge_contradiction.errors
    foreign_expected = V3_G.vnext_g3_binding_expected_commitment_v1(
        chain.transport.candidate_ref,
        V3_G.digest256_text("foreign-expected-bundle"),
        chain.expected.g3_declaration_ref,
        chain.expected.g3_declaration_identity_hash,
        chain.expected.realization, chain.expected.control)
    expected_contradiction =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(chain.transport,
            chain.recheck, chain.parent, foreign_expected, nothing,
            chain.realization_state, chain.control_payload,
            chain.control_state, chain.binding_key)
    @test expected_contradiction.status === :fail_closed
    @test :g3_expected_bundle_hash_mismatch in expected_contradiction.errors
    v3_trace("focused.optional_precedence.complete")

    # A separately rebuilt valid source does not validate against the old
    # independent inputs, even though all its own hashes are fresh.
    foreign = v3_chain(g2_variant=true)
    @test foreign.built.status === :source_ready
    @test foreign.witness.witness_hash != witness.witness_hash
    crossed = v3_validate(chain, foreign.witness)
    @test crossed.status === :fail_closed
    @test :witness_independent_reconstruction_mismatch in crossed.errors

    # Recomputed duplicated G2 candidate envelope attack.
    old_env = witness.g2.candidate_envelope
    forged_env = V3_G.VNextT0LocalG2CandidateEnvelopeV1(
        old_env.candidate_ref, old_env.contract_ref, old_env.source_ref,
        V3_G.digest256_text("forged-g2-envelope-source"))
    forged_g2 = V3_G.VNextT2ConcreteG2DeclarationV3(witness.g2.record,
        forged_env, witness.g2.declaration, witness.g2.identity)
    forged_g2_witness = v3_rehash_witness(witness; g2=forged_g2)
    @test forged_g2_witness.witness_hash ==
        V3_G.vnext_t2_concrete_source_witness_hash_v3(forged_g2_witness)
    @test v3_validate(chain, forged_g2_witness).status === :fail_closed

    # A changed actual feedback link is rejected after all enclosing hashes
    # are recomputed; keeping the old link_hash is not the attack model here.
    first_link = first(witness.feedback.binding_links)
    changed_link = V3_G.G3BindingLinkV1(first_link.link_id,
        first_link.target_layer, first_link.target_path * "/foreign",
        first_link.quantity, first_link.unit, first_link.direction,
        first_link.sign, first_link.source_id, first_link.owner_scope,
        first_link.authority)
    changed_links = (changed_link, Base.tail(witness.feedback.binding_links)...)
    forged_feedback = v3_rehash_feedback(witness.feedback;
        binding_links=changed_links)
    forged_feedback_witness = v3_rehash_witness(witness;
        feedback=forged_feedback)
    @test forged_feedback_witness.feedback.identity_hash ==
        V3_G.canonical_hash(V3_G._vnext_t2_v3_feedback_body(
            forged_feedback_witness.feedback))
    @test v3_validate(chain, forged_feedback_witness).status === :fail_closed

    # A different fully valid realization child cannot be paired with the old
    # independently expected child commitment.
    foreign_children = v3_rehash_children(witness.children;
        realization_state=coherent.realization_state)
    forged_child_witness = v3_rehash_witness(witness;
        children=foreign_children)
    @test forged_child_witness.children.identity_hash ==
        V3_G.canonical_hash(V3_G._vnext_t2_v3_children_body(
            forged_child_witness.children))
    @test v3_validate(chain, forged_child_witness).status === :fail_closed

    # Axes and top-level status remain observed fields after recomputation.
    axes = witness.g1.identity.source_axes
    changed_axes = (V3_G.QualifiedRefV1(axes[1].id, "v2"),
        axes[2], axes[3], axes[4])
    changed_identity = v3_rehash_layer_identity(witness.g1.identity;
        source_axes=changed_axes)
    changed_g1 = V3_G.VNextT2ConcreteG1DeclarationV3(witness.g1.record,
        witness.g1.declaration, changed_identity)
    forged_axis_witness = v3_rehash_witness(witness; g1=changed_g1)
    @test v3_validate(chain, forged_axis_witness).status === :fail_closed
    forged_status_witness = v3_rehash_witness(witness;
        source_status=:formal_accepted, formal_node_accepted=true)
    @test v3_validate(chain, forged_status_witness).status === :fail_closed
    v3_trace("focused.recomputed_tamper.complete")

    # The canonical carrier is stable across a typed Serialization reload and
    # still requires the independent current inputs for validation.
    buffer = IOBuffer()
    Serialization.serialize(buffer, witness)
    seekstart(buffer)
    restored = Serialization.deserialize(buffer)
    @test V3_G.vnext_t2_concrete_source_witness_canonical_bytes_v3(restored) ==
        V3_G.vnext_t2_concrete_source_witness_canonical_bytes_v3(witness)
    @test V3_G.revalidate_vnext_t2_concrete_source_witness_v3(restored,
        chain.transport, chain.recheck, chain.parent, chain.expected,
        chain.bridge, chain.realization_state, chain.control_payload,
        chain.control_state, chain.binding_key).status === :source_ready
    v3_trace("focused.serialization.complete")
end
v3_trace("focused.testset.end")
