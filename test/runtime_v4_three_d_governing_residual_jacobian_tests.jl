using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_three_d_governing_residual_jacobian.jl"))

const TDRJH = digest256_text("three-d-residual-jacobian-adversarial")

@testset "generic G2 retains exact residual/Jacobian gaps" begin
    @test tdrj_generic_resolution.status === :recoverable_gap
    @test tdrj_generic_resolution.ownership === nothing
    @test tdrj_generic_resolution.recoverable_gaps ==
        (TDRJ._TDRJ_GAP, TDRJ._TDRJ_BINDING_GAP,
         TDRJ._TDRJ_DOWNSTREAM_GAPS...)
    @test canonical_hash(tdrj_generic_resolution) ==
        tdrj_generic_resolution.resolution_hash
    @test tdrj_generic_resolution.claim_ceiling == screen_only
    @test !tdrj_generic_resolution.provider_selected
    @test !tdrj_generic_resolution.provider_executed
    @test !tdrj_generic_resolution.emits_evidence
    @test !tdrj_generic_resolution.grants_pass
    @test !tdrj_generic_resolution.promotion_authority
    @test !tdrj_generic_resolution.p5_ready
    @test !tdrj_generic_resolution.terminal_authority
    @test tdrj_generic_resolution.credible_physical_device_count == 0
end

@testset "two-state G2 owns an ordered exact-cover pair set" begin
    declaration = tdrj_declaration
    @test declaration isa
        TDRJ.ThreeDGoverningResidualJacobianDeclarationSetV4
    @test length(declaration.pairs) == 2
    @test Tuple(pair.state_node_id for pair in declaration.pairs) ==
        ("tdrj-pressure-state", "tdrj-magnetic-state")
    @test Tuple(pair.residual_operator.edge_id for pair in declaration.pairs) ==
        ("tdrj-residual-edge-1", "tdrj-residual-edge-2")
    @test Tuple(pair.jacobian_operator.edge_id for pair in declaration.pairs) ==
        ("tdrj-jacobian-edge-1", "tdrj-jacobian-edge-2")
    @test canonical_hash(declaration) == declaration.declaration_hash
    @test length(unique(pair.state_node_identity_hash
        for pair in declaration.pairs)) == 2
    @test length(unique(pair.residual_operator.edge_identity_hash
        for pair in declaration.pairs)) == 2
    @test length(unique(pair.jacobian_operator.edge_identity_hash
        for pair in declaration.pairs)) == 2
    @test length(unique(pair.residual_operator.ast_root_identity_hash
        for pair in declaration.pairs)) == 2
    @test length(unique(pair.jacobian_operator.ast_root_identity_hash
        for pair in declaration.pairs)) == 2

    for (i, pair) in enumerate(declaration.pairs)
        residual = pair.residual_operator
        jacobian = pair.jacobian_operator
        @test pair isa TDRJ.ThreeDResidualJacobianPairV4
        @test canonical_hash(pair) == pair.pair_hash
        @test canonical_hash(residual) == residual.identity_hash
        @test canonical_hash(jacobian) == jacobian.identity_hash
        @test pair.state_type == tdrj_state_types[i]
        @test residual.operator_kind === :residual
        @test residual.edge_role === governing
        @test residual.domain_node_id == pair.state_node_id
        @test residual.domain_type == pair.state_type
        @test residual.codomain_type == tdrj_residual_types[i]
        @test jacobian.operator_kind === :jacobian
        @test jacobian.edge_role === constraint
        @test jacobian.domain_node_id == pair.state_node_id
        @test jacobian.domain_type == pair.state_type
        @test jacobian.codomain_type == tdrj_jacobian_types[i]
        @test jacobian.codomain_type == TDRJ._tdrj_jacobian_type(
            pair.state_type, residual.codomain_type)
        @test residual.edge_identity_hash != jacobian.edge_identity_hash
        @test residual.ast_root_identity_hash !=
            jacobian.ast_root_identity_hash
    end
end

