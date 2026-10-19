using Test
include(joinpath(@__DIR__, "fixture_helpers.jl"))

@testset "VNext T2 native bound input and real consumers" begin
    chain = t2_chain()
    @test chain.build.status === :prepared_not_executed
    @test chain.build.resolution === :terminal_deferred
    @test chain.build.input isa T2_G.VNextT2UP2BoundInputV2
    input = chain.build.input
    validation = T2_G.vnext_t2_up2_validate_input_v2(input)
    @test validation.status === :valid
    @test validation.reason === :none
    @test input.formal_gate.evidence_kind === :synthetic_local
    @test chain.formal_gate_verified === false
    @test chain.admission.status === :prepared_not_executed
    @test chain.admission.resolution === :terminal_deferred
    @test chain.admission.accepted === false
    @test chain.admission.claim_ceiling === :contract_only
    @test chain.t1_admission_invocation_count == 2
    @test chain.admission.package === chain.package
    @test chain.package.package_hash == chain.reloaded_package.package_hash
    @test input.package === chain.reloaded_package
    @test input.package.parent_commitments == chain.t1_parents ==
        input.formal_gate.parent_commitments
    source_parent_commitments = (
        input.witness.parent_bundle.g1.authority_commitment,
        input.witness.parent_bundle.g2.authority_commitment)
    @test source_parent_commitments != chain.t1_parents
    @test T2_G.verify_present_t0_local_parent_bundle_v1(
        input.witness.parent_bundle,
        T2_G.t0_parent_authority_commitment_v1(input.witness.g1.record),
        T2_G.t0_parent_authority_commitment_v1(input.witness.g2.record))
    @test input.witness.children.expected_commitment.commitment_hash ==
        input.formal_gate.g3_authority_commitment
    @test input.formal_gate.formal_t1_software_acceptance_receipt_hash ==
        chain.synthetic_software_acceptance_receipt_hash
    @test input.formal_gate.candidate_t1_admission_receipt_hash ==
        chain.synthetic_candidate_admission_receipt_hash
    recheck_projection = T2_G._vnext_t2_t1_recheck_projection_v2(
        chain.admission_input.t0_recheck)
    @test keys(recheck_projection) == (:domain, :status, :resolution,
        :accepted, :claim_ceiling, :output, :errors, :reasons,
        :prior_bundle_bytes, :prior_bundle_sha256)
    @test keys(recheck_projection.output) == (:domain, :candidate_ref,
        :bundle_hash, :declarations, :children, :feedback,
        :g3_children_deferred)
    @test recheck_projection.status == chain.admission_input.t0_recheck.status
    @test recheck_projection.output.declarations ==
        chain.admission_input.t0_recheck.output.declarations
    @test recheck_projection.prior_bundle_bytes ===
        chain.admission_input.t0_recheck.prior_bundle_bytes
    @test T2_G._vnext_t2_t1_recheck_projection_v2(nothing) ==
        (domain="vnext-t2-t1-recheck-v2/nothing",)
    typed_absent_output = T2_G.VNextAuthorityRecheckLocalV2TypedAbsent(
        chain.admission_input.candidate_ref,
        chain.admission_input.transport.bundle_hash,
        (:fixture_typed_absence,), true)
    typed_absent_projection =
        T2_G._vnext_t2_t1_recheck_output_projection_v2(typed_absent_output)
    @test keys(typed_absent_projection) == (:domain, :candidate_ref,
        :bundle_hash, :reasons, :g3_children_deferred)
    @test input.witness.g1.declaration isa T2_G.G1DiffusionDeclarationV1
    @test input.witness.g2.declaration isa T2_G.G2MBDeclarationV1
    @test input.witness.g3.declaration isa T2_G.G3SFDeclarationV1

    package_hash_before = input.package.package_hash
    result = T2_G.vnext_t2_rebind_identity_receipts_v2(chain.build)
    @test result.status === :complete_contract_receipts
    @test result.resolution === :terminal_deferred
    @test result.reason === :none
    @test result.committed
    @test result.ledger isa T2_G.VNextT2ReceiptLedgerV2
    @test result.ledger.input_hash == input.input_hash
    @test result.ledger.package_hash == input.package.package_hash
    @test Tuple(x.consumer_id for x in result.ledger.receipts) ==
        T2_G.VNEXT_T2_CONSUMER_ORDER_V2
    @test Tuple(x.invocation_count for x in result.ledger.receipts) ==
        (1, 1, 1, 1, 1)
    @test result.ledger.counts ==
        T2_G.VNextT2InvocationCountsV2(1, 1, 1, 1, 1, 0, 0, 0)
    @test result.attempted_trace.counts == result.ledger.counts
    @test Tuple(x.consumer_id for x in result.attempted_trace.events) ==
        T2_G.VNEXT_T2_CONSUMER_ORDER_V2
    @test result.ledger.receipts[3].status === :typed_absent
    @test result.ledger.receipts[3].resolution === :terminal_deferred
    @test result.ledger.receipts[4].status === :typed_absent
    @test result.ledger.receipts[4].resolution === :terminal_deferred
    @test result.ledger.accepted === false
    @test result.ledger.claim_ceiling === :contract_only
    @test :formal_gate_verified_false_synthetic_local in result.ledger.gaps
    @test input.package.package_hash == package_hash_before
    @test T2_G.vnext_t1_package_v2_validate(input.package) === nothing
