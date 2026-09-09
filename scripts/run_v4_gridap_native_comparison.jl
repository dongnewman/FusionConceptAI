push!(LOAD_PATH, dirname(@__DIR__))
using FusionConceptAI
using Gridap
Base.include(Main, joinpath(@__DIR__, "..", "examples", "runtime_v4_gridap_native_comparison_fixture.jl"))
let r = gridap_c_report
    FusionRuntimeV4.validate_gridap_native_comparison(r,
        gridap_c_gridap_bundles, gridap_c_native_witnesses,
        gridap_c_native_convergence, gridap_c_gridap_convergence;
        compiled=composition_compiled, genome_registry=tdae_registry,
        scenario=d3_g2_scenario) || error("Batch C validation failed")
    println("gridap_c_status=", r.status)
    println("gridap_c_native_linf=", r.native_linf_errors)
    println("gridap_c_gridap_l2=", r.gridap_l2_errors)
    println("gridap_c_gridap_h1=", r.gridap_h1_errors)
    println("gridap_c_transfer_linf=", r.transfer_linf_errors)
    println("gridap_c_transfer_l2=", r.transfer_l2_errors)
    println("gridap_c_transfer_relative_l2=", r.transfer_relative_l2_errors)
    println("gridap_c_transfer_linf_orders=", r.transfer_linf_orders)
    println("gridap_c_transfer_l2_orders=", r.transfer_l2_orders)
    println("gridap_c_native_independence_group=",
        r.receipt.native_independence_group)
    println("gridap_c_gridap_independence_group=",
        r.receipt.gridap_independence_group)
    println("gridap_c_claim_ceiling=", r.claim_ceiling)
    println("gridap_c_credible_physical_candidate_count=", r.credible_physical_candidate_count)
    println("gridap_c_p5_ready=", r.p5_ready)
    r.status === :pass || error("Batch C numerical acceptance failed: $(r.rejection_reasons)")
    println("GRIDAP_NATIVE_COMPARISON_OK")
end
