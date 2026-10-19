include(joinpath(@__DIR__, "shard_test_helpers.jl"))

const V3_SHARD_SCENARIOS = (
    :native_baseline_coupling,
    :edited_state_typed_reload,
    :intrinsic_absence_precedence,
    :foreign_authority_joins,
    :recomputed_source_layer,
    :feedback_child_serialization,
)

function v3_scenario_native_baseline_coupling()
    chain = v3_chain()
    # V3_ASSERTION_BEGIN A001
    v3_site!(:A001)
    @test chain.built.status === :source_ready
    # V3_ASSERTION_END A001
    # V3_ASSERTION_BEGIN A002
    v3_site!(:A002)
    @test chain.built.source_ready
    # V3_ASSERTION_END A002
    witness = chain.witness
    # V3_ASSERTION_BEGIN A003
    v3_site!(:A003)
    @test witness isa V3_G.VNextT2ConcreteSourceWitnessV3
    # V3_ASSERTION_END A003
    # V3_ASSERTION_BEGIN A004
    v3_site!(:A004)
    @test !isempty(V3_G.canonical_json(witness))
    # V3_ASSERTION_END A004
    # V3_ASSERTION_BEGIN A005
    v3_site!(:A005)
    @test witness.witness_hash ==
        V3_G.vnext_t2_concrete_source_witness_hash_v3(witness)
    # V3_ASSERTION_END A005

    # V3_ASSERTION_BEGIN A006
    v3_site!(:A006)
    @test witness.g1.declaration isa V3_G.G1DiffusionDeclarationV1
    # V3_ASSERTION_END A006
    # V3_ASSERTION_BEGIN A007
    v3_site!(:A007)
    @test witness.g2.declaration isa V3_G.G2MBDeclarationV1
    # V3_ASSERTION_END A007
    # V3_ASSERTION_BEGIN A008
    v3_site!(:A008)
    @test witness.g3.declaration isa V3_G.G3SFDeclarationV1
    # V3_ASSERTION_END A008
    # V3_ASSERTION_BEGIN A009
    v3_site!(:A009)
    @test witness.g2.candidate_envelope.candidate_ref == witness.candidate_ref
    # V3_ASSERTION_END A009
    # V3_ASSERTION_BEGIN A010
    v3_site!(:A010)
    @test witness.g2.declaration.source.candidate_ref isa V3_G.GenomeContractRef
    # V3_ASSERTION_END A010
    # V3_ASSERTION_BEGIN A011
    v3_site!(:A011)
    @test witness.g2.candidate_envelope.contract_ref ==
        witness.g2.declaration.source.candidate_ref
    # V3_ASSERTION_END A011
    # V3_ASSERTION_BEGIN A012
    v3_site!(:A012)
    @test witness.g2.candidate_envelope.candidate_ref !=
        witness.g2.declaration.source.candidate_ref
    # V3_ASSERTION_END A012

    for layer in (:g1, :g2, :g3)
        carrier = getproperty(witness, layer)
        # V3_ASSERTION_BEGIN A013
        v3_site!(:A013)
        @test Vector{UInt8}(codeunits(V3_G.canonical_json(carrier.declaration))) ==
            carrier.record.declaration_bytes.bytes
        # V3_ASSERTION_END A013
        # V3_ASSERTION_BEGIN A014
        v3_site!(:A014)
        @test carrier.record.factory_receipt.factory_result.declaration_bytes.bytes ==
            carrier.record.declaration_bytes.bytes
        # V3_ASSERTION_END A014
        # V3_ASSERTION_BEGIN A015
        v3_site!(:A015)
        @test carrier.identity.source_file_sha256 == carrier.record.source_bytes.sha256
        # V3_ASSERTION_END A015
        # V3_ASSERTION_BEGIN A016
        v3_site!(:A016)
        @test carrier.identity.source_axes == carrier.record.axes
        # V3_ASSERTION_END A016
        # V3_ASSERTION_BEGIN A017
        v3_site!(:A017)
        @test carrier.identity.factory_axes == carrier.record.factory_receipt.factory_axes
        # V3_ASSERTION_END A017
        # V3_ASSERTION_BEGIN A018
        v3_site!(:A018)
        @test carrier.identity.identity_hash ==
            V3_G.canonical_hash(V3_G._vnext_t2_v3_layer_identity_body(
                carrier.identity))
        # V3_ASSERTION_END A018
    end

    # V3_ASSERTION_BEGIN A019
    v3_site!(:A019)
    @test witness.children.realization_state.payload.body ==
        chain.realization_state.payload.body
    # V3_ASSERTION_END A019
    # V3_ASSERTION_BEGIN A020
    v3_site!(:A020)
    @test witness.children.control_payload.body == chain.control_payload.body
    # V3_ASSERTION_END A020
    # V3_ASSERTION_BEGIN A021
    v3_site!(:A021)
    @test witness.children.control_state.editable_body ==
        chain.control_state.editable_body
    # V3_ASSERTION_END A021
    # V3_ASSERTION_BEGIN A022
    v3_site!(:A022)
    @test witness.children.binding_state.editable_body ==
        chain.bridge.binding_state.editable_body
    # V3_ASSERTION_END A022
    # V3_ASSERTION_BEGIN A023
    v3_site!(:A023)
    @test witness.feedback.g3_targets == witness.g3.declaration.feedback_targets
    # V3_ASSERTION_END A023
    # V3_ASSERTION_BEGIN A024
    v3_site!(:A024)
    @test witness.feedback.binding_links ==
        witness.children.binding_state.source_payload.initial_links
    # V3_ASSERTION_END A024
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
    # V3_ASSERTION_BEGIN A025
    v3_site!(:A025)
    @test recheck_projection == expected_recheck_projection
    # V3_ASSERTION_END A025
    # V3_ASSERTION_BEGIN A026
    v3_site!(:A026)
    @test witness.manifest.t0_recheck_output_hash ==
        V3_G.canonical_hash(expected_recheck_projection)
    # V3_ASSERTION_END A026
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
    # V3_ASSERTION_BEGIN A027
    v3_site!(:A027)
    @test all(V3_G.canonical_hash(mutation) !=
        witness.manifest.t0_recheck_output_hash
        for mutation in recheck_projection_mutations)
    # V3_ASSERTION_END A027

    # V3_ASSERTION_BEGIN A028
    v3_site!(:A028)
    @test witness.formal_t1.status === :typed_absent
    # V3_ASSERTION_END A028
    # V3_ASSERTION_BEGIN A029
    v3_site!(:A029)
    @test witness.formal_t1.formal_t1_accepted == false
    # V3_ASSERTION_END A029
    # V3_ASSERTION_BEGIN A030
    v3_site!(:A030)
    @test witness.formal_t1.package_hash === nothing
    # V3_ASSERTION_END A030
    # V3_ASSERTION_BEGIN A031
    v3_site!(:A031)
    @test witness.formal_t1.semantic_identity_hash === nothing
    # V3_ASSERTION_END A031
    # V3_ASSERTION_BEGIN A032
    v3_site!(:A032)
    @test witness.formal_t1.bundle_hash === nothing
    # V3_ASSERTION_END A032
    # V3_ASSERTION_BEGIN A033
    v3_site!(:A033)
    @test witness.formal_t1.reload_adapter_receipt_hash === nothing
    # V3_ASSERTION_END A033
    # V3_ASSERTION_BEGIN A034
    v3_site!(:A034)
    @test witness.formal_t1.formal_consumer_counts ==
        (e0=0, gi1a=0, e1=0, e2=0, n10=0)
    # V3_ASSERTION_END A034
    # V3_ASSERTION_BEGIN A035
    v3_site!(:A035)
    @test witness.formal_node_accepted == false
    # V3_ASSERTION_END A035
    # V3_ASSERTION_BEGIN A036
    v3_site!(:A036)
    @test v3_validate(chain).status === :source_ready
    # V3_ASSERTION_END A036

    # The historical fixture is materializable source, but its explicitly
    # associated G3 child contradicts the 3/4,1/8,1/8 source law and units.
    # V3_ASSERTION_BEGIN A037
    v3_site!(:A037)
    @test witness.coupling.status === :fail_closed
    # V3_ASSERTION_END A037
    # V3_ASSERTION_BEGIN A038
    v3_site!(:A038)
    @test :g3_source_law_realization_allocation_mismatch in witness.coupling.errors
    # V3_ASSERTION_END A038
    # V3_ASSERTION_BEGIN A039
    v3_site!(:A039)
    @test :g3_source_law_realization_unit_mismatch in witness.coupling.errors
    # V3_ASSERTION_END A039
    coherent = v3_chain(coherent_g3_child=true)
    # V3_ASSERTION_BEGIN A040
    v3_site!(:A040)
    @test coherent.built.status === :source_ready
    # V3_ASSERTION_END A040
    # V3_ASSERTION_BEGIN A041
    v3_site!(:A041)
    @test coherent.witness.coupling.status === :declared_consistent
    # V3_ASSERTION_END A041
    # V3_ASSERTION_BEGIN A042
    v3_site!(:A042)
    @test isempty(coherent.witness.coupling.errors)
    # V3_ASSERTION_END A042
    # V3_ASSERTION_BEGIN A043
    v3_site!(:A043)
    @test coherent.witness.coupling.resolution === :terminal_deferred
    # V3_ASSERTION_END A043
    nothing
