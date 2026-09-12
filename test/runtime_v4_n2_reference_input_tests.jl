using Test
using SHA
using JSON3
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_three_d_physical_provider_input.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "N2ReferenceInputV4.jl"))
const N2R = N2ReferenceInputRuntime

const n2_artifact_path = joinpath(@__DIR__, "..", "benchmarks",
    "desc_heliotron_v0173", "HELIOTRON_output.h5")
const n2_result_path = joinpath(@__DIR__, "..", "runs",
    "goal_recovery_20260913_012528_cst",
    "n2_desc_heliotron_normalize_r2", "result.json")
const n2_record = JSON3.read(read(n2_result_path, String))

function n2_tuple_rows(rows)
    Tuple((m=Int(row.m), n=Int(row.n),
        coefficient_m=Float64(row.coefficient_m)) for row in rows)
end

function n2_subject(record=n2_record)
    source = record.subject
    boundary = source.boundary
    pressure = source.pressure_profile
    rotational = source.rotational_or_current_profile
    provenance = source.provenance
    resolution = source.source_resolution
    (schema_version=String(source.schema_version),
     source_class=String(source.source_class),
     source_artifact_sha256=String(source.source_artifact_sha256),
     provenance=(
        distributed_in_release_tag=String(provenance.distributed_in_release_tag),
        distribution_tag_commit=String(provenance.distribution_tag_commit),
        embedded_producer_version=String(provenance.embedded_producer_version),
        loader_runtime_version=String(provenance.loader_runtime_version),
        equilibrium_count=Int(provenance.equilibrium_count),
        selected_equilibrium_index=Int(provenance.selected_equilibrium_index)),
     field_periods=Int(source.field_periods),
     stellarator_symmetric=Bool(source.stellarator_symmetric),
     boundary=(radial_modes=n2_tuple_rows(boundary.radial_modes),
        vertical_modes=n2_tuple_rows(boundary.vertical_modes),
        uniform_pointwise_error_bound_m=(
            R=Float64(boundary.uniform_pointwise_error_bound_m.R),
            Z=Float64(boundary.uniform_pointwise_error_bound_m.Z),
            RZ_euclidean=Float64(
                boundary.uniform_pointwise_error_bound_m.RZ_euclidean))),
     pressure_profile=(quantity=String(pressure.quantity),
        unit=String(pressure.unit),
        coefficients_by_power=Tuple(Float64(x) for x in pressure.coefficients_by_power),
        uniform_pointwise_error_bound=Float64(
            pressure.uniform_pointwise_error_bound)),
     rotational_or_current_profile=(quantity=String(rotational.quantity),
        unit=String(rotational.unit),
        coefficients_by_power=Tuple(Float64(x) for x in
            rotational.coefficients_by_power),
        uniform_pointwise_error_bound=Float64(
            rotational.uniform_pointwise_error_bound)),
     toroidal_flux=(value=Float64(source.toroidal_flux.value),
        unit=String(source.toroidal_flux.unit)),
     source_resolution=(L=Int(resolution.L), M=Int(resolution.M),
        N=Int(resolution.N), L_grid=Int(resolution.L_grid),
        M_grid=Int(resolution.M_grid), N_grid=Int(resolution.N_grid)),
     display_name=String(record.reference.display_name),
     reference_id=String(record.reference.reference_id))
end

const n2_boundary = TDPI.ThreeDFourierBoundaryV4(
    "desc-heliotron-v0173-selected-equilibrium-3", 19, true,
    (TDPI.ThreeDFourierCoefficientV4(-1, -1, 0.3),
     TDPI.ThreeDFourierCoefficientV4(0, 0, 10.000000000000005),
     TDPI.ThreeDFourierCoefficientV4(1, 0, -0.9999999999999998),
     TDPI.ThreeDFourierCoefficientV4(1, 1, -0.29999999999999993)),
    (TDPI.ThreeDFourierCoefficientV4(1, -1, -0.29999999999999993),
     TDPI.ThreeDFourierCoefficientV4(-1, 0, 1.0),
     TDPI.ThreeDFourierCoefficientV4(-1, 1, -0.3)))
const n2_pressure = TDPI.ThreeDRadialProfileV4(
    "desc-heliotron-pressure", :pressure,
    (18000.0, 0.0, -36000.0, 0.0, 18000.0), tdpi_pressure_unit,
    tdpi_radial_domain)
const n2_iota = TDPI.ThreeDRadialProfileV4(
    "desc-heliotron-iota", :iota, (1.0, 0.0, 1.5), UnitSignature(),
    tdpi_radial_domain)
const n2_profiles = TDPI.ThreeDProfilesFluxV4(
    "desc-heliotron-profiles", n2_pressure, n2_iota, 1.0, tdpi_flux_unit)
const n2_input = TDPI.ThreeDPhysicalProviderInputV4(
    "desc-heliotron-external-boundary-profiles-with-coordinate-gap",
    n2_boundary, tdpi_coordinate_metric, n2_profiles)
