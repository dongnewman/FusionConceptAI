"""Exclusive UP2-05 test for the existing D-T provider -> thermal FV route.

Run with Julia from the repository root and the project's existing Gridap
qualification environment. This test uses the real source-declared thermal
candidate, the production D-T capability/manifest, and the original thermal
consumer. It retains the provider's screen-only scope.
"""

using Test
using FusionConceptAI
using LinearAlgebra
using SparseArrays
using Pkg

const _DCCE = FusionConceptAI
const _DCCE_ROOT = pwd()
_DCCE.load_genome_v5_components!()
_DCCE.load_vnext_t2_components_v2!()
include(joinpath(_DCCE_ROOT, "src", "RuntimeV4", "FusionRuntimeV4.jl"))
const _DT_RUNTIME = Main.FusionRuntimeV4
const _DT_RUNTIME_MODULE = _DT_RUNTIME
Base.include(_DT_RUNTIME_MODULE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "NativeG1G2DiffusionCompilerV1.jl"))
Pkg.activate(joinpath(_DCCE_ROOT, "tools", "qualification", "gridap"); io=devnull)
Base.include(_DT_RUNTIME_MODULE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "GridapFieldResidualAdapter.jl"))
Base.include(_DT_RUNTIME_MODULE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "GridapNativeG1G2DiffusionAdapterV1.jl"))
Pkg.activate(_DCCE_ROOT; io=devnull)
Base.include(_DCCE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "DeclaredG123DiffusionExecutionV1.jl"))
Base.include(_DCCE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "DeclaredSpatialCompositionExecutionV1.jl"))
Base.include(_DCCE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "DeclaredDiffusionCompileExecuteV1.jl"))

# Reuse the current-source fixture builder without including or running the
# large test file and its unrelated testsets.
include(joinpath(_DCCE_ROOT, "test", "RuntimeV4", "DeclaredDiffusionCompileExecute",
    "thermal_slab_actual_source_fixture.jl"))

