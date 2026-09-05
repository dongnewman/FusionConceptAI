using Test
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_typed_time_refinement_fixture.jl"))

@testset "typed time refinement D1.2a" begin
    @test tref_protocol.ratio == 2
    @test tref_protocol.max_steps_per_level == (40, 80, 160)
    @test tref_receipt.status == :refinement_pass
    @test tref_receipt.failure_code === nothing
    @test tref_receipt.actual_step_counts == (5, 10, 20)
    @test tref_receipt.rhs_evaluations == (40, 80, 160)
    @test tref_receipt.endpoint_linf_differences !== nothing
    @test tref_receipt.self_convergence_order !== nothing
    @test 3.5 <= tref_receipt.self_convergence_order <= 4.5
    @test tref_receipt.receipt_hash == canonical_hash(tref_receipt)
    @test tref_receipt.form_hash == ttr_plan.form.form_hash
    @test tref_receipt.scenario_hash == ttr_scenario.scenario_hash
    @test tref_receipt.protocol_hash == tref_protocol.protocol_hash
    @test_throws ArgumentError TimeRefinementProtocolV4(0.2, (40, 80, 160); ratio=3)
    @test_throws ArgumentError TimeRefinementProtocolV4(true, (40, 80, 160))
    @test_throws ArgumentError TimeRefinementProtocolV4(NaN, (40, 80, 160))
    @test_throws ArgumentError TimeRefinementProtocolV4(Inf, (40, 80, 160))
    @test_throws ArgumentError TimeRefinementProtocolV4(nextfloat(0.0), (40, 80, 160))
    @test_throws ArgumentError TimeRefinementProtocolV4(0.2, (40, 80, 160); ratio=true)
    @test_throws ArgumentError TimeRefinementProtocolV4(0.2, (40, 80, 160); ratio=2.0)
    @test_throws ArgumentError TimeRefinementProtocolV4(0.2, (40, 80, 160); ratio=3)
    @test_throws ArgumentError TimeRefinementProtocolV4(0.2, (40, 80, 160); order_lower=2.0)
    @test_throws ArgumentError TimeRefinementProtocolV4(0.2, (40, 80, 160); order_upper=5.0)
    @test_throws ArgumentError TimeRefinementProtocolV4(0.2, (40, 80, 160); order_lower=4.5, order_upper=4.5)
    @test tref_protocol.protocol_hash != TimeRefinementProtocolV4(0.1, (40,80,160)).protocol_hash
    @test tref_receipt.receipt_hash == run_typed_time_refinement(ttr_plan, ttr_scenario, tref_protocol).receipt_hash
    @test length(unique(tref_receipt.plan_hashes)) == 3
    @test length(unique(tref_receipt.result_hashes)) == 3
    independent_plans = [derive_typed_time_residual_plan(ttr_plan,
        TimeIntegrationProtocolV4(:fixed_rk4, h, tref_protocol.max_steps_per_level[i]))
        for (i,h) in enumerate((0.2,0.1,0.05))]
    @test Tuple(p.plan_hash for p in independent_plans) == tref_receipt.plan_hashes
    @test_throws ArgumentError begin
        ttr_plan.form.mass_matrix[1,1] += 1
        run_typed_time_refinement(ttr_plan, ttr_scenario, tref_protocol)
    end
    ttr_plan.form.mass_matrix[1,1] -= 1
    partial = run_typed_time_refinement(ttr_plan, ttr_scenario,
        TimeRefinementProtocolV4(0.2, (40,1,160)))
    @test partial.status == :refinement_failure
    @test partial.plan_hashes[1] !== nothing && partial.plan_hashes[2] !== nothing && partial.plan_hashes[3] === nothing
    @test partial.result_hashes[1] !== nothing && partial.result_hashes[2] !== nothing && partial.result_hashes[3] === nothing
    @test partial.actual_steps == (0.2, 0.1, nothing)
    @test partial.actual_step_counts[2] == 1 && partial.rhs_evaluations[2] == 4
    zero_scenario = TimeIntegrationScenarioV4("equilibrium", 0.0, 1.0, ttr_time_unit,
        (StateValueV4(ttr_refs[1], 0.0, ttr_unit), StateValueV4(ttr_refs[2], 0.0, ttr_unit)))
    zero = run_typed_time_refinement(ttr_plan, zero_scenario, tref_protocol)
    @test zero.status == :refinement_failure && zero.failure_code == :zero_difference
    @test all(x !== nothing for x in zero.plan_hashes) && all(x !== nothing for x in zero.result_hashes)
    @test zero.actual_step_counts == (5,10,20) && zero.rhs_evaluations == (40,80,160)
    @test zero.endpoint_linf_differences == (0.0, 0.0) && zero.self_convergence_order === nothing
    narrow = run_typed_time_refinement(ttr_plan, ttr_scenario,
        TimeRefinementProtocolV4(0.2, (40,80,160); order_lower=4.3, order_upper=4.5))
    @test narrow.status == :refinement_failure && narrow.failure_code == :order_out_of_bounds
    @test narrow.self_convergence_order !== nothing && abs(narrow.self_convergence_order - 4.249551601226762) < 1e-12
    @test all(x !== nothing for x in narrow.plan_hashes) && all(x !== nothing for x in narrow.result_hashes)
    @test canonical_hash(tref_receipt) == tref_receipt.receipt_hash
    @test_throws ErrorException begin
        tref_receipt.result_hashes = (nothing,nothing,nothing)
    end
    bad = run_typed_time_refinement(ttr_plan, ttr_scenario,
        TimeRefinementProtocolV4(0.2, (1, 2, 4)))
    @test bad.status == :refinement_failure
    @test bad.failure_code !== nothing
    @test bad.endpoint_linf_differences === nothing
    @test bad.self_convergence_order === nothing
    @test_throws MethodError TimeRefinementReceiptV4(:refinement_pass, nothing,
        ttr_plan.compiled_prefix_hash, ttr_plan.form.form_hash, ttr_scenario.scenario_hash,
        tref_protocol.protocol_hash, tref_receipt.plan_hashes, tref_receipt.result_hashes,
        tref_receipt.actual_steps, tref_receipt.actual_step_counts, tref_receipt.rhs_evaluations,
        tref_receipt.endpoint_linf_differences, tref_receipt.self_convergence_order,
        tref_receipt.receipt_hash)
end
