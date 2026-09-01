"""Candidate package and immutable Proposal/Evidence envelopes."""

struct ProposalEnvelopeV4
    proposal_id::String
    candidate_or_prefix_ref::String
    parent_refs::Tuple{Vararg{String}}
    search_channel::Symbol
    typed_edit_trace::Tuple
    target_behavior_cell::String
    predicted_outcomes::NamedTuple
    uncertainty::NamedTuple
    estimated_cost::Float64
    model_or_rule_hash::String
    requested_next_stage::Symbol
    function ProposalEnvelopeV4(id::AbstractString, candidate::AbstractString, parents, channel::Symbol,
                                edits, cell::AbstractString, predicted::NamedTuple, uncertainty::NamedTuple,
                                cost::Real, model_hash::AbstractString, next_stage::Symbol)
        all(!isempty, (id, candidate, model_hash)) || throw(ArgumentError("proposal references cannot be empty"))
        isfinite(cost) && cost >= 0 || throw(ArgumentError("estimated_cost must be finite and non-negative"))
        new(String(id), String(candidate), Tuple(String(p) for p in parents), channel, Tuple(edits), String(cell),
            predicted, uncertainty, Float64(cost), String(model_hash), next_stage)
    end
end

struct EvidenceEnvelopeV4
    evidence_id::String
    physical_subject_hash::String
    scenario_hash::String
    solver_input_hash::String
    provider_manifest_hash::String
    backend_revision::String
    numerical_configuration_hash::String
    applicability::ApplicabilityStatus
    match_status::MatchStatus
    resolution_status::ResolutionStatus
    stage_outcome::StageOutcome
    metrics_with_units::NamedTuple
    uncertainty_or_null::Union{Nothing,NamedTuple}
    artifact_refs::Tuple{Vararg{String}}
    independence_group::String
    claim_ceiling::Symbol
    function EvidenceEnvelopeV4(id::AbstractString, physical::AbstractString, scenario::AbstractString,
                                solver::AbstractString, provider::AbstractString, backend::AbstractString,
                                numerical::AbstractString, applicability::ApplicabilityStatus,
                                match_status::MatchStatus, resolution::ResolutionStatus, outcome::StageOutcome,
                                metrics::NamedTuple; uncertainty=nothing, artifact_refs=(), independence_group="",
                                claim_ceiling::Symbol=:screen_only)
        all(!isempty, (id, physical, scenario, solver, provider, backend, numerical)) ||
            throw(ArgumentError("EvidenceEnvelopeV4 content hashes/revisions cannot be empty"))
        uncertainty === nothing || uncertainty isa NamedTuple || throw(ArgumentError("uncertainty must be NamedTuple or nothing"))
        new(String(id), String(physical), String(scenario), String(solver), String(provider), String(backend), String(numerical),
            applicability, match_status, resolution, outcome, metrics, uncertainty, Tuple(String(a) for a in artifact_refs),
            String(independence_group), claim_ceiling)
    end
end

struct CanonicalHashesV4
    mechanism_hash::String
    field_geometry_hash::String
    realization_control_hash::String
    genome_bundle_hash::String
    physical_subject_hash::String
    solver_input_hashes::Tuple{Vararg{String}}
end

struct CandidateStatePackageV4
    identity_ref::String
    mission_contract_ref::GenomeContractRef
    mechanism_genome_ref::MechanismGenomeV4
    field_geometry_genome_ref::FieldGeometryGenomeV4
    realization_control_genome_ref::RealizationControlGenomeV4
    canonical_hashes::CanonicalHashesV4
    lifecycle::LifecycleStatus
    applicability_records::Tuple{Vararg{ApplicabilityRecord}}
    compilation_records::Tuple
    proposal_lineage::Tuple{Vararg{ProposalEnvelopeV4}}
    stage_evidence_refs::Tuple{Vararg{EvidenceRef}}
    archive_memberships::Tuple{Vararg{String}}
    terminal_authority_ref::Union{Nothing,String}
    claim_ceiling::Symbol
end

function CandidateStatePackageV4(identity::AbstractString, mission::GenomeContractRef,
                                 mechanism::MechanismGenomeV4, field::FieldGeometryGenomeV4,
                                 realization::RealizationControlGenomeV4, registry::GenomeContractRegistryV4;
                                 lifecycle::LifecycleStatus=proposed, applicability_records=(), compilation_records=(),
                                 proposal_lineage=(), stage_evidence_refs=(), archive_memberships=(), claim_ceiling::Symbol=:none)
    hashes = CanonicalHashesV4(mechanism_hash(mechanism), field_geometry_hash(field), realization_control_hash(realization),
                               genome_bundle_hash(mechanism, field, realization; mission_contract=mission), "", ())
    CandidateStatePackageV4(String(identity), mission, mechanism, field, realization, hashes, lifecycle,
                            Tuple(applicability_records), Tuple(compilation_records), Tuple(proposal_lineage),
                            Tuple(stage_evidence_refs), Tuple(String(a) for a in archive_memberships), nothing, claim_ceiling)
end

function with_physical_subject(pkg::CandidateStatePackageV4, physical_hash::AbstractString, solver_hashes=())
    isempty(physical_hash) && throw(ArgumentError("physical_subject_hash cannot be empty"))
    h = pkg.canonical_hashes
    newh = CanonicalHashesV4(h.mechanism_hash, h.field_geometry_hash, h.realization_control_hash,
                             h.genome_bundle_hash, String(physical_hash), Tuple(String(s) for s in solver_hashes))
    CandidateStatePackageV4(pkg.identity_ref, pkg.mission_contract_ref, pkg.mechanism_genome_ref,
                            pkg.field_geometry_genome_ref, pkg.realization_control_genome_ref, newh,
                            pkg.lifecycle, pkg.applicability_records, pkg.compilation_records, pkg.proposal_lineage,
                            pkg.stage_evidence_refs, pkg.archive_memberships, pkg.terminal_authority_ref, pkg.claim_ceiling)
end
