include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_engineering_control_fault_graph_obligation.jl"))
using Test

function ecfgo_make_subject(compiled, candidate, bindings, scenarios;
        materialized=(model="ecfgo-adversarial", revision="v1"))
    ECFGO.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, bindings, scenarios,
        materialized, ECFGO.derive_capability_obligations(compiled))
end

function ecfgo_make_context(candidate, compiled, mission, bounds, comparison_scope,
        scenario_scope, subject, scenario)
    ECFGO.make_forward_chain_context(candidate, compiled, registry, mission, bounds,
        comparison_scope, scenario_scope, subject, scenario)
end

function ecfgo_forge(obj, replacements::NamedTuple)
    T = typeof(obj)
    names = fieldnames(T)
    values = ntuple(i -> hasproperty(replacements, names[i]) ?
        getproperty(replacements, names[i]) : getfield(obj, i), length(names))
    T(ECFGO._ECFGO_TOKEN, values...)
end

@testset "current-G3-owned engineering control/fault graph obligation" begin
    result = ecfgo_resolution
    declaration = something(result.declaration)
    subject_binding = something(result.subject_binding)
    graph_binding = ECFGO.forward_graph_binding(ecfgo_context, :control)

    @test result.status === :compiled_contract
    @test result.gap === nothing
    @test ECFGO.validate_engineering_control_fault_graph_compilation(
        result, ecfgo_context)
    @test canonical_hash(result) == result.compilation_hash
    @test result.context_hash == ecfgo_context.context_hash
    @test result.physical_subject_hash == ecfgo_subject.physical_subject_hash

    owned_declarations = Tuple(x for x in
        ecfgo_candidate.realization_control_genome_ref.control
        if x isa ECFGO.EngineeringControlFaultDeclarationV4)
    @test length(owned_declarations) == 1
    @test only(owned_declarations) === ecfgo_declaration
    @test declaration === ecfgo_declaration
    @test canonical_hash(declaration) == declaration.declaration_hash
    @test declaration.specs == ecfgo_specs
    @test declaration.actuator_limit === ecfgo_limit
    @test declaration.timing === ecfgo_timing

    owned_bindings = Tuple(x for x in ecfgo_subject.bindings
        if x isa ECFGO.EngineeringControlFaultSubjectBindingV4)
    @test length(owned_bindings) == 1
    @test only(owned_bindings) === ecfgo_subject_binding
    @test subject_binding === ecfgo_subject_binding
    @test canonical_hash(subject_binding) == subject_binding.binding_hash
    @test subject_binding.candidate_identity_hash ==
        ECFGO._forward_candidate_identity(ecfgo_candidate)
    @test subject_binding.compiled_prefix_hash == ecfgo_compiled.prefix_hash
    @test subject_binding.registry_hash == canonical_hash(registry)
    @test subject_binding.genome_bundle_hash ==
        ecfgo_candidate.canonical_hashes.genome_bundle_hash
    @test subject_binding.realization_control_genome_hash ==
        realization_control_hash(ecfgo_candidate.realization_control_genome_ref)
    @test subject_binding.control_graph_hash == canonical_hash(ecfgo_control_graph_value)
    @test subject_binding.control_graph_binding_hash == canonical_hash(graph_binding)
    @test subject_binding.declaration_hash == canonical_hash(ecfgo_declaration)
    @test subject_binding.actuator_limit_hash == canonical_hash(ecfgo_limit)
    @test subject_binding.timing_hash == canonical_hash(ecfgo_timing)
    @test subject_binding.mission_hash == ECFGO._runtime_decl_hash(ecfgo_mission)
    @test subject_binding.bounds_hash ==
        ECFGO._runtime_decl_hash(ecfgo_bounds_payload)
    @test subject_binding.comparison_scope == ecfgo_comparison_scope
    @test subject_binding.scenario_scope == ecfgo_scenario_scope
    @test subject_binding.scenario_hash == canonical_hash(first(ecfgo_scenarios))

    edges = subject_binding.edges
    @test Tuple(e.stage for e in edges) ==
        (ECFGO.observation_stage, ECFGO.controller_stage, ECFGO.actuator_stage)
    @test Tuple(e.edge_id for e in edges) ==
        ("ecfgo-observation-edge", "ecfgo-controller-edge", "ecfgo-actuator-edge")
    @test all(e -> e.edge isa AtomicMIMOHyperedgeV1, edges)
    @test all(e -> e.edge.role === control, edges)
    @test all(e -> e.edge.program == e.program, edges)
    @test all(e -> canonical_hash(e) == e.ref_hash, edges)
    @test Tuple(e.edge_identity_hash for e in edges) ==
        graph_binding.hyperedge_identity_hashes
    @test Tuple(e.ast_root_identity_hash for e in edges) ==
        graph_binding.ast_root_identity_hashes
    @test Tuple(e.input_node.node_id for e in edges) ==
        ("ecfgo-plant-signal", "ecfgo-observation", "ecfgo-controller-command")
    @test Tuple(e.output_node.node_id for e in edges) ==
        ("ecfgo-observation", "ecfgo-controller-command", "ecfgo-actuator-command")
    @test edges[1].output_node_position == edges[2].input_node_position
    @test edges[2].output_node_position == edges[3].input_node_position
    @test edges[1].output_node_identity_hash == edges[2].input_node_identity_hash
    @test edges[2].output_node_identity_hash == edges[3].input_node_identity_hash

    @test ecfgo_limit.interval.interval.lower == -10 // 1
    @test ecfgo_limit.interval.interval.upper == 10 // 1
    @test ecfgo_limit.actuator_edge_id == edges[3].edge_id
    @test ecfgo_limit.actuator_output_node_id == edges[3].output_node.node_id
    @test ecfgo_timing.transport_delay.value == 2 // 1000
    @test ecfgo_timing.dropout_probability == 1 // 100
    @test ecfgo_timing.dropout_onset.value == 1 // 1
    @test ecfgo_timing.dropout_duration.value == 1 // 10
    @test ecfgo_timing.fault_onset.value == 2 // 1
    @test ecfgo_timing.recovery_deadline.value == 5 // 2
    @test ecfgo_timing.fault_mode === ECFGO.observation_dropout

    for object in (declaration, subject_binding, result)
        @test object.claim_ceiling === screen_only
        @test object.credible_device_count == 0
        @test !object.emits_evidence
        @test !object.execution_authority
        @test !object.promotion_authority
        @test !object.p5_authority
        @test !object.terminal_authority
    end
    manifest = ECFGO.engineering_control_fault_graph_obligation_manifest()
    @test manifest.resolver_inputs == (:forward_chain_context,)
    @test !manifest.execution_available
    @test !manifest.emits_evidence
    @test !manifest.promotion_authority
    @test !manifest.p5_authority
    @test !manifest.terminal_authority
    @test manifest.claim_ceiling === screen_only
    @test manifest.credible_device_count == 0