@testset "UP2-05 actual registered D-T provider reaches original FV consumer" begin
    case = _thermal_source_case()
    built = case.built
    runtime = _DT_RUNTIME
    consumer = Main.SteadyPlanarThermalDiffusionConsumerV1
    bundle, spatial = case.t0.transport, case.spatial

    # The actual authored G1/G2/G3 declarations bind the downstream candidate;
    # plasma quantities are explicit homogeneous 0-D screen inputs, as scoped
    # by the existing provider contract.
    candidate = _DCCE.dcce_input_v1(built.candidate_ref,
        built.g1.declaration, built.g2.declaration, built.g3.declaration,
        bundle, spatial)
    source_unit = _DCCE.UnitSignature((-1, 1, -3, 0, 0, 0, 0))
    density_unit = _DCCE.UnitSignature((-3, 0, 0, 0, 0, 0, 0))
    energy_unit = _DCCE.UnitSignature((2, 1, -2, 0, 0, 0, 0))
    volume_unit = _DCCE.UnitSignature((3, 0, 0, 0, 0, 0, 0))
    seconds_unit = _DCCE.UnitSignature((0, 0, 1, 0, 0, 0, 0))
    one_unit = _DCCE.UnitSignature()
    quantity(value, unit, dimension) = runtime.DTFusionQuantityV1(value, unit, dimension)
    plasma = runtime.DTFusionReactivityInputV1(
        quantity(1.0e17, :m3_inverse, density_unit),
        quantity(1.0e17, :m3_inverse, density_unit),
        quantity(10.0, :keV, energy_unit),
        quantity(1.0, :m3, volume_unit),
        quantity(0.01, :s, seconds_unit),
        quantity(0.5, :one, one_unit),
        quantity(1.0, :W_m3, source_unit),
        quantity(0.25, :W_m3, source_unit))

    chart = built.g2.declaration.source.chart_map
    g2_volume_m3 = abs(prod(Float64(chart.jacobian_rows[i][i]) *
        Float64(chart.domain_upper[i] - chart.domain_lower[i]) for i in 1:3))
    thermal_region = only(filter(face -> face.face === :x_min,
        built.g2.declaration.source.faces)).owner_region_id
    spec = (schema="candidate-dt-to-thermal-source-v1",
        candidate_ref=candidate.candidate_ref, plasma_region_id="synthetic-plasma",
        thermal_region_id=thermal_region, plasma_input=plasma,
        wall_transfer_fraction=quantity(1.0, :one, one_unit),
        wall_volume_m3=quantity(g2_volume_m3, :m3, volume_unit),
        q_bounds_W_m3=(quantity(1//100, :W_m3, source_unit),
            quantity(2//1, :W_m3, source_unit)),
        parameter_id="up2-05-actual-dt-source")
    args = (built.candidate_ref, built.g1.declaration,
        built.g2.declaration, built.g3.declaration, bundle, spatial, spec)

    capability = runtime.dt_fusion_reactivity_capability_v1()
    manifest = runtime.dt_fusion_reactivity_manifest_v1()
    registry_match = runtime.match_provider(capability, (manifest,))
    @test registry_match.status === runtime.unique_match
    @test registry_match.provider.manifest_hash === manifest.manifest_hash
    @test manifest.executor !== nothing

    # Omit the providers override: the production consumer resolves the
    # canonical source-owned provider manifest through the capability matcher.
    result = consumer.execute_steady_planar_dt_screen_thermal_v1(args...)
    @test result.status === :screen_only
    @test result.provider_result.provider_match_status === runtime.unique_match
    @test result.provider_result.provider_manifest_hash === manifest.manifest_hash
    @test result.provider_result.provider_code_hash === manifest.code_hash
    @test result.provider_result.candidate_bound === false
    @test result.provider_result.physical_evidence === false
    @test result.candidate_bound === false
    @test result.physical_evidence === false
    expected_power_W = result.provider_result.net_thermal_source_W_m3 *
        result.plasma_volume_m3 * spec.wall_transfer_fraction.value
    expected_rhs_W_m3 = expected_power_W / result.thermal_volume_m3
    @test isapprox(result.transferred_power_W, expected_power_W; rtol=1e-12, atol=1e-12)
    @test all(q -> isapprox(q, expected_rhs_W_m3; rtol=1e-12, atol=1e-12),
        result.rhs_source_W_m3)
    @test length(result.rhs_source_W_m3) == length(spatial.field.source)
    @test length(result.thermal_result.volume_source_W_m3) ==
        length(spatial.field.source)
    @test result.thermal_result.volume_source_W_m3 == result.rhs_source_W_m3
    @test isapprox(result.thermal_result.integrated_source_W,
        result.transferred_power_W; rtol=1e-10, atol=1e-10)
    @test result.thermal_result.residual_norm <= 1e-12
    @test abs(result.thermal_result.energy_balance_residual_W) <= 1e-10
    @test result.evidence_credit == 0

    required = runtime.dt_fusion_reactivity_capability_v1()
    expected_gap = "dt_thermal_required_provider_missing:no_match:" *
        string(required.schema, "@", required.revision, "/", required.kind, "/",
            required.operator, "/", _DCCE.canonical_hash(required))
    removed_provider_error = try
        consumer.execute_steady_planar_dt_screen_thermal_v1(args...; providers=())
        nothing
    catch err
        err
    end
    @test removed_provider_error isa ArgumentError
    @test removed_provider_error.msg == expected_gap
    println("UP2_05_DTFUSION_ACTUAL_ROUTE=", (status=result.status,
        provider_manifest_hash=string(result.provider_result.provider_manifest_hash),
        transferred_power_W=result.transferred_power_W,
        fv_integrated_source_W=result.thermal_result.integrated_source_W,
        removed_provider_message=removed_provider_error.msg,
        claim_ceiling=result.claim_ceiling, evidence_credit=result.evidence_credit))
end
