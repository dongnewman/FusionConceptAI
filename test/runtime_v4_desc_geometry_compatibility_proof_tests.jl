using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_desc_geometry_compatibility_proof.jl"))

function dgcp_variant(radial_powers, vertical_powers, suffix)
    program = DGCP.DESCFourierGeometryProgramV4(dgpi_boundary, dgpi_scale,
        radial_powers, vertical_powers)
    coordinate_site = FieldOperatorSiteRefV1("dgcp-coordinate-$suffix")
    metric_site = FieldOperatorSiteRefV1("dgcp-metric-$suffix")
    binding = DGCP.desc_geometry_typed_binding(program,
        coordinate_site, metric_site)
    graph = TypedOperatorHypergraphV1(
        (node(:chart_coordinate, chart_coordinate_type_v1();
            id="dgcp-chart-input-$suffix"),
         node(:normalized_coordinate, normalized_ambient_coordinate_type_v1();
            id="dgcp-normalized-coordinate-$suffix"),
         node(:physical_coordinate, tdpi_coordinate_type;
            id="dgcp-physical-coordinate-$suffix"),
         node(:normalized_metric, normalized_covariant_metric_type_v1();
            id="dgcp-normalized-metric-$suffix"),
         node(:physical_metric, tdpi_metric_type;
            id="dgcp-physical-metric-$suffix")),
        (binding.coordinate_edge, binding.metric_edge);
        registry=binding.registry)
    prebinding = DGCP._make_forward_graph_binding(:field_geometry, graph)
    support_ref = SpatialSupportRefV1("dgcp-support-$suffix")
    chart_ref = ChartRefV1("dgcp-chart-$suffix")
    frame_ref = CoordinateFrameRefV1("dgcp-frame-$suffix")
    support = SpatialSupportGeneV1(support_ref, 3, (frame_ref,),
        (CoordinateChartGeneV1(chart_ref, frame_ref, dgpi_chart_bounds,
            dgpi_periodic_axes,
            SpatialProgramRootRefV1(coordinate_site, 1,
                chart_coordinate_type_v1(),
                normalized_ambient_coordinate_type_v1()),
            SpatialProgramRootRefV1(metric_site, 1,
                chart_coordinate_type_v1(),
                normalized_covariant_metric_type_v1())),), (), dgpi_scale)
    coordinate_metric = DGCP.ThreeDCoordinateMetricV4(support_ref, chart_ref,
        coordinate_site, metric_site, prebinding.ast_root_identity_hashes[2],
        prebinding.ast_root_identity_hashes[4], tdpi_coordinate_type,
        tdpi_metric_type, dgpi_chart_bounds)
    declaration = DGCP.ThreeDPhysicalProviderInputV4("dgcp-declaration-$suffix",
        dgpi_boundary, coordinate_metric, tdpi_profiles_flux)
    field_genome = FieldGeometryGenomeV4(20260910,
        GenericThreeDG2Fixture._fixture_refs[2], graph;
        fields=(support, declaration))
    candidate = CandidateStatePackageV4("dgcp-candidate-$suffix",
        dgpi_base._fixture_mission, dgpi_base._fixture_mechanism,
        field_genome, dgpi_base._fixture_realization, generic_3d_registry)
    mission = (mission="desc-geometry-proof-$suffix",
        contract=candidate.mission_contract_ref)
    bounds = (declaration_hash=canonical_hash(declaration),
        scope="desc geometry proof variant")
    comparison_scope = ("desc-geometry-proof-$suffix",)
    scenario = (name="dgcp-scenario-$suffix", fixture="proof-variant")
    scenario_scope = (scenario.name,)
    compiled = DGCP.compile_candidate(candidate, generic_3d_registry;
        mission_payload=mission, bounds_payload=bounds,
        comparison_scope=comparison_scope, scenario_scope=scenario_scope)
    subject_binding = DGCP.make_three_d_physical_provider_input_binding(
        compiled, generic_3d_registry, mission, bounds, comparison_scope,
        scenario_scope, scenario, declaration)
    subject = DGCP.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, (subject_binding,), (scenario,),
        (materialization="desc-geometry-proof-variant",
         declaration_hash=canonical_hash(declaration)),
        DGCP.derive_capability_obligations(compiled))
    context = DGCP.make_forward_chain_context(candidate, compiled,
        generic_3d_registry, mission, bounds, comparison_scope,
        scenario_scope, subject, scenario)
    bridge = DGCP.compile_three_d_normalized_physical_root_bridge(context)
    evaluation = DGCP.interpret_desc_geometry_program(context, bridge,
        (0.75, 0.23, 0.17))
    (program=program, context=context, bridge=bridge, evaluation=evaluation)
end

