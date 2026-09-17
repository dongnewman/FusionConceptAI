include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_regional_mhd_weak_residual_production_gap.jl"))
println("status=", rmwr_production_gap.status)
println("missing_capabilities=", rmwr_production_gap.missing_capabilities)
println("REGIONAL_MHD_WEAK_RESIDUAL_EXIT_CODE=0")
