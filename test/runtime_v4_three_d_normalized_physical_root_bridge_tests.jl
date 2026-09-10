using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_three_d_normalized_physical_root_bridge.jl"))

@testset "legacy single-root declaration remains an exact recoverable gap" begin
    @test tdnprb_legacy_resolution.status === :recoverable_gap
    @test tdnprb_legacy_resolution.audit !== nothing
    @test tdnprb_legacy_resolution.recoverable_gaps == TDNPRB._TDNPRB_GAPS
    @test !tdnprb_legacy_resolution.audit.normalized_coordinate_root_distinct
    @test !tdnprb_legacy_resolution.audit.normalized_metric_root_distinct
    @test !tdnprb_legacy_resolution.audit.coordinate_bridge_exact
    @test !tdnprb_legacy_resolution.audit.metric_bridge_exact
    @test canonical_hash(tdpi_input_declaration) ==
        tdpi_input_declaration.declaration_hash
    @test TDNPRB.validate_three_d_normalized_physical_root_bridge(
        tdpi_context, tdnprb_legacy_resolution) ==
        tdnprb_legacy_resolution.resolution_hash
    @test !TDNPRB.validate_three_d_normalized_physical_root_bridge(
        tdnprb_legacy_resolution)

    @test tdnprb_missing_resolution.status === :recoverable_gap
    @test tdnprb_missing_resolution.audit === nothing
    @test tdnprb_missing_resolution.recoverable_gaps == TDNPRB._TDNPRB_GAPS
end

@testset "AtomicMIMO two-root programs bind normalized roots to SI roots" begin
    resolution = tdnprb_resolution
    audit = something(resolution.audit)
    @test resolution.status === :bridge_ready
    @test isempty(resolution.recoverable_gaps)
    @test audit.status === :bridge_ready
    @test audit.normalized_coordinate_root_distinct
    @test audit.normalized_metric_root_distinct
    @test audit.coordinate_bridge_exact
    @test audit.metric_bridge_exact
    @test audit.support_scale == tdnprb_support_scale
    @test audit.normalized_coordinate_root_identity_hash ==
        tdnprb_prebinding.ast_root_identity_hashes[1]
    @test audit.physical_coordinate_root_identity_hash ==
        tdnprb_prebinding.ast_root_identity_hashes[2]
    @test audit.normalized_metric_root_identity_hash ==
        tdnprb_prebinding.ast_root_identity_hashes[3]
    @test audit.physical_metric_root_identity_hash ==
        tdnprb_prebinding.ast_root_identity_hashes[4]
    @test canonical_hash(audit) == audit.audit_hash
    @test canonical_hash(resolution) == resolution.resolution_hash
    @test TDNPRB.validate_three_d_normalized_physical_root_bridge(
        tdnprb_context, resolution) == resolution.resolution_hash
    @test TDNPRB.validate_three_d_normalized_physical_root_bridge(resolution)
end

@testset "bridge result stays structural and non-evidentiary" begin
    for value in (tdnprb_resolution, something(tdnprb_resolution.audit),
            TDNPRB.three_d_normalized_physical_root_bridge_manifest())
        @test value.claim_ceiling == screen_only
        @test !value.bridge_ready_is_geometry_proof
        @test !value.geometry_program_interpreted
        @test !value.geometry_proved
        @test !value.certificate_emitted
        @test !value.request_emitted
        @test !value.provider_selected
        @test !value.provider_executed
        @test !value.solver_execution_attempted
        @test !value.solver_executed
        @test !value.physical_validation
        @test !value.engineering_validation
        @test !value.emits_evidence
        @test !value.grants_pass
        @test !value.promotion_authority
        @test !value.p5_ready
        @test !value.terminal_authority
        @test value.credible_physical_device_count == 0
    end
end

