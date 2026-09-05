using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "TypedTimeResidual.jl"))
using .FusionRuntimeV4
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_typed_time_fixture.jl"))

exact = ((1 + exp(-2)) / 2, (1 - exp(-2)) / 2)
results = NamedTuple[]
for h in (0.2, 0.1, 0.05)
    protocol = TimeIntegrationProtocolV4(:fixed_rk4, h, 1000)
    run_plan = derive_typed_time_residual_plan(ttr_plan, protocol)
    result = integrate_typed_time_residual(run_plan, ttr_scenario)
    error = result.status == :integrated ?
        maximum(abs.(Float64[result.states[end]...] .- exact)) : NaN
    drift = result.status == :integrated ?
        sum(result.states[end]) - sum(result.states[1]) : NaN
    push!(results, (h=h, status=result.status, steps=length(result.times) - 1,
        rhs=result.rhs_evaluations, error=error, drift=drift,
        residual=result.residual_norm))
end
for row in results
    println("h=$(row.h) status=$(row.status) steps=$(row.steps) rhs=$(row.rhs) " *
        "error=$(row.error) drift=$(row.drift) residual=$(row.residual)")
end
errors = [row.error for row in results]
orders = (log(errors[1] / errors[2]) / log(2),
    log(errors[2] / errors[3]) / log(2))
println("observed_order=$(orders)")
manifest = typed_time_residual_manifest()
println("policy_claim_ceiling=$(manifest.claim_ceiling) policy_source=typed_time_residual_manifest")
all(row -> row.status == :integrated && isfinite(row.error) && row.residual !== nothing && abs(row.drift) <= 1e-12, results) || exit(1)
all(o -> 3.5 <= o <= 4.5, orders) || exit(1)
