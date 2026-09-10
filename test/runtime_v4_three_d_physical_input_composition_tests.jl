using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_three_d_physical_input_composition.jl"))

function tdpic_context_with_bindings(bindings; payload=(case="test",))
    subject = TDPIC.ExecutablePhysicalSubjectV4(
        tdpic_compiled.prefix_hash,
        tdpic_candidate.canonical_hashes.genome_bundle_hash,
        tdpic_compiled.minimality_scope.mission_hash,
        tdpic_compiled.minimality_scope.bounds_hash, bindings,
        (tdpic_scenario,), payload,
        TDPIC.derive_capability_obligations(tdpic_compiled))
    TDPIC.make_forward_chain_context(tdpic_candidate, tdpic_compiled,
        generic_3d_registry, tdpic_mission, tdpic_bounds,
        tdpic_comparison, tdpic_scenarios, subject, tdpic_scenario)
end

function tdpic_context_for_fields(fields, bindings; stem)
    genome = FieldGeometryGenomeV4(20260910,
        GenericThreeDG2Fixture._fixture_refs[2], tdpic_graph; fields=fields)
    candidate = CandidateStatePackageV4("$stem-candidate",
        tdpic_base._fixture_mission, tdpic_base._fixture_mechanism, genome,
        tdpic_base._fixture_realization, generic_3d_registry)
    scenario = (name="$stem-scenario", fixture="fail-closed-input")
    mission = (mission="$stem-mission",
        contract=candidate.mission_contract_ref)
    bounds = (scope="$stem-bounds",)
    comparison = ("$stem-comparison",)
    scenarios = (scenario.name,)
    compiled = TDPIC.compile_candidate(candidate, generic_3d_registry;
        mission_payload=mission, bounds_payload=bounds,
        comparison_scope=comparison, scenario_scope=scenarios)
    subject = TDPIC.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, bindings, (scenario,),
        (materialization="$stem-materialization",),
        TDPIC.derive_capability_obligations(compiled))
    TDPIC.make_forward_chain_context(candidate, compiled,
        generic_3d_registry, mission, bounds, comparison, scenarios, subject,
        scenario)
end

@testset "generic context reports the exact composition gaps" begin
    result = tdpic_generic_resolution
    @test result.status === :recoverable_gap
    @test result.input === nothing
    @test result.recoverable_gaps == TDPIC._TDPIC_REQUIRED_GAPS
    @test canonical_hash(result) == result.resolution_hash
    @test result.claim_ceiling == screen_only
    @test !result.provider_selected
    @test !result.provider_executed
    @test !result.solver_executed
    @test !result.emits_evidence
    @test !result.grants_pass
    @test !result.promotion_authority
    @test !result.p5_ready
    @test !result.terminal_authority
    @test result.credible_physical_device_count == 0
end

