# Real candidate-bound DESC equilibrium field sampling.
include(joinpath(@__DIR__, "runtime_v4_desc_request_provider_execution.jl"))
const DFP = DGRPE
Base.include(DFP, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCFieldProviderV4.jl"))

const dfp_points = (
    DFP.DESCFieldSamplePointV4(0.25, 0.10, 0.20),
    DFP.DESCFieldSamplePointV4(0.75, 0.30, 0.40))
const dfp_request = DFP.make_desc_field_provider_request(dgpi_context,
    dgrpe_request, dgrpe_result, dgrpe_receipt, dfp_points)
const dfp_run_dir = get(ENV, "DFP_RUN_DIR",
    joinpath(dirname(@__DIR__), "runs", "desc_field_provider"))
const dfp_result = DFP.execute_desc_field_provider(dgpi_context,
    dgrpe_request, dgrpe_result, dgrpe_receipt, dfp_request;
    run_dir=dfp_run_dir)
const dfp_receipt = dfp_result.receipt

function run_desc_field_provider_example(io::IO=stdout)
    println(io, "candidate_hash=", dfp_result.candidate_hash)
    println(io, "field_request_hash=", dfp_result.field_request_hash)
    println(io, "sample_count=", length(dfp_result.samples))
    println(io, "provider_exit_code=", dfp_receipt.exit_code)
    println(io, "result_schema_validated=",
        dfp_result.result_schema_validated)
    println(io, "solver_convergence_validated=",
        dfp_result.solver_convergence_validated)
    println(io, "multiregion_closure=", dfp_result.multiregion_closure)
    println(io, "physical_validation=", dfp_result.physical_validation)
    println(io, "claim_ceiling=", dfp_result.claim_ceiling)
    println(io, "DESC_FIELD_PROVIDER_OK")
    dfp_result
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_desc_field_provider_example()
end
