# Run the D4.1 candidate-bound field residual composition fixture.
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_field_residual_composition_fixture.jl"))

validate_manufactured_field_convergence_receipt(field_residual_convergence) ||
    error("D4.1 convergence receipt failed validation")
for c in field_residual_cases
    c.report.status === :pass || error("D4.1 grid $(c.n) did not pass")
    println("n=$(c.n) points=$(length(c.report.artifact.solution)) " *
        "status=$(c.report.status) residual=$(c.report.artifact.residual_norm) " *
        "backend=$(c.provider.backend) factorization=$(c.report.artifact.factorization_status)")
end
println("convergence_errors=$(field_residual_convergence.errors)")
println("convergence_orders=$(field_residual_convergence.orders)")
println("evidence_class=$(field_residual_plans[1].mission.evidence_class) " *
    "claim_ceiling=$(field_residual_reports[1].claim_ceiling) " *
    "credible=$(field_residual_reports[1].credible_physical_candidate_count) " *
    "p5_ready=$(field_residual_reports[1].p5_ready) " *
    "unsupported=$(field_residual_reports[1].unsupported_emitted)")
