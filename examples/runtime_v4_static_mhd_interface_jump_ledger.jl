include(joinpath(@__DIR__, "runtime_v4_ideal_mhd_interface_residual_jacobian.jl"))
const SMJL = Main
Base.include(SMJL, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "StaticMHDInterfaceJumpLedgerV4.jl"))

const smjl_execution = execute_static_mhd_interface_jump_ledger(
    imit_upstream..., imit_request, imit_result, imit_rj_request, imit_rj_result)
const smjl_request = smjl_execution.request
const smjl_result = smjl_execution.result

function run_static_mhd_interface_jump_ledger(io::IO=stdout)
    println(io, "candidate_hash=", smjl_result.candidate_hash)
    println(io, "interface_count=", length(smjl_result.entries))
    println(io, "boundary_limits_validated=", smjl_result.boundary_limits_validated)
    println(io, "jump_conditions_validated=", smjl_result.jump_conditions_validated)
    println(io, "multiregion_closure=", smjl_result.multiregion_closure)
    println(io, "claim_ceiling=", smjl_result.claim_ceiling)
    println(io, "STATIC_MHD_INTERFACE_JUMP_LEDGER_OK")
    smjl_result
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_static_mhd_interface_jump_ledger()
end
