using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples", "runtime_v4_forward_chain_context.jl"))
const R = ForwardChainContextRuntime
const FC = forward_context
const FH = digest256_text("forward-context-adversarial")

function _test_subject(compiled=forward_compiled;
        scenarios=forward_scenarios,
        bindings=((binding_kind="typed_fixture_materialization", candidate_ref=compiled.candidate.identity_ref),),
        materialized=(materialization="immutable-software-fixture", revision="v1"),
        obligations=R.derive_capability_obligations(compiled),
        prefix_hash=compiled.prefix_hash,
        bundle_hash=compiled.candidate.canonical_hashes.genome_bundle_hash,
        mission_hash=compiled.minimality_scope.mission_hash,
        bounds_hash=compiled.minimality_scope.bounds_hash)
    R.ExecutablePhysicalSubjectV4(prefix_hash, bundle_hash, mission_hash, bounds_hash,
        bindings, scenarios, materialized, obligations)
end

function _test_context(candidate_value=candidate, compiled_value=forward_compiled,
        registry_value=registry, subject_value=forward_subject;
        mission=forward_mission_payload, bounds=forward_bounds_payload,
        comparison=forward_comparison_scope, scope=forward_scenario_scope,
        scenario=first(forward_scenarios))
    R.make_forward_chain_context(candidate_value, compiled_value, registry_value,
        mission, bounds, comparison, scope, subject_value, scenario)
end

function _forge_context(context::R.ForwardChainContextV4;
        genome_bindings=context.genome_bindings, obligations=context.obligations,
        candidate_hash=context.candidate_hash, registry_hash=context.registry_hash,
        scenario_hash=context.scenario_hash, obligation_hashes=context.obligation_hashes,
        context_hash=context.context_hash)
    R.ForwardChainContextV4(R._FORWARD_CHAIN_CONTEXT_TOKEN,
        context.candidate, context.compiled, context.registry,
        context.mission_payload, context.bounds_payload, context.comparison_scope,
        context.scenario_scope, context.subject, context.scenario, genome_bindings,
        obligations, candidate_hash, registry_hash, scenario_hash,
        obligation_hashes, context_hash)
end

@testset "ForwardChainContext exact positive binding" begin
    @test R.validate_forward_chain_context(FC) == FC.context_hash
    @test canonical_hash(FC) == FC.context_hash
    @test length(forward_contexts) == length(forward_scenarios) == 2
    @test Tuple(c.scenario_hash for c in forward_contexts) ==
        Tuple(canonical_hash(s) for s in forward_scenarios)
    @test all(canonical_hash(c) == c.context_hash for c in forward_contexts)
    @test FC.candidate_hash == R._forward_candidate_identity(candidate)
    @test FC.registry_hash == canonical_hash(registry)
    @test FC.subject === forward_subject
    @test FC.compiled === forward_compiled
    @test FC.scenario_hash == canonical_hash(first(forward_scenarios))
    @test FC.obligations == R.derive_capability_obligations(forward_compiled)
    @test FC.obligation_hashes == Tuple(canonical_hash(o) for o in FC.obligations)
    @test Tuple(g.role for g in FC.genome_bindings) ==
        (:mechanism, :field_geometry, :realization_control)
    @test Tuple(g.role for g in R.forward_genome_binding(FC, :realization_control).graph_bindings) ==
        (:realization, :control)
    @test R.forward_graph_binding(FC, :mechanism).graph === forward_compiled.mechanism_graph
    @test R.forward_graph_binding(FC, :field_geometry).graph === forward_compiled.field_geometry_graph
    @test R.forward_graph_binding(FC, :realization).graph === forward_compiled.realization_graph
    @test R.forward_graph_binding(FC, :control).graph === forward_compiled.control_graph
    @test R.forward_genome_binding(FC, :mechanism).contract_ref == registry.mechanism
    @test R.forward_genome_binding(FC, :field_geometry).contract_ref == registry.field_geometry
    @test R.forward_genome_binding(FC, :realization_control).contract_ref == registry.realization_control
    @test R.forward_genome_binding(FC, :mechanism).genome_hash == mechanism_hash(candidate.mechanism_genome_ref)
    @test R.forward_genome_binding(FC, :field_geometry).genome_hash == field_geometry_hash(candidate.field_geometry_genome_ref)
    @test R.forward_genome_binding(FC, :realization_control).genome_hash == realization_control_hash(candidate.realization_control_genome_ref)
    @test !isempty(R.forward_graph_binding(FC, :mechanism).ast_root_identity_hashes)
    @test R.forward_chain_context_manifest() == (
        schema="fusionconceptai:runtime-v4-forward-chain-context",
        revision="forward-chain-context-v1", purpose=:validated_forward_identity,
        emits_evidence=false, terminal_authority=false)
    @test !hasproperty(FC, :stage_outcome)
    @test !hasproperty(FC, :evidence)
    @test !hasproperty(FC, :promotion)
    @test !hasproperty(FC, :terminal_disposition)
