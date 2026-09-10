using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_desc_geometry_program_interpreter.jl"))

const _DGPI_ATOL = 2e-11
dgpi_flat(x) = collect(Iterators.flatten(x))
dgpi_close(a, b; atol=_DGPI_ATOL) =
    maximum(abs.(dgpi_flat(a) .- dgpi_flat(b))) <= atol
function dgpi_rotate_vector(x, angle)
    c, s = cos(angle), sin(angle)
    (c * x[1] - s * x[2], s * x[1] + c * x[2], x[3])
end
function dgpi_rotate_jacobian(J, angle)
    c, s = cos(angle), sin(angle)
    (ntuple(j -> c * J[1][j] - s * J[2][j], 3),
     ntuple(j -> s * J[1][j] + c * J[2][j], 3), J[3])
end

@testset "candidate-owned DESC Fourier payload and typed roots" begin
    @test dgpi_program.radial_law === :explicit_power_per_mode
    @test Tuple(mode.radial_power for mode in dgpi_program.radial_modes) ==
        (0, 1, 1)
    @test Tuple(mode.radial_power for mode in dgpi_program.vertical_modes) ==
        (1, 1)
    @test canonical_hash(dgpi_program) == canonical_hash(dgpi_program)
    @test dgpi_program_binding.coordinate_edge isa AtomicMIMOHyperedgeV1
    @test dgpi_program_binding.metric_edge isa AtomicMIMOHyperedgeV1
    @test dgpi_program_binding.coordinate_program.nodes[2].value ==
        DGPI._dgpi_ast_payload(dgpi_program)
    @test dgpi_program_binding.metric_program.nodes[2].value ==
        DGPI._dgpi_ast_payload(dgpi_program)
    @test dgpi_prebinding.ast_root_identity_hashes[2] ==
        dgpi_coordinate_metric.coordinate_map_root_identity_hash
    @test dgpi_prebinding.ast_root_identity_hashes[4] ==
        dgpi_coordinate_metric.metric_root_identity_hash
    @test length(DGPI.desc_geometry_operator_registry().operators) == 24
    @test length(default_operator_registry().operators) == 20

    @test_throws ArgumentError DGPI.DESCFourierGeometryProgramV4(
        tdpi_fourier_boundary, dgpi_scale, (0, 1), (1, 1))
    @test_throws ArgumentError DGPI.DESCFourierGeometryProgramV4(
        tdpi_fourier_boundary, dgpi_scale, (1, 1, 1), (1, 1))
    @test_throws ArgumentError DGPI.DESCFourierGeometryProgramV4(
        tdpi_fourier_boundary, dgpi_scale, (0, 0, 1), (1, 1))
    @test_throws ArgumentError DGPI.DESCFourierGeometryProgramV4(
        tdpi_fourier_boundary, dgpi_scale, (0, 1, 1), (0, 1))
end

@testset "analytic coordinate, Jacobian, metric, and SI scaling" begin
    p = dgpi_program
    q = (0.83, 0.27, 0.31)
    h = 1e-6
    xhat = DGPI.desc_normalized_coordinate(p, q)
    Jhat = DGPI.desc_normalized_jacobian(p, q)
    ghat = DGPI.desc_normalized_metric(p, q)
    x = DGPI.desc_coordinate(p, q)
    J = DGPI.desc_coordinate_jacobian(p, q)
    g = DGPI.desc_metric(p, q)
    L = Float64(p.support_scale.value)

    @test dgpi_close(x, ntuple(i -> L * xhat[i], 3))
    @test dgpi_close(J,
        ntuple(i -> ntuple(j -> L * Jhat[i][j], 3), 3))
    @test dgpi_close(g,
        ntuple(i -> ntuple(j -> L^2 * ghat[i][j], 3), 3))
    @test dgpi_close(g, ntuple(i -> ntuple(j ->
        sum(J[k][i] * J[k][j] for k in 1:3), 3), 3))
    @test dgpi_close(g, ntuple(i -> ntuple(j -> g[j][i], 3), 3))
    fd = ntuple(i -> ntuple(j ->
        (DGPI.desc_coordinate(p,
             ntuple(k -> k == j ? q[k] + h : q[k], 3))[i] -
         DGPI.desc_coordinate(p,
             ntuple(k -> k == j ? q[k] - h : q[k], 3))[i]) / (2h),
        3), 3)
    @test dgpi_close(J, fd; atol=1e-7)
    @test isapprox(DGPI._dgpi_determinant(J),
        L^3 * DGPI._dgpi_determinant(Jhat); atol=2e-10)
    @test isapprox(DGPI._dgpi_determinant(
        DGPI.desc_coordinate_jacobian(p, (0.0, q[2], q[3]))), 0.0;
        atol=1e-12)
end

