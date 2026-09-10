using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_desc_fixed_boundary_request_compiler.jl"))

function dfbrc_context_with_bindings(bindings; payload=(case="test",))
    subject = DFBRC.ExecutablePhysicalSubjectV4(
        dfbrc_compiled.prefix_hash,
        dfbrc_candidate.canonical_hashes.genome_bundle_hash,
        dfbrc_compiled.minimality_scope.mission_hash,
        dfbrc_compiled.minimality_scope.bounds_hash,
        bindings, (dfbrc_scenario,), payload,
        DFBRC.derive_capability_obligations(dfbrc_compiled))
    DFBRC.make_forward_chain_context(dfbrc_candidate, dfbrc_compiled,
        generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, subject, dfbrc_scenario)
end

function dfbrc_base_context_with_bindings(bindings; payload=(case="test",))
    subject = DFBRC.ExecutablePhysicalSubjectV4(
        tdpic_compiled.prefix_hash,
        tdpic_candidate.canonical_hashes.genome_bundle_hash,
        tdpic_compiled.minimality_scope.mission_hash,
        tdpic_compiled.minimality_scope.bounds_hash,
        bindings, (tdpic_scenario,), payload,
        DFBRC.derive_capability_obligations(tdpic_compiled))
    DFBRC.make_forward_chain_context(tdpic_candidate, tdpic_compiled,
        generic_3d_registry, tdpic_mission, tdpic_bounds,
        tdpic_comparison, tdpic_scenarios, subject, tdpic_scenario)
end

function dfbrc_controls(; id="dfbrc-test-controls", L=4, M=4, N=2,
        L_grid=8, M_grid=8, N_grid=6, max_iterations=80,
        ftol=1.0e-8, xtol=1.0e-8, gtol=1.0e-8,
        pressure_step=0.5, boundary_step=0.5, shaping_first=true,
        max_force_normalized_magnetic=1.0e-3,
        max_fixed_constraint_error=1.0e-10, min_sqrt_g=0.0)
    DFBRC.DESCFixedBoundaryRequestDeclarationV4(id, dfbrc_compatibility;
        L=L, M=M, N=N, L_grid=L_grid, M_grid=M_grid, N_grid=N_grid,
        max_iterations=max_iterations, ftol=ftol, xtol=xtol, gtol=gtol,
        pressure_step=pressure_step, boundary_step=boundary_step,
        shaping_first=shaping_first,
        max_force_normalized_magnetic=max_force_normalized_magnetic,
        max_fixed_constraint_error=max_fixed_constraint_error,
        min_sqrt_g=min_sqrt_g)
end

function dfbrc_private_value(T, values;
        token=DFBRC._DFBRC_TOKEN)
    T(token, (getproperty(values, name) for name in fieldnames(T))...)
end

function dfbrc_field_values(value; overrides=(;))
    (; (name => (hasproperty(overrides, name) ?
        getproperty(overrides, name) : getfield(value, name))
       for name in fieldnames(typeof(value)))...)
end

function dfbrc_test_boundary(; id="dfbrc-test-boundary", field_periods=5,
        symmetric=true,
        radial=dfbrc_boundary.radial_coefficients,
        vertical=dfbrc_boundary.vertical_coefficients)
    DFBRC.ThreeDFourierBoundaryV4(id, field_periods, symmetric,
        radial, vertical)
end

function dfbrc_test_profiles(; id="dfbrc-test-profiles",
        pressure=(1000.0, -1000.0), iota=(0.4, 0.1), flux=1.0)
    DFBRC.ThreeDProfilesFluxV4(id,
        DFBRC.ThreeDRadialProfileV4("$id-pressure", :pressure,
            pressure, tdpic_pressure_unit, tdpic_radial_domain),
        DFBRC.ThreeDRadialProfileV4("$id-iota", :iota,
            iota, tdpic_unit, tdpic_radial_domain),
        flux, tdpic_flux_unit)
end