@testset "typed subject binding and context ownership seal the full set" begin
    binding = tdrj_subject_binding
    pairs = tdrj_declaration.pairs
    @test canonical_hash(binding) == binding.binding_hash
    @test binding.declaration_hash == tdrj_declaration.declaration_hash
    @test binding.candidate_hash == tdrj_context.candidate_hash
    @test binding.compiled_prefix_hash == tdrj_context.compiled.prefix_hash
    @test binding.field_geometry_genome_hash ==
        tdrj_context.candidate.canonical_hashes.field_geometry_hash
    @test binding.field_geometry_graph_hash ==
        tdrj_declaration.field_geometry_graph_hash
    @test binding.field_geometry_graph_binding_hash ==
        tdrj_declaration.field_geometry_graph_binding_hash
    @test binding.ordered_pair_hashes ==
        Tuple(pair.pair_hash for pair in pairs)
    @test binding.ordered_residual_ast_root_identity_hashes ==
        Tuple(pair.residual_operator.ast_root_identity_hash for pair in pairs)
    @test binding.ordered_jacobian_ast_root_identity_hashes ==
        Tuple(pair.jacobian_operator.ast_root_identity_hash for pair in pairs)
    @test binding.mission_hash == TDRJ._runtime_decl_hash(tdrj_mission)
    @test binding.bounds_hash == TDRJ._runtime_decl_hash(tdrj_bounds)
    @test binding.scenario_hash == canonical_hash(tdrj_scenario)

    @test tdrj_resolution.status === :compiled
    @test tdrj_resolution.recoverable_gaps == TDRJ._TDRJ_DOWNSTREAM_GAPS
    ownership = tdrj_resolution.ownership
    @test ownership isa TDRJ.ThreeDGoverningResidualJacobianOwnershipV4
    @test canonical_hash(ownership) == ownership.ownership_hash
    @test TDRJ.validate_three_d_governing_residual_jacobian_ownership(
        tdrj_context, ownership) == ownership.ownership_hash
    @test !TDRJ.validate_three_d_governing_residual_jacobian_ownership(
        ownership)
    @test ownership.context_hash == tdrj_context.context_hash
    @test ownership.candidate_hash == tdrj_context.candidate_hash
    @test ownership.compiled_prefix_hash == tdrj_context.compiled.prefix_hash
    @test ownership.registry_hash == tdrj_context.registry_hash
    @test ownership.physical_subject_hash ==
        tdrj_context.subject.physical_subject_hash
    @test ownership.declaration_hash == tdrj_declaration.declaration_hash
    @test ownership.binding_hash == binding.binding_hash
    @test Tuple(pair.pair_hash for pair in ownership.pairs) ==
        binding.ordered_pair_hashes
    @test ownership.claim_ceiling == screen_only
    @test !ownership.provider_selected
    @test !ownership.provider_executed
    @test !ownership.emits_evidence
    @test !ownership.grants_pass
    @test !ownership.promotion_authority
    @test !ownership.p5_ready
    @test !ownership.terminal_authority
    @test ownership.credible_physical_device_count == 0
end

function tdrj_bad_binding(; first_jacobian_type=tdrj_jacobian_types[1],
        first_jacobian_domain::Int=1,
        first_residual_role::HyperedgeRoleV1=governing,
        extra_residual::Bool=false)
    residual_roles = (first_residual_role, governing)
    jacobian_domains = (first_jacobian_domain, 2)
    jacobian_types = (first_jacobian_type, tdrj_jacobian_types[2])
    registry = OperatorRegistryV1()
    residual_ids = ("TDRJ_BAD_RESIDUAL_1", "TDRJ_BAD_RESIDUAL_2")
    jacobian_ids = ("TDRJ_BAD_JACOBIAN_1", "TDRJ_BAD_JACOBIAN_2")
    for i in 1:2
        registry = register_operator(registry, tdrj_operator_manifest(
            residual_ids[i], Symbol(residual_roles[i]), tdrj_state_types[i],
            tdrj_residual_types[i]))
        input_type = tdrj_state_types[jacobian_domains[i]]
        registry = register_operator(registry, tdrj_operator_manifest(
            jacobian_ids[i], :constraint, input_type, jacobian_types[i]))
    end
    make_program(id, input_type) = begin
        input = ASTInputV1(1, input_type)
        root = ASTApplyV1(OperatorRefV1(id, "v1"), (1,), (;);
            registry=registry, input_types=(input_type,))
        TypedASTProgramV1((input, root), (2,), (1,); registry=registry)
    end
    residual_edges = ntuple(i -> AtomicMIMOHyperedgeV1(
        "tdrj-bad-residual-edge-$i", (MIMOInputBindingV1(1, i),),
        (MIMOOutputBindingV1(1, 2 + i),),
        make_program(residual_ids[i], tdrj_state_types[i]),
        residual_roles[i]; registry=registry), 2)
    jacobian_edges = ntuple(i -> begin
        domain_index = jacobian_domains[i]
        AtomicMIMOHyperedgeV1("tdrj-bad-jacobian-edge-$i",
            (MIMOInputBindingV1(1, domain_index),),
            (MIMOOutputBindingV1(1, 4 + i),),
            make_program(jacobian_ids[i], tdrj_state_types[domain_index]),
            constraint; registry=registry)
    end, 2)
    nodes = (node(:state, tdrj_state_types[1]; id="tdrj-bad-state-1"),
        node(:state, tdrj_state_types[2]; id="tdrj-bad-state-2"),
        node(:residual, tdrj_residual_types[1]; id="tdrj-bad-residual-1"),
        node(:residual, tdrj_residual_types[2]; id="tdrj-bad-residual-2"),
        node(:jacobian, jacobian_types[1]; id="tdrj-bad-jacobian-1"),
        node(:jacobian, jacobian_types[2]; id="tdrj-bad-jacobian-2"),
        (extra_residual ?
            (node(:residual, tdrj_residual_types[1];
                id="tdrj-unowned-residual"),) : ())...)
    graph = TypedOperatorHypergraphV1(nodes,
        (residual_edges..., jacobian_edges...); registry=registry)
    TDRJ._make_forward_graph_binding(:field_geometry, graph)