end

function v3_scenario_edited_state_typed_reload()
    chain = v3_chain()
    witness = chain.witness

    # A real source-payload replacement preserves the frozen initial identity,
    # binds the current state hash, and keeps its operation/receipt as external
    # replay evidence.  The witness states that it does not carry the full op.
    edited = v3_chain(edited_realization=true)
    # V3_ASSERTION_BEGIN A044
    v3_site!(:A044)
    @test edited.realization_edit_operation isa
        V3_G.G3RealizationReplaceSourcePayloadV1
    # V3_ASSERTION_END A044
    # V3_ASSERTION_BEGIN A045
    v3_site!(:A045)
    @test edited.realization_edit_receipt isa V3_G.G3RealizationOperationReceiptV1
    # V3_ASSERTION_END A045
    # V3_ASSERTION_BEGIN A046
    v3_site!(:A046)
    @test edited.realization_state.initial_state_hash ==
        edited.realization_initial_state.initial_state_hash
    # V3_ASSERTION_END A046
    # V3_ASSERTION_BEGIN A047
    v3_site!(:A047)
    @test edited.realization_state.initial_source_content_hash ==
        edited.realization_initial_state.source_content_hash
    # V3_ASSERTION_END A047
    # V3_ASSERTION_BEGIN A048
    v3_site!(:A048)
    @test edited.realization_state.source_content_hash !=
        edited.realization_state.initial_source_content_hash
    # V3_ASSERTION_END A048
    # V3_ASSERTION_BEGIN A049
    v3_site!(:A049)
    @test edited.realization_state.operation_history == ("v3-realization-edit",)
    # V3_ASSERTION_END A049
    # V3_ASSERTION_BEGIN A050
    v3_site!(:A050)
    @test edited.bridge.projection.realization.state_hash ==
        edited.realization_state.state_hash
    # V3_ASSERTION_END A050
    # V3_ASSERTION_BEGIN A051
    v3_site!(:A051)
    @test edited.expected.realization.state_hash ==
        edited.realization_state.state_hash
    # V3_ASSERTION_END A051
    # V3_ASSERTION_BEGIN A052
    v3_site!(:A052)
    @test edited.built.status === :source_ready
    # V3_ASSERTION_END A052
    # V3_ASSERTION_BEGIN A053
    v3_site!(:A053)
    @test v3_validate(edited).status === :source_ready
    # V3_ASSERTION_END A053
    # V3_ASSERTION_BEGIN A054
    v3_site!(:A054)
    @test :realization_full_operation_replay_evidence_not_carried in
        edited.witness.gaps
    # V3_ASSERTION_END A054

    # Serialization bypasses inner constructors.  The public bridge therefore
    # recomputes the independently supplied expected commitment before granting
    # authority, rather than trusting the deserialized saved hash.
    forged_expected_hash = V3_G.digest256_text("forged-expected-commitment")
    forged_expected = v3_serialization_replace_ascii(chain.expected,
        chain.expected.commitment_hash.value, forged_expected_hash.value)
    # V3_ASSERTION_BEGIN A055
    v3_site!(:A055)
    @test forged_expected.commitment_hash == forged_expected_hash
    # V3_ASSERTION_END A055
    # V3_ASSERTION_BEGIN A056
    v3_site!(:A056)
    @test v3_fields_equal_except(chain.expected, forged_expected,
        :commitment_hash)
    # V3_ASSERTION_END A056
    # V3_ASSERTION_BEGIN A057
    v3_site!(:A057)
    @test forged_expected.commitment_hash !=
        V3_G.vnext_g3_binding_expected_commitment_hash_v1(forged_expected)
    # V3_ASSERTION_END A057
    forged_bridge = V3_G.vnext_t2_concrete_g3_bridge_v3(chain.recheck,
        forged_expected, chain.realization_state, chain.control_payload,
        chain.control_state, chain.binding_key;
        initial_links=chain.witness.feedback.binding_links)
    # V3_ASSERTION_BEGIN A058
    v3_site!(:A058)
    @test forged_bridge.status === :fail_closed
    # V3_ASSERTION_END A058
    # V3_ASSERTION_BEGIN A059
    v3_site!(:A059)
    @test :expected_commitment_hash_mismatch in forged_bridge.errors
    # V3_ASSERTION_END A059
    nothing