end

@testset "recoverable ownership gaps" begin
    @test ecfgo_generic_gap.status === :recoverable_gap
    @test ecfgo_generic_gap.declaration === nothing
    @test ecfgo_generic_gap.subject_binding === nothing
    @test ecfgo_generic_gap.gap.reason ===
        :required_current_g3_engineering_control_fault_declaration
    for object in (ecfgo_generic_gap, ecfgo_generic_gap.gap)
        @test object.claim_ceiling === screen_only
        @test object.credible_device_count == 0
        @test !object.emits_evidence
        @test !object.execution_authority
        @test !object.promotion_authority
        @test !object.p5_authority
        @test !object.terminal_authority
    end
    @test ECFGO.validate_engineering_control_fault_graph_compilation(
        ecfgo_generic_gap, ecfgo_generic_context)

    missing_binding_subject = ecfgo_make_subject(ecfgo_compiled,
        ecfgo_candidate, ((binding_kind="non-ecfgo-binding",),), ecfgo_scenarios)
    missing_binding_context = ecfgo_make_context(ecfgo_candidate, ecfgo_compiled,
        ecfgo_mission, ecfgo_bounds_payload, ecfgo_comparison_scope,
        ecfgo_scenario_scope, missing_binding_subject, first(ecfgo_scenarios))
    missing_binding = ECFGO.resolve_engineering_control_fault_graph_obligation(
        missing_binding_context)
    @test missing_binding.status === :recoverable_gap
    @test missing_binding.gap.reason ===
        :required_engineering_control_fault_subject_binding

    duplicate_binding_subject = ecfgo_make_subject(ecfgo_compiled,
        ecfgo_candidate, (ecfgo_subject_binding, ecfgo_subject_binding),
        ecfgo_scenarios)
    duplicate_binding_context = ecfgo_make_context(ecfgo_candidate,
        ecfgo_compiled, ecfgo_mission, ecfgo_bounds_payload,
        ecfgo_comparison_scope, ecfgo_scenario_scope,
        duplicate_binding_subject, first(ecfgo_scenarios))
    duplicate_binding = ECFGO.resolve_engineering_control_fault_graph_obligation(
        duplicate_binding_context)
    @test duplicate_binding.status === :recoverable_gap
    @test duplicate_binding.gap.reason ===
        :unique_engineering_control_fault_subject_binding_required

    duplicate_g3 = RealizationControlGenomeV4(3, 4, _fixture_refs[3],
        _fixture_graph(), ecfgo_control_graph_value;
        control=(ecfgo_declaration, ecfgo_declaration))
    duplicate_candidate = CandidateStatePackageV4("ecfgo-duplicate-declaration",
        _fixture_mission, _fixture_mechanism, _fixture_field, duplicate_g3, registry)
    duplicate_compiled = ECFGO.compile_candidate(duplicate_candidate, registry;
        mission_payload=ecfgo_mission, bounds_payload=ecfgo_bounds_payload,
        comparison_scope=ecfgo_comparison_scope,
        scenario_scope=ecfgo_scenario_scope)
    duplicate_subject = ecfgo_make_subject(duplicate_compiled,
        duplicate_candidate, ((binding_kind="non-ecfgo-binding",),),
        ecfgo_scenarios)
    duplicate_context = ecfgo_make_context(duplicate_candidate,
        duplicate_compiled, ecfgo_mission, ecfgo_bounds_payload,
        ecfgo_comparison_scope, ecfgo_scenario_scope, duplicate_subject,
        first(ecfgo_scenarios))
    duplicate_declaration =
        ECFGO.resolve_engineering_control_fault_graph_obligation(duplicate_context)
    @test duplicate_declaration.status === :recoverable_gap
    @test duplicate_declaration.gap.reason ===
        :unique_current_g3_engineering_control_fault_declaration_required
    @test_throws ArgumentError ECFGO.make_engineering_control_fault_subject_binding(
        duplicate_compiled, registry, ecfgo_mission, ecfgo_bounds_payload,
        ecfgo_comparison_scope, ecfgo_scenario_scope, first(ecfgo_scenarios),
        ecfgo_declaration)