@testset "current and declared fixtures remain exact proof gaps" begin
    current = dfbrc_current_fixture_resolution
    @test current.status === :recoverable_gap
    @test current.request === nothing
    @test current.recoverable_gaps == DFBRC._DFBRC_REQUIRED_GAPS
    @test canonical_hash(current) == current.resolution_hash

    declared = dfbrc_resolution
    @test declared.status === :recoverable_gap
    @test declared.request === nothing
    @test declared.recoverable_gaps ==
        (DFBRC._DFBRC_GEOMETRY_PROOF_GAP,)
    @test canonical_hash(declared) == declared.resolution_hash
    @test dfbrc_composition_resolution.status === :input_complete
    @test !isdefined(Main, :dfbrc_request)
    @test_throws ArgumentError DFBRC.validate_desc_fixed_boundary_request(
        dfbrc_context,
        dfbrc_private_value(DFBRC.DESCFixedBoundaryExecutionRequestV4,
            merge(DFBRC._dfbrc_request_body(dfbrc_context,
                    something(dfbrc_composition_resolution.input),
                    dfbrc_compatibility, dfbrc_request_declaration,
                    dfbrc_request_binding,
                    DFBRC._dfbrc_runner_payload(
                        something(dfbrc_composition_resolution.input),
                        dfbrc_request_declaration)),
                (request_hash=digest256_text("untrusted-request"),))))
end

@testset "convention declaration is explicit and never a proof" begin
    convention = dfbrc_compatibility
    @test canonical_hash(convention) == convention.declaration_hash
    @test convention.physical_declaration_hash ==
        canonical_hash(dfbrc_physical_declaration)
    @test convention.support_mapping_declaration_hash ==
        canonical_hash(dfbrc_support_mapping)
    @test convention.physical_support_ref ==
        dfbrc_physical_declaration.coordinate_metric.support_ref
    @test convention.chart_ref ==
        dfbrc_physical_declaration.coordinate_metric.chart_ref
    @test convention.coordinate_order == (:rho, :theta, :zeta)
    @test convention.radial_domain === :rho_zero_to_one
    @test convention.toroidal_domain === :zeta_zero_to_two_pi_over_nfp
    @test convention.radial_fourier_basis ===
        :cos_mtheta_minus_n_nfp_zeta
    @test convention.vertical_fourier_basis ===
        :sin_mtheta_minus_n_nfp_zeta
    @test convention.mode_index_mapping ===
        :poloidal_to_m_toroidal_to_n_identity
    @test convention.radial_profile_basis ===
        :ascending_monic_power_series_in_rho
    @test convention.coordinate_orientation ===
        :right_handed_e_theta_cross_e_zeta_outward
    @test convention.coefficient_length_unit === :metre
    @test !convention.geometric_compatibility_proved
    @test !hasproperty(convention, :proof_method)
    @test !hasproperty(convention, :proof_artifact_hash)
    @test_throws ArgumentError DFBRC.declare_desc_geometry_convention(
        dfbrc_physical_declaration, tdpic_support_mapping;
        declaration_id="foreign-map")
end

