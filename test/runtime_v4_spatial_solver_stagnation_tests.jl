using Test
using LinearAlgebra
include(joinpath(@__DIR__,"runtime_v4_spatial_multiregion_tests.jl"))

@testset "recorded spatial solver stagnation is numerical no-progress" begin
    root=joinpath(@__DIR__,"..")
    history=joinpath(root,"runs","spatial_chain_20260912_r1","physics","nominal_coarse","state_history.csv")
    @test isfile(history)
    rows=readlines(history)
    @test length(rows)>4
    iterations=joinpath(root,"runs","spatial_chain_20260912_r1","physics","nominal_coarse","iterations.csv")
    itrows=readlines(iterations)
    itfields=split.(itrows[2:end],',')
    tail_norm=parse.(Float64,[r[2] for r in itfields[end-4:end]])
    @test all(==(tail_norm[1]),tail_norm) # accepted motion did not reduce phi
    fields=split.(rows[2:end],',')
    # The recorded tail is the actual artifact: iteration, node, BR, Bphi, BZ, p.
    node1=filter(r->r[2]=="1",fields)
    tail_iterations=sort(unique(parse.(Int,[r[1] for r in node1])))
    @test length(tail_iterations)>=4
    @test tail_iterations[end-3:end]==[9,10,11,12]
    pressures=parse.(Float64,[r[6] for r in node1[end-3:end]])
    @test length(pressures)==4
    @test all(pressures .> 0)
    cols=fill(1.0,4);cols[4]=1e5
    x=[0.,0.,0.,pressures[1]]; y=[0.,0.,0.,pressures[2]]
    # Historical logic accepted trial!=x; the scaled state change is below
    # floating resolution and therefore is not progress.
    @test y != x
    @test !SPF._smr_scaled_state_change(x,y,cols)
    @test SPF._smr_pressure_feasible(0.0,1e5)
    @test SPF._smr_pressure_feasible(-1e-15,1e5) # roundoff-sized negative
    @test !SPF._smr_pressure_feasible(-1e-5,1e5) # materially infeasible
    @test !SPF._smr_scaled_state_change(x,[NaN,0.,0.,pressures[2]],cols)
    @test SPF._smr_scaled_state_change(x,[1e-8,0.,0.,pressures[1]],cols)
    @test dot([1.,2.],[1.,2.]) > dot([.5,1.],[.5,1.]) # strict decrease is meaningful
end

@testset "solver outcome classifications" begin
    d,data=manufactured_spatial_fixture();x=copy(data.initial_state)
    with_solver(solver)=SPF.SpatialMultiRegionDeclarationV4(
        d.revision,d.regions,d.states,d.interfaces,d.source,d.boundary,d.spaces,
        d.flux,d.cases,d.parameters,d.quadrature,d.scaling,solver,d.applicability)

    # Production tolerances remain unchanged. Modified declarations below are
    # branch controls only; they grant no convergence or physical credit.
    initial=SPF.assemble_spatial_system_v4(d,data,x)
    initial_max=maximum(abs,initial.residual./initial.row_scales)
    converged=SPF.solve_spatial_state_v4(with_solver(merge(d.solver,
        (residual_tolerance=nextfloat(initial_max),))),data,x;
        limits=(max_iterations=1,seconds=60.))
    @test converged.solver_exit_code==0
    @test converged.status==:converged
    @test converged.stopping_reason==:all_scaled_residuals_converged
    @test converged.attempt_count==converged.accepted_update_count==0

    stationary=SPF.solve_spatial_state_v4(with_solver(merge(d.solver,
        (gradient_tolerance=1e100,))),data,x;limits=(max_iterations=1,seconds=60.))
    @test stationary.solver_exit_code==2
    @test stationary.status==:fail
    @test stationary.stopping_reason==:stationary_nonzero_residual
    @test stationary.attempt_count==stationary.accepted_update_count==0

    budget=SPF.solve_spatial_state_v4(d,data,x;limits=(max_iterations=0,seconds=60.))
    @test budget.solver_exit_code==4
    @test budget.status==:fail
    @test budget.stopping_reason==:iteration_limit
    @test budget.attempt_count==budget.accepted_update_count==0

    bad=copy(x);bad[4]=-1e-5
    infeasible=SPF.solve_spatial_state_v4(d,data,bad;limits=(max_iterations=1,seconds=60.))
    @test infeasible.solver_exit_code==6
    @test infeasible.status==:fail
    @test infeasible.stopping_reason==:nonfinite_or_infeasible_state
    @test infeasible.attempt_count==infeasible.accepted_update_count==0

    nonfinite=SPF.solve_spatial_state_v4(d,data,x;limits=(max_iterations=1,seconds=60.),
        _test_qr_factorization=(A,tol)->Diagonal(fill(NaN,size(A,2))))
    @test nonfinite.solver_exit_code==5
    @test nonfinite.status==:fail
    @test nonfinite.stopping_reason==:sparse_QR_failure
    @test !nonfinite.last_attempt.linear_solution_finite
    @test nonfinite.accepted_update_count==0
    @test nonfinite.last_attempt.state_after_hash==nonfinite.last_attempt.state_before_hash

    no_progress=SPF.solve_spatial_state_v4(d,data,x;limits=(max_iterations=1,seconds=60.),
        _test_line_search_acceptance=t->false)
    @test no_progress.solver_exit_code==3
    @test no_progress.status==:fail
    @test no_progress.accepted_update_count==0
    @test no_progress.final_state==Tuple(x)
    @test no_progress.stopping_reason==:feasible_line_search_failed
    @test no_progress.last_attempt.progress_classification==:line_search_rejected

    accepted=SPF.solve_spatial_state_v4(d,data,x;limits=(max_iterations=1,seconds=60.),
        _test_line_search_acceptance=t->t.armijo_accepted)
    @test accepted.solver_exit_code==4
    @test accepted.status==:fail
    @test accepted.stopping_reason==:iteration_limit
    @test accepted.accepted_update_count==accepted.attempt_count==1
    @test only(accepted.attempts).strict_objective_decrease
    @test only(accepted.attempts).objective_decrease>0
    @test only(accepted.attempts).scaled_state_change
    @test only(accepted.attempts).progress_classification==:accepted_strict_decrease
    @test only(filter(t->t.accepted,only(accepted.attempts).trials)).strict_objective_decrease
end