end

@testset "VNext T2 N10 actual field projection and five attacks" begin
    chain = t2_chain()
    input = chain.build.input
    projection = T2_G.n10_identity_projection_from_a(input)
    validation = T2_G.vnext_t2_validate_identity_receipt_v2(projection)
    @test validation.status === :valid
    @test validation.resolution === :terminal_deferred
    @test Tuple(x.row_id for x in projection.fields) ==
        T2_G.VNEXT_T2_IDENTITY_ROW_IDS_V2
    @test projection.gaps == (:legacy_migration_provenance_absent,)
    @test projection.fields[1].original_value.value ==
        T2_G.g1_diffusion_schema_hash_v1()
    @test projection.fields[2].original_value.value ==
        T2_G.g2mb_canonicalization_hash_v1()
    @test projection.fields[3].original_value.child_contract_ref ==
        input.witness.children.binding_state.source_payload.child_contract_ref
    @test projection.fields[4].authoritative_value.value ==
        T2_G.vnext_t1_package_v2_manifest_hash(input.package)
    @test projection.fields[5].original_value.binding_receipt_hash ==
        input.adapter.binding.receipt_hash
    expected_reasons = (
        :up2_n10_01_g1_schema_descriptor_mismatch,
        :up2_n10_02_g2_canonicalization_descriptor_mismatch,
        :up2_n10_03_g3_binding_child_identity_mismatch,
        :up2_n10_04_t1_package_hash_mismatch,
        :up2_n10_05_reload_binding_identity_mismatch)
    for (row_id, expected_reason) in zip(
            T2_G.VNEXT_T2_IDENTITY_ROW_IDS_V2, expected_reasons)
        attacked = T2_G.vnext_t2_identity_projection_attack_v2(
            projection, row_id)
        rejected = T2_G.vnext_t2_validate_identity_receipt_v2(attacked)
        @test attacked.projection_hash != projection.projection_hash
        @test rejected.status === :fail_closed
        @test rejected.resolution === :none
        @test rejected.reason === expected_reason
        @test rejected.row_id == row_id
    end

    projection_reload = t2_serialize_reload(projection)
    @test projection_reload.value.projection_hash == projection.projection_hash
    @test T2_G.vnext_t2_validate_identity_receipt_v2(
        projection_reload.value).status === :valid
end

