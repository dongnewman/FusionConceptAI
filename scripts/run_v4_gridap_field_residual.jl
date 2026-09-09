push!(LOAD_PATH, dirname(@__DIR__))
using FusionConceptAI
using Gridap

Base.include(Main, joinpath(@__DIR__, "..", "examples",
    "runtime_v4_gridap_field_fixture.jl"))

report = FusionRuntimeV4.run_gridap_field_residual(gridap_b1_compilation)
result = report.result
receipt = report.receipt
report.status === :pass || error("Gridap B1 did not pass: $(report.status)")
FusionRuntimeV4.validate_gridap_field_residual_report(
    gridap_b1_compilation, report) || error("Gridap B1 report validation failed")
FusionRuntimeV4.replay_gridap_field_residual(
    gridap_b1_compilation, report) || error("Gridap B1 fresh replay failed")
report.evidence_class === :manufactured_control ||
    error("Gridap B1 evidence class exceeded manufactured control")
report.claim_ceiling === screen_only || error("Gridap B1 claim ceiling changed")
report.numerical_vvuq_status === :terminal_deferred ||
    error("Gridap B1 prematurely claimed numerical VVUQ")
report.credible_physical_candidate_count == 0 && !report.p5_ready &&
    !report.unsupported_emitted || error("Gridap B1 authority boundary changed")
println("julia_version=", VERSION)
println("gridap_version=", Base.pkgversion(Gridap))
println("gridap_b1_status=", report.status)
println("gridap_b1_cells=", receipt.cells)
println("gridap_b1_free_dofs=", receipt.free_dofs)
println("gridap_b1_dirichlet_dofs=", receipt.dirichlet_dofs)
println("gridap_b1_residual_inf=", result.residual_abs)
println("gridap_b1_relative_residual=", result.residual_rel)
println("gridap_b1_boundary_mismatch=", result.boundary_mismatch)
println("gridap_b1_manufactured_node_linf=", result.manufactured_node_linf_error)
println("gridap_b1_claim_ceiling=", report.claim_ceiling)
println("gridap_b1_numerical_vvuq_status=", report.numerical_vvuq_status)
println("gridap_b1_credible_physical_candidate_count=",
    report.credible_physical_candidate_count)
println("gridap_b1_p5_ready=", report.p5_ready)
println("GRIDAP_B1_OK")
