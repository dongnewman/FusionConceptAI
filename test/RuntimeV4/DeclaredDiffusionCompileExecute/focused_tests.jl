"""Focused DCCE V1 contract runner.

This file defines the serialized Julia command for a later lane.  The
companion static QA and independent oracle are the verification run for this
handoff; they never start Julia or DESC.
"""

using Test
using FusionConceptAI

const _DCCE_ROOT = normpath(joinpath(@__DIR__, "..", "..", ".."))
const _DCCE = FusionConceptAI
_DCCE.load_genome_v5_components!()
include(joinpath(_DCCE_ROOT, "test", "GenomeV5", "Integration",
    "vnext_declaration_transport_local_v1_tests.jl"))
Base.include(_DCCE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "DeclaredG123DiffusionExecutionV1.jl"))
Base.include(_DCCE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "DeclaredSpatialCompositionExecutionV1.jl"))
Base.include(_DCCE, joinpath(_DCCE_ROOT, "src", "RuntimeV4",
    "DeclaredDiffusionCompileExecuteV1.jl"))
include(joinpath(_DCCE_ROOT, "test", "RuntimeV4", "DeclaredG123DiffusionExecution",
    "fixture.jl"))

function _dcce_case()
    old = _DCCE.DeclaredSpatialGeometryV1("old-display", [0.0, 0.5, 1.0];
        cell_labels=["old-a", "old-b"])
    new = _DCCE.DeclaredSpatialGeometryV1("new-display", [0.0, 0.25, 0.5, 0.75, 1.0];
        cell_labels=["new-a", "new-b", "new-c", "new-d"])
    field = _DCCE.DeclaredSpatialFieldV1([1.0, 2.0, 1.5, 0.8], [1.0, 0.0, -0.5, 0.75])
    boundary = _DCCE.DeclaredSpatialBoundaryV1(:dirichlet, 0.0, :dirichlet, 1.0)
    p(a, d, q, u, account, role, mag, payload) =
        _DCCE.DeclaredSpatialPortV1(a, d, q, u, account; role=role,
            magnitude=mag, payload=payload)
    src = Tuple([1.0, 0.0, -0.5, 0.75]); bv = (0.0, 1.0)
    comps = (
        _DCCE.DeclaredSpatialComponentV1("source-label", (p("s-o", :output, :source,
            "scalar", "source", :source, 1.0, src),)),
        _DCCE.DeclaredSpatialComponentV1("source-consumer-label", (p("s-i", :input,
            :source, "scalar", "source", :source, 1.0, src),)),
        _DCCE.DeclaredSpatialComponentV1("boundary-label", (p("b-o", :output, :field,
            "scalar", "boundary", :boundary, 1.0, bv),)),
        _DCCE.DeclaredSpatialComponentV1("boundary-consumer-label", (p("b-i", :input,
            :field, "scalar", "boundary", :boundary, 1.0, bv),)),
        _DCCE.DeclaredSpatialComponentV1("solver-label", (p("f-o", :output, :field,
            "scalar", "field", :field, 1.0, nothing),)),
        _DCCE.DeclaredSpatialComponentV1("return-label", (p("f-i", :input, :field,
            "scalar", "field", :field, 1.0, nothing),)))
    composition = _DCCE.DeclaredSpatialCompositionV1(comps; plan_ref="display-plan")
    _DCCE.DeclaredSpatialCaseV1(old, new, [0.25, 0.75], field, boundary, composition)
end

function _dcce_actual_input()
    g1, g2, g3 = _t0l_g1(), _t0l_g2(), _t0l_g3()
    declarations = (_t0l_present(:G1, g1),
        _t0l_present(:G2, g2; path="src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl"),
        _t0l_present(:G3, g3; path="src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"))
    children = (_t0l_child(:realization), _t0l_child(:control), _t0l_child(:binding))
    feedback = (_t0l_feedback("g1-residual", declarations[1].declaration_ref),
        _t0l_feedback("g2-thermal", declarations[2].declaration_ref))
    admission = _DCCE.vnext_declaration_transport_local_v1(_T0L_CANDIDATE,
        declarations, children, feedback)
    admission.status === :valid || error("fixture transport did not validate")
    (candidate=_T0L_CANDIDATE, g1=g1, g2=g2, g3=g3,
        bundle=admission.transport, spatial_case=_dcce_case())
