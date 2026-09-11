"""Real-DESC regional integrated-force observation over the current chain."""

include(joinpath(@__DIR__, "runtime_v4_ideal_mhd_interface_traction.jl"))
const DRIFO = IMIT
Base.include(DRIFO, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCRegionalIntegratedForceObservationV4.jl"))

const drifo_request = DRIFO.make_desc_regional_integrated_force_observation_request(
    imit_upstream..., imit_request, imit_result)
const drifo_run_dir = get(ENV, "DRIFO_RUN_DIR",
    joinpath(dirname(@__DIR__), "runs",
        "desc_regional_integrated_force_observation"))
const drifo_execution = DRIFO.execute_desc_regional_integrated_force_observation(
    imit_upstream..., imit_request, imit_result, drifo_request;
    run_dir=drifo_run_dir)
const drifo_result = drifo_execution.observation

function run_desc_regional_integrated_force_observation(io::IO=stdout)
    println(io, "candidate_hash=", drifo_result.candidate_hash)
    println(io, "request_hash=", drifo_request.request_hash)
    println(io, "region_count=", length(drifo_result.region_observations))
    println(io, "node_count=", length(drifo_result.node_observations))
    println(io, "field_provider_exit_code=",
        drifo_execution.field_result.receipt.exit_code)
    println(io, "basis_provider_exit_code=",
        drifo_execution.basis_result.receipt.exit_code)
    println(io, "observed_total_force_norm_N=",
        drifo_result.observed_total_force_norm_N)
    println(io, "regional_force_integrals_observed=",
        drifo_result.regional_force_integrals_observed)
    println(io, "regional_residual_assembled=",
        drifo_result.regional_residual_assembled)
    println(io, "multiregion_closure=", drifo_result.multiregion_closure)
    println(io, "claim_ceiling=", drifo_result.claim_ceiling)
    println(io, "DESC_REGIONAL_INTEGRATED_FORCE_OBSERVATION_OK")
    drifo_result
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_desc_regional_integrated_force_observation()
end
