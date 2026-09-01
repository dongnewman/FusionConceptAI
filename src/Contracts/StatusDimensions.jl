"""Independent status dimensions; no aggregate status is provided."""

struct StatusVectorV4
    applicability::ApplicabilityStatus
    match_status::MatchStatus
    resolution::ResolutionStatus
    lifecycle::LifecycleStatus
    stage_outcome::StageOutcome
    function StatusVectorV4(applicability::ApplicabilityStatus, match_status::MatchStatus, resolution::ResolutionStatus,
                            lifecycle::LifecycleStatus, stage_outcome::StageOutcome)
        match_status in (no_match, ambiguous, out_of_domain, invalid_signature) && resolution != terminal_deferred && throw(ArgumentError("non-unique match cannot be resolved"))
        resolution == resolved && match_status != unique_match && throw(ArgumentError("resolved requires unique_match"))
        stage_outcome == pass && (applicability == required && match_status == unique_match && resolution == resolved) || stage_outcome != pass || throw(ArgumentError("pass status combination is invalid"))
        new(applicability, match_status, resolution, lifecycle, stage_outcome)
    end
end
semantic_view(x::StatusVectorV4) = (applicability=x.applicability, match_status=x.match_status, resolution=x.resolution,
                                    lifecycle=x.lifecycle, stage_outcome=x.stage_outcome)