@testset "binding is rebuilt across every current-context join" begin
    binding = dfbrc_request_binding
    @test canonical_hash(binding) == binding.binding_hash
    @test binding.declaration_hash == canonical_hash(dfbrc_request_declaration)
    @test binding.compatibility_declaration_hash ==
        canonical_hash(dfbrc_compatibility)
    @test binding.candidate_hash == DFBRC._forward_candidate_identity(
        dfbrc_candidate)
    @test binding.compiled_prefix_hash == dfbrc_compiled.prefix_hash
    @test binding.field_geometry_genome_hash ==
        field_geometry_hash(dfbrc_candidate.field_geometry_genome_ref)
    @test binding.composition_binding_hash ==
        canonical_hash(dfbrc_composition_binding)
    @test binding.physical_binding_hash == canonical_hash(dfbrc_physical_binding)
    @test binding.support_mapping_binding_hash ==
        canonical_hash(dfbrc_support_mapping_binding)
    @test binding.region_law_set_binding_hash ==
        canonical_hash(dfbrc_region_law_set_binding)
    @test binding.oriented_binding_hash ==
        canonical_hash(dfbrc_oriented_binding)
    @test binding.residual_binding_hash ==
        canonical_hash(dfbrc_residual_binding)
    @test binding.discretization_binding_hash ==
        canonical_hash(dfbrc_discretization_binding)
    @test binding.mission_hash == DFBRC._runtime_decl_hash(dfbrc_mission)
    @test binding.bounds_hash == DFBRC._runtime_decl_hash(dfbrc_bounds)
    @test binding.scenario_hash == canonical_hash(dfbrc_scenario)

    rebuilt = DFBRC.make_desc_fixed_boundary_request_binding(
        dfbrc_compiled, generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        dfbrc_composition_binding, dfbrc_physical_binding,
        dfbrc_support_mapping_binding, dfbrc_region_law_set_binding,
        dfbrc_oriented_binding, dfbrc_residual_binding,
        dfbrc_discretization_binding, dfbrc_compatibility,
        dfbrc_request_declaration)
    @test canonical_hash(rebuilt) == canonical_hash(binding)
    @test semantic_view(rebuilt) == semantic_view(binding)

    @test_throws ArgumentError DFBRC.make_desc_fixed_boundary_request_binding(
        dfbrc_compiled, generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        tdpic_composition_binding, tdpic_physical_binding,
        tdpic_support_mapping_binding, tdpic_region_law_set_binding,
        tdpic_oriented_binding, tdpic_residual_binding,
        tdpic_discretization_binding, dfbrc_compatibility,
        dfbrc_request_declaration)
    @test_throws ArgumentError DFBRC.make_desc_fixed_boundary_request_binding(
        dfbrc_compiled, generic_3d_registry, dfbrc_mission, dfbrc_bounds,
        dfbrc_comparison, dfbrc_scenarios, dfbrc_scenario,
        dfbrc_composition_binding, tdpic_physical_binding,
        dfbrc_support_mapping_binding, dfbrc_region_law_set_binding,
        dfbrc_oriented_binding, dfbrc_residual_binding,
        dfbrc_discretization_binding, dfbrc_compatibility,
        dfbrc_request_declaration)
end

@testset "missing binding is recoverable; duplicate and orphan are corrupt" begin
    missing = DFBRC.compile_desc_fixed_boundary_request(
        dfbrc_context_with_bindings(dfbrc_component_bindings;
            payload=(case="missing-request-binding",)))
    @test missing.status === :recoverable_gap
    @test missing.request === nothing
    @test missing.recoverable_gaps == (DFBRC._DFBRC_REQUIRED_GAPS[3],)

    duplicate = dfbrc_context_with_bindings((dfbrc_component_bindings...,
        dfbrc_request_binding, dfbrc_request_binding);
        payload=(case="duplicate-request-binding",))
    @test_throws ArgumentError DFBRC.compile_desc_fixed_boundary_request(
        duplicate)

    orphan = dfbrc_base_context_with_bindings((
        tdpic_physical_binding, tdpic_support_mapping_binding,
        tdpic_region_law_set_binding, tdpic_oriented_binding,
        tdpic_residual_binding, tdpic_discretization_binding,
        tdpic_composition_binding, dfbrc_request_binding);
        payload=(case="orphan-request-binding",))
    @test_throws ArgumentError DFBRC.compile_desc_fixed_boundary_request(orphan)

    incomplete_orphan = dfbrc_context_with_bindings((
        dfbrc_component_bindings[1:6]..., dfbrc_request_binding);
        payload=(case="orphan-request-binding-without-composition",))
    @test_throws ArgumentError DFBRC.compile_desc_fixed_boundary_request(
        incomplete_orphan)
end

