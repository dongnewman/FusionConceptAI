using Test
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_ideal_mhd_interface_residual_jacobian.jl"))
@testset "static ideal MHD interface residual Jacobian" begin
    @test canonical_hash(imit_rj_request)==imit_rj_request.request_hash
    @test canonical_hash(imit_rj_result)==imit_rj_result.result_hash
    @test imit_rj_result.fd_validated && imit_rj_result.jacobian_validated
    @test imit_rj_result.interface_subset_residual
    @test !imit_rj_result.jump_conditions_validated && !imit_rj_result.multiregion_closure
    @test imit_rj_result.residuals[1][4] isa Float64
    @test imit_rj_result.fd_max_abs_errors[1] <= imit_rj_request.fd_abs_tolerance

    foreign_body = merge(_imirj_body(imit_rj_request),
        (candidate_hash=canonical_hash((foreign_candidate=true,)),))
    foreign_request = IdealMHDInterfaceResidualJacobianRequestV4(
        _IMIRJ_TOKEN, values(foreign_body)..., canonical_hash(foreign_body))
    @test canonical_hash(foreign_request) == foreign_request.request_hash
    @test_throws ArgumentError execute_ideal_mhd_interface_residual_jacobian(
        foreign_request, imit_request, imit_result, (imit_rj_state,))

    subset_body = merge(_imirj_body(imit_rj_request),
        (interface_subset=(canonical_hash((foreign_interface=true,)),),))
    subset_request = IdealMHDInterfaceResidualJacobianRequestV4(
        _IMIRJ_TOKEN, values(subset_body)..., canonical_hash(subset_body))
    @test_throws ArgumentError execute_ideal_mhd_interface_residual_jacobian(
        subset_request, imit_request, imit_result, (imit_rj_state,))

    altered_residuals = ((imit_rj_result.residuals[1][1] + 1.0,
        imit_rj_result.residuals[1][2:end]...),)
    altered_body = merge(_imirj_result_body(imit_rj_result),
        (residuals=altered_residuals,))
    altered_result = IdealMHDInterfaceResidualJacobianResultV4(
        _IMIRJ_TOKEN, values(altered_body)..., canonical_hash(altered_body))
    @test canonical_hash(altered_result) == altered_result.result_hash
    @test_throws ArgumentError validate_ideal_mhd_interface_residual_jacobian_result(
        imit_rj_request, imit_request, imit_result, altered_result)
end
println("IDEAL_MHD_INTERFACE_RESIDUAL_JACOBIAN_FOCUSED_EXIT_CODE=0")
