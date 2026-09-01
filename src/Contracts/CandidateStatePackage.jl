"""Immutable v4 candidate, proposal, and evidence contracts."""

struct MissionContractRef
    uri::String
    version::String
    schema_hash::Digest256
    canonicalization_hash::Digest256
    function MissionContractRef(uri::AbstractString, version::AbstractString, schema_hash::Digest256, canonicalization_hash::Digest256)
        all(!isempty, (uri, version)) || throw(ArgumentError("incomplete MissionContractRef"))
        new(String(uri), String(version), schema_hash, canonicalization_hash)
    end
end
MissionContractRef(uri::AbstractString, version::AbstractString, schema::AbstractString, canon::AbstractString) =
    MissionContractRef(uri, version, Digest256(schema), Digest256(canon))
semantic_view(x::MissionContractRef) = (uri=x.uri, version=x.version, schema_hash=x.schema_hash, canonicalization_hash=x.canonicalization_hash)
Base.:(==)(a::MissionContractRef, b::MissionContractRef) = semantic_view(a) == semantic_view(b)

function _deep_immutable(x)
    deep_immutable(x)
end

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
    model_or_rule_hash::Digest256
    requested_next_stage::Symbol
    function ProposalEnvelopeV4(id::AbstractString, candidate::AbstractString, parents, channel::Symbol,
                                edits, cell::AbstractString, predicted::NamedTuple, uncertainty::NamedTuple,
                                cost::Real, model_hash::Digest256, next_stage::Symbol)
        all(!isempty, (id, candidate)) || throw(ArgumentError("proposal references cannot be empty"))
        cost64 = Float64(cost)
        isfinite(cost64) && cost64 >= 0 || throw(ArgumentError("estimated_cost must be finite and non-negative after Float64 conversion"))
        vals = (Tuple(String(p) for p in parents), Tuple(edits), predicted, uncertainty)
        all(_deep_immutable, vals) || throw(ArgumentError("ProposalEnvelopeV4 must be deeply immutable"))
        new(String(id), String(candidate), vals[1], channel, vals[2], String(cell), predicted, uncertainty,
            cost64, model_hash, next_stage)
    end
end
ProposalEnvelopeV4(id::AbstractString, candidate::AbstractString, parents, channel::Symbol, edits, cell::AbstractString,
                   predicted::NamedTuple, uncertainty::NamedTuple, cost::Real, model_hash::AbstractString, next_stage::Symbol) =
    ProposalEnvelopeV4(id, candidate, parents, channel, edits, cell, predicted, uncertainty, cost, Digest256(model_hash), next_stage)
semantic_view(x::ProposalEnvelopeV4) = (proposal_id=x.proposal_id, candidate_or_prefix_ref=x.candidate_or_prefix_ref,
    parent_refs=x.parent_refs, search_channel=x.search_channel, typed_edit_trace=x.typed_edit_trace,
    target_behavior_cell=x.target_behavior_cell, predicted_outcomes=x.predicted_outcomes, uncertainty=x.uncertainty,
    estimated_cost=x.estimated_cost, model_or_rule_hash=x.model_or_rule_hash, requested_next_stage=x.requested_next_stage)

struct UncertaintyV4
    metrics::Tuple{Vararg{MetricWithUnit}}
    function UncertaintyV4(metrics=())
        ms = Tuple(metrics); all(m -> m isa MetricWithUnit, ms) || throw(ArgumentError("uncertainty metrics must be typed"))
        deep_immutable(ms) || throw(ArgumentError("uncertainty must be immutable"))
        new(ms)
    end
end
semantic_view(x::UncertaintyV4) = (metrics=x.metrics,)

