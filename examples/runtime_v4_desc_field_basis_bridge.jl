# Explicit candidate-bound DESC cylindrical-to-Cartesian field bridge.
include(joinpath(@__DIR__, "runtime_v4_desc_field_provider.jl"))
const DFB = DFP
Base.include(DFB, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCFieldBasisBridgeV4.jl"))

const dfb_request = DFB.make_desc_field_basis_bridge_request(dgpi_context,
    dgpi_bridge_resolution, dgpi_evaluation, dgcp_resolution, dgrpe_request,
    dgrpe_result, dgrpe_receipt, dfp_request, dfp_result)
const dfb_run_dir = get(ENV, "DFB_RUN_DIR",
    joinpath(dirname(@__DIR__), "runs", "desc_field_basis_bridge"))
const dfb_result = DFB.execute_desc_field_basis_bridge(dgpi_context,
    dgpi_bridge_resolution, dgpi_evaluation, dgcp_resolution, dgrpe_request,
    dgrpe_result, dgrpe_receipt, dfp_request, dfp_result, dfb_request;
    run_dir=dfb_run_dir)
const dfb_receipt = dfb_result.receipt

function run_desc_field_basis_bridge_example(io::IO=stdout)
    println(io, "candidate_hash=", dfb_result.candidate_hash)
    println(io, "basis_request_hash=", dfb_result.basis_request_hash)
    println(io, "sample_count=", length(dfb_result.samples))
    println(io, "source_basis=", dfb_result.source_basis)
    println(io, "target_basis=", dfb_result.target_basis)
    println(io, "field_values_cross_checked=",
        dfb_result.field_values_cross_checked)
    println(io, "basis_process_exit_code=", dfb_receipt.exit_code)
    println(io, "region_partition_validated=",
        dfb_result.region_partition_validated)
    println(io, "interface_trace_validated=",
        dfb_result.interface_trace_validated)
    println(io, "multiregion_closure=", dfb_result.multiregion_closure)
    println(io, "claim_ceiling=", dfb_result.claim_ceiling)
    println(io, "DESC_FIELD_BASIS_BRIDGE_OK")
    dfb_result
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_desc_field_basis_bridge_example()
end