end

@testset "ForwardChainContext rejects candidate, registry, Genome, and graph substitution" begin
    foreign_candidate = CandidateStatePackageV4("foreign-candidate-identity",
        candidate.mission_contract_ref, candidate.mechanism_genome_ref,
        candidate.field_geometry_genome_ref, candidate.realization_control_genome_ref,
        registry)
    @test foreign_candidate.canonical_hashes == candidate.canonical_hashes
    @test_throws ArgumentError _test_context(foreign_candidate)

    foreign_field_ref = GenomeContractRef("urn:fusion:runtime:foreign-field", "v4",
        digest256_text("foreign-field-schema"), digest256_text("foreign-field-canon"), "runtime")
    foreign_registry = GenomeContractRegistryV4(registry.mechanism, foreign_field_ref,
        registry.realization_control)
    @test_throws ArgumentError _test_context(candidate, forward_compiled, foreign_registry)

    duplicate_registry = GenomeContractRegistryV4(_fixture_refs[1], _fixture_refs[1], _fixture_refs[3])
    duplicate_field = FieldGeometryGenomeV4(2, _fixture_refs[1], _fixture_graph())
    duplicate_candidate = CandidateStatePackageV4("duplicate-contract-role-fixture",
        _fixture_mission, _fixture_mechanism, duplicate_field, _fixture_realization,
        duplicate_registry)
    duplicate_compiled = R.compile_candidate(duplicate_candidate, duplicate_registry;
        mission_payload=forward_mission_payload, bounds_payload=forward_bounds_payload,
        comparison_scope=forward_comparison_scope, scenario_scope=forward_scenario_scope)
    duplicate_subject = _test_subject(duplicate_compiled)
    @test_throws ArgumentError _test_context(duplicate_candidate, duplicate_compiled,
        duplicate_registry, duplicate_subject)

    c = forward_compiled
    swapped_graph_compiled = R.CompiledCandidatePrefixV4(c.candidate, c.mission_payload,
        c.bounds_payload, c.minimality_scope, c.mechanism_graph, c.mechanism_graph,
        c.realization_graph, c.control_graph, c.normalized_regions,
        c.normalized_interfaces, c.normalized_boundaries, c.unresolved_nonterminals,
        c.capability_obligations, c.compilation_status)
    swapped_subject = _test_subject(swapped_graph_compiled)
    @test_throws ArgumentError _test_context(candidate, swapped_graph_compiled,
        registry, swapped_subject)

    duplicate_node_graph = TypedOperatorHypergraphV1(
        (node(:region, _fixture_type; id="duplicate-node"),
         node(:boundary, _fixture_type; id="duplicate-node")), (),
        registry=_fixture_ops)
    @test_throws ArgumentError R._make_forward_graph_binding(:field_geometry,
        duplicate_node_graph)
    mechanism_graph = forward_compiled.mechanism_graph
    duplicate_edge_graph = TypedOperatorHypergraphV1(mechanism_graph.nodes,
        (mechanism_graph.hyperedges[1], mechanism_graph.hyperedges[1]),
        registry=_fixture_ops)
    @test_throws ArgumentError R._make_forward_graph_binding(:mechanism,
        duplicate_edge_graph)

    @test_throws ArgumentError R.forward_genome_binding(FC, :missing_role)
    @test_throws ArgumentError R.forward_graph_binding(FC, :missing_role)
end

@testset "ForwardChainContext rejects mission, bounds, scope, and subject drift" begin
    @test_throws ArgumentError _test_context(; mission=(mission_id="wrong",))
    @test_throws ArgumentError _test_context(; bounds=(scope="wrong",))
    @test_throws ArgumentError _test_context(; comparison=("wrong-comparison",))
    @test_throws ArgumentError _test_context(; scope=("startup",))

    @test_throws ArgumentError _test_context(candidate, forward_compiled, registry,
        _test_subject(; prefix_hash=FH))
    @test_throws ArgumentError _test_context(candidate, forward_compiled, registry,
        _test_subject(; bundle_hash=FH))
    @test_throws ArgumentError _test_context(candidate, forward_compiled, registry,
        _test_subject(; mission_hash=FH))
    @test_throws ArgumentError _test_context(candidate, forward_compiled, registry,
        _test_subject(; bounds_hash=FH))
    @test_throws ArgumentError _test_context(candidate, forward_compiled, registry,
        _test_subject(; bindings=()))
    @test_throws ArgumentError _test_context(candidate, forward_compiled, registry,
        _test_subject(; materialized=nothing))
    @test_throws ArgumentError _test_context(candidate, forward_compiled, registry,
        _test_subject(; obligations=()))
