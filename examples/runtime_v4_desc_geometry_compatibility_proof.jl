"""Positive analytic DESC geometry proof fixture bound to the interpreter context."""

include(joinpath(@__DIR__, "runtime_v4_desc_geometry_program_interpreter.jl"))
Base.include(DGPI, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCGeometryCompatibilityProofV4.jl"))
const DGCP = DGPI

const dgcp_resolution = DGCP.prove_desc_geometry_compatibility(
    dgpi_context, dgpi_bridge_resolution, dgpi_evaluation)
const dgcp_certificate = something(dgcp_resolution.certificate)

function run_desc_geometry_compatibility_proof_example(io::IO=stdout)
    println(io, "proof_status=", dgcp_resolution.status)
    println(io, "geometric_compatibility_proved=",
        dgcp_resolution.geometric_compatibility_proved)
    println(io, "major_radius_lower_bound=",
        dgcp_certificate.payload.major_radius_lower_bound)
    println(io, "oriented_density_lower_bound=",
        dgcp_certificate.payload.normalized_oriented_volume_density_lower_bound)
    println(io, "request_emitted=", dgcp_resolution.request_emitted)
    println(io, "claim_ceiling=", dgcp_resolution.claim_ceiling)
    println(io, "DESC_GEOMETRY_COMPATIBILITY_PROOF_OK")
    dgcp_resolution
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_desc_geometry_compatibility_proof_example()
end