end

tdrj_bad_selectors() = (
    (state_node_id="tdrj-bad-state-1",
     residual_edge_id="tdrj-bad-residual-edge-1",
     jacobian_edge_id="tdrj-bad-jacobian-edge-1"),
    (state_node_id="tdrj-bad-state-2",
     residual_edge_id="tdrj-bad-residual-edge-2",
     jacobian_edge_id="tdrj-bad-jacobian-edge-2"))

@testset "full state and output coverage fail closed" begin
    @test_throws ArgumentError TDRJ.declare_three_d_governing_residual_jacobian_set(
        tdrj_prebinding; declaration_id="missing-state",
        pair_selectors=(tdrj_pair_selectors[1],))
    @test_throws ArgumentError TDRJ.declare_three_d_governing_residual_jacobian_set(
        tdrj_prebinding; declaration_id="duplicate-state",
        pair_selectors=(tdrj_pair_selectors[1], tdrj_pair_selectors[1]))
    @test_throws ArgumentError TDRJ.declare_three_d_governing_residual_jacobian_set(
        tdrj_prebinding; declaration_id="extra-state",
        pair_selectors=(tdrj_pair_selectors...,
            (state_node_id="foreign-state",
             residual_edge_id="tdrj-residual-edge-1",
             jacobian_edge_id="tdrj-jacobian-edge-1")))
    shared = (
        (state_node_id="tdrj-pressure-state",
         residual_edge_id="tdrj-residual-edge-1",
         jacobian_edge_id="tdrj-jacobian-edge-1"),
        (state_node_id="tdrj-magnetic-state",
         residual_edge_id="tdrj-residual-edge-1",
         jacobian_edge_id="tdrj-jacobian-edge-1"))
    @test_throws ArgumentError TDRJ.declare_three_d_governing_residual_jacobian_set(
        tdrj_prebinding; declaration_id="shared-pair", pair_selectors=shared)
    @test_throws ArgumentError TDRJ.declare_three_d_governing_residual_jacobian_set(
        tdrj_bad_binding(extra_residual=true);
        declaration_id="unowned-residual",
        pair_selectors=tdrj_bad_selectors())
end