end

@testset "foreign candidate scenario and subject bindings" begin
    foreign_candidate = CandidateStatePackageV4("ecfgo-foreign-candidate",
        _fixture_mission, _fixture_mechanism, _fixture_field, ecfgo_g3, registry)
    foreign_compiled = ECFGO.compile_candidate(foreign_candidate, registry;
        mission_payload=ecfgo_mission, bounds_payload=ecfgo_bounds_payload,
        comparison_scope=ecfgo_comparison_scope,
        scenario_scope=ecfgo_scenario_scope)
    foreign_binding = ECFGO.make_engineering_control_fault_subject_binding(
        foreign_compiled, registry, ecfgo_mission, ecfgo_bounds_payload,
        ecfgo_comparison_scope, ecfgo_scenario_scope, first(ecfgo_scenarios),
        ecfgo_declaration)
    foreign_subject = ecfgo_make_subject(ecfgo_compiled, ecfgo_candidate,
        (foreign_binding,), ecfgo_scenarios)
    foreign_context = ecfgo_make_context(ecfgo_candidate, ecfgo_compiled,
        ecfgo_mission, ecfgo_bounds_payload, ecfgo_comparison_scope,
        ecfgo_scenario_scope, foreign_subject, first(ecfgo_scenarios))
    foreign_result = ECFGO.resolve_engineering_control_fault_graph_obligation(
        foreign_context)
    @test foreign_result.status === :recoverable_gap
    @test foreign_result.gap.reason ===
        :engineering_control_fault_subject_binding_mismatch

    two_scenarios = ((name="ecfgo-scenario-a", fixture="manufactured"),
        (name="ecfgo-scenario-b", fixture="manufactured"))
    two_scope = ("ecfgo-scenario-a", "ecfgo-scenario-b")
    scenario_compiled = ECFGO.compile_candidate(ecfgo_candidate, registry;
        mission_payload=ecfgo_mission, bounds_payload=ecfgo_bounds_payload,
        comparison_scope=ecfgo_comparison_scope, scenario_scope=two_scope)
    scenario_a_binding = ECFGO.make_engineering_control_fault_subject_binding(
        scenario_compiled, registry, ecfgo_mission, ecfgo_bounds_payload,
        ecfgo_comparison_scope, two_scope, two_scenarios[1], ecfgo_declaration)
    scenario_subject = ecfgo_make_subject(scenario_compiled, ecfgo_candidate,
        (scenario_a_binding,), two_scenarios)
    scenario_b_context = ecfgo_make_context(ecfgo_candidate, scenario_compiled,
        ecfgo_mission, ecfgo_bounds_payload, ecfgo_comparison_scope, two_scope,
        scenario_subject, two_scenarios[2])
    foreign_scenario = ECFGO.resolve_engineering_control_fault_graph_obligation(
        scenario_b_context)
    @test foreign_scenario.status === :recoverable_gap
    @test foreign_scenario.gap.reason ===
        :engineering_control_fault_subject_binding_mismatch

    @test_throws ArgumentError ECFGO.make_engineering_control_fault_subject_binding(
        ecfgo_compiled, registry, ecfgo_mission, ecfgo_bounds_payload,
        ecfgo_comparison_scope, ecfgo_scenario_scope,
        (name="foreign-scenario", fixture="manufactured"), ecfgo_declaration)
