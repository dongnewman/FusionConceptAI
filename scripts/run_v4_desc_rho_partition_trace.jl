# Standalone runner: exit marker is emitted only after the accepted fixture
# and structural screen complete without an exception.
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_desc_rho_partition_trace.jl"))
run_desc_rho_partition_trace_example()
println("DESC_RHO_PARTITION_TRACE_RUN_EXIT_CODE=0")