@testset "domain codomain unit rank dimension and role checks fail closed" begin
    @test TDRJ._tdrj_jacobian_type(tdrj_state_types[1],
        tdrj_residual_types[1]) == tdrj_jacobian_types[1]
    @test TDRJ._tdrj_jacobian_type(tdrj_state_types[2],
        tdrj_residual_types[2]) == tdrj_jacobian_types[2]
    two_d_state = PhysicalType(:state_scalar, 0, 2,
        TemporalTypeV1(static_time), tdrj_pressure_unit)
    @test_throws ArgumentError TDRJ._tdrj_jacobian_type(two_d_state,
        tdrj_residual_types[1])
    algebraic_residual = PhysicalType(:governing_residual, 0, 3,
        TemporalTypeV1(algebraic_time), tdrj_pressure_unit)
    @test_throws ArgumentError TDRJ._tdrj_jacobian_type(
        tdrj_state_types[1], algebraic_residual)

    wrong_unit = PhysicalType(:residual_jacobian, 0, 3,
        TemporalTypeV1(static_time),
        UnitSignature((0, 1, 0, 0, 0, 0, 0)))
    @test_throws ArgumentError TDRJ.declare_three_d_governing_residual_jacobian_set(
        tdrj_bad_binding(first_jacobian_type=wrong_unit);
        declaration_id="wrong-unit", pair_selectors=tdrj_bad_selectors())
    wrong_rank = PhysicalType(:residual_jacobian, 1, 3,
        TemporalTypeV1(static_time), tdrj_unit)
    @test_throws ArgumentError TDRJ.declare_three_d_governing_residual_jacobian_set(
        tdrj_bad_binding(first_jacobian_type=wrong_rank);
        declaration_id="wrong-rank", pair_selectors=tdrj_bad_selectors())
    @test_throws ArgumentError TDRJ.declare_three_d_governing_residual_jacobian_set(
        tdrj_bad_binding(first_jacobian_domain=2);
        declaration_id="wrong-domain", pair_selectors=tdrj_bad_selectors())
    @test_throws ArgumentError TDRJ.declare_three_d_governing_residual_jacobian_set(
        tdrj_bad_binding(first_residual_role=constraint);
        declaration_id="wrong-role", pair_selectors=tdrj_bad_selectors())
end

@testset "stored hashes authority and subject links cannot be forged" begin
    pair = first(tdrj_declaration.pairs)
    op = pair.residual_operator
    forged_op = TDRJ.ThreeDResidualJacobianOperatorIdentityV4(
        TDRJ._TDRJ_TOKEN, op.operator_kind, op.edge_id, op.edge_role,
        op.edge_position, op.edge_identity_hash, op.program_hash,
        op.program_root_index, op.ast_root_identity_hash, op.operator_ref,
        op.operator_manifest_hash, op.domain_node_id,
        op.domain_node_identity_hash, op.domain_type, op.codomain_node_id,
        op.codomain_node_identity_hash, op.codomain_type, TDRJH)
    @test_throws ArgumentError canonical_hash(forged_op)

    forged_pair = TDRJ.ThreeDResidualJacobianPairV4(TDRJ._TDRJ_TOKEN,
        pair.state_node_id, pair.state_node_identity_hash, pair.state_type,
        pair.residual_operator, pair.jacobian_operator,
        pair.expected_jacobian_type, TDRJH)
    @test_throws ArgumentError canonical_hash(forged_pair)

    declaration = tdrj_declaration
    forged_declaration = TDRJ.ThreeDGoverningResidualJacobianDeclarationSetV4(
        TDRJ._TDRJ_TOKEN, declaration.declaration_id,
        declaration.field_geometry_graph_hash,
        declaration.field_geometry_graph_binding_hash, declaration.pairs,
        declaration.model_class, declaration.claim_ceiling,
        declaration.provider_selected, declaration.provider_executed,
        declaration.emits_evidence, true, declaration.promotion_authority,
        declaration.p5_ready, declaration.terminal_authority,
        declaration.credible_physical_device_count,
        declaration.declaration_hash)
    @test_throws ArgumentError canonical_hash(forged_declaration)

    binding = tdrj_subject_binding
    forged_binding = TDRJ.ThreeDGoverningResidualJacobianBindingV4(
        TDRJ._TDRJ_TOKEN, binding.declaration_hash, binding.candidate_hash,
        binding.compiled_prefix_hash, binding.field_geometry_genome_hash,
        binding.field_geometry_graph_hash,
        binding.field_geometry_graph_binding_hash,
        (first(binding.ordered_pair_hashes),),
        binding.ordered_residual_ast_root_identity_hashes,
        binding.ordered_jacobian_ast_root_identity_hashes,
        binding.mission_hash, binding.bounds_hash, binding.scenario_hash,
        binding.binding_hash)
    @test_throws ArgumentError canonical_hash(forged_binding)
    @test_throws ArgumentError begin
        TDRJ.make_three_d_governing_residual_jacobian_binding(
            tdrj_compiled, tdrj_registry, tdrj_mission, tdrj_bounds,
            tdrj_comparison, tdrj_scenarios,
            (name="foreign-scenario",), tdrj_declaration)
    end

    ownership = tdrj_resolution.ownership
    forged_ownership = TDRJ.ThreeDGoverningResidualJacobianOwnershipV4(
        TDRJ._TDRJ_TOKEN, ownership.context_hash, ownership.candidate_hash,
        ownership.compiled_prefix_hash, ownership.registry_hash,
        ownership.physical_subject_hash,
        ownership.field_geometry_genome_hash,
        ownership.field_geometry_graph_hash,
        ownership.field_geometry_graph_binding_hash,
        ownership.mission_hash, ownership.bounds_hash,
        ownership.scenario_hash, ownership.declaration_hash,
        ownership.binding_hash, ownership.pairs, ownership.model_class,
        ownership.claim_ceiling, ownership.provider_selected,
        ownership.provider_executed, ownership.emits_evidence, true,
        ownership.promotion_authority, ownership.p5_ready,
        ownership.terminal_authority,
        ownership.credible_physical_device_count, ownership.ownership_hash)
    @test_throws ArgumentError canonical_hash(forged_ownership)
    @test_throws ArgumentError begin
        TDRJ.validate_three_d_governing_residual_jacobian_ownership(
            tdrj_generic_context, ownership)
    end