@testset "latent payload mapping is exact but not publicly emitted" begin
    composition = something(dfbrc_composition_resolution.input)
    declaration = dfbrc_request_declaration
    payload = DFBRC._dfbrc_runner_payload(composition, declaration)
    @test DFBRC._dfbrc_validate_runner_payload(payload) === payload
    @test keys(payload) == (:runner_version, :model_id, :source_binding,
        :boundary, :profiles, :resolution, :solver, :audit)
    @test payload.runner_version ==
        "desc_explicit_fourier_fixed_boundary_runner_v1"
    @test payload.model_id ==
        "stellarator_symmetric_fourier_fixed_boundary_v1"
    @test payload.source_binding == "DESC-0.17.3"
    @test payload.boundary.field_periods == dfbrc_boundary.field_periods
    @test payload.boundary.R_modes == ((m=0, n=0, coefficient_m=5.5),
        (m=1, n=0, coefficient_m=0.4),
        (m=1, n=1, coefficient_m=0.05))
    @test payload.boundary.Z_modes ==
        ((m=-1, n=0, coefficient_m=-0.4),
         (m=-1, n=1, coefficient_m=-0.05))
    @test payload.profiles.pressure_power_series_pa == (1000.0, -1000.0)
    @test payload.profiles.iota_power_series == (0.4, 0.1)
    @test payload.profiles.toroidal_flux_wb == 1.0
    @test payload.resolution ==
        (L=4, M=4, N=2, L_grid=8, M_grid=8, N_grid=6)
    @test payload.solver.optimizer == "lsq-exact"
    @test payload.audit.max_force_normalized_magnetic == 1.0e-3
    @test declaration.generic_control_translation === :none
    @test DFBRC._dfbrc_unsupported_reasons(composition,
        dfbrc_compatibility, declaration) == ()
    @test_throws ArgumentError DFBRC._dfbrc_make_request(dfbrc_context,
        composition, dfbrc_compatibility, declaration,
        dfbrc_request_binding)

    extra = merge(payload, (unexpected=true,))
    @test_throws ArgumentError DFBRC._dfbrc_validate_runner_payload(extra)
    vector_modes = merge(payload, (boundary=merge(payload.boundary,
        (R_modes=collect(payload.boundary.R_modes),)),))
    @test_throws ArgumentError DFBRC._dfbrc_validate_runner_payload(vector_modes)
    duplicate_modes = merge(payload, (boundary=merge(payload.boundary,
        (R_modes=(payload.boundary.R_modes...,
            payload.boundary.R_modes[2]),)),))
    @test_throws ArgumentError DFBRC._dfbrc_validate_runner_payload(
        duplicate_modes)
    wrong_symmetry = merge(payload, (boundary=merge(payload.boundary,
        (stellarator_symmetric=false,)),))
    @test_throws ArgumentError DFBRC._dfbrc_validate_runner_payload(
        wrong_symmetry)
    bad_orientation = merge(payload, (boundary=merge(payload.boundary,
        (Z_modes=((m=-1, n=0, coefficient_m=0.4),
                  (m=-1, n=1, coefficient_m=0.05)),)),))
    @test_throws ArgumentError DFBRC._dfbrc_validate_runner_payload(
        bad_orientation)
    open_pressure = merge(payload, (profiles=merge(payload.profiles,
        (pressure_power_series_pa=(1000.0, -900.0),)),))
    @test_throws ArgumentError DFBRC._dfbrc_validate_runner_payload(
        open_pressure)
    bad_iota = merge(payload, (profiles=merge(payload.profiles,
        (iota_power_series=(0.01,),)),))
    @test_throws ArgumentError DFBRC._dfbrc_validate_runner_payload(bad_iota)
end