@testset "one context reconstructs five inputs and the support map" begin
    result = tdpic_resolution
    input = tdpic_input
    binding = tdpic_composition_binding
    @test result.status === :input_complete
    @test isempty(result.recoverable_gaps)
    @test result.input === input
    @test canonical_hash(result) == result.resolution_hash
    @test canonical_hash(input) == input.input_hash
    @test canonical_hash(binding) == binding.binding_hash
    @test TDPIC.validate_three_d_physical_input_composition(
        tdpic_context, input) == input.input_hash
    @test !TDPIC.validate_three_d_physical_input_composition(input)
    @test input.context_hash == tdpic_context.context_hash
    @test input.candidate_hash == tdpic_context.candidate_hash
    @test input.compiled_prefix_hash == tdpic_compiled.prefix_hash
    @test input.registry_hash == tdpic_context.registry_hash
    @test input.physical_subject_hash == tdpic_subject.physical_subject_hash
    @test input.composition_binding_hash == canonical_hash(binding)
    @test input.physical === tdpic_physical_declaration
    @test input.support_mapping === tdpic_support_mapping
    @test input.support_mapping.physical_support_ref ==
        tdpic_physical_declaration.coordinate_metric.support_ref
    @test input.support_mapping.ordered_region_ids == input.ordered_region_ids
    @test input.support_mapping.ordered_region_support_refs ==
        Tuple(x.support_ref for x in tdpic_oriented_declaration.regions)
    @test input.region_laws.status === :compiled
    @test input.oriented.context_hash == input.context_hash
    @test input.residual.context_hash == input.context_hash
    @test input.discretization.context_hash == input.context_hash
    @test input.region_laws.context_hash == input.context_hash
    @test isempty(input.region_laws.recoverable_gaps)
    @test input.region_laws.ordered_region_ids == input.ordered_region_ids
    @test length(input.region_laws.laws) == 2
    @test length(input.region_laws.ordered_edge_identity_hashes) == 6
    @test length(unique(input.region_laws.ordered_edge_identity_hashes)) == 6
    @test length(unique(input.region_laws.ordered_ast_root_identity_hashes)) == 6
    @test length(unique(input.region_laws.ordered_output_node_identity_hashes)) == 6
    @test input.ordered_region_ids == ("left-region", "right-region")
    @test input.ordered_state_node_ids ==
        ("tdpic-left-state", "tdpic-right-state")
    @test length(input.ordered_state_node_identity_hashes) == 2
    @test length(input.ordered_interface_ref_hashes) == 1
    @test length(input.ordered_discrete_space_identity_hashes) == 5
    @test input.ordered_state_node_identity_hashes == Tuple(
        x.state_node_identity_hash for x in input.oriented.regions)
    @test Tuple(x.state_node_id for x in input.residual.pairs) ==
        ("tdpic-right-state", "tdpic-left-state")
    @test input.ordered_state_node_ids !=
        Tuple(x.state_node_id for x in input.residual.pairs)
    @test !hasproperty(input.oriented.regions[1], :state_node_id)
    @test TDPIC._tdpic_keyed_state_cover(tdpic_oriented_declaration.regions,
        input.oriented.regions, input.residual.pairs)
    @test_throws ArgumentError TDPIC._tdpic_keyed_state_cover(
        tdpic_oriented_declaration.regions, input.oriented.regions,
        (input.residual.pairs[1], input.residual.pairs[1]))
    @test input.ordered_interface_ref_hashes == Tuple(
        x.ref_hash for x in input.oriented.interfaces)
    @test input.ordered_discrete_space_identity_hashes == Tuple(
        canonical_hash(x) for x in TDPIC._tddc_oriented_spaces(
            input.oriented.regions, input.oriented.interfaces))
    @test tdpic_region_law_set_declaration.ordered_region_ids ==
        input.ordered_region_ids
    @test binding.physical_declaration_hash ==
        canonical_hash(tdpic_physical_declaration)
    @test binding.support_mapping_declaration_hash ==
        canonical_hash(tdpic_support_mapping)
end

@testset "component declarations and bindings are the same current objects" begin
    input = tdpic_input
    binding = tdpic_composition_binding
    @test binding.physical_declaration_hash ==
        canonical_hash(tdpic_physical_declaration)
    @test binding.region_law_set_declaration_hash ==
        canonical_hash(tdpic_region_law_set_declaration)
    @test binding.oriented_declaration_hash ==
        canonical_hash(tdpic_oriented_declaration)
    @test binding.residual_declaration_hash ==
        canonical_hash(tdpic_residual_declaration)
    @test binding.discretization_declaration_hash ==
        canonical_hash(tdpic_discretization_declaration)
    @test binding.physical_binding_hash == canonical_hash(tdpic_physical_binding)
    @test binding.support_mapping_binding_hash ==
        canonical_hash(tdpic_support_mapping_binding)
    @test binding.region_law_set_binding_hash ==
        canonical_hash(tdpic_region_law_set_binding)
    @test binding.oriented_binding_hash == canonical_hash(tdpic_oriented_binding)
    @test binding.residual_binding_hash == canonical_hash(tdpic_residual_binding)
    @test binding.discretization_binding_hash ==
        canonical_hash(tdpic_discretization_binding)
    @test input.discretization.oriented_declaration_hash ==
        binding.oriented_declaration_hash
    @test input.discretization.oriented_binding_hash ==
        binding.oriented_binding_hash
    @test input.discretization.oriented_region_ref_hashes ==
        Tuple(x.ref_hash for x in input.oriented.regions)
    @test input.discretization.oriented_interface_ref_hashes ==
        input.ordered_interface_ref_hashes
    @test Set(input.ordered_state_node_ids) ==
        Set(x.state_node_id for x in input.residual.pairs)
    @test Set(input.ordered_state_node_identity_hashes) ==
        Set(value for x in input.oriented.interfaces for value in
            (x.minus_state_node_identity_hash,
             x.plus_state_node_identity_hash))