end

@testset "public trust boundaries revalidate upstream compiled/context data" begin
    context = tdrj_context
    forged_context = TDRJ.ForwardChainContextV4(
        TDRJ._FORWARD_CHAIN_CONTEXT_TOKEN, context.candidate,
        context.compiled, context.registry, context.mission_payload,
        context.bounds_payload, context.comparison_scope,
        context.scenario_scope, context.subject, context.scenario,
        context.genome_bindings, context.obligations, context.candidate_hash,
        context.registry_hash, context.scenario_hash,
        context.obligation_hashes, TDRJH)
    @test_throws ArgumentError begin
        TDRJ.compile_three_d_governing_residual_jacobian(forged_context)
    end
    @test_throws ArgumentError begin
        TDRJ.validate_three_d_governing_residual_jacobian_ownership(
            forged_context, tdrj_resolution.ownership)
    end

    compiled = tdrj_compiled
    forged_compiled = TDRJ.CompiledCandidatePrefixV4(
        compiled.candidate, compiled.mission_payload,
        compiled.bounds_payload, compiled.minimality_scope,
        compiled.mechanism_graph, tdrj_generic_compiled.field_geometry_graph,
        compiled.realization_graph, compiled.control_graph,
        compiled.normalized_regions, compiled.normalized_interfaces,
        compiled.normalized_boundaries, compiled.unresolved_nonterminals,
        compiled.capability_obligations, compiled.compilation_status)
    @test_throws ArgumentError begin
        TDRJ.make_three_d_governing_residual_jacobian_binding(
            forged_compiled, tdrj_registry, tdrj_mission, tdrj_bounds,
            tdrj_comparison, tdrj_scenarios, tdrj_scenario,
            tdrj_declaration)
    end
end

@testset "manifest exposes compiler-only authority" begin
    manifest = TDRJ.three_d_governing_residual_jacobian_manifest()
    @test manifest.generic_status === :recoverable_gap
    @test manifest.manufactured_fixture_status === :compiled
    @test manifest.declaration_kind === :ordered_exact_state_cover_set
    @test manifest.resolved_gap == TDRJ._TDRJ_GAP
    @test manifest.downstream_gaps == TDRJ._TDRJ_DOWNSTREAM_GAPS
    @test manifest.requires_atomic_mimo
    @test manifest.requires_registered_ast_roots
    @test manifest.requires_distinct_edges_and_roots
    @test manifest.requires_exact_state_coverage
    @test manifest.requires_domain_codomain_unit_dimension_compatibility
    @test manifest.claim_ceiling == screen_only
    @test !manifest.provider_selected
    @test !manifest.provider_executed
    @test !manifest.emits_evidence
    @test !manifest.grants_pass
    @test !manifest.physical_validation
    @test !manifest.engineering_validation
    @test !manifest.promotion_authority
    @test !manifest.p5_ready
    @test !manifest.terminal_authority
    @test manifest.credible_physical_device_count == 0
end

println("THREE_D_GOVERNING_RESIDUAL_JACOBIAN_FOCUSED_EXIT_CODE=0")
