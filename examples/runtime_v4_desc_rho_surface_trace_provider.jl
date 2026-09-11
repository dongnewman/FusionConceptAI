# Fresh candidate-bound DESC rho-surface geometry and two-sided trace sampling.
include(joinpath(@__DIR__, "runtime_v4_desc_rho_partition_trace.jl"))
const DRSTP = DRP
Base.include(DRSTP, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCRhoSurfaceTraceProviderV4.jl"))

const drstp_upstream = (drp_upstream..., drp_request, drp_result)
const drstp_request = DRSTP.make_desc_rho_surface_trace_provider_request(
    drstp_upstream...; epsilon_rho=1.0e-3)
const drstp_run_dir = get(ENV, "DRSTP_RUN_DIR",
    joinpath(dirname(@__DIR__), "runs", "desc_rho_surface_trace_provider"))
const drstp_result = DRSTP.execute_desc_rho_surface_trace_provider(
    drstp_upstream..., drstp_request; run_dir=drstp_run_dir)
const drstp_receipt = drstp_result.receipt

function run_desc_rho_surface_trace_provider_example(io::IO=stdout)
    println(io, "candidate_hash=", drstp_result.candidate_hash)
    println(io, "provider_request_hash=", drstp_request.request_hash)
    println(io, "sample_count=", length(drstp_result.samples))
    println(io, "provider_exit_code=", drstp_receipt.exit_code)
    println(io, "desc_version=", drstp_result.desc_version)
    println(io, "surface_geometry_sampled=",
        drstp_result.surface_geometry_sampled)
    println(io, "normal_geometry_validated=",
        drstp_result.normal_geometry_validated)
    println(io, "two_sided_trace_executed=",
        drstp_result.two_sided_trace_executed)
    println(io, "region_ownership_validated=",
        drstp_result.region_ownership_validated)
    println(io, "spatial_partition_geometry_validated=",
        drstp_result.spatial_partition_geometry_validated)
    println(io, "interface_flux_executed=",
        drstp_result.interface_flux_executed)
    println(io, "multiregion_closure=", drstp_result.multiregion_closure)
    println(io, "claim_ceiling=", drstp_result.claim_ceiling)
    println(io, "DESC_RHO_SURFACE_TRACE_PROVIDER_OK")
    drstp_result
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_desc_rho_surface_trace_provider_example()
end