end

@testset "missing components remain exact and non-authoritative" begin
    six = (tdpic_physical_binding, tdpic_support_mapping_binding,
        tdpic_region_law_set_binding,
        tdpic_oriented_binding, tdpic_residual_binding,
        tdpic_discretization_binding)
    missing_composition = TDPIC.compose_three_d_physical_inputs(
        tdpic_context_with_bindings(six; payload=(case="missing-composition",)))
    @test missing_composition.status === :recoverable_gap
    @test missing_composition.recoverable_gaps ==
        (TDPIC._TDPIC_REQUIRED_GAPS[15],)

    missing_discretization = TDPIC.compose_three_d_physical_inputs(
        tdpic_context_with_bindings(six[1:5];
            payload=(case="missing-discretization-and-composition",)))
    @test missing_discretization.status === :recoverable_gap
    @test missing_discretization.recoverable_gaps ==
        (TDPIC._TDPIC_REQUIRED_GAPS[14],
         TDPIC._TDPIC_REQUIRED_GAPS[15])
    @test missing_discretization.input === nothing
    @test !missing_discretization.provider_selected
    @test !missing_discretization.provider_executed
    @test !missing_discretization.solver_executed
    @test !missing_discretization.emits_evidence
    @test !missing_discretization.grants_pass
    @test !missing_discretization.p5_ready
    @test !missing_discretization.terminal_authority
    @test missing_discretization.credible_physical_device_count == 0
end

@testset "duplicate binding fails closed" begin
    bindings = (tdpic_physical_binding, tdpic_support_mapping_binding,
        tdpic_region_law_set_binding,
        tdpic_oriented_binding, tdpic_residual_binding,
        tdpic_discretization_binding, tdpic_physical_binding)
    context = tdpic_context_with_bindings(bindings;
        payload=(case="duplicate-physical-binding",))
    result = TDPIC.compose_three_d_physical_inputs(context)
    @test result.status === :recoverable_gap
    @test "ambiguous_three_d_physical_provider_input_subject_binding" in
        result.recoverable_gaps
    @test TDPIC._TDPIC_REQUIRED_GAPS[15] in result.recoverable_gaps
    @test result.input === nothing

    duplicate_composition = tdpic_context_with_bindings((
        tdpic_physical_binding, tdpic_support_mapping_binding,
        tdpic_region_law_set_binding,
        tdpic_oriented_binding, tdpic_residual_binding,
        tdpic_discretization_binding, tdpic_composition_binding,
        tdpic_composition_binding);
        payload=(case="duplicate-composition-binding",))
    @test_throws ArgumentError TDPIC.compose_three_d_physical_inputs(
        duplicate_composition)
end


@testset "missing and duplicate declarations fail closed" begin
    base_fields = (tdpic_left_support, tdpic_right_support,
        tdpic_interface_support, tdpic_physical_declaration,
        tdpic_support_mapping, tdpic_region_law_set_declaration,
        tdpic_oriented_declaration,
        tdpic_residual_declaration, tdpic_discretization_declaration)
    missing_fields = (base_fields[1:7]..., base_fields[9])
    missing_residual = tdpic_context_for_fields(missing_fields,
        (tdpic_physical_binding,); stem="tdpic-missing-residual")
    @test_throws ArgumentError TDPIC.compose_three_d_physical_inputs(
        missing_residual)

    duplicate_physical = tdpic_context_for_fields(
        (base_fields..., tdpic_physical_declaration),
        ((binding_kind="duplicate-declaration-no-typed-binding",),);
        stem="tdpic-duplicate-physical")
    duplicate_result =
        TDPIC.compose_three_d_physical_inputs(duplicate_physical)
    @test duplicate_result.status === :recoverable_gap
    @test "ambiguous_typed_three_d_geometry_profile_declaration" in
        duplicate_result.recoverable_gaps
    @test duplicate_result.input === nothing

    duplicate_mapping = tdpic_context_for_fields(
        (base_fields..., tdpic_support_mapping),
        ((binding_kind="duplicate-support-map-no-typed-binding",),);
        stem="tdpic-duplicate-support-map")
    mapping_result = TDPIC.compose_three_d_physical_inputs(duplicate_mapping)
    @test mapping_result.status === :recoverable_gap
    @test "ambiguous_typed_three_d_physical_region_support_mapping" in
        mapping_result.recoverable_gaps
    @test mapping_result.input === nothing