@testset "DESC control endpoints and constructor adversaries" begin
    low = dfbrc_controls(id="dfbrc-low", L=2, M=2, N=1,
        L_grid=2, M_grid=2, N_grid=1, max_iterations=1,
        ftol=1.0e-12, xtol=1.0e-12, gtol=1.0e-12,
        pressure_step=0.05, boundary_step=0.05,
        max_force_normalized_magnetic=1.0e-5,
        max_fixed_constraint_error=1.0e-15, min_sqrt_g=0.0)
    high = dfbrc_controls(id="dfbrc-high", L=12, M=12, N=12,
        L_grid=24, M_grid=24, N_grid=24, max_iterations=200,
        ftol=1.0e-3, xtol=1.0e-3, gtol=1.0e-3,
        pressure_step=1.0, boundary_step=1.0,
        max_force_normalized_magnetic=0.1,
        max_fixed_constraint_error=1.0e-8, min_sqrt_g=1.0)
    @test canonical_hash(low) == low.declaration_hash
    @test canonical_hash(high) == high.declaration_hash
    @test low.generic_control_translation === :none
    @test high.generic_control_translation === :none

    @test_throws ArgumentError dfbrc_controls(L=true)
    @test_throws ArgumentError dfbrc_controls(L=1)
    @test_throws ArgumentError dfbrc_controls(L=13, L_grid=13)
    @test_throws ArgumentError dfbrc_controls(M=1)
    @test_throws ArgumentError dfbrc_controls(N=0)
    @test_throws ArgumentError dfbrc_controls(L=6, L_grid=5)
    @test_throws ArgumentError dfbrc_controls(M=6, M_grid=5)
    @test_throws ArgumentError dfbrc_controls(N=6, N_grid=5)
    @test_throws ArgumentError dfbrc_controls(max_iterations=0)
    @test_throws ArgumentError dfbrc_controls(max_iterations=201)
    @test_throws ArgumentError dfbrc_controls(ftol=NaN)
    @test_throws ArgumentError dfbrc_controls(ftol=1.0e-13)
    @test_throws ArgumentError dfbrc_controls(xtol=1.0e-2)
    @test_throws ArgumentError dfbrc_controls(gtol=Inf)
    @test_throws ArgumentError dfbrc_controls(pressure_step=0.049)
    @test_throws ArgumentError dfbrc_controls(boundary_step=1.001)
    @test_throws ArgumentError dfbrc_controls(shaping_first=1)
    @test_throws ArgumentError dfbrc_controls(
        max_force_normalized_magnetic=1.0e-6)
    @test_throws ArgumentError dfbrc_controls(
        max_fixed_constraint_error=1.0e-7)
    @test_throws ArgumentError dfbrc_controls(min_sqrt_g=-eps())
    @test_throws ArgumentError dfbrc_controls(min_sqrt_g=1.0 + eps())
end

@testset "boundary exclusions are exact and recoverable" begin
    declaration = dfbrc_request_declaration
    @test DFBRC._dfbrc_boundary_reasons(dfbrc_boundary, declaration) == ()

    low_nfp = dfbrc_test_boundary(id="low-nfp", field_periods=1)
    @test "desc_field_periods_outside_2_8" in
        DFBRC._dfbrc_boundary_reasons(low_nfp, declaration)
    high_nfp = dfbrc_test_boundary(id="high-nfp", field_periods=9)
    @test "desc_field_periods_outside_2_8" in
        DFBRC._dfbrc_boundary_reasons(high_nfp, declaration)
    nonsymmetric = dfbrc_test_boundary(id="not-symmetric", symmetric=false)
    @test "desc_requires_stellarator_symmetric_boundary" in
        DFBRC._dfbrc_boundary_reasons(nonsymmetric, declaration)

    bad_r_symmetry = dfbrc_test_boundary(id="bad-r-symmetry",
        radial=(DFBRC.ThreeDFourierCoefficientV4(0, 0, 5.5),
                DFBRC.ThreeDFourierCoefficientV4(-1, 0, 0.4)))
    @test "desc_radial_mode_would_be_truncated_by_symmetry" in
        DFBRC._dfbrc_boundary_reasons(bad_r_symmetry, declaration)
    bad_z_symmetry = dfbrc_test_boundary(id="bad-z-symmetry",
        vertical=(DFBRC.ThreeDFourierCoefficientV4(1, 0, -0.4),))
    @test "desc_vertical_mode_would_be_truncated_by_symmetry" in
        DFBRC._dfbrc_boundary_reasons(bad_z_symmetry, declaration)

    outside_mode = dfbrc_test_boundary(id="outside-mode",
        radial=(DFBRC.ThreeDFourierCoefficientV4(0, 0, 5.5),
                DFBRC.ThreeDFourierCoefficientV4(7, 1, 0.1)))
    @test "desc_boundary_mode_outside_abs_6" in
        DFBRC._dfbrc_boundary_reasons(outside_mode, declaration)
    crowded_radial = (DFBRC.ThreeDFourierCoefficientV4(0, 0, 100.0),
        (DFBRC.ThreeDFourierCoefficientV4(1, n, 0.1)
         for n in 0:29)...)
    crowded = dfbrc_test_boundary(id="crowded", radial=crowded_radial)
    @test "desc_radial_mode_count_outside_1_30" in
        DFBRC._dfbrc_boundary_reasons(crowded, declaration)

    weak_radius = dfbrc_test_boundary(id="weak-radius",
        radial=(DFBRC.ThreeDFourierCoefficientV4(0, 0, 0.7),
                DFBRC.ThreeDFourierCoefficientV4(1, 0, 0.4)))
    @test "desc_major_radius_dominance_not_satisfied" in
        DFBRC._dfbrc_boundary_reasons(weak_radius, declaration)
    left_handed = dfbrc_test_boundary(id="left-handed",
        vertical=(DFBRC.ThreeDFourierCoefficientV4(-1, 0, 0.4),
                  DFBRC.ThreeDFourierCoefficientV4(-1, 1, 0.05)))
    @test "desc_boundary_not_strictly_right_handed" in
        DFBRC._dfbrc_boundary_reasons(left_handed, declaration)

    uncovered = dfbrc_test_boundary(id="uncovered",
        radial=(DFBRC.ThreeDFourierCoefficientV4(0, 0, 5.5),
                DFBRC.ThreeDFourierCoefficientV4(1, 0, 0.4),
                DFBRC.ThreeDFourierCoefficientV4(5, 3, 0.01)),
        vertical=(DFBRC.ThreeDFourierCoefficientV4(-1, 0, -0.4),
                  DFBRC.ThreeDFourierCoefficientV4(-5, 3, -0.01)))
    uncovered_reasons = DFBRC._dfbrc_boundary_reasons(uncovered, declaration)
    @test "desc_spectral_m_below_boundary_mode" in uncovered_reasons
    @test "desc_spectral_n_below_boundary_mode" in uncovered_reasons