end

function v3_scenario_intrinsic_absence_precedence()
    chain = v3_chain()
    witness = chain.witness

    # These same-length serialized field edits produce typed states that could
    # not pass the full public constructor.  Replaying that constructor in the
    # V3 validator is the discriminator; saved state/source hashes still match.
    invalid_admission = v3_serialization_replace_ascii(
        chain.realization_state, "declared_consistent", "invalid_admissionxx")
    # V3_ASSERTION_BEGIN A060
    v3_site!(:A060)
    @test invalid_admission.contract_admission === :invalid_admissionxx
    # V3_ASSERTION_END A060
    # V3_ASSERTION_BEGIN A061
    v3_site!(:A061)
    @test v3_fields_equal_except(chain.realization_state, invalid_admission,
        :contract_admission)
    # V3_ASSERTION_END A061
    invalid_admission_result =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(chain.transport,
            chain.recheck, chain.parent, chain.expected, nothing,
            invalid_admission, chain.control_payload, chain.control_state,
            chain.binding_key)
    # V3_ASSERTION_BEGIN A062
    v3_site!(:A062)
    @test invalid_admission_result.status === :fail_closed
    # V3_ASSERTION_END A062
    # V3_ASSERTION_BEGIN A063
    v3_site!(:A063)
    @test :realization_state_invalid in invalid_admission_result.errors
    # V3_ASSERTION_END A063
    invalid_physical = v3_serialization_replace_ascii(
        chain.realization_state, "unknown", "invalid")
    # V3_ASSERTION_BEGIN A064
    v3_site!(:A064)
    @test invalid_physical.physical_resolution === :invalid
    # V3_ASSERTION_END A064
    # V3_ASSERTION_BEGIN A065
    v3_site!(:A065)
    @test v3_fields_equal_except(chain.realization_state, invalid_physical,
        :physical_resolution)
    # V3_ASSERTION_END A065
    invalid_physical_result =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(chain.transport,
            chain.recheck, chain.parent, chain.expected, nothing,
            invalid_physical, chain.control_payload, chain.control_state,
            chain.binding_key)
    # V3_ASSERTION_BEGIN A066
    v3_site!(:A066)
    @test invalid_physical_result.status === :fail_closed
    # V3_ASSERTION_END A066
    # V3_ASSERTION_BEGIN A067
    v3_site!(:A067)
    @test :realization_state_invalid in invalid_physical_result.errors
    # V3_ASSERTION_END A067
    invalid_control = v3_serialization_replace_ascii(
        chain.control_state, "declared_consistent", "invalid_admissionxx")
    # V3_ASSERTION_BEGIN A068
    v3_site!(:A068)
    @test invalid_control.contract_admission === :invalid_admissionxx
    # V3_ASSERTION_END A068
    # V3_ASSERTION_BEGIN A069
    v3_site!(:A069)
    @test v3_fields_equal_except(chain.control_state, invalid_control,
        :contract_admission)
    # V3_ASSERTION_END A069
    invalid_control_result =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(chain.transport,
            chain.recheck, chain.parent, chain.expected, nothing,
            chain.realization_state, nothing, invalid_control,
            chain.binding_key)
    # V3_ASSERTION_BEGIN A070
    v3_site!(:A070)
    @test invalid_control_result.status === :fail_closed
    # V3_ASSERTION_END A070
    # V3_ASSERTION_BEGIN A071
    v3_site!(:A071)
    @test :control_state_invalid in invalid_control_result.errors
    # V3_ASSERTION_END A071
    # V3_ASSERTION_BEGIN A072
    v3_site!(:A072)
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
    # V3_ASSERTION_END A072

    # Intrinsic state validation does not depend on present G3 material.  A
    # corrupt state still fails before source/bridge absence is classified.
    absent_g3 = V3_G.VNextT0LocalAbsentDeclarationV1(:G3,
        chain.transport.candidate_ref, :missing_material, :terminal_deferred)
    absent_admission = V3_G.vnext_declaration_transport_local_v1(
        chain.transport.candidate_ref,
        (chain.declarations[1], chain.declarations[2], absent_g3),
        chain.transport.children, ();
        frozen_contexts=Main._T0L_CONTEXTS)
    # V3_ASSERTION_BEGIN A073
    v3_site!(:A073)
    @test absent_admission.status === :valid
    # V3_ASSERTION_END A073
    absent_transport = absent_admission.transport
    absent_recheck = V3_G.vnext_declaration_authority_recheck_local_v1(
        V3_G.VNextAuthorityRecheckLocalInputV1(
            chain.transport.candidate_ref, absent_transport,
            absent_transport.declarations))
    # V3_ASSERTION_BEGIN A074
    v3_site!(:A074)
    @test absent_recheck.status === :typed_absent
    # V3_ASSERTION_END A074
    absent_with_invalid_state =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(absent_transport,
            absent_recheck, chain.parent, nothing, nothing,
            invalid_admission, nothing, nothing, nothing)
    # V3_ASSERTION_BEGIN A075
    v3_site!(:A075)
    @test absent_with_invalid_state.status === :fail_closed
    # V3_ASSERTION_END A075
    # V3_ASSERTION_BEGIN A076
    v3_site!(:A076)
    @test :realization_state_invalid in absent_with_invalid_state.errors
    # V3_ASSERTION_END A076

    # The payload/state join is intrinsic to the pair.  Same-candidate values
    # with independently valid but crossed source refs fail even without G3.
    alternate_control = v3_control_material(chain.transport.candidate_ref,
        chain.recheck.output.g3; variant=true)
    # V3_ASSERTION_BEGIN A077
    v3_site!(:A077)
    @test alternate_control.payload.key == chain.control_state.key
    # V3_ASSERTION_END A077
    # V3_ASSERTION_BEGIN A078
    v3_site!(:A078)
    @test !V3_G._g3ce_payload_ref_equal(
        V3_G.g3_control_source_payload_ref_v1(alternate_control.payload),
        chain.control_state.source_payload_ref)
    # V3_ASSERTION_END A078
    absent_with_crossed_control =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(absent_transport,
            absent_recheck, chain.parent, nothing, nothing, nothing,
            alternate_control.payload, chain.control_state, nothing)
    # V3_ASSERTION_BEGIN A079
    v3_site!(:A079)
    @test absent_with_crossed_control.status === :fail_closed
    # V3_ASSERTION_END A079
    # V3_ASSERTION_BEGIN A080
    v3_site!(:A080)
    @test :control_payload_ref_mismatch in absent_with_crossed_control.errors
    # V3_ASSERTION_END A080

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
    # V3_ASSERTION_BEGIN A081
    v3_site!(:A081)
    @test contradiction.status === :fail_closed
    # V3_ASSERTION_END A081
    # V3_ASSERTION_BEGIN A082
    v3_site!(:A082)
    @test :t0_bundle_hash_mismatch in contradiction.errors
    # V3_ASSERTION_END A082
    nothing
