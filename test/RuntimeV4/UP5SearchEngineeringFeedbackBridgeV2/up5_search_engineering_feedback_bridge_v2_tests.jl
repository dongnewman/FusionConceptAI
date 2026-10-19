using Test
using FusionConceptAI

const UP5_SEFB_V2_REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))

module UP5SearchFeedbackV2TestRuntime
using FusionConceptAI

const REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
include(joinpath(REPO, "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "Capability.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "Search.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "ForwardChainContext.jl"))
# The UP4 fixture supplies real reduced-SI execution requests and its own
# focused checks; it does not run a production forward chain.
include(joinpath(REPO, "test", "RuntimeV4", "UP4",
    "engineering_feedback_execution_v1_tests.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "UP5SearchEngineeringFeedbackBridgeV1.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "UP5SearchEngineeringFeedbackBridgeV2.jl"))
end

include(joinpath(UP5_SEFB_V2_REPO, "examples", "runtime_v4_declared_fixture.jl"))
const U = UP5SearchFeedbackV2TestRuntime

function _up5_v2_feedback(request, result; route_status=:screen_only,
        evaluator_status=result.status, output_digest=canonical_hash(result))
    U._up5_sefb_finish_v1(U.CandidateQueueV4(),
        digest256_text("up5-v2-feedback-entry"), route_status,
        canonical_hash(request), :canonical;
        candidate_hash=result.candidate_hash,
        scenario_hash=result.scenario_hash, g3_hash=result.g3_hash,
        output_digest=output_digest, output_digest_kind=:canonical,
        evaluator_status, failure_codes=result.failures)
end

function _up5_v2_with_thermal_limit(request)
    envelope_type = U.EngineeringFeedbackReducedSIEnvelopeV1
    body = merge(U._up4_02b_envelope_body(request.envelope),
        (max_temperature_K=300.01, cooling_capacity_W=0.01))
    fields = fieldnames(envelope_type)[1:end-1]
    envelope = envelope_type((getproperty(body, field) for field in fields)...,
        canonical_hash(body))
    U.engineering_feedback_request(request.upstream_execution,
        request.load_sample, envelope;
        upstream_execution_hash=request.upstream_execution_hash,
        load_sample_hash=request.load_sample_hash,
        shir_hash=request.shir_hash, bridge_hash=request.bridge_hash,
        candidate_hash=request.candidate_hash,
        scenario_hash=request.scenario_hash, g3_hash=request.g3_hash,
        shir_contract=request.shir_contract,
        bridge_contract=request.bridge_contract,
        max_iterations=request.max_iterations, tolerance=request.tolerance)
end

@testset "UP5 V2 typed reduced-SI engineering signals" begin
    request = U._up4b_request()
    result = U.execute_engineering_feedback(request)
    @test result.status === :pass
    envelope = U._up5_sefb_v2_wrap(_up5_v2_feedback(request, result), nothing, result)
    signal = envelope.signal
    @test signal.observation_status === :reduced_si_screen
    @test signal.failure_class === :pass
    @test signal.candidate_hash == request.candidate_hash
    @test signal.scenario_hash == request.scenario_hash
    @test signal.g3_hash == request.g3_hash
    @test signal.component_load_status === :unknown
    @test all(x -> x === :pass, values(signal.gate_states))
    @test signal.thermal_bottleneck === :none
    @test signal.supply_bottleneck === :none
    @test isempty(signal.edit_targets)
    @test U.canonical_hash(signal) == signal.signal_hash
    @test U.canonical_hash(envelope) == envelope.record_hash
    @test !envelope.feedback.accepted && envelope.feedback.discovery_credit === :none

    capacity_request = U._up4b_request(mutation=:capacity_exceeded)
    capacity_result = U.execute_engineering_feedback(capacity_request)
    @test capacity_result.status === :physical_fail
    capacity_feedback = _up5_v2_feedback(capacity_request, capacity_result;
        route_status=:failed)
    capacity = U._up5_sefb_v2_wrap(capacity_feedback, nothing,
        capacity_result).signal
    @test capacity.observation_status === :reduced_si_screen
    @test capacity.failure_class === :physical_fail
    @test capacity.gate_states.source_capacity === :violated
    @test capacity.supply_bottleneck === :source
    @test :capacity_exceeded in capacity.failure_codes
    @test length(capacity.edit_targets) == 1
    @test only(capacity.edit_targets).genome_role === :G3
    @test only(capacity.edit_targets).facet === :source_network
    @test only(capacity.edit_targets).applicability === :requires_typed_model_binding
    @test capacity.component_load_status === :unknown

    thermal_request = _up5_v2_with_thermal_limit(request)
    thermal_result = U.execute_engineering_feedback(thermal_request)
    @test thermal_result.status === :physical_fail
    thermal = U._up5_sefb_v2_wrap(_up5_v2_feedback(
        thermal_request, thermal_result; route_status=:failed),
        nothing, thermal_result).signal
    @test thermal.thermal_bottleneck === :cooling_and_temperature
    @test thermal.gate_states.cooling_capacity === :violated
    @test thermal.gate_states.temperature === :violated
    @test Set(x.facet for x in thermal.edit_targets) ==
        Set((:cooling_path, :thermal_management))
    @test all(x -> x.genome_role === :G3, thermal.edit_targets)

    unconverged_request = U._up4b_request(mutation=:iteration_limit)
    unconverged_result = U.execute_engineering_feedback(unconverged_request)
    @test unconverged_result.status === :numerical_fail
    unconverged = U._up5_sefb_v2_wrap(_up5_v2_feedback(
        unconverged_request, unconverged_result; route_status=:failed),
        nothing, unconverged_result).signal
    @test unconverged.failure_class === :numerical_fail
    @test unconverged.observation_status === :unknown
    @test all(x -> x === :unknown, values(unconverged.gate_states))
    @test isempty(unconverged.edit_targets)

    missing_request = U._up4b_request(mutation=:missing_cooling)
    missing_result = U.execute_engineering_feedback(missing_request)
    @test missing_result.status === :fail_closed
    missing_feedback = _up5_v2_feedback(missing_request, missing_result;
        route_status=:deferred)
    missing = U._up5_sefb_v2_wrap(missing_feedback, nothing,
        missing_result).signal
    @test missing.observation_status === :unknown
    @test missing.thermal_bottleneck === :unknown
    @test missing.gate_states.cooling_capacity === :unknown
    @test isempty(missing.edit_targets)
    @test :missing_cooling in missing.failure_codes

    # A digest or candidate mismatch cannot turn an evaluator result into
    # search-facing constraints, even when the result itself is well formed.
    wrong_digest = _up5_v2_feedback(request, result;
        output_digest=digest256_text("foreign-output"))
    @test U._up5_sefb_v2_wrap(wrong_digest, nothing, result).signal.observation_status === :unknown
    foreign_request = U._up4b_request(mutation=:capacity_exceeded)
    foreign_result = U.execute_engineering_feedback(foreign_request)
    @test U._up5_sefb_v2_wrap(_up5_v2_feedback(request, result),
        nothing, foreign_result).signal.observation_status === :unknown
end

function _up5_v2_candidate(; identity="up5-v2-registry-join")
    source_g3 = Main._fixture_realization
    g3 = U.RealizationControlGenomeV4(source_g3.seed, source_g3.control_seed,
        source_g3.contract_ref, source_g3.realization_graph, source_g3.control_graph;
        realization=((revision="up5-v2-test-realization-v1",
            status=:test_declaration, model_scope=:screen_only),),
        control=((revision="up5-v2-test-control-v1",
            status=:test_declaration, model_scope=:screen_only),))
    U.CandidateStatePackageV4(identity, Main._fixture_mission,
        Main._fixture_mechanism, Main._fixture_field, g3, Main.registry)
end

function _up5_v2_context(candidate; scenario=(name="startup", load_case="nominal"))
    mission = (mission_id="up5-v2-registry-join-test",
        contract=candidate.mission_contract_ref, authority=:no_publish)
    bounds = (scope="test-only-registry-join", lower=-1.0, upper=1.0)
    comparison = ("UP5-v2-registry-join",)
    scenarios = ((name="startup", load_case="nominal"),
        (name="hold", load_case="nominal"))
    scenario_scope = Tuple(x.name for x in scenarios)
    compiled = U.compile_candidate(candidate, Main.registry;
        mission_payload=mission, bounds_payload=bounds,
        comparison_scope=comparison, scenario_scope)
    # This typed subject is solely for context identity tests. It is not made
    # by materialize(), has no solver input, and is never submitted as evidence.
    subject = U.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash, compiled.minimality_scope.bounds_hash,
        ((binding_kind="UP5-v2-test-only", candidate_ref=candidate.identity_ref),),
        scenarios,
        (materialization="identity-test-only", revision="v1", authority=:no_publish),
        U.derive_capability_obligations(compiled))
    context = U.make_forward_chain_context(candidate, compiled, Main.registry,
        mission, bounds, comparison, scenario_scope, subject, scenario)
    (; context, compiled)
end

@testset "UP5 V2 Search/context registry provenance join" begin
    candidate = _up5_v2_candidate()
    built = _up5_v2_context(candidate)
    @test !isempty(built.compiled.unresolved_nonterminals)

    matching_queue = U.CandidateQueueV4()
    matching_entry = U.enqueue_candidate!(matching_queue, candidate,
        built.compiled; registry_hash=canonical_hash(Main.registry))
    @test matching_entry.status === :deferred
    @test U.next_compilable!(matching_queue) === nothing
    matching_status_before = matching_queue.entries[matching_entry.candidate_ref].status
    matching = U.search_engineering_registry_binding_v2(matching_entry,
        built.context)
    @test matching.status === :exact
    @test matching.queue_registry_hash == canonical_hash(Main.registry)
    @test matching.context_registry_hash == built.context.registry_hash
    @test matching.context_registry_hash == canonical_hash(built.context.registry)
    @test matching.entry_ref == matching_entry.candidate_ref
    @test matching.candidate_hash == built.context.candidate_hash
    @test matching.scenario_hash == built.context.scenario_hash
    @test matching.g3_hash == canonical_hash(candidate.realization_control_genome_ref)
    @test U.canonical_hash(matching) == matching.binding_hash
    @test matching_queue.entries[matching_entry.candidate_ref].status === matching_status_before

    mismatch_queue = U.CandidateQueueV4()
    foreign_registry_hash = digest256_text("not-the-context-registry")
    mismatch_entry = U.enqueue_candidate!(mismatch_queue, candidate,
        built.compiled; registry_hash=foreign_registry_hash)
    @test mismatch_entry.status === :deferred
    @test U.next_compilable!(mismatch_queue) === nothing
    mismatch_status_before = mismatch_queue.entries[mismatch_entry.candidate_ref].status
    mismatch = U.search_engineering_registry_binding_v2(mismatch_entry,
        built.context)
    @test mismatch.status === :mismatch
    @test mismatch.queue_registry_hash == foreign_registry_hash
    @test mismatch.context_registry_hash == canonical_hash(Main.registry)
    @test U.canonical_hash(mismatch) == mismatch.binding_hash
    @test mismatch_queue.entries[mismatch_entry.candidate_ref].status === mismatch_status_before

    same_prefix_foreign_candidate = _up5_v2_candidate(identity="same-prefix-foreign-candidate")
    @test same_prefix_foreign_candidate.canonical_hashes == candidate.canonical_hashes
    @test built.compiled.prefix_hash == U.compile_candidate(
        same_prefix_foreign_candidate, Main.registry;
        mission_payload=built.compiled.mission_payload,
        bounds_payload=built.compiled.bounds_payload,
        comparison_scope=built.compiled.minimality_scope.comparison_scope,
        scenario_scope=built.compiled.minimality_scope.scenario_scope).prefix_hash
    foreign_queue = U.CandidateQueueV4()
    foreign_entry = U.enqueue_candidate!(foreign_queue,
        same_prefix_foreign_candidate, built.compiled;
        registry_hash=canonical_hash(Main.registry))
    @test_throws ArgumentError U.search_engineering_registry_binding_v2(
        foreign_entry, built.context)
    @test foreign_entry.status === :deferred
    @test U.next_compilable!(foreign_queue) === nothing

    calls = Ref(0)
    deferred_request = U._up4b_request()
    deferred = U.route_search_engineering_feedback_v2!(matching_queue,
        matching_entry.candidate_ref, built.context, deferred_request;
        executor=req -> (calls[] += 1; U.execute_engineering_feedback(req)))
    @test calls[] == 0
    @test deferred.feedback.route_status === :deferred
    @test deferred.signal.observation_status === :unknown
    @test all(x -> x === :unknown, values(deferred.signal.gate_states))
    @test isempty(deferred.signal.edit_targets)
end