end

@testset "graph declaration adversaries" begin
    wrong_id_specs = (ecfgo_specs[1], ecfgo_specs[2],
        ECFGO.EngineeringControlEdgeSpecV4(ECFGO.actuator_stage,
            "absent-actuator", OperatorRefV1("ECFGO_ACTUATE", "v1")))
    wrong_id_limit = ECFGO.make_engineering_actuator_limit(
        "absent-actuator", "ecfgo-actuator-command", ecfgo_limit.interval)
    wrong_id_declaration = ECFGO.declare_engineering_control_fault_graph(
        "ecfgo-wrong-edge", wrong_id_specs, wrong_id_limit, ecfgo_timing)
    wrong_id_g3 = RealizationControlGenomeV4(3, 4, _fixture_refs[3],
        _fixture_graph(), ecfgo_control_graph_value;
        control=(wrong_id_declaration,))
    wrong_id_candidate = CandidateStatePackageV4("ecfgo-wrong-edge",
        _fixture_mission, _fixture_mechanism, _fixture_field, wrong_id_g3, registry)
    wrong_id_compiled = ECFGO.compile_candidate(wrong_id_candidate, registry;
        mission_payload=ecfgo_mission, bounds_payload=ecfgo_bounds_payload,
        comparison_scope=ecfgo_comparison_scope,
        scenario_scope=ecfgo_scenario_scope)
    @test_throws ArgumentError ECFGO.make_engineering_control_fault_subject_binding(
        wrong_id_compiled, registry, ecfgo_mission, ecfgo_bounds_payload,
        ecfgo_comparison_scope, ecfgo_scenario_scope, first(ecfgo_scenarios),
        wrong_id_declaration)

    wrong_root_specs = (ecfgo_specs[1], ecfgo_specs[2],
        ECFGO.EngineeringControlEdgeSpecV4(ECFGO.actuator_stage,
            "ecfgo-actuator-edge", OperatorRefV1("ECFGO_CONTROL", "v1")))
    wrong_root_declaration = ECFGO.declare_engineering_control_fault_graph(
        "ecfgo-wrong-root", wrong_root_specs, ecfgo_limit, ecfgo_timing)
    wrong_root_g3 = RealizationControlGenomeV4(3, 4, _fixture_refs[3],
        _fixture_graph(), ecfgo_control_graph_value;
        control=(wrong_root_declaration,))
    wrong_root_candidate = CandidateStatePackageV4("ecfgo-wrong-root",
        _fixture_mission, _fixture_mechanism, _fixture_field, wrong_root_g3,
        registry)
    wrong_root_compiled = ECFGO.compile_candidate(wrong_root_candidate, registry;
        mission_payload=ecfgo_mission, bounds_payload=ecfgo_bounds_payload,
        comparison_scope=ecfgo_comparison_scope,
        scenario_scope=ecfgo_scenario_scope)
    @test_throws ArgumentError ECFGO.make_engineering_control_fault_subject_binding(
        wrong_root_compiled, registry, ecfgo_mission, ecfgo_bounds_payload,
        ecfgo_comparison_scope, ecfgo_scenario_scope, first(ecfgo_scenarios),
        wrong_root_declaration)

    @test_throws ArgumentError ECFGO.declare_engineering_control_fault_graph(
        "reversed", reverse(ecfgo_specs), ecfgo_limit, ecfgo_timing)
    detached_limit = ECFGO.make_engineering_actuator_limit(
        "ecfgo-actuator-edge", "ecfgo-observation", ecfgo_limit.interval)
    detached_declaration = ECFGO.declare_engineering_control_fault_graph(
        "detached-limit", ecfgo_specs, detached_limit, ecfgo_timing)
    detached_g3 = RealizationControlGenomeV4(3, 4, _fixture_refs[3],
        _fixture_graph(), ecfgo_control_graph_value;
        control=(detached_declaration,))
    detached_candidate = CandidateStatePackageV4("ecfgo-detached-limit",
        _fixture_mission, _fixture_mechanism, _fixture_field, detached_g3, registry)
    detached_compiled = ECFGO.compile_candidate(detached_candidate, registry;
        mission_payload=ecfgo_mission, bounds_payload=ecfgo_bounds_payload,
        comparison_scope=ecfgo_comparison_scope,
        scenario_scope=ecfgo_scenario_scope)
    @test_throws ArgumentError ECFGO.make_engineering_control_fault_subject_binding(
        detached_compiled, registry, ecfgo_mission, ecfgo_bounds_payload,
        ecfgo_comparison_scope, ecfgo_scenario_scope, first(ecfgo_scenarios),
        detached_declaration)