@testset "VNext T2 zero-call preflight, duplicate and fail atomic" begin
    chain = t2_chain()
    input = chain.build.input

    absent_build = T2_G.vnext_t2_up2_input_from_t1_v2(nothing,
        chain.reloaded_package, chain.adapter, chain.gate)
    absent = T2_G.vnext_t2_rebind_identity_receipts_v2(absent_build)
    @test absent.status === :typed_absent
    @test absent.resolution === :terminal_deferred
    @test !absent.committed
    @test isempty(absent.attempted_trace.events)
    @test absent.attempted_trace.counts == T2_G.VNextT2InvocationCountsV2()

    foreign_scenario = t2_bound_input_with(input,
        scenario="foreign-vnext-t2-scenario")
    foreign = T2_G.vnext_t2_rebind_identity_receipts_v2(foreign_scenario)
    @test foreign.status === :fail_closed
    @test foreign.reason === :t2_preflight_scenario_mismatch
    @test isempty(foreign.attempted_trace.events)

    unaccepted_chain = t2_chain(formal_t1_accepted=false)
    @test unaccepted_chain.build.status === :fail_closed
    @test unaccepted_chain.build.reason === :t2_preflight_formal_t1_not_accepted
    unaccepted = T2_G.vnext_t2_rebind_identity_receipts_v2(
        unaccepted_chain.build)
    @test isempty(unaccepted.attempted_trace.events)
    @test unaccepted.ledger === nothing

    absent_receipt_chain = t2_chain(formal_t1_accepted=false,
        software_acceptance_receipt_hash=T2_G._vnext_t2_v2_zero_digest(),
        candidate_admission_receipt_hash=T2_G._vnext_t2_v2_zero_digest())
    @test absent_receipt_chain.gate.
        formal_t1_software_acceptance_receipt_hash ==
        T2_G._vnext_t2_v2_zero_digest()
    @test absent_receipt_chain.gate.candidate_t1_admission_receipt_hash ==
        T2_G._vnext_t2_v2_zero_digest()
    @test absent_receipt_chain.build.status === :fail_closed
    @test absent_receipt_chain.build.reason ===
        :t2_preflight_formal_t1_not_accepted

    first = T2_G.vnext_t2_rebind_identity_receipts_v2(chain.build)
    duplicate = T2_G.vnext_t2_rebind_identity_receipts_v2(chain.build,
        prior_ledger=first.ledger)
    @test duplicate.status === :fail_closed
    @test duplicate.reason === :t2_preflight_duplicate_invocation
    @test !duplicate.committed
    @test duplicate.ledger === first.ledger
    @test duplicate.committed_counts == first.ledger.counts
    @test isempty(duplicate.attempted_trace.events)

    injected = T2_G.vnext_t2_rebind_identity_receipts_v2(chain.build,
        fault_after_stage=:e0)
    @test injected.status === :program_exception
    @test injected.reason === :e0_program_exception
    @test !injected.committed
    @test injected.ledger === nothing
    @test length(injected.attempted_trace.events) == 1
    @test injected.attempted_trace.events[1].consumer_id === :E0
    @test injected.attempted_trace.counts.e0 == 1
    @test injected.committed_counts == T2_G.VNextT2InvocationCountsV2()

    after_gi1a = T2_G.vnext_t2_rebind_identity_receipts_v2(chain.build,
        fault_after_stage=:gi1a)
    @test after_gi1a.status === :program_exception
    @test after_gi1a.reason === :gi1a_program_exception
    @test Tuple(x.consumer_id for x in after_gi1a.attempted_trace.events) ==
        (:E0, :GI1A)
    @test after_gi1a.attempted_trace.counts ==
        T2_G.VNextT2InvocationCountsV2(1, 1, 0, 0, 0, 0, 0, 0)

    after_e1 = T2_G.vnext_t2_rebind_identity_receipts_v2(chain.build,
        fault_after_stage=:e1)
    @test after_e1.status === :program_exception
    @test after_e1.reason === :e1_program_exception
    @test Tuple(x.consumer_id for x in after_e1.attempted_trace.events) ==
        (:E0, :GI1A, :E1)
    @test after_e1.attempted_trace.counts ==
        T2_G.VNextT2InvocationCountsV2(1, 1, 1, 0, 0, 0, 0, 0)
