using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_desc_geometry_program_preflight.jl"))

@testset "RuntimeV4 DESC geometry program preflight" begin
    missing = dgpp_missing_declarations_resolution
    current = dgpp_current_resolution
    audit = something(current.audit)

    @test missing.status === :recoverable_gap
    @test missing.audit === nothing
    @test missing.recoverable_gaps == (
        "required_desc_geometry_convention_declaration",
        "required_desc_fixed_boundary_request_declaration",
        "required_desc_fixed_boundary_request_subject_binding")
    @test DGPP.canonical_hash(missing) == missing.resolution_hash
    @test DGPP.validate_desc_geometry_program_preflight(
        tdpic_context, missing) == missing.resolution_hash

    expected = (
        "required_desc_normalized_turn_chart_domain",
        "required_desc_poloidal_turn_period_axis_declaration",
        "required_desc_field_period_turn_axis_declaration",
        "required_desc_exact_periodic_turn_axis_set",
        "desc_coordinate_chart_root_abi_mismatch",
        "desc_metric_chart_root_abi_mismatch",
        "required_desc_normalized_physical_root_bridge_contract",
        "required_executable_desc_coordinate_map_program",
        "required_executable_desc_metric_program",
        "required_pinned_desc_geometry_operator_manifests",
        "required_desc_geometry_program_interpreter")
    @test current.status === :recoverable_gap
    @test current.audit !== nothing
    @test current.recoverable_gaps == expected
    @test audit.recoverable_gaps == expected
    @test DGPP.canonical_hash(audit) == audit.audit_hash
    @test DGPP.canonical_hash(current) == current.resolution_hash
    @test DGPP.validate_desc_geometry_program_preflight(
        dfbrc_context, current) == current.resolution_hash
    @test DGPP.validate_desc_geometry_program_preflight(current) === false

    @test !audit.normalized_turn_domain
    @test !audit.poloidal_turn_period_axis_declared
    @test !audit.field_period_turn_axis_declared
    @test !audit.periodic_turn_axis_set_exact
    @test !audit.coordinate_input_abi_exact
    @test !audit.metric_input_abi_exact
    @test !audit.coordinate_output_abi_exact
    @test !audit.metric_output_abi_exact
    @test audit.coordinate_identity_exact
    @test audit.metric_identity_exact
    @test !audit.normalized_physical_root_bridge_available
    @test !audit.coordinate_program_shape_admissible
    @test !audit.metric_program_shape_admissible
    @test !audit.operator_manifests_pinned
    @test !audit.geometry_program_interpreter_available

    @test audit.context_hash == dfbrc_context.context_hash
    @test audit.candidate_hash == dfbrc_context.candidate_hash
    @test audit.compiled_prefix_hash == dfbrc_context.compiled.prefix_hash
    @test audit.registry_hash == dfbrc_context.registry_hash
    @test audit.physical_subject_hash ==
        dfbrc_context.subject.physical_subject_hash
    @test audit.field_geometry_genome_hash ==
        dfbrc_context.candidate.canonical_hashes.field_geometry_hash
    @test audit.compatibility_declaration_hash ==
        canonical_hash(dfbrc_compatibility)
    @test audit.request_declaration_hash ==
        canonical_hash(dfbrc_request_declaration)
    @test audit.request_binding_hash == canonical_hash(dfbrc_request_binding)
    @test audit.coordinate_root_identity_hash ==
        dfbrc_physical_declaration.coordinate_metric.coordinate_map_root_identity_hash
    @test audit.metric_root_identity_hash ==
        dfbrc_physical_declaration.coordinate_metric.metric_root_identity_hash
    field_graph = DGPP._dgpp_field_graph(dfbrc_context)
    coordinate_edge = DGPP._dgpp_edge(field_graph,
        dfbrc_physical_declaration.coordinate_metric.coordinate_map_site_ref,
        "coordinate-map")
    @test DGPP._dgpp_root_position_valid(coordinate_edge, 1)
    @test !DGPP._dgpp_root_position_valid(coordinate_edge, 2)

    for value in (missing, current, audit,
            DGPP.desc_geometry_program_preflight_manifest())
        @test value.claim_ceiling == screen_only
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

    @test DGPP.desc_geometry_program_preflight_manifest().program_ready === false
    @test_throws ArgumentError DGPP._dgpp_gap_tuple((expected[2], expected[1]))
    @test_throws ArgumentError DGPP._dgpp_gap_tuple((expected[1], expected[1]))
    @test_throws ArgumentError DGPP._dgpp_gap_tuple(("wildcard",))

    audit_values = Tuple(getfield(audit, i)
        for i in 1:fieldcount(typeof(audit))-1)
    @test_throws ArgumentError DGPP.DESCGeometryProgramAuditV4(
        DGPP._DGPPPrivateToken(), audit_values..., audit.audit_hash)

    forged_values = collect(audit_values)
    coordinate_executable_position = findfirst(==(:coordinate_program_shape_admissible),
        fieldnames(typeof(audit)))
    forged_values[coordinate_executable_position] = true
    forged_body = DGPP._dgpp_audit_body_from_values(Tuple(forged_values)...)
    forged = DGPP.DESCGeometryProgramAuditV4(DGPP._DGPP_TOKEN,
        Tuple(forged_values)..., canonical_hash(forged_body))
    @test_throws ArgumentError DGPP.canonical_hash(forged)

    bridge_values = collect(audit_values)
    bridge_position = findfirst(
        ==(:normalized_physical_root_bridge_available),
        fieldnames(typeof(audit)))
    bridge_values[bridge_position] = true
    bridge_gaps_position = findfirst(==(:recoverable_gaps),
        fieldnames(typeof(audit)))
    bridge_values[bridge_gaps_position] = Tuple(g for g in expected
        if g != "required_desc_normalized_physical_root_bridge_contract")
    bridge_body = DGPP._dgpp_audit_body_from_values(Tuple(bridge_values)...)
    bridge_forge = DGPP.DESCGeometryProgramAuditV4(DGPP._DGPP_TOKEN,
        Tuple(bridge_values)..., canonical_hash(bridge_body))
    @test_throws ArgumentError DGPP.canonical_hash(bridge_forge)

    interpreter_values = collect(audit_values)
    interpreter_position = findfirst(
        ==(:geometry_program_interpreter_available),
        fieldnames(typeof(audit)))
    interpreter_values[interpreter_position] = true
    interpreter_values[bridge_gaps_position] = Tuple(g for g in expected
        if g != "required_desc_geometry_program_interpreter")
    interpreter_body = DGPP._dgpp_audit_body_from_values(
        Tuple(interpreter_values)...)
    interpreter_forge = DGPP.DESCGeometryProgramAuditV4(DGPP._DGPP_TOKEN,
        Tuple(interpreter_values)..., canonical_hash(interpreter_body))
    @test_throws ArgumentError DGPP.canonical_hash(interpreter_forge)

    provenance_values = collect(audit_values)
    candidate_position = findfirst(==(:candidate_hash),
        fieldnames(typeof(audit)))
    provenance_values[candidate_position] = missing.context_hash
    provenance_body = DGPP._dgpp_audit_body_from_values(
        Tuple(provenance_values)...)
    provenance_forge = DGPP.DESCGeometryProgramAuditV4(DGPP._DGPP_TOKEN,
        Tuple(provenance_values)..., canonical_hash(provenance_body))
    @test DGPP.canonical_hash(provenance_forge) ==
        provenance_forge.audit_hash

    resolution_values = Tuple(getfield(current, i)
        for i in 1:fieldcount(typeof(current))-1)
    forged_resolution_values = collect(resolution_values)
    context_position = findfirst(==(:context_hash), fieldnames(typeof(current)))
    forged_resolution_values[context_position] = missing.context_hash
    resolution_names = fieldnames(typeof(current))[1:end-1]
    forged_resolution_body = NamedTuple{resolution_names}(
        Tuple(forged_resolution_values))
    forged_resolution = DGPP.DESCGeometryProgramPreflightResolutionV4(
        DGPP._DGPP_TOKEN, Tuple(forged_resolution_values)...,
        canonical_hash(forged_resolution_body))
    @test_throws ArgumentError DGPP.canonical_hash(forged_resolution)
    @test_throws ArgumentError DGPP.validate_desc_geometry_program_preflight(
        dfbrc_context, forged_resolution)

    provenance_resolution_values = collect(resolution_values)
    audit_position = findfirst(==(:audit), fieldnames(typeof(current)))
    provenance_resolution_values[audit_position] = provenance_forge
    provenance_resolution_names = fieldnames(typeof(current))[1:end-1]
    provenance_resolution_body = NamedTuple{provenance_resolution_names}(
        Tuple(provenance_resolution_values))
    provenance_resolution = DGPP.DESCGeometryProgramPreflightResolutionV4(
        DGPP._DGPP_TOKEN, Tuple(provenance_resolution_values)...,
        canonical_hash(provenance_resolution_body))
    @test DGPP.canonical_hash(provenance_resolution) ==
        provenance_resolution.resolution_hash
    @test_throws ArgumentError DGPP.validate_desc_geometry_program_preflight(
        dfbrc_context, provenance_resolution)
end