struct EvidenceContentV4
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    solver_input_hash::Digest256
    provider_manifest_hash::Digest256
    backend_revision::String
    numerical_configuration_hash::Digest256
    applicability::ApplicabilityStatus
    applicability_record::Union{Nothing,ApplicabilityRecord}
    match_status::MatchStatus
    resolution_status::ResolutionStatus
    stage_outcome::StageOutcome
    metrics_with_units::Tuple{Vararg{MetricWithUnit}}
    uncertainty_or_null::Union{Nothing,UncertaintyV4}
    artifact_refs::Tuple{Vararg{Digest256}}
    independence_group::String
    claim_ceiling::ClaimCeiling
    function EvidenceContentV4(physical::Digest256, scenario::Digest256, solver::Digest256, provider::Digest256,
        backend::AbstractString, numerical::Digest256, applicability::ApplicabilityStatus,
        applicability_record::Union{Nothing,ApplicabilityRecord}, match::MatchStatus, resolution::ResolutionStatus,
        outcome::StageOutcome, metrics::Tuple{Vararg{MetricWithUnit}}, uncertainty::Union{Nothing,UncertaintyV4},
        artifacts::Tuple{Vararg{Digest256}}, group::AbstractString, ceiling::ClaimCeiling)
        match in (no_match, ambiguous, out_of_domain, invalid_signature) &&
            (resolution == terminal_deferred && outcome == terminal_deferred_stage && outcome != pass || throw(ArgumentError("non-unique match must be terminal_deferred")))
        (resolution == terminal_deferred) == (outcome == terminal_deferred_stage) ||
            throw(ArgumentError("terminal_deferred resolution requires terminal_deferred_stage"))
        resolution == resolved && match == unique_match || resolution == terminal_deferred || throw(ArgumentError("resolved evidence requires unique_match"))
        outcome == pass && (applicability == required && match == unique_match && resolution == resolved) || outcome != pass || throw(ArgumentError("pass status combination is invalid"))
        outcome == not_applicable_stage && (applicability == not_applicable && applicability_record !== nothing && applicability_record.status == not_applicable) || outcome != not_applicable_stage || throw(ArgumentError("not_applicable_stage requires applicability proof"))
        if applicability == not_applicable
            applicability_record !== nothing && applicability_record.status == not_applicable && !isempty(applicability_record.obligation) ||
                throw(ArgumentError("not_applicable evidence requires an applicability proof"))
        elseif applicability_record !== nothing && applicability_record.status == not_applicable
            throw(ArgumentError("required evidence cannot carry a not_applicable proof"))
        end
        ceiling in (none, screen_only) || throw(ArgumentError("P0 evidence ceiling is at most screen_only"))
        all(m -> m isa MetricWithUnit, metrics) && deep_immutable((metrics, uncertainty, artifacts)) || throw(ArgumentError("EvidenceContentV4 payload must be typed and immutable"))
        new(physical, scenario, solver, provider, String(backend), numerical, applicability, applicability_record, match, resolution,
            outcome, metrics, uncertainty, artifacts, String(group), ceiling)
    end
end
EvidenceContentV4(physical::AbstractString, scenario::AbstractString, solver::AbstractString, provider::AbstractString,
                  backend::AbstractString, numerical::AbstractString, applicability::ApplicabilityStatus,
                  applicability_record, match::MatchStatus, resolution::ResolutionStatus, outcome::StageOutcome,
                  metrics::Tuple{Vararg{MetricWithUnit}}, uncertainty, artifacts, group::AbstractString, ceiling::ClaimCeiling) =
    EvidenceContentV4(Digest256(physical), Digest256(scenario), Digest256(solver), Digest256(provider), backend, Digest256(numerical),
                      applicability, applicability_record, match, resolution, outcome, metrics, uncertainty,
                      Tuple(Digest256(a) for a in artifacts), group, ceiling)
semantic_view(x::EvidenceContentV4) = (physical_subject_hash=x.physical_subject_hash, scenario_hash=x.scenario_hash,
    solver_input_hash=x.solver_input_hash, provider_manifest_hash=x.provider_manifest_hash, backend_revision=x.backend_revision,
    numerical_configuration_hash=x.numerical_configuration_hash, applicability=x.applicability,
    applicability_record=x.applicability_record, match_status=x.match_status, resolution_status=x.resolution_status,
    stage_outcome=x.stage_outcome, metrics_with_units=x.metrics_with_units, uncertainty_or_null=x.uncertainty_or_null,
    artifact_refs=x.artifact_refs, independence_group=x.independence_group, claim_ceiling=x.claim_ceiling)

evidence_id_for(content::EvidenceContentV4) = canonical_hash(content)

struct EvidenceEnvelopeV4
    evidence_id::Digest256
    content::EvidenceContentV4
    function EvidenceEnvelopeV4(content::EvidenceContentV4)
        new(evidence_id_for(content), content)
    end
end
semantic_view(x::EvidenceEnvelopeV4) = (content=x.content,)
evidence_envelope(content::EvidenceContentV4) = EvidenceEnvelopeV4(content)

struct CanonicalHashesV4
    mechanism_hash::Digest256
    field_geometry_hash::Digest256
    realization_control_hash::Digest256
    genome_bundle_hash::Digest256
    physical_subject_hash::Union{Nothing,Digest256}
    solver_input_hashes::Tuple{Vararg{Digest256}}
end
semantic_view(x::CanonicalHashesV4) = (mechanism_hash=x.mechanism_hash, field_geometry_hash=x.field_geometry_hash,
    realization_control_hash=x.realization_control_hash, genome_bundle_hash=x.genome_bundle_hash,
    physical_subject_hash=x.physical_subject_hash, solver_input_hashes=x.solver_input_hashes)