end

@testset "support mapping is exact structural ownership" begin
    caller_only_physical = TDPIC.ThreeDPhysicalProviderInputV4(
        "caller-only-physical", tdpic_boundary, tdpic_coordinate_metric,
        tdpic_profiles)
    caller_only_oriented = TDPIC.ThreeDOrientedInterfaceDeclarationSetV4(
        "caller-only-oriented", tdpic_oriented_declaration.regions,
        tdpic_oriented_declaration.interfaces)
    @test_throws ArgumentError TDPIC._tdpic_validate_support_mapping(
        tdpic_candidate, tdpic_prebinding, caller_only_physical,
        tdpic_oriented_declaration, tdpic_support_mapping)
    @test_throws ArgumentError TDPIC._tdpic_validate_support_mapping(
        tdpic_candidate, tdpic_prebinding, tdpic_physical_declaration,
        caller_only_oriented, tdpic_support_mapping)

    @test_throws ArgumentError begin
        TDPIC.declare_three_d_physical_region_support_mapping(
            tdpic_physical_declaration, tdpic_oriented_declaration;
            declaration_id="partial-support-map",
            region_supports=((region_id="left-region",
                support_ref=tdpic_left_support_ref),))
    end
    @test_throws ArgumentError begin
        TDPIC.declare_three_d_physical_region_support_mapping(
            tdpic_physical_declaration, tdpic_oriented_declaration;
            declaration_id="duplicate-support-map",
            region_supports=(
                (region_id="left-region", support_ref=tdpic_left_support_ref),
                (region_id="left-region", support_ref=tdpic_left_support_ref)))
    end
    @test_throws ArgumentError begin
        TDPIC.declare_three_d_physical_region_support_mapping(
            tdpic_physical_declaration, tdpic_oriented_declaration;
            declaration_id="unrelated-support-map",
            region_supports=(
                (region_id="left-region", support_ref=tdpic_left_support_ref),
                (region_id="right-region", support_ref=tdpic_left_support_ref)))
    end

    without_mapping = (tdpic_physical_binding,
        tdpic_region_law_set_binding, tdpic_oriented_binding,
        tdpic_residual_binding, tdpic_discretization_binding)
    missing = TDPIC.compose_three_d_physical_inputs(
        tdpic_context_with_bindings(without_mapping;
            payload=(case="missing-support-mapping",)))
    @test missing.status === :recoverable_gap
    @test missing.recoverable_gaps ==
        (TDPIC._TDPIC_REQUIRED_GAPS[6],
         TDPIC._TDPIC_REQUIRED_GAPS[15])

    mapping = tdpic_support_mapping
    forged = TDPIC.ThreeDPhysicalRegionSupportMappingV4(TDPIC._TDPIC_TOKEN,
        mapping.declaration_id, mapping.physical_declaration_hash,
        mapping.oriented_declaration_hash, mapping.physical_support_ref,
        mapping.ordered_region_ids, mapping.ordered_region_support_refs,
        mapping.model_class, mapping.claim_ceiling,
        mapping.geometric_compatibility_proved, mapping.provider_selected,
        mapping.provider_executed, mapping.solver_executed,
        mapping.emits_evidence, mapping.grants_pass,
        mapping.promotion_authority, mapping.p5_ready,
        mapping.terminal_authority, mapping.credible_physical_device_count,
        digest256_text("forged-support-map"))
    @test_throws ArgumentError canonical_hash(forged)
end

