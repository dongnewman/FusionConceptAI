"""Independent status dimensions; no aggregate status is provided."""

struct StatusVectorV4
    applicability::ApplicabilityStatus
    match_status::MatchStatus
    resolution::ResolutionStatus
    lifecycle::LifecycleStatus
    stage_outcome::StageOutcome
end

function StatusVectorV4(; applicability=required, match_status=unique_match, resolution=resolved,
                        lifecycle=proposed, stage_outcome=unknown)
    applicability isa ApplicabilityStatus || throw(ArgumentError("invalid applicability dimension"))
    match_status isa MatchStatus || throw(ArgumentError("invalid match dimension"))
    resolution isa ResolutionStatus || throw(ArgumentError("invalid resolution dimension"))
    lifecycle isa LifecycleStatus || throw(ArgumentError("invalid lifecycle dimension"))
    stage_outcome isa StageOutcome || throw(ArgumentError("invalid stage dimension"))
    StatusVectorV4(applicability, match_status, resolution, lifecycle, stage_outcome)
end