end

@testset "VNext T2 real T1 admission and disjoint parent domains" begin
    local_parent_fixture = t2_t1_admission_fixture()
    source_parent_commitments = (
        local_parent_fixture.source.parent.output.g1.authority_commitment,
        local_parent_fixture.source.parent.output.g2.authority_commitment)
    mixed = t2_t1_admission_fixture(
        parent_commitments=source_parent_commitments)
    @test mixed.admission.status === :fail_closed
    @test mixed.admission.resolution === :none
    @test mixed.admission.package === nothing
    @test mixed.admission.errors == (:parent_commitment_mismatch,)
    mixed_build = T2_G.vnext_t2_up2_input_from_t1_admission_v2(
        mixed.source.witness, mixed.admission_input, mixed.admission,
        nothing, nothing, nothing, scenario="mixed-parent-domain-negative")
    @test mixed_build.status === :fail_closed
    @test mixed_build.reason === :t2_preflight_t1_admission_input_mismatch
    mixed_result = T2_G.vnext_t2_rebind_identity_receipts_v2(mixed_build)
    @test isempty(mixed_result.attempted_trace.events)
    @test mixed_result.attempted_trace.counts ==
        T2_G.VNextT2InvocationCountsV2()

    missing = t2_t1_admission_fixture(transport_override=nothing,
        recheck_override=nothing)
    @test missing.admission.status === :terminal_deferred
    @test missing.admission.gaps == (:t0_transport_required,)
    missing_build = T2_G.vnext_t2_up2_input_from_t1_admission_v2(
        missing.source.witness, missing.admission_input, missing.admission,
        nothing, nothing, nothing, scenario="missing-t1-admission-negative")
    @test missing_build.status === :typed_absent
    @test missing_build.resolution === :terminal_deferred
    @test missing_build.reason === :t2_preflight_t1_admission_absent
    missing_result = T2_G.vnext_t2_rebind_identity_receipts_v2(missing_build)
    @test isempty(missing_result.attempted_trace.events)
    @test missing_result.attempted_trace.counts ==
        T2_G.VNextT2InvocationCountsV2()

    chain = t2_chain()
    malformed_wire_bytes = T2_G.copy_bytes(
        chain.admission_input.t0_recheck.prior_bundle_bytes)
    malformed_wire_bytes[1] = xor(malformed_wire_bytes[1], 0x01)
    malformed_recheck = t2_replace_struct_field(
        chain.admission_input.t0_recheck, :prior_bundle_bytes,
        T2_G.VNextT1CanonicalBytesV2(malformed_wire_bytes))
    malformed_input = t2_replace_struct_field(chain.admission_input,
        :t0_recheck, malformed_recheck)
    actual_malformed_admission = T2_G.vnext_t1_admit_v2(malformed_input)
    @test actual_malformed_admission.status === :fail_closed
    @test actual_malformed_admission.errors ==
        (:t0_recheck_wire_hash_mismatch,)
    stale_result_build = T2_G.vnext_t2_up2_input_from_t1_admission_v2(
        chain.source.witness, malformed_input, chain.admission,
        chain.reloaded_package, chain.adapter, chain.gate,
        scenario=chain.gate.scenario)
    @test stale_result_build.status === :fail_closed
    @test stale_result_build.reason ===
        :t2_preflight_t1_admission_result_mismatch
    stale_result = T2_G.vnext_t2_rebind_identity_receipts_v2(
        stale_result_build)
    @test isempty(stale_result.attempted_trace.events)
    @test stale_result.attempted_trace.counts ==
        T2_G.VNextT2InvocationCountsV2()

    forged_admission = T2_G.VNextT1AdmissionResultV2(
        chain.admission.status, chain.admission.resolution,
        chain.admission.accepted, chain.admission.claim_ceiling,
        chain.admission.package, chain.admission.errors, (:forged_gap,),
        (:entry, :forged_trace))
    forged_result_build = T2_G.vnext_t2_up2_input_from_t1_admission_v2(
        chain.source.witness, chain.admission_input, forged_admission,
        chain.reloaded_package, chain.adapter, chain.gate,
        scenario=chain.gate.scenario)
    @test forged_result_build.status === :fail_closed
    @test forged_result_build.reason ===
        :t2_preflight_t1_admission_result_mismatch
    forged_result = T2_G.vnext_t2_rebind_identity_receipts_v2(
        forged_result_build)
    @test isempty(forged_result.attempted_trace.events)
    @test forged_result.attempted_trace.counts ==
        T2_G.VNextT2InvocationCountsV2()

    mixed_witness = t2_witness_with_t1_commitments_as_source_parent(chain)
    @test mixed_witness.parent_bundle.g1.authority_commitment ==
        chain.t1_parents[1]
    @test !T2_G.verify_present_t0_local_parent_bundle_v1(
        mixed_witness.parent_bundle,
        T2_G.t0_parent_authority_commitment_v1(mixed_witness.g1.record),
        T2_G.t0_parent_authority_commitment_v1(mixed_witness.g2.record))
    mixed_gate = t2_gate_for_witness(chain, mixed_witness)
    source_mixed_build = T2_G.vnext_t2_up2_input_from_t1_admission_v2(
        mixed_witness, chain.admission_input, chain.admission,
        chain.reloaded_package, chain.adapter, mixed_gate,
        scenario=chain.gate.scenario)
    @test source_mixed_build.status === :fail_closed
    @test source_mixed_build.reason ===
        :t2_preflight_parent_commitment_mismatch
    source_mixed_result = T2_G.vnext_t2_rebind_identity_receipts_v2(
        source_mixed_build)
    @test isempty(source_mixed_result.attempted_trace.events)
    @test source_mixed_result.attempted_trace.counts ==
        T2_G.VNextT2InvocationCountsV2()