end

function v3_scenario_foreign_authority_joins()
    chain = v3_chain()
    witness = chain.witness

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
    # V3_ASSERTION_BEGIN A083
    v3_site!(:A083)
    @test child_contradiction.status === :fail_closed
    # V3_ASSERTION_END A083
    # V3_ASSERTION_BEGIN A084
    v3_site!(:A084)
    @test :realization_candidate_mismatch in child_contradiction.errors
    # V3_ASSERTION_END A084
    bridge_contradiction =
        V3_G.prepare_vnext_t2_concrete_source_witness_v3(chain.transport,
            chain.recheck, chain.parent, chain.expected, foreign_chain.bridge,
            chain.realization_state, chain.control_payload,
            chain.control_state, nothing)
    # V3_ASSERTION_BEGIN A085
    v3_site!(:A085)
    @test bridge_contradiction.status === :fail_closed
    # V3_ASSERTION_END A085
    # V3_ASSERTION_BEGIN A086
    v3_site!(:A086)
    @test :g3_bridge_projection_candidate_mismatch in
        bridge_contradiction.errors
    # V3_ASSERTION_END A086
    # V3_ASSERTION_BEGIN A087
    v3_site!(:A087)
    @test :g3_bridge_binding_candidate_mismatch in bridge_contradiction.errors
    # V3_ASSERTION_END A087
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
    # V3_ASSERTION_BEGIN A088
    v3_site!(:A088)
    @test expected_contradiction.status === :fail_closed
    # V3_ASSERTION_END A088
    # V3_ASSERTION_BEGIN A089
    v3_site!(:A089)
    @test :g3_expected_bundle_hash_mismatch in expected_contradiction.errors
    # V3_ASSERTION_END A089
    nothing
