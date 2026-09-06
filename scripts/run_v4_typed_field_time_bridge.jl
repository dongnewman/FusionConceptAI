include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_typed_field_time_bridge_fixture.jl"))

println("D3 typed field-time bridge: PASS")
println("candidate = ", d3_candidate.identity_ref)
println("shared prefix = ", d3_compiled.prefix_hash)
println("D2.1 status = ", d3_init_report.numerical_status)
println("D2.2 status = ", d3_time_report.numerical_status,
    ", steps = ", d3_time_report.artifact.accepted_steps,
    ", final x = ", d3_time_report.artifact.trajectory[end].states[1].value)
println("G2 status = ", d3_g2_report.status,
    ", grid points = ", length(d3_g2_report.result.values),
    ", range = [", d3_g2_report.result.min_value, ", ",
    d3_g2_report.result.max_value, "]")
println("component evidence ids = ", d3_report.component_evidence_ids)
println("scenario relationship = ",
    d3_report.materialization.scenario_relationship)
println("unresolved obligations:")
for gap in d3_report.unresolved_gaps
    println("  - ", gap.code, " ", gap.missing_axes)
end
println("field_time_executable = ", d3_report.field_time_executable)
println("claim_ceiling = ", d3_report.claim_ceiling)
println("credible_physical_candidate_count = ",
    d3_report.credible_physical_candidate_count)
println("p5_ready = ", d3_report.p5_ready)
println("unsupported_emitted = ", d3_report.unsupported_emitted)
