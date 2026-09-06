using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_typed_dae_time_execution_fixture.jl"))

store = TypedDAETimeStoreV4()
report = FusionRuntimeV4.execute_once!(store, d2_time_plan.input,
    d2_time_plan.provider, d2_time_plan)
validated = validate_typed_dae_time_report(d2_time_plan, report)
result = report.artifact
result === nothing && error("D2.2 fixture produced no artifact")
final_values = Dict(value.state_ref.value => value.value
    for value in result.trajectory[end].states)
oracle = (1 + d2_time_plan.protocol.step)^(-d2_time_plan.protocol.step_count)

println("method=", d2_time_plan.protocol.method,
    " step=", d2_time_plan.protocol.step,
    " accepted_steps=", result.accepted_steps)
println("initial_states=", result.trajectory[1].states)
println("final_states=", result.trajectory[end].states)
println("final_x=", final_values["x"], " backward_euler_oracle=", oracle,
    " oracle_error=", abs(final_values["x"] - oracle))
println("max_scaled_differential_residual=",
    result.max_scaled_differential_residual,
    " max_scaled_algebraic_residual=",
    result.max_scaled_algebraic_residual)
println("max_scaled_joint_condition=", result.max_scaled_joint_condition,
    " final_scaled_jzz_condition=",
    result.trajectory[end].scaled_jzz_condition)
println("initialization_plan_hash=", d2_init_plan.plan_hash)
println("initialization_report_hash=", canonical_hash(d2_init_report))
println("initialization_artifact_hash=", canonical_hash(d2_init_report.artifact))
println("dae_time_plan_hash=", d2_time_plan.plan_hash)
println("solver_input_hash=", d2_time_plan.input.solver_input_hash)
println("provider_hash=", d2_time_plan.provider.manifest_hash)
println("source_hash=", d2_time_plan.source_hash)
println("artifact_hash=", canonical_hash(result))
println("evidence_hash=", report.evidence.evidence_id)
println("receipt_hash=", report.receipt.receipt_hash)
println("report_hash=", report.report_hash)
println("execution_count=",
    store.execution_counts[d2_time_plan.input.solver_input_hash],
    " validation=", validated ? "PASS" : "FAIL")
println("claim_ceiling=", report.claim_ceiling,
    " credible_physical_candidates=", report.credible_physical_candidate_count,
    " p5_ready=", report.p5_ready,
    " unsupported=", report.unsupported_emitted)
