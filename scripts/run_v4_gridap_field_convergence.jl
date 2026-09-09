push!(LOAD_PATH, dirname(@__DIR__))
using FusionConceptAI
using Gridap
Base.include(Main, joinpath(@__DIR__, "..", "examples", "runtime_v4_gridap_field_convergence_fixture.jl"))
receipt = FusionRuntimeV4.run_gridap_field_convergence(gridap_b2_compilations)
FusionRuntimeV4.validate_gridap_field_convergence_receipt(receipt) || error("B2 receipt validation failed")
println("gridap_b2_status=", receipt.status)
println("gridap_b2_l2_orders=", receipt.observed_l2_orders)
println("gridap_b2_h1_orders=", receipt.observed_h1_orders)
for c in receipt.cases
    println("gridap_b2_case nodes=$(c.nodes_per_axis) cells=$(c.cells) dofs=$(c.dofs) l2=$(c.solution_l2) h1=$(c.solution_h1_seminorm) source_cell_center_rms=$(c.source_cell_center_rms) boundary_face_center_linf=$(c.boundary_face_center_linf) residual=$(c.residual) runtime=$(c.runtime_seconds) memory=$(c.memory_bytes)")
end
println("gridap_b2_claim_ceiling=", receipt.claim_ceiling)
println("GRIDAP_B2_OK")
exit(0)
