"""Exact gap fixtures for the candidate-bound DESC geometry-program preflight."""

using FusionConceptAI

include(joinpath(@__DIR__, "runtime_v4_desc_fixed_boundary_request_compiler.jl"))
Base.include(DFBRC, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCGeometryProgramPreflightV4.jl"))
const DGPP = DFBRC

# The accepted composition fixture has no DESC-specific declarations.
const dgpp_missing_declarations_resolution =
    DGPP.preflight_desc_geometry_program(tdpic_context)

# The DESC-declared fixture reaches the actual G2 roots.  Those roots are
# constant, zero-input programs on [-1,1]^3 with no periodic axes, while their
# chart declarations advertise normalized outputs.  The preflight must expose
# all of those exact gaps and must not emit a proof, certificate, or request.
const dgpp_current_resolution =
    DGPP.preflight_desc_geometry_program(dfbrc_context)

function run_desc_geometry_program_preflight_example(io::IO=stdout)
    println(io, "missing_status=", dgpp_missing_declarations_resolution.status)
    println(io, "missing_gaps=", join(
        dgpp_missing_declarations_resolution.recoverable_gaps, ","))
    println(io, "current_status=", dgpp_current_resolution.status)
    println(io, "current_gaps=", join(
        dgpp_current_resolution.recoverable_gaps, ","))
    println(io, "geometry_proved=", dgpp_current_resolution.geometry_proved)
    println(io, "certificate_emitted=",
        dgpp_current_resolution.certificate_emitted)
    println(io, "request_emitted=", dgpp_current_resolution.request_emitted)
    dgpp_current_resolution
end