end

@testset "VNext T2 explicit child coupling contradiction" begin
    contradiction = t2_chain(coherent_g3_child=false)
    @test contradiction.source.witness.coupling.status === :fail_closed
    result = T2_G.vnext_t2_rebind_identity_receipts_v2(
        contradiction.build)
    @test result.status === :fail_closed
    @test result.reason === :e2_declared_source_child_contradiction
    @test !result.committed
    @test result.ledger === nothing
    @test result.attempted_trace.counts.e0 == 1
    @test result.attempted_trace.counts.gi1a == 1
    @test result.attempted_trace.counts.e1 == 1
    @test result.attempted_trace.counts.e2 == 1
    @test result.attempted_trace.counts.n10 == 0
    @test Tuple(x.consumer_id for x in result.attempted_trace.events) ==
        (:E0, :GI1A, :E1, :E2)
end

@testset "VNext T2 edited operation evidence remains deferred" begin
    edited = t2_chain(edited_realization=true)
    @test :realization_full_operation_replay_evidence_not_carried in
        edited.source.witness.gaps
    result = T2_G.vnext_t2_rebind_identity_receipts_v2(edited.build)
    @test result.committed
    @test result.ledger.receipts[4].status === :typed_absent
    @test result.ledger.receipts[4].reason ===
        :e2_operation_replay_evidence_missing
    @test :full_child_operation_replay_evidence in
        result.ledger.receipts[4].unsupported_capabilities
    @test :realization_full_operation_replay_evidence_not_carried in
        result.ledger.gaps
end

println("VNEXT_T2_IDENTITY_RECEIPT_V2_FOCUSED=PASS")
println("VNEXT_T2_FORMAL_GATE_EVIDENCE_KIND=synthetic_local")
println("VNEXT_T2_FORMAL_GATE_VERIFIED=false")
println("VNEXT_T2_FORMAL_ACCEPTANCE=false")
