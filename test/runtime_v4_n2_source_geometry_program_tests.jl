using Test
using JSON3
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "N2SourceGeometryProgramV4.jl"))
const N2G = N2SourceGeometryProgramRuntime
const root_n2g = normpath(joinpath(@__DIR__, ".."))
const source_n2g = joinpath(root_n2g, "benchmarks",
    "desc_heliotron_v0173", "HELIOTRON_output.h5")
const result_n2g = joinpath(root_n2g, "runs",
    "goal_recovery_20260913_012528_cst",
    "n2_desc_heliotron_interior_r1", "result.json")
const receipt_n2g = joinpath(root_n2g, "runs",
    "goal_recovery_20260913_012528_cst",
    "n2_desc_heliotron_derivative_receipt_r1", "result.json")
const result_sha_n2g = Digest256(
    "fe6258bd0e1368dbc4d0eafef092588e3a95d76842d3c48e4f29c14987d7fcb8")
const scale_n2g = NonnegativeQuantityV1(1,
    UnitSignature((0, 1, 0, 0, 0, 0, 0)))
const program_n2g = N2G.load_n2_source_geometry_program(source_n2g,
    result_n2g, result_sha_n2g, scale_n2g)
const binding_n2g = N2G.n2_source_geometry_typed_binding(program_n2g,
    FieldOperatorSiteRefV1("n2-source-coordinate"),
    FieldOperatorSiteRefV1("n2-source-metric"))

@testset "N2 source Fourier-Zernike typed coordinate/metric graph" begin
    default_hash = canonical_hash(default_operator_registry())
    graph = N2G.n2_source_geometry_graph(binding_n2g)
    @test length(graph.nodes) == 5
    @test length(graph.hyperedges) == 2
    @test length(binding_n2g.registry.operators) ==
        length(default_operator_registry().operators) + 4
    @test canonical_hash(default_operator_registry()) == default_hash
    @test binding_n2g.coordinate_program.roots == (3, 5)
    @test binding_n2g.metric_program.roots == (3, 5)
    @test binding_n2g.coordinate_program.input_ports == (1,)
    @test binding_n2g.metric_program.input_ports == (1,)
    @test binding_n2g.coordinate_program.nodes[2].value ==
        binding_n2g.metric_program.nodes[2].value
    @test binding_n2g.coordinate_program.nodes[2].value.radial_basis ==
        :DESC_FourierZernike_fringe
    @test binding_n2g.coordinate_program.nodes[2].value.program_code_sha256 ==
        N2G._N2G_PROGRAM_CODE_SHA
    @test binding_n2g.coordinate_program.nodes[2].value.evaluator_source_sha256 ==
        N2G._N2G_SOURCE_EVALUATOR_SHA
    @test binding_n2g.coordinate_program.nodes[2].value.radial_mode_count == 598
    @test binding_n2g.metric_program.nodes[2].value.vertical_mode_count == 585
    @test binding_n2g.coordinate_edge.role === constraint
    @test binding_n2g.metric_edge.role === constraint
    @test isempty(binding_n2g.coordinate_edge.account_effects)
    @test isempty(binding_n2g.metric_edge.account_effects)
    @test canonical_hash(binding_n2g) == canonical_hash(
        N2G.n2_source_geometry_typed_binding(program_n2g,
            binding_n2g.coordinate_site_ref, binding_n2g.metric_site_ref))
    @test N2G.n2_source_geometry_manifest().claim_ceiling === screen_only
    @test !N2G.n2_source_geometry_manifest().geometry_proved
end