end

@testset "sealed hashes timing and authority" begin
    @test_throws ArgumentError ECFGO.make_engineering_control_fault_timing(
        NonnegativeQuantityV1(0, ecfgo_seconds), 101//100,
        NonnegativeQuantityV1(1, ecfgo_seconds),
        NonnegativeQuantityV1(1, ecfgo_seconds),
        NonnegativeQuantityV1(2, ecfgo_seconds),
        NonnegativeQuantityV1(3, ecfgo_seconds), ECFGO.actuator_stuck)
    @test_throws ArgumentError ECFGO.make_engineering_control_fault_timing(
        NonnegativeQuantityV1(0, ecfgo_seconds), 0//1,
        NonnegativeQuantityV1(1, ecfgo_seconds),
        NonnegativeQuantityV1(0, ecfgo_seconds),
        NonnegativeQuantityV1(2, ecfgo_seconds),
        NonnegativeQuantityV1(3, ecfgo_seconds), ECFGO.actuator_stuck)
    @test_throws ArgumentError ECFGO.make_engineering_control_fault_timing(
        NonnegativeQuantityV1(0, ecfgo_seconds), 0//1,
        NonnegativeQuantityV1(1, ecfgo_seconds),
        NonnegativeQuantityV1(1, ecfgo_seconds),
        NonnegativeQuantityV1(2, ecfgo_seconds),
        NonnegativeQuantityV1(2, ecfgo_seconds), ECFGO.actuator_stuck)

    fake_token = ECFGO._ECFGOToken()
    for T in (ECFGO.EngineeringActuatorLimitV4,
            ECFGO.EngineeringControlFaultTimingV4,
            ECFGO.EngineeringControlFaultDeclarationV4,
            ECFGO.EngineeringControlGraphEdgeRefV4,
            ECFGO.EngineeringControlFaultSubjectBindingV4,
            ECFGO.EngineeringControlFaultGraphGapV4,
            ECFGO.EngineeringControlFaultGraphCompilationV4)
        @test_throws ArgumentError T(fake_token)
        @test_throws ArgumentError T(nothing)
    end

    bad_digest = digest256_text("ecfgo-forged-stored-hash")
    stored_objects = (ecfgo_limit, ecfgo_timing, ecfgo_declaration,
        first(ecfgo_subject_binding.edges), ecfgo_subject_binding,
        ecfgo_generic_gap.gap, ecfgo_resolution)
    hash_fields = (:limit_hash, :timing_hash, :declaration_hash, :ref_hash,
        :binding_hash, :gap_hash, :compilation_hash)
    for (object, field) in zip(stored_objects, hash_fields)
        forged = ecfgo_forge(object, NamedTuple{(field,)}((bad_digest,)))
        @test_throws ArgumentError canonical_hash(forged)
    end

    authority_binding = ecfgo_forge(ecfgo_subject_binding,
        (execution_authority=true,))
    @test_throws ArgumentError canonical_hash(authority_binding)
    authority_result = ecfgo_forge(ecfgo_resolution, (p5_authority=true,))
    @test_throws ArgumentError canonical_hash(authority_result)

    for object in (ecfgo_declaration, ecfgo_subject_binding,
            ecfgo_generic_gap.gap, ecfgo_resolution, ecfgo_generic_gap)
        forged_ceiling = ecfgo_forge(object, (claim_ceiling=none,))
        @test_throws ArgumentError canonical_hash(forged_ceiling)
        forged_count = ecfgo_forge(object, (credible_device_count=1,))
        @test_throws ArgumentError canonical_hash(forged_count)
    end
end

println("ENGINEERING_CONTROL_FAULT_GRAPH_OBLIGATION_FOCUSED_EXIT_CODE=0")
