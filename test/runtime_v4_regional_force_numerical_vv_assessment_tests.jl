using Test
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_regional_force_numerical_vv_assessment.jl"))
@testset "negative q2/q3 numerical V&V assessment" begin
    a=regional_force_vv_assessment
    @test canonical_hash(a)==a.assessment_hash
    @test a.numerical_convergence_status===:fail
    @test a.numerical_convergence_assessed
    @test a.absolute_difference_N==q3_comparison.absolute_difference_N
    @test a.relative_difference==q3_comparison.relative_difference
    @test a.relative_difference > a.relative_tolerance
    @test a.absolute_difference_N > a.absolute_tolerance_N
    @test a.next_layer_request===:q4_required
    @test a.recoverable_gap===:independent_code_validation_required
    @test a.evidence_credit==0 && a.claim_ceiling==screen_only
    @test !a.independent_code_validation && !a.physical_validation && !a.validation_uq
    @test !a.promotion_authority && !a.terminal_authority && a.credible_device_count==0
    @test a.q3_request_hash==q3_comparison.q3_request.request_hash && a.q3_result_hash==q3_comparison.q3_result.result_hash && a.q3_receipt_hash==q3_comparison.q3_receipt.receipt_hash
    @test_throws ArgumentError RFVV.execute_regional_force_numerical_vv_assessment(
        imit_upstream, imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution; relative_tolerance=-1.0)
    @test_throws ArgumentError RFVV.execute_regional_force_numerical_vv_assessment(
        imit_upstream, imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution; absolute_tolerance_N=Inf)
    loose=RFVV.execute_regional_force_numerical_vv_assessment(
        imit_upstream, imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution; relative_tolerance=2.0)
    @test loose.numerical_convergence_status===:pass
    @test canonical_hash(loose)==loose.assessment_hash
    @test !loose.independent_code_validation && !loose.physical_validation &&
        !loose.validation_uq && !loose.promotion_authority && !loose.terminal_authority
    @test_throws Exception RFVV.execute_regional_force_numerical_vv_assessment(
        imit_upstream, imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, (comparison=q3_comparison,))
    forged_authority=merge(semantic_view(a),(promotion_authority=true,))
    @test_throws ArgumentError RFVV.RegionalForceNumericalVVAssessmentV4(
        RFVV._RFVV_TOKEN, values(forged_authority)...,canonical_hash(forged_authority)) |> canonical_hash
    forged_difference=merge(semantic_view(a),
        (absolute_difference_N=a.absolute_difference_N + 1.0,))
    @test_throws ArgumentError RFVV.RegionalForceNumericalVVAssessmentV4(
        RFVV._RFVV_TOKEN, values(forged_difference)...,canonical_hash(forged_difference)) |> canonical_hash
    forged=merge(semantic_view(a),(numerical_convergence_status=:pass,))
    @test_throws ArgumentError RFVV.RegionalForceNumericalVVAssessmentV4(
        RFVV._RFVV_TOKEN, values(forged)...,canonical_hash(forged)) |> canonical_hash
    @test_throws MethodError RFVV.RegionalForceNumericalVVAssessmentV4(
        values(semantic_view(a))..., a.assessment_hash)
end
println("REGIONAL_FORCE_NUMERICAL_VV_ASSESSMENT_FOCUSED_EXIT_CODE=0")
