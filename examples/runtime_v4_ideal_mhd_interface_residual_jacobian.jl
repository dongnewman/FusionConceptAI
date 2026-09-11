include(joinpath(@__DIR__, "runtime_v4_ideal_mhd_interface_traction.jl"))
const IMIRJ = Main
Base.include(Main, joinpath(@__DIR__, "..", "src", "RuntimeV4", "IdealMHDInterfaceResidualJacobianV4.jl"))
const imit_rj_request = make_ideal_mhd_interface_residual_jacobian_request(imit_request, imit_result)
const imit_rj_state = (imit_result.samples[1].minus_pressure_Pa, imit_result.samples[1].minus_B_xyz_T...,
    imit_result.samples[1].plus_pressure_Pa, imit_result.samples[1].plus_B_xyz_T...)
const imit_rj_result = execute_ideal_mhd_interface_residual_jacobian(imit_rj_request, imit_request, imit_result, (imit_rj_state,))
function run_ideal_mhd_interface_residual_jacobian_example(io::IO=stdout)
    println(io, "interface_subset_residual=", imit_rj_result.interface_subset_residual)
    println(io, "jacobian_validated=", imit_rj_result.jacobian_validated)
    println(io, "jump_conditions_validated=", imit_rj_result.jump_conditions_validated)
end
