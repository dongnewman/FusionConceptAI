using Test
using JSON3
using SHA
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "N2SourceFourierZernikeV4.jl"))
const N2Z = N2SourceFourierZernikeRuntime
const n2z_root = joinpath(@__DIR__, "..")
const n2z_source = joinpath(n2z_root, "benchmarks", "desc_heliotron_v0173",
    "HELIOTRON_output.h5")
const n2z_result = joinpath(n2z_root, "runs",
    "goal_recovery_20260913_012528_cst", "n2_desc_heliotron_interior_r1",
    "result.json")
const n2z_compare = joinpath(n2z_root, "runs",
    "goal_recovery_20260913_012528_cst",
    "n2_desc_heliotron_interior_compare_r1", "result.json")
const n2z_derivatives = joinpath(n2z_root, "runs",
    "goal_recovery_20260913_012528_cst",
    "n2_desc_heliotron_derivative_receipt_r1", "result.json")
const n2z_expected_result_hash = Digest256(
    "fe6258bd0e1368dbc4d0eafef092588e3a95d76842d3c48e4f29c14987d7fcb8")

@testset "N2 selected source Fourier-Zernike scalar geometry" begin
    interior = N2Z.load_n2_source_interior(n2z_source, n2z_result,
        n2z_expected_result_hash)
    comparison = JSON3.read(read(n2z_compare, String))
    @test N2Z._n2z_sha(n2z_compare) == Digest256(
        "545da259243385be98a26ac5facfbd4678c7bae54f80280b12631bc07143d402")
    @test interior.source_artifact_sha256 == Digest256(
        "305cbba9c82c32dff7cb4954367c20f0428f6ff216f5d1f53c3038870ca06dfe")
    @test interior.subject_sha256 == Digest256(
        "e314aa58f728b5946d3a6175d569a77c0195679c5101d485c0dd60ef5ab127a9")
    @test interior.selected_equilibrium_index == 3
    @test interior.field_periods == 19
    @test length(interior.radial_modes) == 598
    @test length(interior.vertical_modes) == 585
    for row in comparison.rows
        point = Tuple(Float64(value) for value in row.node_rho_theta_zeta_radians)
        actual = N2Z.evaluate_n2_source_rz(interior, point...)
        expected = Tuple(Float64(value) for value in row.desc_RZ_m)
        @test all(abs(actual[i] - expected[i]) <= 1e-9 for i in 1:2)
    end
    @test interior.claim_ceiling === screen_only
    @test !interior.physical_validation && !interior.provider_selected
    @test !interior.solver_executed && interior.credible_device_count == 0
    @test N2Z.n2_source_interior_manifest().typed_G2_coordinate_metric_program == false
end