@testset "theta seam and field-period-turn equivariance" begin
    p = dgpi_program
    rho = 0.83
    theta = 0.27
    x0 = DGPI.desc_coordinate(p, (rho, 0.0, 0.31))
    x1 = DGPI.desc_coordinate(p, (rho, 1.0, 0.31))
    J0 = DGPI.desc_coordinate_jacobian(p, (rho, 0.0, 0.31))
    J1 = DGPI.desc_coordinate_jacobian(p, (rho, 1.0, 0.31))
    g0 = DGPI.desc_metric(p, (rho, 0.0, 0.31))
    g1 = DGPI.desc_metric(p, (rho, 1.0, 0.31))
    @test dgpi_close(x0, x1)
    @test dgpi_close(J0, J1)
    @test dgpi_close(g0, g1)

    xu0 = DGPI.desc_coordinate(p, (rho, theta, 0.0))
    xu1 = DGPI.desc_coordinate(p, (rho, theta, 1.0))
    Ju0 = DGPI.desc_coordinate_jacobian(p, (rho, theta, 0.0))
    Ju1 = DGPI.desc_coordinate_jacobian(p, (rho, theta, 1.0))
    gu0 = DGPI.desc_metric(p, (rho, theta, 0.0))
    gu1 = DGPI.desc_metric(p, (rho, theta, 1.0))
    angle = 2pi / p.boundary.field_periods
    @test dgpi_close(xu1, dgpi_rotate_vector(xu0, angle))
    @test dgpi_close(Ju1, dgpi_rotate_jacobian(Ju0, angle))
    @test dgpi_close(gu1, gu0)
end

@testset "context-bound sealed evaluation and authority ceiling" begin
    evaluation = DGPI.interpret_desc_geometry_program(
        dgpi_context, dgpi_bridge_resolution, (0.83, 0.27, 0.31))
    @test evaluation.status === :interpreted
    @test evaluation.context_hash == dgpi_context.context_hash
    @test evaluation.candidate_hash == dgpi_context.candidate_hash
    @test evaluation.payload_hash == canonical_hash(dgpi_program)
    @test evaluation.support_scale == Float64(dgpi_scale.value)
    @test evaluation.coordinate == DGPI.desc_coordinate(
        dgpi_program, evaluation.input)
    @test evaluation.metric == DGPI.desc_metric(dgpi_program, evaluation.input)
    @test DGPI.validate_desc_geometry_program_evaluation(
        dgpi_context, dgpi_bridge_resolution, evaluation) == evaluation.evaluation_hash
    @test canonical_hash(evaluation) == evaluation.evaluation_hash

    for value in (evaluation,
            DGPI.desc_geometry_program_interpreter_manifest())
        @test value.claim_ceiling == screen_only
        @test value.geometry_program_interpreted
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

@testset "nonfinite, domain, private, foreign, and forged inputs fail closed" begin
    p = dgpi_program
    @test_throws ArgumentError DGPI.desc_coordinate(p, (0.5, NaN, 0.5))
    @test_throws ArgumentError DGPI.desc_coordinate(p, (-0.1, 0.5, 0.5))
    @test_throws ArgumentError DGPI.desc_coordinate(p, (0.5, 0.5, 1.1))
    @test_throws ArgumentError DGPI.desc_coordinate(p, [0.5, 0.5, 0.5])
    @test_throws ArgumentError DGPI.interpret_desc_geometry_program(
        tdnprb_context, tdnprb_resolution, (0.5, 0.5, 0.5))

    values = DGPI._dgpi_evaluation_values(dgpi_evaluation)
    @test_throws ArgumentError DGPI.DESCGeometryProgramEvaluationV4(
        DGPI._DGPIPrivateToken(), values..., dgpi_evaluation.evaluation_hash)
    forged_values = collect(values)
    index = findfirst(==(:geometry_proved),
        fieldnames(typeof(dgpi_evaluation)))
    forged_values[index] = true
    forged_body = DGPI._dgpi_evaluation_body_from_values(
        Tuple(forged_values)...)
    forged = DGPI.DESCGeometryProgramEvaluationV4(DGPI._DGPI_TOKEN,
        Tuple(forged_values)..., canonical_hash(forged_body))
    @test_throws ArgumentError canonical_hash(forged)

    numeric_values = collect(values)
    coordinate_index = findfirst(==(:coordinate),
        fieldnames(typeof(dgpi_evaluation)))
    numeric_values[coordinate_index] =
        (dgpi_evaluation.coordinate[1] + 1.0,
         dgpi_evaluation.coordinate[2], dgpi_evaluation.coordinate[3])
    numeric_body = DGPI._dgpi_evaluation_body_from_values(
        Tuple(numeric_values)...)
    numeric_forgery = DGPI.DESCGeometryProgramEvaluationV4(DGPI._DGPI_TOKEN,
        Tuple(numeric_values)..., canonical_hash(numeric_body))
    @test_throws ArgumentError canonical_hash(numeric_forgery)
end

println("DESC_GEOMETRY_PROGRAM_INTERPRETER_FOCUSED_EXIT_CODE=0")
