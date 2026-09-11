using FusionConceptAI
using LinearAlgebra
using SHA
const _RFVV_REVISION = "regional-force-numerical-vv-assessment-v1"
const _RFVV_SOURCE = abspath(@__FILE__)
const _RFVV_TOKEN = Val(:regional_force_numerical_vv_assessment_private)
_rfvv_sha(p)=Digest256(bytes2hex(SHA.sha256(read(p))))

"""Candidate-bound q2/q3 numerical convergence assessment.

This is a numerical screen only: it grants no independent-code, physical, UQ,
promotion, or terminal authority, regardless of the tolerance outcome.
"""
struct RegionalForceNumericalVVAssessmentV4
    revision::String; candidate_hash::Digest256; context_hash::Digest256
    q2_request_hash::Digest256; q2_result_hash::Digest256; q2_receipt_hash::Digest256
    q3_comparison_hash::Digest256; q3_request_hash::Digest256; q3_result_hash::Digest256; q3_receipt_hash::Digest256
    q2_total_force::NTuple{3,Float64}; q3_total_force::NTuple{3,Float64}
    absolute_difference_N::Float64; relative_difference::Float64; relative_tolerance::Float64; absolute_tolerance_N::Float64
    numerical_convergence_status::Symbol; numerical_convergence_assessed::Bool; next_layer_request::Symbol; recoverable_gap::Symbol
    independent_code_validation::Bool; physical_validation::Bool; validation_uq::Bool; promotion_authority::Bool; terminal_authority::Bool
    credible_device_count::Int
    evidence_credit::Int; claim_ceiling::ClaimCeiling; source_path::String; source_sha256::Digest256
    assessment_hash::Digest256
    function RegionalForceNumericalVVAssessmentV4(
            token::Val{:regional_force_numerical_vv_assessment_private}, fields...)
        token === _RFVV_TOKEN || throw(ArgumentError("private assessment constructor"))
        new(fields...)
    end
end
semantic_view(x::RegionalForceNumericalVVAssessmentV4)=NamedTuple{fieldnames(typeof(x))[1:end-1]}(ntuple(i->getfield(x,i),fieldcount(typeof(x))-1))
function canonical_hash(x::RegionalForceNumericalVVAssessmentV4)
    expected_absolute=norm(collect(ntuple(k->x.q3_total_force[k]-x.q2_total_force[k],3)))
    expected_relative=expected_absolute/max(norm(collect(x.q2_total_force)),eps())
    expected_status=(expected_absolute <= x.absolute_tolerance_N || expected_relative <= x.relative_tolerance) ? :pass : :fail
    x.revision==_RFVV_REVISION && x.numerical_convergence_assessed && x.numerical_convergence_status===expected_status &&
        x.next_layer_request===:q4_required && x.recoverable_gap===:independent_code_validation_required &&
        isfinite(x.relative_tolerance) && x.relative_tolerance>0 && isfinite(x.absolute_tolerance_N) && x.absolute_tolerance_N>0 &&
        all(isfinite,x.q2_total_force) && all(isfinite,x.q3_total_force) &&
        x.absolute_difference_N==expected_absolute && x.relative_difference==expected_relative &&
        !x.independent_code_validation && !x.physical_validation && !x.validation_uq && !x.promotion_authority && !x.terminal_authority &&
        x.credible_device_count==0 && x.evidence_credit==0 && x.claim_ceiling==screen_only && isfile(x.source_path) &&
        _rfvv_sha(x.source_path)==x.source_sha256 || throw(ArgumentError("invalid numerical V&V assessment"))
    h=canonical_hash(semantic_view(x)); h==x.assessment_hash || throw(ArgumentError("assessment hash mismatch")); h
end

function execute_regional_force_numerical_vv_assessment(upstream, traction_request, traction_result, q2_request, q2_result, q2_execution, q3_execution; relative_tolerance=1e-3, absolute_tolerance_N=1e-6)
    isfinite(relative_tolerance) && relative_tolerance>0 && isfinite(absolute_tolerance_N) && absolute_tolerance_N>0 || throw(ArgumentError("tolerances must be finite and positive"))
    q3_comparison=q3_execution.comparison
    validate_regional_force_q3_execution(upstream, traction_request, traction_result, q2_request, q2_result, q2_execution, q3_execution)
    canonical_hash(q3_comparison)
    q2_receipt=q2_result.receipt
    canonical_hash(q2_request); canonical_hash(q2_result); canonical_hash(q2_receipt)
    q3_comparison.q2_request_hash == canonical_hash(q2_request) &&
        q3_comparison.q2_result_hash == canonical_hash(q2_result) &&
        q3_comparison.q2_receipt_hash == canonical_hash(q2_receipt) ||
        throw(ArgumentError("q2/q3 request identity mismatch"))
    q3_comparison.q3_result.request_hash == q3_comparison.q3_request.request_hash &&
        q3_comparison.q3_result.receipt_hash == q3_comparison.q3_receipt.receipt_hash ||
        throw(ArgumentError("q3 receipt identity mismatch"))
    q2=q2_result.observed_total_force_xyz_N; q3=q3_comparison.q3_result.total_force
    ad=norm(collect(ntuple(k->q3[k]-q2[k],3))); rd=ad/max(norm(collect(q2)),eps())
    body=(revision=_RFVV_REVISION,candidate_hash=q3_comparison.candidate_hash,context_hash=q3_comparison.context_hash,
      q2_request_hash=q3_comparison.q2_request_hash,q2_result_hash=q3_comparison.q2_result_hash,
      q2_receipt_hash=q3_comparison.q2_receipt_hash,q3_comparison_hash=q3_comparison.comparison_hash,
      q3_request_hash=q3_comparison.q3_request.request_hash,q3_result_hash=q3_comparison.q3_result.result_hash,q3_receipt_hash=q3_comparison.q3_receipt.receipt_hash,
      q2_total_force=q2,q3_total_force=q3,
      absolute_difference_N=ad,relative_difference=rd,
      relative_tolerance=Float64(relative_tolerance),absolute_tolerance_N=Float64(absolute_tolerance_N),
      numerical_convergence_status=(ad <= absolute_tolerance_N || rd <= relative_tolerance ? :pass : :fail), numerical_convergence_assessed=true,next_layer_request=:q4_required,
      recoverable_gap=:independent_code_validation_required,independent_code_validation=false,
      physical_validation=false,validation_uq=false,promotion_authority=false,terminal_authority=false,credible_device_count=0,evidence_credit=0,claim_ceiling=screen_only,
      source_path=_RFVV_SOURCE,source_sha256=_rfvv_sha(_RFVV_SOURCE))
    x=RegionalForceNumericalVVAssessmentV4(_RFVV_TOKEN, values(body)...,canonical_hash(body)); canonical_hash(x); x
end
validate_regional_force_numerical_vv_assessment(x::RegionalForceNumericalVVAssessmentV4)=canonical_hash(x)