end

@testset "profile exclusions cover sampled shapes and endpoints" begin
    @test DFBRC._dfbrc_profile_reasons(dfbrc_profiles) == ()
    @test DFBRC._dfbrc_profile_reasons(
        dfbrc_test_profiles(id="flux-low", flux=1.0e-4)) == ()
    @test DFBRC._dfbrc_profile_reasons(
        dfbrc_test_profiles(id="flux-high", flux=100.0)) == ()

    open_edge = dfbrc_test_profiles(id="open-edge",
        pressure=(1000.0, -900.0))
    @test "desc_pressure_profile_not_closed_at_rho_1" in
        DFBRC._dfbrc_profile_reasons(open_edge)
    negative_inside = dfbrc_test_profiles(id="negative-inside",
        pressure=(1000.0, -2500.0, 1500.0))
    @test "desc_pressure_profile_negative_on_audited_grid" in
        DFBRC._dfbrc_profile_reasons(negative_inside)
    long_pressure = dfbrc_test_profiles(id="long-pressure",
        pressure=(1000.0, -1000.0, ntuple(_ -> 0.0, 12)...))
    @test "desc_pressure_series_length_outside_1_13" in
        DFBRC._dfbrc_profile_reasons(long_pressure)
    long_iota = dfbrc_test_profiles(id="long-iota",
        iota=(0.4, ntuple(_ -> 0.0, 13)...))
    @test "desc_iota_series_length_outside_1_13" in
        DFBRC._dfbrc_profile_reasons(long_iota)
    low_iota = dfbrc_test_profiles(id="low-iota", iota=(0.01,))
    @test "desc_iota_profile_outside_abs_0_02_3" in
        DFBRC._dfbrc_profile_reasons(low_iota)
    high_iota = dfbrc_test_profiles(id="high-iota", iota=(3.01,))
    @test "desc_iota_profile_outside_abs_0_02_3" in
        DFBRC._dfbrc_profile_reasons(high_iota)
    low_flux = dfbrc_test_profiles(id="below-flux", flux=9.9e-5)
    @test "desc_toroidal_flux_outside_1e_4_100_wb" in
        DFBRC._dfbrc_profile_reasons(low_flux)
    high_flux = dfbrc_test_profiles(id="above-flux", flux=100.1)
    @test "desc_toroidal_flux_outside_1e_4_100_wb" in
        DFBRC._dfbrc_profile_reasons(high_flux)

    current_profile = DFBRC.ThreeDRadialProfileV4("dfbrc-current",
        :current, (1.0,), DFBRC._tdpi_current_unit(), tdpic_radial_domain)
    current_profiles = DFBRC.ThreeDProfilesFluxV4("current-profiles",
        DFBRC.ThreeDRadialProfileV4("current-pressure", :pressure,
            (1000.0, -1000.0), tdpic_pressure_unit,
            tdpic_radial_domain), current_profile, 1.0, tdpic_flux_unit)
    @test "desc_requires_iota_profile_not_current" in
        DFBRC._dfbrc_profile_reasons(current_profiles)
