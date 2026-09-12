# Include in an existing real DESC run to consume its objects without restarting
# providers. Standalone execution creates the accepted q3 prerequisite once.
if !isdefined(@__MODULE__,:q3_execution)
    include(joinpath(@__DIR__,"runtime_v4_regional_force_observation_q3_comparison.jl"))
end
const CCPP=Module(:CCPP)
Base.include(CCPP,joinpath(@__DIR__,"..","src","RuntimeV4","CandidateCoupledPhysicsV4.jl"))
const coupled_physics_execution=CCPP.execute_candidate_coupled_physics(imit_upstream,q3_execution;
    run_dir=joinpath(RFQ3_RUN_ROOT,"candidate_weak_volume"))
println("candidate_weak_volume_region_count=",length(coupled_physics_execution.region_ids))
println("candidate_weak_volume_N=",coupled_physics_execution.region_weak_volume_N)
println("candidate_strong_moments_N=",coupled_physics_execution.region_strong_moments_N)
println("candidate_constitutive_jacobian_fd_error=",coupled_physics_execution.jacobian_fd_max_scaled_error)
println("candidate_coupled_physics_status=",coupled_physics_execution.status)
println("candidate_coupled_physics_executed=",coupled_physics_execution.execution)
println("candidate_coupled_physics_gaps=",coupled_physics_execution.missing_capabilities)
println("CANDIDATE_COUPLED_PHYSICS_EXAMPLE_EXIT_CODE=0")
