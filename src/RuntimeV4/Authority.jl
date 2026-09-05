"""Claim firewall for the P2-P5 spine."""

struct AuthorityClassificationV4
    disposition::Symbol
    claim_ceiling::ClaimCeiling
    p5_ready::Bool
    unresolved_gaps::Tuple
    reason::String
    provider_coverage_complete::Bool
    goal_acceptance::Bool
    terminal_classification_executed::Bool
end

function classify_authority(audit::WholeDeviceClosureV4)
    # P1-P5 software closure cannot emit a physical terminal disposition.
    AuthorityClassificationV4(:withheld, audit.claim_ceiling, audit.p5_ready,
        audit.unresolved_gaps, audit.p5_ready ?
            "closure is software-complete but final physical authority is absent" :
            "required stage evidence or admission prerequisite is unresolved",
        audit.provider_coverage_complete, audit.goal_acceptance,
        audit.terminal_classification_executed)
end