@testset "analytic directed-rounding DESC geometry proof" begin
    resolution = dgcp_resolution
    certificate = dgcp_certificate
    payload = certificate.payload
    @test resolution.status === :proved
    @test isempty(resolution.recoverable_gaps)
    @test resolution.geometric_compatibility_proved
    @test resolution.certificate_emitted
    @test !resolution.request_emitted
    @test payload.proof_method === :analytic_fourier_mpfr
    @test payload.precision_bits == 256
    @test payload.phase_convention ===
        :two_pi_m_theta_minus_n_zeta_field_turn
    @test payload.azimuth_convention ===
        :two_pi_zeta_field_turn_over_nfp
    @test payload.boundary_value_exact
    @test payload.boundary_tangential_first_derivatives_exact
    @test payload.poloidal_seam_symbolic
    @test payload.field_period_equivariance_symbolic
    @test payload.metric_identity_symbolic
    @test payload.axis_regularity_symbolic
    @test payload.axis_coordinate_singularity_explicit
    @test payload.global_nondegenerate_for_positive_rho
    @test payload.determinant_orientation_sign == -1
    @test payload.major_radius_lower_bound > 0.0
    @test payload.cross_section_orientation_lower_bound > 0.0
    @test payload.normalized_oriented_volume_density_lower_bound > 0.0
    @test canonical_hash(certificate) == certificate.certificate_hash
    @test canonical_hash(resolution) == resolution.resolution_hash
    replay = DGCP.prove_desc_geometry_compatibility(
        dgpi_context, dgpi_bridge_resolution, dgpi_evaluation)
    @test semantic_view(replay) == semantic_view(resolution)
end

@testset "BigFloat lower bounds convert downward" begin
    for value in (BigFloat(1.0),
            (BigFloat(1.0) + BigFloat(nextfloat(1.0))) / 2,
            BigFloat(1.0) +
                (BigFloat(nextfloat(1.0)) - BigFloat(1.0)) * 3 / 4)
        converted = DGCP._dgcp_lower_float(value)
        @test BigFloat(converted) <= value
        @test BigFloat(nextfloat(converted)) > value
    end
end

@testset "certificate bound is below the exact program density" begin
    lower = dgcp_certificate.payload.
        normalized_oriented_volume_density_lower_bound
    for rho in (0.125, 0.5, 1.0), theta in (0.0, 0.17, 0.5, 0.83),
            zeta in (0.0, 0.31, 1.0)
        J = DGCP.desc_normalized_jacobian(dgpi_program,
            (rho, theta, zeta))
        density = -DGCP._dgpi_determinant(J) / rho
        @test density >= lower
    end
end

@testset "unsupported analytic family remains a recoverable gap" begin
    variant = dgcp_variant((0, 3, 1), (1, 1), "cubic")
    resolution = DGCP.prove_desc_geometry_compatibility(variant.context,
        variant.bridge, variant.evaluation)
    @test resolution.status === :recoverable_gap
    @test resolution.certificate === nothing
    @test resolution.recoverable_gaps == (
        DGCP._DGCP_GAPS[1], DGCP._DGCP_GAPS[5],
        DGCP._DGCP_GAPS[6], DGCP._DGCP_GAPS[7])
    @test !resolution.geometric_compatibility_proved
    @test !resolution.certificate_emitted
    @test !resolution.request_emitted
    @test canonical_hash(resolution) == resolution.resolution_hash
end

@testset "private, forged, and foreign certificates fail closed" begin
    certificate = dgcp_certificate
    @test_throws ArgumentError DGCP.DESCGeometryCompatibilityCertificateV4(
        DGCP._DGCPPrivateToken(), certificate.payload,
        certificate.certificate_hash)
    forged_payload = merge(certificate.payload,
        (normalized_oriented_volume_density_lower_bound=-1.0,))
    forged = DGCP.DESCGeometryCompatibilityCertificateV4(DGCP._DGCP_TOKEN,
        forged_payload, canonical_hash(forged_payload))
    @test_throws ArgumentError canonical_hash(forged)
    @test_throws ArgumentError DGCP.prove_desc_geometry_compatibility(
        tdnprb_context, tdnprb_resolution, dgpi_evaluation)
end

@testset "proof authority remains bounded" begin
    payload = dgcp_certificate.payload
    @test payload.claim_ceiling == screen_only
    @test !payload.request_emitted
    @test !payload.provider_selected
    @test !payload.provider_executed
    @test !payload.solver_execution_attempted
    @test !payload.solver_executed
    @test !payload.physical_validation
    @test !payload.engineering_validation
    @test !payload.grants_pass
    @test !payload.promotion_authority
    @test !payload.p5_ready
    @test !payload.terminal_authority
    @test payload.credible_physical_device_count == 0
end

println("DESC_GEOMETRY_COMPATIBILITY_PROOF_FOCUSED_EXIT_CODE=0")
