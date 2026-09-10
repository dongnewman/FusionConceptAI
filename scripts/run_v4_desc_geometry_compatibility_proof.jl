include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_desc_geometry_compatibility_proof.jl"))
resolution = run_desc_geometry_compatibility_proof_example()
resolution.status === :proved &&
    resolution.geometric_compatibility_proved &&
    resolution.certificate_emitted &&
    !resolution.request_emitted &&
    resolution.claim_ceiling == screen_only &&
    resolution.credible_physical_device_count == 0 ||
    error("DESC geometry compatibility proof runner acceptance failed")
DGCP.validate_desc_geometry_compatibility(dgpi_context,
    dgpi_bridge_resolution, dgpi_evaluation, resolution)
println("DESC_GEOMETRY_COMPATIBILITY_PROOF_RUNNER_EXIT_CODE=0")