end

@testset "ForwardChainContext scenario membership and exact batch order" begin
    @test_throws ArgumentError _test_context(; scenario=(name="startup", load_case="foreign"))
    @test_throws ArgumentError _test_context(; scenario=(load_case="nominal",))

    reordered = reverse(forward_scenarios)
    reordered_subject = _test_subject(; scenarios=reordered)
    @test_throws ArgumentError _test_context(candidate, forward_compiled, registry,
        reordered_subject; scenario=first(reordered))
    duplicate_subject = _test_subject(; scenarios=(forward_scenarios[1], forward_scenarios[1]))
    @test_throws ArgumentError _test_context(candidate, forward_compiled, registry,
        duplicate_subject)

    @test_throws ArgumentError R.make_forward_chain_contexts(candidate,
        forward_compiled, registry, forward_mission_payload, forward_bounds_payload,
        forward_comparison_scope, forward_scenario_scope, forward_subject,
        (first(forward_scenarios),))
    @test_throws ArgumentError R.make_forward_chain_contexts(candidate,
        forward_compiled, registry, forward_mission_payload, forward_bounds_payload,
        forward_comparison_scope, forward_scenario_scope, forward_subject, reordered)
    @test_throws ArgumentError R.make_forward_chain_contexts(candidate,
        forward_compiled, registry, forward_mission_payload, forward_bounds_payload,
        forward_comparison_scope, forward_scenario_scope, forward_subject,
        (forward_scenarios[1], forward_scenarios[1]))
    @test_throws ArgumentError R.make_forward_chain_contexts(candidate,
        forward_compiled, registry, forward_mission_payload, forward_bounds_payload,
        forward_comparison_scope, forward_scenario_scope, forward_subject, ())
end

@testset "ForwardChainContext validators recompute sealed bodies" begin
    @test_throws MethodError R.ForwardGraphBindingV4(:mechanism,
        forward_compiled.mechanism_graph, FH, (), (), (), FH)
    @test_throws MethodError R.ForwardGenomeBindingV4(:mechanism,
        registry.mechanism, FH, (), FH)

    graph = R.forward_graph_binding(FC, :mechanism)
    forged_graph = R.ForwardGraphBindingV4(R._FORWARD_CHAIN_CONTEXT_TOKEN,
        graph.role, graph.graph, graph.canonical_graph_hash,
        graph.node_identity_hashes, graph.hyperedge_identity_hashes,
        graph.ast_root_identity_hashes, FH)
    @test_throws ArgumentError canonical_hash(forged_graph)
    forged_roots = R.ForwardGraphBindingV4(R._FORWARD_CHAIN_CONTEXT_TOKEN,
        graph.role, graph.graph, graph.canonical_graph_hash,
        graph.node_identity_hashes, graph.hyperedge_identity_hashes, (),
        graph.binding_hash)
    @test_throws ArgumentError canonical_hash(forged_roots)

    genome = R.forward_genome_binding(FC, :mechanism)
    forged_genome = R.ForwardGenomeBindingV4(R._FORWARD_CHAIN_CONTEXT_TOKEN,
        genome.role, genome.contract_ref, FH, genome.graph_bindings,
        genome.binding_hash)
    @test_throws ArgumentError canonical_hash(forged_genome)

    @test_throws ArgumentError canonical_hash(_forge_context(FC; context_hash=FH))
    @test_throws ArgumentError canonical_hash(_forge_context(FC; candidate_hash=FH))
    @test_throws ArgumentError canonical_hash(_forge_context(FC; registry_hash=FH))
    @test_throws ArgumentError canonical_hash(_forge_context(FC; scenario_hash=FH))
    @test_throws ArgumentError canonical_hash(_forge_context(FC;
        obligation_hashes=(FH,)))
    @test_throws ArgumentError canonical_hash(_forge_context(FC; obligations=()))
    @test_throws MethodError _forge_context(FC;
        genome_bindings=(FC.genome_bindings[1], FC.genome_bindings[2]))
    @test_throws ArgumentError canonical_hash(_forge_context(FC;
        genome_bindings=(FC.genome_bindings[2], FC.genome_bindings[1],
            FC.genome_bindings[3])))
    @test_throws ArgumentError canonical_hash(_forge_context(FC;
        genome_bindings=(FC.genome_bindings[1], FC.genome_bindings[1],
            FC.genome_bindings[3])))
end