end

@testset "canonical validators reject self-consistent forged values" begin
    convention_body = merge(DFBRC._dfbrc_compatibility_body(
        dfbrc_compatibility.declaration_id,
        dfbrc_compatibility.physical_declaration_hash,
        dfbrc_compatibility.support_mapping_declaration_hash,
        dfbrc_compatibility.physical_support_ref,
        dfbrc_compatibility.chart_ref), (provider_selected=true,))
    forged_convention = dfbrc_private_value(
        DFBRC.DESCGeometryCompatibilityV4,
        merge(convention_body,
            (declaration_hash=canonical_hash(convention_body),)))
    @test_throws ArgumentError canonical_hash(forged_convention)

    declaration_body = DFBRC._dfbrc_declaration_body(
        "forged-invalid-range",
        canonical_hash(dfbrc_compatibility), 1,
        dfbrc_request_declaration.spectral_m,
        dfbrc_request_declaration.spectral_n,
        dfbrc_request_declaration.grid_l,
        dfbrc_request_declaration.grid_m,
        dfbrc_request_declaration.grid_n,
        dfbrc_request_declaration.optimizer,
        dfbrc_request_declaration.max_iterations,
        dfbrc_request_declaration.ftol,
        dfbrc_request_declaration.xtol,
        dfbrc_request_declaration.gtol,
        dfbrc_request_declaration.pressure_step,
        dfbrc_request_declaration.boundary_step,
        dfbrc_request_declaration.shaping_first,
        dfbrc_request_declaration.max_force_normalized_magnetic,
        dfbrc_request_declaration.max_fixed_constraint_error,
        dfbrc_request_declaration.min_sqrt_g)
    forged_declaration = dfbrc_private_value(
        DFBRC.DESCFixedBoundaryRequestDeclarationV4,
        merge(declaration_body,
            (declaration_hash=canonical_hash(declaration_body),)))
    @test_throws ArgumentError canonical_hash(forged_declaration)

    binding_view = semantic_view(dfbrc_request_binding)
    binding_body = NamedTuple{keys(binding_view)[1:end-1]}(
        values(binding_view)[1:end-1])
    forged_binding_body = merge(binding_body, (solver_executed=true,))
    forged_binding = dfbrc_private_value(
        DFBRC.DESCFixedBoundaryRequestBindingV4,
        merge(forged_binding_body,
            (binding_hash=canonical_hash(forged_binding_body),)))
    @test_throws ArgumentError canonical_hash(forged_binding)

    composition = something(dfbrc_composition_resolution.input)
    request_body = DFBRC._dfbrc_request_body(dfbrc_context, composition,
        dfbrc_compatibility, dfbrc_request_declaration,
        dfbrc_request_binding,
        DFBRC._dfbrc_runner_payload(composition,
            dfbrc_request_declaration))
    forged_request = dfbrc_private_value(
        DFBRC.DESCFixedBoundaryExecutionRequestV4,
        merge(request_body, (request_hash=canonical_hash(request_body),)))
    @test_throws ArgumentError canonical_hash(forged_request)
    @test_throws ArgumentError DFBRC.desc_fixed_boundary_runner_payload(
        forged_request)
    @test !DFBRC.validate_desc_fixed_boundary_request(forged_request)

    resolution_body = merge(DFBRC._dfbrc_resolution_body(
        dfbrc_context.context_hash, :recoverable_gap, nothing,
        (DFBRC._DFBRC_GEOMETRY_PROOF_GAP,)), (grants_pass=true,))
    forged_resolution = dfbrc_private_value(
        DFBRC.DESCFixedBoundaryRequestResolutionV4,
        dfbrc_field_values(dfbrc_resolution; overrides=(grants_pass=true,
            resolution_hash=canonical_hash(resolution_body))))
    @test_throws ArgumentError canonical_hash(forged_resolution)

    function forged_gap_resolution(gaps)
        body = DFBRC._dfbrc_resolution_body(dfbrc_context.context_hash,
            :recoverable_gap, nothing, gaps)
        dfbrc_private_value(DFBRC.DESCFixedBoundaryRequestResolutionV4,
            dfbrc_field_values(dfbrc_resolution; overrides=(
                recoverable_gaps=gaps,
                resolution_hash=canonical_hash(body))))
    end
    @test_throws ArgumentError canonical_hash(forged_gap_resolution(
        ("unknown_desc_gap",)))
    @test_throws ArgumentError canonical_hash(forged_gap_resolution((
        DFBRC._DFBRC_GEOMETRY_PROOF_GAP,
        DFBRC._DFBRC_GEOMETRY_PROOF_GAP)))
    @test_throws ArgumentError canonical_hash(forged_gap_resolution((
        DFBRC._DFBRC_REQUIRED_GAPS[2], DFBRC._DFBRC_REQUIRED_GAPS[1])))
    ordered_domain_gaps = (
        "desc_compatibility_physical_hash_mismatch",
        "desc_field_periods_outside_2_8",
        DFBRC._DFBRC_GEOMETRY_PROOF_GAP)
    ordered_resolution = forged_gap_resolution(ordered_domain_gaps)
    @test canonical_hash(ordered_resolution) ==
        ordered_resolution.resolution_hash
