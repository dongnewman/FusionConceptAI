using Test
using FusionConceptAI

const _VUP2_ROOT = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
const _VUP2 = FusionConceptAI

_VUP2.load_genome_v5_components!()
_VUP2.load_vnext_t2_components_v2!()

# Reuse the existing source-backed producer/consumer fixture helpers read-only.
include(joinpath(_VUP2_ROOT, "test", "GenomeV5", "Integration",
    "VNextT2IdentityReceiptV2", "fixture_helpers.jl"))

if !isdefined(_VUP2, :dgd_execute_v1)
    Base.include(_VUP2, joinpath(_VUP2_ROOT, "src", "RuntimeV4",
        "DeclaredG123DiffusionExecutionV1.jl"))
end
Base.include(_VUP2, joinpath(_VUP2_ROOT, "src", "GenomeV5", "UP2",
    "VNextUP2ConsumerBridgeV1.jl"))

@testset "VNext source-backed local contract input to unintegrated DGD screen" begin
    edited = t2_chain(edited_realization=true,
        scenario="vnext-up2-consumer-edited-source-r1")
    baseline = t2_chain(edited_realization=false,
        scenario="vnext-up2-consumer-baseline-source-r1")

    @test edited.build.status === :prepared_not_executed
    @test edited.build.input isa _VUP2.VNextT2UP2BoundInputV2
    @test edited.reloaded_package isa _VUP2.CandidateStatePackageV5NextV2
    @test edited.source.witness.source_status === :source_ready
    @test edited.gate.evidence_kind === :synthetic_local
    @test edited.gate.formal_t1_accepted === true
    @test edited.formal_gate_verified === false
    @test _VUP2.canonical_hash(edited.reloaded_package.children) !=
        _VUP2.canonical_hash(baseline.reloaded_package.children)

    t2_aggregate = _VUP2.vnext_t2_rebind_identity_receipts_v2(
        edited.build.input)
    @test t2_aggregate.status === :complete_contract_receipts
    @test t2_aggregate.committed === true
    @test t2_aggregate.ledger.counts.compiler == 0
    @test t2_aggregate.ledger.counts.provider == 0
    @test t2_aggregate.ledger.counts.solver == 0

    result = _VUP2.vnext_up2_dgd_consume_v1(edited.build, t2_aggregate)
    @test result.status in (:screen_observed, :numerical_fail, :fail_closed)
    @test result.dgd_invocation_count == 1
    @test result.candidate_ref == edited.reloaded_package.candidate_ref
    @test result.t1_package_hash == edited.reloaded_package.package_hash
    @test result.t2_ledger_hash == t2_aggregate.ledger.ledger_hash
    @test result.b00_status === :typed_absent
    @test result.b04_status === :typed_absent
    @test result.formal_gate_resolution === :terminal_deferred
    @test result.accepted === false
    @test result.claim_ceiling === :screen_only
    @test result.formal_up_credit === false
    @test result.formal_r_credit === false
    @test result.observation !== nothing
    @test result.observation.package_children_hash ==
        _VUP2.canonical_hash(edited.reloaded_package.children)
    @test result.observation.witness_children_hash ==
        edited.source.witness.children.identity_hash
    @test result.observation.g3_edit_use ===
        :identity_bound_not_consumed_by_dgd
    @test :formal_gate_verified_false_synthetic_local in
        result.observation.gaps
    @test all(gap in result.observation.gaps for gap in
        edited.source.witness.gaps)
    @test :formal_b00_b04_receipts_not_supplied in
        result.observation.gaps
    @test result.observation.runtime_status in
        (:ready, :terminal_deferred, :numerical_fail, :fail_closed)
    @test result.observation.solver_calls in (0, 1)
    @test _VUP2.canonical_hash(
        _VUP2._vnext_up2_consumer_result_body_v1(result)) ==
        result.result_hash
    @test _VUP2.canonical_hash(
        _VUP2._vnext_up2_dgd_observation_body_v1(result.observation)) ==
        result.observation.observation_hash

    missing_gate = _VUP2.VNextT2UP2InputBuildResultV2(:typed_absent,
        :terminal_deferred, :t2_preflight_source_witness_absent, nothing,
        _VUP2.canonical_hash((missing=:source_witness,)))
    absent_result = _VUP2.vnext_up2_dgd_consume_v1(missing_gate, nothing)
    @test absent_result.status === :typed_absent
    @test absent_result.resolution === :terminal_deferred
    @test absent_result.reason === :t2_preflight_source_witness_absent
    @test absent_result.dgd_invocation_count == 0
    @test absent_result.observation === nothing

    missing_aggregate = _VUP2.vnext_up2_dgd_consume_v1(edited.build, nothing)
    @test missing_aggregate.status === :typed_absent
    @test missing_aggregate.reason ===
        :t2_identity_receipt_aggregate_absent
    @test missing_aggregate.dgd_invocation_count == 0

    bad_build = t2_replace_struct_field(edited.build, :input_hash,
        _VUP2.Digest256(repeat("0", 64)))
    stale_build_result = _VUP2.vnext_up2_dgd_consume_v1(
        bad_build, t2_aggregate)
    @test stale_build_result.status === :fail_closed
    @test stale_build_result.reason === :t2_preflight_build_hash_mismatch
    @test stale_build_result.dgd_invocation_count == 0

    bad_ledger = t2_replace_struct_field(t2_aggregate.ledger,
        :package_hash, _VUP2.Digest256(repeat("0", 64)))
    bad_aggregate = t2_replace_struct_field(t2_aggregate, :ledger,
        bad_ledger)
    aggregate_mismatch = _VUP2.vnext_up2_dgd_consume_v1(
        edited.build, bad_aggregate)
    @test aggregate_mismatch.status === :fail_closed
    @test aggregate_mismatch.reason ===
        :t2_identity_receipt_aggregate_mismatch
    @test aggregate_mismatch.dgd_invocation_count == 0
    @test aggregate_mismatch.observation === nothing

    unaccepted = t2_chain(edited_realization=true,
        formal_t1_accepted=false,
        scenario="vnext-up2-consumer-unaccepted-source-r1")
    @test unaccepted.build.status === :fail_closed
    unaccepted_result = _VUP2.vnext_up2_dgd_consume_v1(
        unaccepted.build, nothing)
    @test unaccepted_result.status === :fail_closed
    @test unaccepted_result.dgd_invocation_count == 0
    @test unaccepted_result.observation === nothing

    println("VUP2_SCREEN_STATUS=$(result.status)")
    println("VUP2_DGD_RUNTIME_STATUS=$(result.observation.runtime_status)")
    println("VUP2_DGD_COMPILE=$(result.observation.compile_status)/$(result.observation.compile_code)")
    println("VUP2_DGD_NUMERICAL=$(result.observation.numerical_status)/$(result.observation.numerical_code)")
    println("VUP2_DGD_SOLUTION=$(result.observation.numerical_solution)")
    println("VUP2_DGD_RESIDUAL=$(result.observation.numerical_residual_norm)")
    println("VUP2_DGD_COUNTS=provider:$(result.observation.provider_calls),mesh:$(result.observation.mesh_calls),solver:$(result.observation.solver_calls)")
    println("VUP2_CLAIM_CEILING=$(result.claim_ceiling); accepted=$(result.accepted); formal_up=$(result.formal_up_credit); formal_r=$(result.formal_r_credit)")
    println("VUP2_B00=$(result.b00_status); VUP2_B04=$(result.b04_status)")
    println("VUP2_LOCAL_GATE=evidence_kind:$(edited.gate.evidence_kind); formal_t1_accepted:$(edited.gate.formal_t1_accepted); formal_gate_verified:$(edited.formal_gate_verified)")
    println("VUP2_LOCAL_CONTRACT_GAPS=$(t2_aggregate.ledger.gaps)")
    println("VUP2_SOURCE_BACKED_PACKAGE_SHA256=$(edited.reloaded_package.package_hash)")
    println("VUP2_LOCAL_CONTRACT_LEDGER_SHA256=$(t2_aggregate.ledger.ledger_hash)")
    println("VUP2_DGD_RECEIPT_SHA256=$(result.observation.runtime_receipt_hash)")
end