@testset "private, canonical, foreign, and duplicate checks fail closed" begin
    @test_throws ArgumentError TDNPRB._tdnprb_gaps(
        (TDNPRB._TDNPRB_GAPS[2], TDNPRB._TDNPRB_GAPS[1]))
    @test_throws ArgumentError TDNPRB._tdnprb_gaps(("wildcard",))

    audit = something(tdnprb_resolution.audit)
    audit_values = TDNPRB._tdnprb_audit_values(audit)
    @test_throws ArgumentError TDNPRB.ThreeDNormalizedPhysicalRootBridgeAuditV4(
        TDNPRB._TDNPRBPrivateToken(), audit_values..., audit.audit_hash)
    forged_values = collect(audit_values)
    coordinate_position = findfirst(==(:coordinate_bridge_exact),
        fieldnames(typeof(audit)))
    forged_values[coordinate_position] = false
    forged_body = TDNPRB._tdnprb_audit_body_from_values(Tuple(forged_values)...)
    forged = TDNPRB.ThreeDNormalizedPhysicalRootBridgeAuditV4(
        TDNPRB._TDNPRB_TOKEN, Tuple(forged_values)..., canonical_hash(forged_body))
    @test_throws ArgumentError canonical_hash(forged)

    nonexact_registry = let
        registry = default_operator_registry()
        probe_type = PhysicalType(:bridge_probe, 0, 3,
            TemporalTypeV1(static_time), UnitSignature())
        registry = register_operator(registry, tdnprb_manifest(
            "RUNTIME_V4_NORMALIZED_COORDINATE_FIXTURE",
            (tdnprb_chart_type,), probe_type))
        variadic = SameTypeVariadicRuleV1(2, 2)
        register_operator(registry, OperatorManifestV1(
            OperatorRefV1("RUNTIME_V4_SUPPORT_SCALE_COORDINATE", "v1"),
            2, 1, variadic, variadic; allowed_roles=(:constraint,)))
    end
    probe_type = PhysicalType(:bridge_probe, 0, 3,
        TemporalTypeV1(static_time), UnitSignature())
    nonexact_nodes = let
        chart = ASTInputV1(1, tdnprb_chart_type)
        normalized = ASTApplyV1(OperatorRefV1(
            "RUNTIME_V4_NORMALIZED_COORDINATE_FIXTURE", "v1"), (1,), (;);
            registry=nonexact_registry, input_types=(tdnprb_chart_type,))
        scale = ASTConstantV1(:support_scale, 1 // 1, probe_type)
        physical = ASTApplyV1(OperatorRefV1(
            "RUNTIME_V4_SUPPORT_SCALE_COORDINATE", "v1"), (2, 3), (;);
            registry=nonexact_registry,
            input_types=(probe_type, probe_type))
        (chart, normalized, scale, physical)
    end
    nonexact_program = TypedASTProgramV1(nonexact_nodes, (2, 4), (1,);
        registry=nonexact_registry)
    nonexact_edge = AtomicMIMOHyperedgeV1("tdnprb-nonexact-coordinate",
        (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 3)),
        nonexact_program, constraint; registry=nonexact_registry)
    nonexact_graph = TypedOperatorHypergraphV1(
        (node(:chart_coordinate, tdnprb_chart_type; id="nonexact-chart"),
         node(:normalized_coordinate, probe_type;
            id="nonexact-normalized"),
         node(:physical_coordinate, probe_type;
            id="nonexact-physical")), (nonexact_edge,);
        registry=nonexact_registry)
    nonexact_binding = TDNPRB._make_forward_graph_binding(
        :field_geometry, nonexact_graph)
    nonexact_normalized = TDNPRB._tdnprb_root(
        nonexact_binding, 1, nonexact_edge, 1)
    nonexact_physical = TDNPRB._tdnprb_root(
        nonexact_binding, 1, nonexact_edge, 2)
    @test !TDNPRB._tdnprb_bridge_exact(nonexact_edge,
        nonexact_normalized, nonexact_physical, tdnprb_support_scale,
        TDNPRB._TDNPRB_COORDINATE_OPERATOR, probe_type, 1 // 1)
    @test_throws ArgumentError TDNPRB.validate_three_d_normalized_physical_root_bridge(
        tdpi_context, tdnprb_resolution)

    duplicate_subject = TDNPRB.ExecutablePhysicalSubjectV4(
        tdnprb_compiled.prefix_hash,
        tdnprb_candidate.canonical_hashes.genome_bundle_hash,
        tdnprb_compiled.minimality_scope.mission_hash,
        tdnprb_compiled.minimality_scope.bounds_hash,
        (tdnprb_subject_binding, tdnprb_subject_binding),
        (tdnprb_scenario,), tdnprb_subject.materialized_payload,
        TDNPRB.derive_capability_obligations(tdnprb_compiled))
    duplicate_context = TDNPRB.make_forward_chain_context(tdnprb_candidate,
        tdnprb_compiled, generic_3d_registry, tdnprb_mission, tdnprb_bounds,
        tdnprb_comparison_scope, tdnprb_scenario_scope,
        duplicate_subject, tdnprb_scenario)
    @test_throws ArgumentError TDNPRB.compile_three_d_normalized_physical_root_bridge(
        duplicate_context)
end

println("THREE_D_NORMALIZED_PHYSICAL_ROOT_BRIDGE_FOCUSED_EXIT_CODE=0")
