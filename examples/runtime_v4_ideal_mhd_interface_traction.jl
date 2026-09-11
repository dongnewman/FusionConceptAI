# Candidate-bound real-DESC pressure traces and local ideal-MHD traction.
include(joinpath(@__DIR__, "runtime_v4_desc_rho_surface_trace_provider.jl"))
const IMIT = DRSTP
Base.include(IMIT, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "IdealMHDInterfaceTractionV4.jl"))

const imit_pressure_points = IMIT.ideal_mhd_pressure_points(drstp_result)
const imit_pressure_request = IMIT.make_desc_field_provider_request(
    drstp_upstream[1], drstp_upstream[5], drstp_upstream[6],
    drstp_upstream[7], imit_pressure_points)
const imit_pressure_run_dir = get(ENV, "IMIT_PRESSURE_RUN_DIR",
    joinpath(dirname(@__DIR__), "runs", "ideal_mhd_interface_pressure"))
const imit_pressure_result = IMIT.execute_desc_field_provider(
    drstp_upstream[1], drstp_upstream[5], drstp_upstream[6],
    drstp_upstream[7], imit_pressure_request; run_dir=imit_pressure_run_dir)
const imit_upstream = (drstp_upstream..., drstp_request, drstp_result,
    imit_pressure_request, imit_pressure_result)
const imit_request = IMIT.make_ideal_mhd_interface_traction_request(
    imit_upstream...)
const imit_result = IMIT.execute_ideal_mhd_interface_traction(
    imit_upstream..., imit_request)

function run_ideal_mhd_interface_traction_example(io::IO=stdout)
    println(io, "candidate_hash=", imit_result.candidate_hash)
    println(io, "request_hash=", imit_request.request_hash)
    println(io, "pressure_provider_exit_code=",
        imit_pressure_result.receipt.exit_code)
    println(io, "interface_sample_count=", length(imit_result.samples))
    println(io, "mu0_N_A2=", imit_request.mu0_N_A2)
    println(io, "constitutive_evaluated=", imit_result.constitutive_evaluated)
    println(io, "one_sided_traction_validated=",
        imit_result.one_sided_traction_validated)
    println(io, "interface_flux_executed=",
        imit_result.interface_flux_executed)
    println(io, "central_pair_cancelled=",
        imit_result.central_pair_cancelled)
    println(io, "jump_conditions_validated=",
        imit_result.jump_conditions_validated)
    println(io, "regional_residual_assembled=",
        imit_result.regional_residual_assembled)
    println(io, "jacobian_executed=", imit_result.jacobian_executed)
    println(io, "multiregion_closure=", imit_result.multiregion_closure)
    println(io, "claim_ceiling=", imit_result.claim_ceiling)
    println(io, "IDEAL_MHD_INTERFACE_TRACTION_OK")
    imit_result
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_ideal_mhd_interface_traction_example()
end
