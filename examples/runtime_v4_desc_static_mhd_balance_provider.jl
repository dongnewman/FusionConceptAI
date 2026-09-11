include(joinpath(@__DIR__, "runtime_v4_ideal_mhd_interface_traction.jl"))
const DSMB = IMIT
Base.include(DSMB, joinpath(@__DIR__, "..", "src", "RuntimeV4", "DESCStaticMHDBalanceProviderV4.jl"))
const dsmb_result = DSMB.execute_desc_static_mhd_balance(
    imit_upstream[1], imit_upstream[2], imit_upstream[3], imit_upstream[4],
    imit_upstream[5], imit_upstream[6], imit_upstream[7], imit_upstream[8],
    imit_upstream[9], imit_upstream[10], imit_upstream[11], imit_upstream[12],
    imit_upstream[13], imit_upstream[14], imit_upstream[15], imit_request,
    imit_result, imit_upstream[16], imit_upstream[17];
    run_dir=get(ENV, "DSMB_RUN_DIR", joinpath(dirname(@__DIR__), "runs", "desc_static_mhd_balance")))
function run_desc_static_mhd_balance_provider(io::IO=stdout)
    println(io, "sample_count=", length(dsmb_result.samples))
    println(io, "regional_force_balance_sampled=", dsmb_result.regional_force_balance_sampled)
    println(io, "cross_checked=", dsmb_result.cross_checked)
    println(io, "claim_ceiling=", dsmb_result.claim_ceiling)
    println(io, "DESC_STATIC_MHD_BALANCE_PROVIDER_OK")
    dsmb_result
end
if abspath(PROGRAM_FILE) == @__FILE__; run_desc_static_mhd_balance_provider(); end
