using Test
using FusionConceptAI

const UP5_SEFB_REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))

module UP5SearchFeedbackTestRuntimeV1
using Test
using FusionConceptAI

const REPO = normpath(joinpath(@__DIR__, "..", "..", ".."))
include(joinpath(REPO, "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "Capability.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "Search.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "ForwardChainContext.jl"))

# Reuse the existing UP4-02B typed fixture constructors. This also runs their
# focused actual-executor tests in the same isolated module and process.
include(joinpath(REPO, "test", "RuntimeV4", "UP4", "engineering_feedback_execution_v1_tests.jl"))
include(joinpath(REPO, "src", "RuntimeV4", "UP5SearchEngineeringFeedbackBridgeV1.jl"))
end

include(joinpath(UP5_SEFB_REPO, "examples", "runtime_v4_declared_fixture.jl"))
const U = UP5SearchFeedbackTestRuntimeV1

function _up5_candidate_v1(; identity="up5-feedback-candidate",
        g3_payload=true)
    source_g3 = Main._fixture_realization
    realization = g3_payload ? ((revision="up5-test-realization-declaration-v1",
        status=:declared_test_input, model_scope=:screen_only),) : ()
    control = g3_payload ? ((revision="up5-test-control-declaration-v1",
        status=:declared_test_input, model_scope=:screen_only),) : ()
    g3 = RealizationControlGenomeV4(source_g3.seed, source_g3.control_seed,
        source_g3.contract_ref, source_g3.realization_graph, source_g3.control_graph;
        realization, control)
    CandidateStatePackageV4(identity, Main._fixture_mission,
        Main._fixture_mechanism, Main._fixture_field, g3, Main.registry)
end

function _up5_context_v1(candidate; scenario_index=1)
    mission = (mission_id="up5-engineering-feedback-test",
        contract=candidate.mission_contract_ref, authority=:no_publish)
    bounds = (scope="test-only-reduced-engineering-feedback", lower=-1.0, upper=1.0)
    comparison = ("UP5-isolated-feedback-screen",)
    scenarios = ((name="startup", load_case="nominal"),
        (name="hold", load_case="nominal"))
    scenario_scope = Tuple(x.name for x in scenarios)
    compiled = U.compile_candidate(candidate, Main.registry;
        mission_payload=mission, bounds_payload=bounds,
        comparison_scope=comparison, scenario_scope)
    subject = U.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash, compiled.minimality_scope.bounds_hash,
        ((binding_kind="UP5-test-only-materialization", candidate_ref=candidate.identity_ref),),
        scenarios,
        (materialization="isolated-test-fixture", revision="v1", authority=:no_publish),
        U.derive_capability_obligations(compiled))
    context = U.make_forward_chain_context(candidate, compiled, Main.registry,
        mission, bounds, comparison, scenario_scope, subject, scenarios[scenario_index])
    (; context, compiled, scenarios)
end

function _up5_active_queue_v1(context)
    queue = U.CandidateQueueV4()
    U.enqueue_candidate!(queue, context.candidate, context.compiled;
        registry_hash=canonical_hash(Main.registry))
    active = U.next_compilable!(queue)
    active === nothing && error("test fixture did not compile into an active Search entry")
    queue, active
end

function _up5_request_v1(context; candidate_hash=U._forward_candidate_identity(context.candidate),
        scenario_hash=context.scenario_hash,
        g3_hash=canonical_hash(context.candidate.realization_control_genome_ref),
        mutation=:positive)
    sample = U._up4b_sample(candidate_hash, scenario_hash, g3_hash; mutation)
    upstream = U._up4b_upstream(sample, candidate_hash, scenario_hash, g3_hash;
        mutation=mutation in (:foreign_sample, :negative_stored_difference) ? :positive : mutation)
    shir, bridge = U._up4b_contracts(candidate_hash, scenario_hash, g3_hash; mutation)
    envelope = U._up4b_envelope(candidate_hash, scenario_hash, g3_hash, sample;
        mutation=mutation)
    U.engineering_feedback_request(upstream, sample, envelope;
        shir_hash=shir.contract_hash, bridge_hash=bridge.contract_hash,
        candidate_hash, scenario_hash, g3_hash,
        shir_contract=shir, bridge_contract=bridge,
        max_iterations=mutation === :iteration_limit ? 1 : 50, tolerance=1e-8)
end

@testset "UP5 isolated Search to real engineering feedback bridge V1" begin
    positive_candidate = _up5_candidate_v1()
    positive = _up5_context_v1(positive_candidate)
    queue, active = _up5_active_queue_v1(positive.context)
    request = _up5_request_v1(positive.context)
    actual_result = Ref{Any}(nothing)
    calls = Ref(0)
    record = U.route_search_engineering_feedback!(queue, active.candidate_ref,
        positive.context, request; executor=req -> begin
            calls[] += 1
            actual_result[] = U.execute_engineering_feedback(req)
            actual_result[]
        end)
    @test calls[] == 1
    @test actual_result[] isa U.EngineeringFeedbackExecutionV1
    @test actual_result[].status === :pass
    @test record.route_status === :screen_only
    @test record.evaluator_status === :pass
    @test record.queue_transition === :deferred
    @test queue.entries[active.candidate_ref].status === :deferred
    @test record.request_digest == canonical_hash(request)
    @test record.output_digest == canonical_hash(actual_result[])
    @test record.request_digest_kind === :canonical
    @test record.output_digest_kind === :canonical
    @test record.accepted === false && record.claim_ceiling === :screen_only
    @test record.engineering_credit === record.physical_credit === :none
    @test record.r01_r10_credit === record.discovery_credit === :none
    @test record.score === 0.0
    @test U.canonical_hash(record) == record.record_hash

    @testset "same prefix never aliases candidate, scenario, or G3 identities" begin
        queue_candidate, queue_active = _up5_active_queue_v1(positive.context)
        foreign_candidate = _up5_candidate_v1(identity="up5-same-genomes-foreign-identity")
        foreign = _up5_context_v1(foreign_candidate)
        @test foreign.compiled.prefix_hash == queue_active.candidate_ref
        foreign_request = _up5_request_v1(foreign.context)
        foreign_calls = Ref(0)
        foreign_record = U.route_search_engineering_feedback!(queue_candidate,
            queue_active.candidate_ref, foreign.context, foreign_request;
            executor=_ -> (foreign_calls[] += 1; U.execute_engineering_feedback(foreign_request)))
        @test :candidate_identity_mismatch in foreign_record.failure_codes
        @test foreign_calls[] == 0
        @test foreign_record.route_status === :deferred
        @test queue_candidate.entries[queue_active.candidate_ref].status === :deferred

        queue_scenario, scenario_active = _up5_active_queue_v1(positive.context)
        alternate_scenario = _up5_context_v1(positive_candidate; scenario_index=2)
        @test alternate_scenario.compiled.prefix_hash == scenario_active.candidate_ref
        original_scenario_request = _up5_request_v1(positive.context)
        scenario_calls = Ref(0)
        scenario_record = U.route_search_engineering_feedback!(queue_scenario,
            scenario_active.candidate_ref, alternate_scenario.context,
            original_scenario_request; executor=_ -> (scenario_calls[] += 1;
                U.execute_engineering_feedback(original_scenario_request)))
        @test :request_scenario_mismatch in scenario_record.failure_codes
        @test scenario_calls[] == 0

        queue_g3, g3_active = _up5_active_queue_v1(positive.context)
        foreign_g3_request = _up5_request_v1(positive.context;
            g3_hash=digest256_text("foreign-g3-for-same-prefix"))
        g3_calls = Ref(0)
        g3_record = U.route_search_engineering_feedback!(queue_g3,
            g3_active.candidate_ref, positive.context, foreign_g3_request;
            executor=_ -> (g3_calls[] += 1; U.execute_engineering_feedback(foreign_g3_request)))
        @test :request_g3_mismatch in g3_record.failure_codes
        @test g3_calls[] == 0
    end

    @testset "missing G3 and engineering inputs remain deferred" begin
        missing_candidate = _up5_candidate_v1(identity="up5-missing-g3",
            g3_payload=false)
        missing = _up5_context_v1(missing_candidate)
        missing_queue, missing_active = _up5_active_queue_v1(missing.context)
        missing_request = _up5_request_v1(missing.context)
        missing_calls = Ref(0)
        missing_record = U.route_search_engineering_feedback!(missing_queue,
            missing_active.candidate_ref, missing.context, missing_request;
            executor=_ -> (missing_calls[] += 1; U.execute_engineering_feedback(missing_request)))
        @test :missing_g3_realization_control_payload in missing_record.failure_codes
        @test missing_calls[] == 0
        @test missing_record.output_digest === nothing
        @test missing_record.route_status === :deferred
        @test missing_queue.entries[missing_active.candidate_ref].status === :deferred

        engineering_queue, engineering_active = _up5_active_queue_v1(positive.context)
        missing_engineering_request = _up5_request_v1(positive.context; mutation=:missing_source)
        engineering_record = U.route_search_engineering_feedback!(engineering_queue,
            engineering_active.candidate_ref, positive.context, missing_engineering_request)
        @test engineering_record.evaluator_status === :fail_closed
        @test :missing_source in engineering_record.failure_codes
        @test engineering_record.output_digest !== nothing
        @test engineering_record.route_status === :deferred
        @test engineering_queue.entries[engineering_active.candidate_ref].status === :deferred
    end

    @testset "numerical failure and runner exceptions keep typed receipts" begin
        numerical_queue, numerical_active = _up5_active_queue_v1(positive.context)
        numerical_request = _up5_request_v1(positive.context; mutation=:iteration_limit)
        numerical_record = U.route_search_engineering_feedback!(numerical_queue,
            numerical_active.candidate_ref, positive.context, numerical_request)
        @test numerical_record.evaluator_status === :numerical_fail
        @test :iteration_limit in numerical_record.failure_codes
        @test numerical_record.route_status === :failed
        @test numerical_queue.entries[numerical_active.candidate_ref].status === :failed
        @test numerical_record.request_digest == canonical_hash(numerical_request)
        @test numerical_record.output_digest !== nothing

        exception_queue, exception_active = _up5_active_queue_v1(positive.context)
        exception_record = U.route_search_engineering_feedback!(exception_queue,
            exception_active.candidate_ref, positive.context, request;
            executor=_ -> error("UP5 synthetic evaluator failure"))
        @test exception_record.evaluator_status === :program_exception
        @test exception_record.route_status === :failed
        @test exception_record.output_digest === nothing
        @test exception_record.request_digest == canonical_hash(request)
        @test occursin("UP5 synthetic evaluator failure", exception_record.exception_detail)
        @test exception_record.exception_digest !== nothing
        @test exception_queue.entries[exception_active.candidate_ref].status === :failed
    end
end