end

@testset "DCCE V1 compile, lower, compose, and execute" begin
    a = _dcce_actual_input()
    out = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, a.spatial_case)
    @test out.claim_ceiling === :screen_only
    @test out.accepted === false
    @test out.compile.status === :ready
    @test out.lowering.status === :ready
    @test out.composition.status === :terminal_deferred
    @test out.numerical.status === :ready
    @test out.aggregate.status === :terminal_deferred
    @test out.aggregate.provider_calls == 0
    @test out.aggregate.mesh_calls == 0
    @test out.aggregate.solver_calls == 2
    @test out.aggregate.dgd_solver_calls == 1
    @test out.aggregate.fv_solver_calls == 1
    @test out.numerical.solution !== nothing
    fv = out.numerical.fv
    expected_fv_matrix = ((13.333333333333332, -5.333333333333333, 0.0, 0.0),
        (-5.333333333333333, 12.19047619047619, -6.857142857142858, 0.0),
        (0.0, -6.857142857142858, 11.03105590062112, -4.173913043478261),
        (0.0, 0.0, -4.173913043478261, 10.57391304347826))
    expected_fv_rhs = (0.25, 0.0, -0.125, 6.5875)
    expected_fv_solution = (0.17006478658536586, 0.3782869664634147,
        0.5402375508130082, 0.8362471417682927)
    @test all(isapprox(fv.matrix[i][j], expected_fv_matrix[i][j]; atol=1e-12)
        for i in 1:4, j in 1:4)
    @test all(isapprox(fv.rhs[i], expected_fv_rhs[i]; atol=1e-12) for i in 1:4)
    @test all(isapprox(fv.solution[i], expected_fv_solution[i]; atol=1e-12) for i in 1:4)
    @test fv.residual_norm <= 1e-12
    @test out.composition.transfer.new_state == (0.25, 0.25, 0.75, 0.75)
    @test isapprox(out.composition.transfer.conservation_residual, 0.0; atol=1e-12)
    @test !isempty(out.composition.semantic_hash)
end

@testset "DCCE negative gate names are explicitly dispatched" begin
    a = _dcce_actual_input()
    observed = Dict{Symbol,Tuple{Symbol,Symbol}}()
    foreign = _DCCE.QualifiedRefV1("foreign://candidate", "v5")
    candidate_bad = _DCCE.dcce_compile_execute_v1(foreign, a.g1, a.g2, a.g3,
        a.bundle, a.spatial_case)
    observed[:candidate_mismatch] = (candidate_bad.status, candidate_bad.code)
    missing_boundary = _DCCE.DeclaredSpatialCaseV1(a.spatial_case.old_geometry,
        a.spatial_case.new_geometry, a.spatial_case.old_state,
        a.spatial_case.field, nothing, a.spatial_case.composition)
    missing = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, missing_boundary)
    observed[:missing_boundary] = (missing.status, missing.code)
    pure_neumann = _DCCE.DeclaredSpatialCaseV1(a.spatial_case.old_geometry,
        a.spatial_case.new_geometry, a.spatial_case.old_state,
        a.spatial_case.field, _DCCE.DeclaredSpatialBoundaryV1(:neumann, 0.0,
            :neumann, 0.0), a.spatial_case.composition)
    pure = _DCCE.dcce_compile_execute_v1(a.candidate, a.g1, a.g2, a.g3,
        a.bundle, pure_neumann)
    observed[:pure_neumann] = (pure.status, pure.code)
    @test observed[:candidate_mismatch] == (:fail_closed, :candidate_mismatch)
    @test observed[:missing_boundary] == (:fail_closed, :missing_boundary)
    @test observed[:pure_neumann] == (:numerical_fail, :pure_neumann_singular)
    @test haskey(observed, :candidate_mismatch) && haskey(observed, :missing_boundary)
    @test _DCCE.DCCE_CLAIM_CEILING_V1 === :screen_only
    @test :terminal_deferred in _DCCE.DCCE_STATUSES_V1
end

println("DCCE_DECLARED_DIFFUSION_COMPILE_EXECUTE_V1_JULIA_COMMAND_DEFINED=true")
println("DCCE_DECLARED_DIFFUSION_COMPILE_EXECUTE_V1_JULIA_OR_DESC_EXECUTED=false")