struct CandidateStatePackageV4
    identity_ref::String
    mission_contract_ref::MissionContractRef
    mechanism_genome_ref::MechanismGenomeV4
    field_geometry_genome_ref::FieldGeometryGenomeV4
    realization_control_genome_ref::RealizationControlGenomeV4
    canonical_hashes::CanonicalHashesV4
    resolution::ResolutionStatus
    lifecycle::LifecycleStatus
    applicability_records::Tuple{Vararg{ApplicabilityRecord}}
    compilation_records::Tuple
    proposal_lineage::Tuple{Vararg{ProposalEnvelopeV4}}
    stage_evidence_refs::Tuple{Vararg{EvidenceRef}}
    archive_memberships::Tuple{Vararg{String}}
    terminal_authority_ref::Nothing
    claim_ceiling::ClaimCeiling
    function CandidateStatePackageV4(identity::String, mission::MissionContractRef, mechanism::MechanismGenomeV4,
        field::FieldGeometryGenomeV4, realization::RealizationControlGenomeV4, registry::GenomeContractRegistryV4,
        lifecycle::LifecycleStatus, applicability::Tuple{Vararg{ApplicabilityRecord}}, compilation::Tuple,
        proposals::Tuple{Vararg{ProposalEnvelopeV4}}, evidence::Tuple{Vararg{EvidenceRef}}, archives::Tuple{Vararg{String}}, ceiling::ClaimCeiling)
        lifecycle in (proposed, compiled, dormant, proof_pruned) || throw(ArgumentError("lifecycle is outside P0"))
        ceiling in (none, screen_only) || throw(ArgumentError("claim ceiling is outside P0"))
        deep_immutable((mission=mission, mechanism=mechanism, field=field, realization=realization,
                        applicability=applicability, compilation=compilation, proposals=proposals, evidence=evidence, archives=archives)) || throw(ArgumentError("candidate payload must be deeply immutable"))
        matched = resolve_contract(registry, mechanism.contract_ref, :mechanism) && resolve_contract(registry, field.contract_ref, :field_geometry) && resolve_contract(registry, realization.contract_ref, :realization_control)
        hashes = CanonicalHashesV4(mechanism_hash(mechanism), field_geometry_hash(field), realization_control_hash(realization), genome_bundle_hash(mechanism, field, realization; mission_contract=mission), nothing, ())
        new(identity, mission, mechanism, field, realization, hashes, matched ? resolved : terminal_deferred, lifecycle, applicability, compilation, proposals, evidence, archives, nothing, ceiling)
    end
end
function CandidateStatePackageV4(identity::AbstractString, mission::MissionContractRef, mechanism::MechanismGenomeV4,
                                 field::FieldGeometryGenomeV4, realization::RealizationControlGenomeV4, registry::GenomeContractRegistryV4;
                                 lifecycle::LifecycleStatus=proposed, applicability_records=(), compilation_records=(), proposal_lineage=(),
                                 stage_evidence_refs=(), archive_memberships=(), claim_ceiling::ClaimCeiling=none)
    CandidateStatePackageV4(String(identity), mission, mechanism, field, realization, registry, lifecycle,
                            Tuple(applicability_records), Tuple(compilation_records), Tuple(proposal_lineage), Tuple(stage_evidence_refs),
                            Tuple(String(a) for a in archive_memberships), claim_ceiling)
end
semantic_view(x::CandidateStatePackageV4) = (mission_contract_ref=x.mission_contract_ref, mechanism_genome_ref=x.mechanism_genome_ref,
    field_geometry_genome_ref=x.field_geometry_genome_ref, realization_control_genome_ref=x.realization_control_genome_ref,
    canonical_hashes=x.canonical_hashes, resolution=x.resolution, lifecycle=x.lifecycle, applicability_records=x.applicability_records,
    compilation_records=x.compilation_records, proposal_lineage=x.proposal_lineage, stage_evidence_refs=x.stage_evidence_refs,
    archive_memberships=x.archive_memberships, claim_ceiling=x.claim_ceiling)

struct LegacyMigrationResultV4
    resolution::ResolutionStatus
    package::Union{Nothing,CandidateStatePackageV4}
    reason::String
    function LegacyMigrationResultV4(resolution::ResolutionStatus, package::Union{Nothing,CandidateStatePackageV4}, reason::AbstractString)
        resolution == terminal_deferred && package === nothing && !isempty(reason) ||
            throw(ArgumentError("P0 legacy migration can only produce terminal_deferred without a package"))
        new(resolution, package, String(reason))
    end
end
semantic_view(x::LegacyMigrationResultV4) = (resolution=x.resolution, package=x.package, reason=x.reason)
migrate_legacy(record) = LegacyMigrationResultV4(terminal_deferred, nothing, "legacy mapping is not proven lossless")
