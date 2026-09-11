using Test
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_ecf_numerical_repeatability.jl"))

@testset "ECF fresh-process numerical repeatability" begin
    q=ecf_repeatability.request; r=ecf_repeatability.result
    @test q.execution_count == 2
    @test length(r.observations) == 2
    @test Tuple(o.execution_id for o in r.observations) == (1, 2)
    @test r.trace_observables_validated && r.repeatability_passed
    @test all(o -> o.context_hash == ecfgo_context.context_hash &&
        o.request_hash == tecfe_request.request_hash && o.receipt_hash == tecfe_receipt.receipt_hash,
        r.observations)
    @test r.observations[1].process_id != r.observations[2].process_id
    @test all(o -> o.project_manifest_sha256 == q.project_manifest_sha256 &&
        o.child_source_sha256 == q.child_source_sha256 &&
        o.julia_version == q.julia_version, r.observations)
    @test r.claim_ceiling == screen_only
    @test !r.physical_validation && !r.validation_uq && !r.whole_device_closure
    @test !r.emits_evidence && !r.promotion_authority && !r.terminal_authority
    body=NamedTuple{fieldnames(typeof(r))[1:end-1]}(
        ntuple(i -> getfield(r,i), fieldcount(typeof(r))-1))
    forged=merge(body,(physical_validation=true,))
    forged_result=ECFVUQ.EngineeringControlFaultNumericalRepeatabilityResultV4(
        values(forged)...,ECFVUQ._ecf_nr_result_hash(forged))
    @test_throws ArgumentError canonical_hash(forged_result)
    o1,o2=r.observations
    reused=ECFVUQ.EngineeringControlFaultNumericalRepeatabilityObservationV4(
        o2.execution_id,o1.process_id,o2.julia_executable,o2.julia_executable_sha256,
        o2.julia_version,o2.project_manifest_sha256,o2.child_source_sha256,
        o2.context_hash,o2.request_hash,o2.receipt_hash,o2.result_hash,o2.trace_hash,
        o2.sample_count,o2.transport_release_count,o2.dropout_sample_count,
        o2.declared_fault_sample_count,o2.actuator_bound_violation_count,
        canonical_hash((revision="ecf-operational-numerical-repeatability-v1",
            execution_id=o2.execution_id,process_id=o1.process_id,julia_executable=o2.julia_executable,
            julia_executable_sha256=o2.julia_executable_sha256,julia_version=o2.julia_version,
            project_manifest_sha256=o2.project_manifest_sha256,child_source_sha256=o2.child_source_sha256,
            context_hash=o2.context_hash,request_hash=o2.request_hash,receipt_hash=o2.receipt_hash,
            result_hash=o2.result_hash,trace_hash=o2.trace_hash,sample_count=o2.sample_count,
            transport_release_count=o2.transport_release_count,dropout_sample_count=o2.dropout_sample_count,
            declared_fault_sample_count=o2.declared_fault_sample_count,actuator_bound_violation_count=o2.actuator_bound_violation_count)))
    reused_body=merge(body,(observations=(o1,reused),))
    reused_result=ECFVUQ.EngineeringControlFaultNumericalRepeatabilityResultV4(
        values(reused_body)...,ECFVUQ._ecf_nr_result_hash(reused_body))
    @test_throws ArgumentError canonical_hash(reused_result)
    badobs_body=merge(NamedTuple{fieldnames(typeof(o2))[1:end-1]}(
        ntuple(i -> getfield(o2,i), fieldcount(typeof(o2))-1)),
        (trace_hash=digest256_text("foreign-trace"),))
    badobs=ECFVUQ.EngineeringControlFaultNumericalRepeatabilityObservationV4(
        values(badobs_body)...,ECFVUQ._ecf_nr_observation_hash(badobs_body))
    bad_result_body=merge(body,(observations=(o1,badobs),))
    bad_result=ECFVUQ.EngineeringControlFaultNumericalRepeatabilityResultV4(
        values(bad_result_body)...,ECFVUQ._ecf_nr_result_hash(bad_result_body))
    @test_throws ArgumentError canonical_hash(bad_result)
    bad_request_body=merge(NamedTuple{fieldnames(typeof(q))[1:end-1]}(
        ntuple(i -> getfield(q,i), fieldcount(typeof(q))-1)),
        (nonbridge_hash=digest256_text("foreign-nonbridge"),))
    bad_request=ECFVUQ.EngineeringControlFaultNumericalRepeatabilityRequestV4(
        values(bad_request_body)...,ECFVUQ.canonical_hash(bad_request_body))
    @test_throws ArgumentError ECFVUQ.validate_ecf_numerical_repeatability(
        tecfe_registry,ecfgo_context,tecfe_request,tecfe_receipt,ecf_vuq_bridge,
        bad_request,r)
    bridge_fields=NamedTuple{fieldnames(typeof(ecf_vuq_bridge))[1:end-1]}(
        ntuple(i -> getfield(ecf_vuq_bridge,i), fieldcount(typeof(ecf_vuq_bridge))-1))
    bridge_body=merge(bridge_fields,(detail="foreign",))
    forged_bridge=ECFVUQ.EngineeringControlFaultValidationUQBridgeV4(
        values(bridge_body)...,canonical_hash(bridge_body))
    @test_throws ArgumentError ECFVUQ.validate_engineering_control_fault_vuq_bridge(
        tecfe_registry,ecfgo_context,tecfe_request,tecfe_receipt,forged_bridge)
end
println("ECF_NUMERICAL_REPEATABILITY_FOCUSED_EXIT_CODE=0")
