using Test
push!(LOAD_PATH, dirname(@__DIR__))
using FusionConceptAI
using Gridap
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_gridap_field_convergence_fixture.jl"))

@testset "B2 real candidate-bound convergence" begin
    r = FusionRuntimeV4.run_gridap_field_convergence(gridap_b2_compilations)
    @test FusionRuntimeV4.validate_gridap_field_convergence_receipt(r)
    @test r.status === :pass
    @test r.claim_ceiling === screen_only
    @test r.evidence_class === :manufactured_control
    @test Tuple(c.nodes_per_axis for c in r.cases) == (5,9,17)
    @test all(c -> c.cells > 0 && c.dofs > 0 && c.runtime_seconds >= 0 && c.memory_bytes >= 0, r.cases)
    @test all(c -> isfinite(c.solution_l2) && isfinite(c.solution_h1_seminorm) && isfinite(c.residual), r.cases)
    @test all(r.cases[i].solution_l2 > r.cases[i+1].solution_l2 for i in 1:2)
    @test all(isfinite, r.observed_l2_orders) && all(isfinite, r.observed_h1_orders)
    @test length(unique(c.case_hash for c in r.cases)) == 3
    @test_throws ArgumentError FusionRuntimeV4.run_gridap_field_convergence((gridap_b2_compilations[1], gridap_b2_compilations[3], gridap_b2_compilations[3]))

    q=(0.2,-0.3,0.4)
    u,du=FusionRuntimeV4._b2_typed_ast_value_gradient(q,gridap_b2_compilations[1][2])
    rho=sum(x^2 for x in q)
    @test u ≈ rho^2
    @test all(isapprox.(du,ntuple(i->4rho*q[i],3)))
    f,df=FusionRuntimeV4._b2_typed_ast_value_gradient(q,gridap_b2_compilations[1][3])
    @test f ≈ 10rho
    @test all(isapprox.(df,ntuple(i->20q[i],3)))

    @test_throws ArgumentError FusionRuntimeV4.run_gridap_field_convergence((
        (gridap_b2_compilations[1][1],gridap_b2_compilations[2][2],gridap_b2_compilations[1][3]),
        gridap_b2_compilations[2],gridap_b2_compilations[3]))
    c=r.cases[1]
    forged_case=FusionRuntimeV4.GridapFieldConvergenceCaseV4(FusionRuntimeV4._GRIDAP_B2_TOKEN,
        c.grid_hash,c.plan_hash,c.g2_u_result_hash,c.g2_f_result_hash,c.nodes_per_axis,
        c.cells,c.dofs,c.runtime_seconds,c.memory_bytes,c.solution_l2*2,
        c.solution_h1_seminorm,c.source_cell_center_rms,c.boundary_face_center_linf,
        c.residual,c.status,c.case_hash)
    forged_cases=(forged_case,r.cases[2],r.cases[3])
    forged=FusionRuntimeV4.GridapFieldConvergenceReceiptV4(FusionRuntimeV4._GRIDAP_B2_TOKEN,
        r.candidate_hash,r.scenario_hash,forged_cases,r.observed_l2_orders,
        r.observed_h1_orders,r.acceptance_intervals,r.status,r.evidence_class,
        r.claim_ceiling,r.rejection_reasons,r.source_hash,r.receipt_hash)
    @test !FusionRuntimeV4.validate_gridap_field_convergence_receipt(forged)
end
