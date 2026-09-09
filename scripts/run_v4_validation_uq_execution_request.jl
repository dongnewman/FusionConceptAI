"""Run the trusted-FreeGS Validation/UQ evidence-gap acceptance slice."""

include(joinpath(@__DIR__, "..", "test",
    "runtime_v4_validation_uq_execution_request_tests.jl"))
println("VALIDATION_UQ_EXECUTION_REQUEST_OK")