end

function v3_scenario_recomputed_source_layer()
    chain = v3_chain()
    witness = chain.witness

    # A separately rebuilt valid source does not validate against the old
    # independent inputs, even though all its own hashes are fresh.
    foreign = v3_chain(g2_variant=true)
    # V3_ASSERTION_BEGIN A090
    v3_site!(:A090)
    @test foreign.built.status === :source_ready
    # V3_ASSERTION_END A090
    # V3_ASSERTION_BEGIN A091
    v3_site!(:A091)
    @test foreign.witness.witness_hash != witness.witness_hash
    # V3_ASSERTION_END A091
    crossed = v3_validate(chain, foreign.witness)
    # V3_ASSERTION_BEGIN A092
    v3_site!(:A092)
    @test crossed.status === :fail_closed
    # V3_ASSERTION_END A092
    # V3_ASSERTION_BEGIN A093
    v3_site!(:A093)
    @test :witness_independent_reconstruction_mismatch in crossed.errors
    # V3_ASSERTION_END A093

    # Recomputed duplicated G2 candidate envelope attack.
    old_env = witness.g2.candidate_envelope
    forged_env = V3_G.VNextT0LocalG2CandidateEnvelopeV1(
        old_env.candidate_ref, old_env.contract_ref, old_env.source_ref,
        V3_G.digest256_text("forged-g2-envelope-source"))
    forged_g2 = V3_G.VNextT2ConcreteG2DeclarationV3(witness.g2.record,
        forged_env, witness.g2.declaration, witness.g2.identity)
    forged_g2_witness = v3_rehash_witness(witness; g2=forged_g2)
    # V3_ASSERTION_BEGIN A094
    v3_site!(:A094)
    @test forged_g2_witness.witness_hash ==
        V3_G.vnext_t2_concrete_source_witness_hash_v3(forged_g2_witness)
    # V3_ASSERTION_END A094
    # V3_ASSERTION_BEGIN A095
    v3_site!(:A095)
    @test v3_validate(chain, forged_g2_witness).status === :fail_closed
    # V3_ASSERTION_END A095

    # Axes and top-level status remain observed fields after recomputation.
    axes = witness.g1.identity.source_axes
    changed_axes = (V3_G.QualifiedRefV1(axes[1].id, "v2"),
        axes[2], axes[3], axes[4])
    changed_identity = v3_rehash_layer_identity(witness.g1.identity;
        source_axes=changed_axes)
    changed_g1 = V3_G.VNextT2ConcreteG1DeclarationV3(witness.g1.record,
        witness.g1.declaration, changed_identity)
    forged_axis_witness = v3_rehash_witness(witness; g1=changed_g1)
    # V3_ASSERTION_BEGIN A100
    v3_site!(:A100)
    @test v3_validate(chain, forged_axis_witness).status === :fail_closed
    # V3_ASSERTION_END A100
    forged_status_witness = v3_rehash_witness(witness;
        source_status=:formal_accepted, formal_node_accepted=true)
    # V3_ASSERTION_BEGIN A101
    v3_site!(:A101)
    @test v3_validate(chain, forged_status_witness).status === :fail_closed
    # V3_ASSERTION_END A101
    nothing
