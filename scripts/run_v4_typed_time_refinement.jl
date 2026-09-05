include(joinpath(@__DIR__, "..", "examples", "runtime_v4_typed_time_refinement_fixture.jl"))
using LinearAlgebra
exact = ((1 + exp(-2)) / 2, (1 - exp(-2)) / 2)
hs = (tref_protocol.base_step, tref_protocol.base_step / 2, tref_protocol.base_step / 4)
results = [integrate_typed_time_residual(derive_typed_time_residual_plan(ttr_plan,
    TimeIntegrationProtocolV4(:fixed_rk4, h, tref_protocol.max_steps_per_level[i])), ttr_scenario)
    for (i, h) in enumerate(hs)]
hashes_ok = all(results[i].result_hash == tref_receipt.result_hashes[i] for i in 1:3)
plans_ok = all(derive_typed_time_residual_plan(ttr_plan,
    TimeIntegrationProtocolV4(:fixed_rk4, hs[i], tref_protocol.max_steps_per_level[i])).plan_hash == tref_receipt.plan_hashes[i] for i in 1:3)
errors = [maximum(abs.(Float64[r.states[end]...] .- exact)) for r in results]
orders = [log(errors[i] / errors[i + 1]) / log(2) for i in 1:2]
println("status=$(tref_receipt.status) steps=$(tref_receipt.actual_step_counts) rhs=$(tref_receipt.rhs_evaluations) order=$(tref_receipt.self_convergence_order)")
println("endpoint_linf_differences=$(tref_receipt.endpoint_linf_differences)")
println("external_oracle_errors=$(errors) orders=$(orders) strictly_decreasing=$(errors[1] > errors[2] > errors[3])")
drift = maximum(abs.(sum(Float64[results[i].states[end]...]) - sum(Float64[results[i].states[1]...]) for i in 1:3))
oracle_ok = tref_receipt.status == :refinement_pass && tref_receipt.actual_step_counts == (5, 10, 20) &&
    tref_receipt.rhs_evaluations == (40, 80, 160) && errors[1] > errors[2] > errors[3] &&
    all(3.5 <= o <= 4.5 for o in orders) && drift <= 1e-12
oracle_ok &= hashes_ok && plans_ok
println("external_oracle_drift=$(drift) hashes_ok=$(hashes_ok) plans_ok=$(plans_ok) gate=$(oracle_ok)")
oracle_ok || exit(1)
