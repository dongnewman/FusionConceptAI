# Structural rho partition/trace screen over the accepted basis-bridge fixture.
include(joinpath(@__DIR__, "runtime_v4_desc_field_basis_bridge.jl"))
const DRP = DFB
Base.include(DRP, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCRhoPartitionTraceContractV4.jl"))

const drp_sample = dfb_result.samples[2]
const drp_minus_trace = (DRP.make_desc_rho_trace_sample(drp_sample, :minus,
    (1.0, 0.0, 0.0)),)
const drp_plus_trace = (DRP.make_desc_rho_trace_sample(drp_sample, :plus,
    (-1.0, 0.0, 0.0)),)
const drp_regions = (
    DRP.DESCRhoRegionV4("rho_inner", 0.0, 0.75,
        dfb_request.physical_support_hash),
    DRP.DESCRhoRegionV4("rho_outer", 0.75, 1.0,
        dfb_request.physical_support_hash))
const drp_interfaces = (DRP.DESCRhoInterfaceV4("rho_interface",
    "rho_inner", "rho_outer", 0.75, drp_minus_trace, drp_plus_trace),)
const drp_upstream = (dgpi_context, dgpi_bridge_resolution, dgpi_evaluation,
    dgcp_resolution, dgrpe_request, dgrpe_result, dgrpe_receipt, dfp_request,
    dfp_result, dfb_request, dfb_result)
const drp_request = DRP.make_desc_rho_partition_request(drp_upstream...,
    drp_regions, drp_interfaces)
DRP.validate_desc_rho_partition_request(drp_upstream..., drp_request)
const drp_result = DRP.screen_desc_rho_partition(drp_upstream..., drp_request)

function run_desc_rho_partition_trace_example(io::IO=stdout)
    println(io, "candidate_hash=", drp_request.candidate_hash)
    println(io, "partition_structure_validated=",
        drp_result.partition_structure_validated)
    println(io, "spatial_partition_geometry_validated=",
        drp_result.spatial_partition_geometry_validated)
    println(io, "trace_sample_map_validated=",
        drp_result.trace_sample_map_validated)
    println(io, "declared_normal_pairing_validated=",
        drp_result.declared_normal_pairing_validated)
    println(io, "normal_geometry_validated=",
        drp_result.normal_geometry_validated)
    println(io, "interface_trace_executed=",
        drp_result.interface_trace_executed)
    println(io, "provider_executed=", drp_result.provider_executed)
    println(io, "multiregion_closure=", drp_result.multiregion_closure)
    println(io, "claim_ceiling=", drp_result.claim_ceiling)
    println(io, "DESC_RHO_PARTITION_TRACE_OK")
    drp_result
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_desc_rho_partition_trace_example()
end