@testset "N2 source phase and radial law analytic single-mode controls" begin
    rho, theta, zeta = 0.3, 0.2, 0.1
    positive = N2G.N2Z.N2ZernikeTermV4(1, 1, 1, 2.0)
    p = N2G.N2Z._n2z_eval_with_derivatives(
        (positive,), rho, theta, zeta, 19)
    expected_p = (2rho*cos(theta)*cos(19zeta),
        2cos(theta)*cos(19zeta),
        -2rho*sin(theta)*cos(19zeta),
        -38rho*cos(theta)*sin(19zeta))
    @test all(abs(p[i]-expected_p[i]) <= 1e-12 for i in 1:4)
    negative = N2G.N2Z.N2ZernikeTermV4(1, -1, -1, 2.0)
    n = N2G.N2Z._n2z_eval_with_derivatives(
        (negative,), rho, theta, zeta, 19)
    expected_n = (2rho*sin(theta)*sin(19zeta),
        2sin(theta)*sin(19zeta),
        2rho*cos(theta)*sin(19zeta),
        38rho*sin(theta)*cos(19zeta))
    @test all(abs(n[i]-expected_n[i]) <= 1e-12 for i in 1:4)
    @test N2G.N2SourceUnitTurnChartV4(0.0, 0.0, 0.0).rho == 0.0
    @test N2G.N2SourceUnitTurnChartV4(1.0, 1.0, 1.0).period_turn == 1.0
end

@testset "N2 source AST evaluator uses physical radians and unit turns exactly" begin
    receipt = JSON3.read(read(receipt_n2g, String))
    @test N2G.N2Z._n2z_sha(receipt_n2g) == Digest256(
        "ae81285b05ef1ea84101b106e25c53c8dcb8570056bcad047954ddc785a31223")
    @test receipt.interior_subject_sha256 ==
        program_n2g.interior.subject_sha256.value
    for row in receipt.rows
        rho, theta, zeta = (Float64(x) for x in
            row.node_rho_theta_zeta_radians)
        input = (rho, theta / (2pi), zeta * 19 / (2pi))
        value = N2G.evaluate_n2_source_geometry(binding_n2g,
            N2G.N2SourceUnitTurnChartV4(input...))
        r = Float64(row.desc_R_and_derivatives_m[1])
        z = Float64(row.desc_Z_and_derivatives_m[1])
        expected_coordinate = (r*cos(zeta), r*sin(zeta), z)
        @test all(abs(value.coordinate[i] - expected_coordinate[i]) <=
            1e-8 for i in 1:3)
        factors = (1.0, 2pi, 2pi/19)
        @test all(abs(value.metric[i][j] -
            Float64(row.desc_cartesian_gram_m2[i][j]) *
            factors[i] * factors[j]) <= 1e-7
            for i in 1:3 for j in 1:3)
        @test all(abs(value.coordinate[i] -
            Float64(scale_n2g.value) * value.normalized_coordinate[i]) <=
            1e-12 for i in 1:3)
        @test all(abs(value.metric[i][j] -
            Float64(scale_n2g.value)^2 *
            value.normalized_metric[i][j]) <= 1e-10
            for i in 1:3 for j in 1:3)
        @test value.claim_ceiling === screen_only
        @test !value.geometry_proved && !value.provider_executed &&
            !value.physical_validation && value.credible_device_count == 0
    end
end

@testset "N2 source AST provenance and domain fail closed" begin
    @test_throws ArgumentError N2G.load_n2_source_geometry_program(
        source_n2g, result_n2g, Digest256(repeat("a",64)), scale_n2g)
    @test_throws ArgumentError N2G.load_n2_source_geometry_program(
        source_n2g, result_n2g, result_sha_n2g,
        NonnegativeQuantityV1(0, scale_n2g.unit))
    @test_throws ArgumentError N2G.load_n2_source_geometry_program(
        source_n2g, result_n2g, result_sha_n2g,
        NonnegativeQuantityV1(1, UnitSignature()))
    @test_throws ArgumentError N2G.n2_source_geometry_typed_binding(
        program_n2g, binding_n2g.coordinate_site_ref,
        binding_n2g.coordinate_site_ref)
    @test_throws ArgumentError N2G.N2SourceUnitTurnChartV4(-0.01, 0.2, 0.1)
    @test_throws ArgumentError N2G.N2SourceUnitTurnChartV4(0.5, 1.1, 0.1)
    @test_throws ArgumentError N2G.N2SourceUnitTurnChartV4(0.5, 0.2, true)
    @test_throws MethodError N2G.evaluate_n2_source_geometry(
        binding_n2g, (0.5, 0.2, 0.1))
end