end

function v3_scenario_feedback_child_serialization()
    chain = v3_chain()
    witness = chain.witness

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
    # V3_ASSERTION_BEGIN A096
    v3_site!(:A096)
    @test forged_feedback_witness.feedback.identity_hash ==
        V3_G.canonical_hash(V3_G._vnext_t2_v3_feedback_body(
            forged_feedback_witness.feedback))
    # V3_ASSERTION_END A096
    # V3_ASSERTION_BEGIN A097
    v3_site!(:A097)
    @test v3_validate(chain, forged_feedback_witness).status === :fail_closed
    # V3_ASSERTION_END A097

    coherent = v3_chain(coherent_g3_child=true)

    # A different fully valid realization child cannot be paired with the old
    # independently expected child commitment.
    foreign_children = v3_rehash_children(witness.children;
        realization_state=coherent.realization_state)
    forged_child_witness = v3_rehash_witness(witness;
        children=foreign_children)
    # V3_ASSERTION_BEGIN A098
    v3_site!(:A098)
    @test forged_child_witness.children.identity_hash ==
        V3_G.canonical_hash(V3_G._vnext_t2_v3_children_body(
            forged_child_witness.children))
    # V3_ASSERTION_END A098
    # V3_ASSERTION_BEGIN A099
    v3_site!(:A099)
    @test v3_validate(chain, forged_child_witness).status === :fail_closed
    # V3_ASSERTION_END A099

    # The canonical carrier is stable across a typed Serialization reload and
    # still requires the independent current inputs for validation.
    buffer = IOBuffer()
    Serialization.serialize(buffer, witness)
    seekstart(buffer)
    restored = Serialization.deserialize(buffer)
    # V3_ASSERTION_BEGIN A102
    v3_site!(:A102)
    @test V3_G.vnext_t2_concrete_source_witness_canonical_bytes_v3(restored) ==
        V3_G.vnext_t2_concrete_source_witness_canonical_bytes_v3(witness)
    # V3_ASSERTION_END A102
    # V3_ASSERTION_BEGIN A103
    v3_site!(:A103)
    @test V3_G.revalidate_vnext_t2_concrete_source_witness_v3(restored,
        chain.transport, chain.recheck, chain.parent, chain.expected,
        chain.bridge, chain.realization_state, chain.control_payload,
        chain.control_state, chain.binding_key).status === :source_ready
    # V3_ASSERTION_END A103
    nothing
end
length(ARGS) == 1 || error((:expected_one_shard_argument, ARGS))
scenario = Symbol(only(ARGS))
scenario in V3_SHARD_SCENARIOS || error((:unknown_shard_scenario, scenario))
empty!(V3_SHARD_EXECUTED_SITES)
driver_path = @__FILE__
ledger_path = joinpath(@__DIR__, "shard_coverage_ledger.json")
runner = getfield(Main, Symbol("v3_scenario_", String(scenario)))
v3_trace("shard." * String(scenario) * ".begin")
@testset "VNext T2 concrete native source witness V3 shard $(scenario)" begin
    runner()
    v3_finish_shard!(scenario, driver_path, ledger_path)
end
v3_trace("shard." * String(scenario) * ".complete")
