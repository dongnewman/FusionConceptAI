"""Independent status dimensions; no aggregate status is provided."""

function _validate_status_dimensions(applicability::ApplicabilityStatus, match_status::MatchStatus,
                                     resolution::ResolutionStatus, stage_outcome::StageOutcome;
                                     applicability_record=nothing, require_applicability_proof::Bool=false)
    if applicability == not_applicable
        stage_outcome == not_applicable_stage || throw(ArgumentError("not_applicable requires not_applicable_stage"))
        if require_applicability_proof
            applicability_record !== nothing && applicability_record.status == not_applicable &&
                !isempty(applicability_record.obligation) && applicability_record.proof_ref !== nothing ||
                throw(ArgumentError("not_applicable requires applicability proof"))
        end
    else
        stage_outcome == not_applicable_stage && throw(ArgumentError("required applicability cannot be not_applicable_stage"))
        applicability_record !== nothing && applicability_record.status == not_applicable &&
            throw(ArgumentError("required applicability cannot carry not_applicable proof"))
    end
    match_status in (no_match, ambiguous, out_of_domain, invalid_signature) &&
        (resolution == terminal_deferred && stage_outcome == terminal_deferred_stage) ||
        match_status in (unique_match,) || throw(ArgumentError("non-unique match requires terminal_deferred_stage"))
    (resolution == terminal_deferred) == (stage_outcome == terminal_deferred_stage) ||
        throw(ArgumentError("terminal_deferred resolution requires terminal_deferred_stage"))
    resolution == resolved && match_status != unique_match && throw(ArgumentError("resolved requires unique_match"))
    stage_outcome == pass && (applicability == required && match_status == unique_match && resolution == resolved) ||
        stage_outcome != pass || throw(ArgumentError("pass status combination is invalid"))
    nothing
end

struct StatusVectorV4
    applicability::ApplicabilityStatus
    match_status::MatchStatus
    resolution::ResolutionStatus
    lifecycle::LifecycleStatus
    stage_outcome::StageOutcome
    function StatusVectorV4(applicability::ApplicabilityStatus, match_status::MatchStatus, resolution::ResolutionStatus,
                            lifecycle::LifecycleStatus, stage_outcome::StageOutcome)
        _validate_status_dimensions(applicability, match_status, resolution, stage_outcome)
        new(applicability, match_status, resolution, lifecycle, stage_outcome)
    end
end
semantic_view(x::StatusVectorV4) = (applicability=x.applicability, match_status=x.match_status, resolution=x.resolution,
                                    lifecycle=x.lifecycle, stage_outcome=x.stage_outcome)