end

@testset "private constructors require the one mutable flyweight identity" begin
    @test ismutabletype(DFBRC._DFBRCPrivateToken)
    wrong = DFBRC._DFBRCPrivateToken()
    @test wrong !== DFBRC._DFBRC_TOKEN

    convention_values = semantic_view(dfbrc_compatibility)
    @test_throws ArgumentError dfbrc_private_value(
        DFBRC.DESCGeometryCompatibilityV4, convention_values; token=wrong)
    declaration_values = semantic_view(dfbrc_request_declaration)
    @test_throws ArgumentError dfbrc_private_value(
        DFBRC.DESCFixedBoundaryRequestDeclarationV4,
        declaration_values; token=wrong)
    binding_values = semantic_view(dfbrc_request_binding)
    @test_throws ArgumentError dfbrc_private_value(
        DFBRC.DESCFixedBoundaryRequestBindingV4,
        binding_values; token=wrong)
    request_body = DFBRC._dfbrc_request_body(dfbrc_context,
        something(dfbrc_composition_resolution.input), dfbrc_compatibility,
        dfbrc_request_declaration, dfbrc_request_binding,
        DFBRC._dfbrc_runner_payload(
            something(dfbrc_composition_resolution.input),
            dfbrc_request_declaration))
    @test_throws ArgumentError dfbrc_private_value(
        DFBRC.DESCFixedBoundaryExecutionRequestV4,
        merge(request_body, (request_hash=canonical_hash(request_body),));
        token=wrong)
    resolution_values = dfbrc_field_values(dfbrc_resolution)
    @test_throws ArgumentError dfbrc_private_value(
        DFBRC.DESCFixedBoundaryRequestResolutionV4,
        resolution_values; token=wrong)
end

@testset "authority metadata is complete and uniformly false" begin
    for value in (dfbrc_compatibility, dfbrc_request_declaration,
            dfbrc_request_binding, dfbrc_resolution)
        @test value.model_class === :manufactured_input_fixture
        @test value.claim_ceiling == screen_only
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
    @test !dfbrc_compatibility.geometric_compatibility_proved
    @test !dfbrc_request_binding.geometric_compatibility_proved

    manifest = DFBRC.desc_fixed_boundary_request_manifest()
    @test manifest.statuses == (:recoverable_gap,)
    @test !manifest.can_emit_request
    @test manifest.requires_three_d_physical_input_composition
    @test manifest.requires_geometry_convention_declaration
    @test !manifest.geometric_compatibility_proved
    @test manifest.generic_control_translation === :none
    @test manifest.claim_ceiling == screen_only
    @test !manifest.provider_selected
    @test !manifest.provider_executed
    @test !manifest.solver_execution_attempted
    @test !manifest.solver_executed
    @test !manifest.physical_validation
    @test !manifest.engineering_validation
    @test !manifest.emits_evidence
    @test !manifest.grants_pass
    @test !manifest.promotion_authority
    @test !manifest.p5_ready
    @test !manifest.terminal_authority
    @test manifest.credible_physical_device_count == 0
end