@testset "N2 same-source analytic derivatives and Cartesian Gram" begin
    @test N2Z._n2z_sha(n2z_derivatives) == Digest256(
        "ae81285b05ef1ea84101b106e25c53c8dcb8570056bcad047954ddc785a31223")
    receipt = JSON3.read(read(n2z_derivatives, String))
    scalar_receipt = JSON3.read(read(n2z_compare, String))
    interior = N2Z.load_n2_source_interior(n2z_source, n2z_result,
        n2z_expected_result_hash)
    @test receipt.source_artifact_sha256 == interior.source_artifact_sha256.value
    @test receipt.interior_result_sha256 == interior.result_sha256.value
    @test receipt.interior_subject_sha256 == interior.subject_sha256.value
    @test receipt.selected_equilibrium_index == interior.selected_equilibrium_index
    @test receipt.authority.claim_ceiling == "screen_only"
    @test !receipt.authority.metric_positivity_certified
    @test receipt.authority.physical_validation == "unsupported"
    @test receipt.schema_version == "n2-source-interior-derivative-receipt-v1"
    @test Tuple(Tuple(Int(v) for v in order) for order in receipt.derivative_order) ==
        ((0,0,0), (1,0,0), (0,1,0), (0,0,1))
    @test length(receipt.rows) == length(scalar_receipt.rows) == 5
    @test Tuple(Tuple(Float64(v) for v in row.node_rho_theta_zeta_radians)
        for row in receipt.rows) ==
        Tuple(Tuple(Float64(v) for v in row.node_rho_theta_zeta_radians)
        for row in scalar_receipt.rows)
    derivative_tolerance = Float64(receipt.predeclared_absolute_derivative_tolerance_m)
    gram_tolerance = Float64(receipt.predeclared_absolute_gram_tolerance_m2)
    @test derivative_tolerance == 1e-8 && gram_tolerance == 1e-7
    for row in receipt.rows
        point = Tuple(Float64(v) for v in row.node_rho_theta_zeta_radians)
        evaluated = N2Z.evaluate_n2_source_gram(interior, point...)
        actual_r = (evaluated.chart.R_m, evaluated.chart.dR.rho,
            evaluated.chart.dR.theta, evaluated.chart.dR.zeta)
        actual_z = (evaluated.chart.Z_m, evaluated.chart.dZ.rho,
            evaluated.chart.dZ.theta, evaluated.chart.dZ.zeta)
        for (actual, expected) in ((actual_r, row.desc_R_and_derivatives_m),
                (actual_z, row.desc_Z_and_derivatives_m))
            @test all(abs(actual[i] - Float64(expected[i])) <=
                derivative_tolerance for i in 1:4)
        end
        @test all(abs(evaluated.gram[i][j] -
            Float64(row.desc_cartesian_gram_m2[i][j])) <= gram_tolerance
            for i in 1:3 for j in 1:3)
        @test evaluated.claim_ceiling === screen_only
        @test !evaluated.derivative_metric_proof && !evaluated.physical_validation
    end
    @test !N2Z.n2_source_interior_manifest().derivative_or_metric_proof
    @test N2Z.n2_source_interior_manifest().same_source_analytic_derivative_comparison_only
end

@testset "N2 source interior forgery and chart gaps fail closed" begin
    forged = Digest256(bytes2hex(SHA.sha256(codeunits("forged"))))
    @test_throws ArgumentError N2Z.load_n2_source_interior(
        n2z_source, n2z_result, forged)
    mktempdir() do directory
        cp(n2z_source, joinpath(directory, basename(n2z_source)))
        @test_throws ArgumentError N2Z.load_n2_source_interior(
            joinpath(directory, basename(n2z_source)), n2z_result,
            n2z_expected_result_hash)
        cp(joinpath(dirname(n2z_source), "source.json"),
            joinpath(directory, "source.json"))
        @test N2Z.load_n2_source_interior(
            joinpath(directory, basename(n2z_source)), n2z_result,
            n2z_expected_result_hash).selected_equilibrium_index == 3
        manifest_path = joinpath(directory, "source.json")
        manifest = read(manifest_path, String)
        write(manifest_path, replace(manifest,
            "fcc29be36f0b36b1b667df4b1f8891a9b633f5d1" =>
            "0000000000000000000000000000000000000000"; count=1))
        @test_throws ArgumentError N2Z.load_n2_source_interior(
            joinpath(directory, basename(n2z_source)), n2z_result,
            n2z_expected_result_hash)
    end
    original = read(n2z_result, String)
    promoted = replace(original, "\"measurement\": false" =>
        "\"measurement\": true"; count=1)
    mktemp() do path, stream
        write(stream, promoted); close(stream)
        @test_throws ArgumentError N2Z.load_n2_source_interior(
            n2z_source, path, N2Z._n2z_sha(path))
    end
    changed = replace(original, "\"selected_equilibrium_index\": 3" =>
        "\"selected_equilibrium_index\": 2"; count=1)
    mktemp() do path, stream
        write(stream, changed); close(stream)
        @test_throws ArgumentError N2Z.load_n2_source_interior(
            n2z_source, path, N2Z._n2z_sha(path))
    end
    interior = N2Z.load_n2_source_interior(n2z_source, n2z_result,
        n2z_expected_result_hash)
    @test_throws ArgumentError N2Z.evaluate_n2_source_rz(interior, -0.1, 0.0, 0.0)
    @test_throws ArgumentError N2Z.evaluate_n2_source_rz(interior, 1.1, 0.0, 0.0)
end