@testset "foreign and forged bindings fail closed" begin
    foreign_bounds = (scope="foreign-composition-bounds", region_count=2)
    foreign_compiled = TDPIC.compile_candidate(tdpic_candidate,
        generic_3d_registry; mission_payload=tdpic_mission,
        bounds_payload=foreign_bounds, comparison_scope=tdpic_comparison,
        scenario_scope=tdpic_scenarios)
    foreign_mapping =
        TDPIC.make_three_d_physical_region_support_mapping_binding(
            foreign_compiled, generic_3d_registry, tdpic_mission,
            foreign_bounds, tdpic_comparison, tdpic_scenarios,
            tdpic_scenario, tdpic_physical_declaration,
            tdpic_oriented_declaration, tdpic_support_mapping)
    mixed = (tdpic_physical_binding, foreign_mapping,
        tdpic_region_law_set_binding,
        tdpic_oriented_binding,
        tdpic_residual_binding, tdpic_discretization_binding,
        tdpic_composition_binding)
    mixed_context = tdpic_context_with_bindings(mixed;
        payload=(case="mixed-context-binding",))
    @test_throws ArgumentError TDPIC.compose_three_d_physical_inputs(mixed_context)

    b = tdpic_composition_binding
    forged = TDPIC.ThreeDPhysicalInputCompositionBindingV4(
        TDPIC._TDPIC_TOKEN, digest256_text("foreign-candidate"),
        b.compiled_prefix_hash, b.field_geometry_genome_hash,
        b.field_geometry_graph_hash, b.field_geometry_graph_binding_hash,
        b.physical_declaration_hash, b.physical_binding_hash,
        b.support_mapping_declaration_hash, b.support_mapping_binding_hash,
        b.region_law_set_declaration_hash, b.region_law_set_binding_hash,
        b.oriented_declaration_hash, b.oriented_binding_hash,
        b.residual_declaration_hash, b.residual_binding_hash,
        b.discretization_declaration_hash, b.discretization_binding_hash,
        b.ordered_region_ids, b.ordered_state_node_ids,
        b.ordered_state_node_identity_hashes, b.ordered_interface_ref_hashes,
        b.ordered_discrete_space_identity_hashes, b.mission_hash,
        b.bounds_hash, b.scenario_hash, b.binding_hash)
    @test_throws ArgumentError canonical_hash(forged)
end

@testset "composition retains zero execution and evidence authority" begin
    for value in (tdpic_support_mapping, tdpic_support_mapping_binding,
            tdpic_composition_binding, tdpic_input, tdpic_resolution)
        @test canonical_hash(value) isa Digest256
    end
    input = tdpic_input
    result = tdpic_resolution
    @test input.model_class === :manufactured_input_fixture
    @test input.claim_ceiling == screen_only
    @test !input.provider_selected
    @test !input.provider_executed
    @test !input.solver_executed
    @test !input.emits_evidence
    @test !input.grants_pass
    @test !input.promotion_authority
    @test !input.p5_ready
    @test !input.terminal_authority
    @test input.credible_physical_device_count == 0
    @test result.claim_ceiling == screen_only
    @test !result.provider_selected
    @test !result.provider_executed
    @test !result.solver_executed
    @test !result.emits_evidence
    @test !result.grants_pass
    @test !result.promotion_authority
    @test !result.p5_ready
    @test !result.terminal_authority
    @test result.credible_physical_device_count == 0
    manifest = TDPIC.three_d_physical_input_composition_manifest()
    @test manifest.statuses == (:input_complete, :recoverable_gap)
    @test manifest.requires_same_candidate
    @test manifest.requires_same_compiled_prefix
    @test manifest.requires_same_forward_context_subject
    @test manifest.requires_at_least_two_regions
    @test manifest.requires_physical_region_support_mapping
    @test manifest.support_mapping_is_structural_only
    @test !manifest.geometric_compatibility_proved
    @test manifest.residual_state_cover_is_keyed
    @test !manifest.provider_selected
    @test !manifest.provider_executed
    @test !manifest.solver_executed
    @test !manifest.emits_evidence
    @test !manifest.grants_pass
    @test !manifest.promotion_authority
    @test !manifest.p5_ready
    @test !manifest.terminal_authority
    @test manifest.credible_physical_device_count == 0
end