const n2_field_genome = FieldGeometryGenomeV4(20260913,
    GenericThreeDG2Fixture._fixture_refs[2], tdpi_field_graph;
    fields=(tdpi_support, n2_input))
const n2_candidate = CandidateStatePackageV4(
    "desc-heliotron-reference-input-candidate",
    tdpi_base._fixture_mission, tdpi_base._fixture_mechanism,
    n2_field_genome, tdpi_base._fixture_realization, generic_3d_registry)
const n2_mission = (mission="n2-external-reference-input-binding",
    contract=n2_candidate.mission_contract_ref)
const n2_bounds = (declaration_hash=TDPI.canonical_hash(n2_input),
    scope="external-boundary-and-profiles-only")
const n2_comparison_scope = ("n2-external-reference-input",)
const n2_scenario = (name="desc-heliotron-reference-input",
    source_class="external_simulation")
const n2_scenario_scope = (n2_scenario.name,)
const n2_compiled = TDPI.compile_candidate(n2_candidate, generic_3d_registry;
    mission_payload=n2_mission, bounds_payload=n2_bounds,
    comparison_scope=n2_comparison_scope, scenario_scope=n2_scenario_scope)
const n2_subject_binding = TDPI.make_three_d_physical_provider_input_binding(
    n2_compiled, generic_3d_registry, n2_mission, n2_bounds,
    n2_comparison_scope, n2_scenario_scope, n2_scenario, n2_input)
const n2_executable_subject = TDPI.ExecutablePhysicalSubjectV4(
    n2_compiled.prefix_hash, n2_candidate.canonical_hashes.genome_bundle_hash,
    n2_compiled.minimality_scope.mission_hash,
    n2_compiled.minimality_scope.bounds_hash, (n2_subject_binding,),
    (n2_scenario,), (materialization="external-boundary-profile-input-only",),
    TDPI.derive_capability_obligations(n2_compiled))
const n2_context = TDPI.make_forward_chain_context(
    n2_candidate, n2_compiled, generic_3d_registry, n2_mission, n2_bounds,
    n2_comparison_scope, n2_scenario_scope, n2_executable_subject, n2_scenario)

function n2_bind(subject=n2_subject(); input=n2_input, context=n2_context,
        artifact_sha=N2R._n2r_sha(n2_artifact_path),
        result_sha=N2R._n2r_sha(n2_result_path),
        declared_subject_sha=Digest256(String(n2_record.subject_hash)))
    N2R.bind_n2_reference_input(context, input, n2_artifact_path,
        artifact_sha, n2_result_path, result_sha, declared_subject_sha,
        subject; validator=TDPI.validate_forward_chain_context)
end

@testset "N2 corrected HELIOTRON binding is exact, label-neutral, and screen-only" begin
    subject = n2_subject()
    binding = n2_bind(subject)
    @test binding.source_artifact_sha256 ==
        Digest256(String(n2_record.subject.source_artifact_sha256))
    @test binding.normalized_result_subject_sha256 ==
        Digest256("da67a0040f1bcd3747bbd9e72d0f26849c2b9845ab50d22fc060b4eaceae98b9")
    @test binding.profile_quantity === :iota
    @test binding.desc_compatibility === :recoverable_gap
    @test binding.recoverable_gaps == (
        "source_owned_interior_radial_extension_missing",
        "source_owned_coordinate_metric_program_missing",
        "desc_interpreter_field_periods_outside_2_to_8",
        "desc_radial_base_orientation_proof_mismatch",
        "desc_vertical_base_orientation_proof_mismatch",
        "desc_fixed_boundary_L_outside_0_to_12")
    @test binding.claim_ceiling === screen_only
    @test !binding.measurement && !binding.inverse_ready
    @test !binding.held_out_prediction_ready && !binding.physical_validation
    @test !binding.p5_ready && binding.credible_physical_device_count == 0
    renamed = merge(subject,
        (display_name="renamed", reference_id="different"))
    @test N2R._n2r_subject_hash(renamed) ==
        binding.typed_subject_projection_hash
    @test N2R.canonical_hash(binding) == binding.binding_hash
end

@testset "N2 provenance, bytes, fields, and context fail closed" begin
    forged = Digest256(bytes2hex(SHA.sha256(codeunits("forged"))))
    @test_throws ArgumentError n2_bind(artifact_sha=forged)
    @test_throws ArgumentError n2_bind(result_sha=forged)
    wrong_source = merge(n2_subject(), (source_artifact_sha256=repeat("b", 64),))
    @test_throws ArgumentError n2_bind(wrong_source)
    bad_provenance = merge(n2_subject(), (provenance=merge(
        n2_subject().provenance, (selected_equilibrium_index=4,)),))
    @test_throws ArgumentError n2_bind(bad_provenance)
    wrong_boundary = merge(n2_subject(), (boundary=merge(
        n2_subject().boundary,
        (radial_modes=((m=0, n=0, coefficient_m=10.0),),)),))
    @test_throws ArgumentError n2_bind(wrong_boundary)
    @test_throws ArgumentError n2_bind(context=tdpi_context)
end
