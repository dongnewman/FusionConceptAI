"""Immutable v4 candidate, proposal, and evidence contracts."""

struct MissionContractRef
    uri::String
    version::String
    schema_hash::String
    canonicalization_hash::String
    function MissionContractRef(uri::AbstractString, version::AbstractString, schema_hash::AbstractString, canonicalization_hash::AbstractString)
        all(!isempty, (uri, version, schema_hash, canonicalization_hash)) || throw(ArgumentError("incomplete MissionContractRef"))
        new(String(uri), String(version), String(schema_hash), String(canonicalization_hash))
    end
end
semantic_view(x::MissionContractRef) = (uri=x.uri, version=x.version, schema_hash=x.schema_hash, canonicalization_hash=x.canonicalization_hash)
Base.:(==)(a::MissionContractRef, b::MissionContractRef) = semantic_view(a) == semantic_view(b)

function _deep_immutable(x)
    (x === nothing || x isa Bool || x isa Number || x isa Symbol || x isa AbstractString) && return true
    (x isa AbstractArray || x isa AbstractDict || x isa AbstractSet) && return false
    x isa NamedTuple && return all(_deep_immutable, values(x))
    x isa Tuple && return all(_deep_immutable, x)
    isstructtype(typeof(x)) && return all(_deep_immutable, (getfield(x, f) for f in fieldnames(typeof(x))))
    false
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
    model_or_rule_hash::String
    requested_next_stage::Symbol
    function ProposalEnvelopeV4(id::AbstractString, candidate::AbstractString, parents, channel::Symbol,
                                edits, cell::AbstractString, predicted::NamedTuple, uncertainty::NamedTuple,
                                cost::Real, model_hash::AbstractString, next_stage::Symbol)
        all(!isempty, (id, candidate, model_hash)) || throw(ArgumentError("proposal references cannot be empty"))
        isfinite(cost) && cost >= 0 || throw(ArgumentError("estimated_cost must be finite and non-negative"))
        vals = (Tuple(String(p) for p in parents), Tuple(edits), predicted, uncertainty)
        all(_deep_immutable, vals) || throw(ArgumentError("ProposalEnvelopeV4 must be deeply immutable"))
        new(String(id), String(candidate), vals[1], channel, vals[2], String(cell), predicted, uncertainty,
            Float64(cost), String(model_hash), next_stage)
    end
end
semantic_view(x::ProposalEnvelopeV4) = (proposal_id=x.proposal_id, candidate_or_prefix_ref=x.candidate_or_prefix_ref,
                                         parent_refs=x.parent_refs, search_channel=x.search_channel,
                                         typed_edit_trace=x.typed_edit_trace, target_behavior_cell=x.target_behavior_cell,
                                         predicted_outcomes=x.predicted_outcomes, uncertainty=x.uncertainty,
                                         estimated_cost=x.estimated_cost, model_or_rule_hash=x.model_or_rule_hash,
                                         requested_next_stage=x.requested_next_stage)

function _evidence_content(; physical_subject_hash, scenario_hash, solver_input_hash, provider_manifest_hash,
                            backend_revision, numerical_configuration_hash, applicability, match_status,
                            resolution_status, stage_outcome, metrics_with_units, uncertainty_or_null,
                            artifact_refs, independence_group, claim_ceiling)
    (physical_subject_hash=String(physical_subject_hash), scenario_hash=String(scenario_hash),
     solver_input_hash=String(solver_input_hash), provider_manifest_hash=String(provider_manifest_hash),
     backend_revision=String(backend_revision), numerical_configuration_hash=String(numerical_configuration_hash),
     applicability=applicability, match_status=match_status, resolution_status=resolution_status,
     stage_outcome=stage_outcome, metrics_with_units=metrics_with_units, uncertainty_or_null=uncertainty_or_null,
     artifact_refs=Tuple(String(a) for a in artifact_refs), independence_group=String(independence_group), claim_ceiling=claim_ceiling)
end

evidence_id_for(content::NamedTuple) = canonical_hash(content)

struct EvidenceEnvelopeV4
    evidence_id::String
    content::NamedTuple
    function EvidenceEnvelopeV4(seal::Val{:trusted_evidence}, id::String, content::NamedTuple)
        id == evidence_id_for(content) || throw(ArgumentError("evidence_id must content-address the evidence"))
        new(id, content)
    end
end
semantic_view(x::EvidenceEnvelopeV4) = x.content

function evidence_envelope(; physical_subject_hash, scenario_hash, solver_input_hash, provider_manifest_hash,
                           backend_revision, numerical_configuration_hash, applicability::ApplicabilityStatus,
                           match_status::MatchStatus, resolution_status::ResolutionStatus, stage_outcome::StageOutcome,
                           metrics_with_units::Tuple{Vararg{MetricWithUnit}}=(), uncertainty_or_null=nothing,
                           artifact_refs=(), independence_group="", claim_ceiling::ClaimCeiling=screen_only)
    all(!isempty, (physical_subject_hash, scenario_hash, solver_input_hash, provider_manifest_hash,
                   backend_revision, numerical_configuration_hash)) || throw(ArgumentError("evidence hashes cannot be empty"))
    uncertainty_or_null === nothing || uncertainty_or_null isa NamedTuple || throw(ArgumentError("uncertainty must be NamedTuple or nothing"))
    _deep_immutable(uncertainty_or_null) || throw(ArgumentError("uncertainty must be immutable"))
    content = _evidence_content(; physical_subject_hash, scenario_hash, solver_input_hash, provider_manifest_hash,
                                 backend_revision, numerical_configuration_hash, applicability, match_status,
                                 resolution_status, stage_outcome, metrics_with_units, uncertainty_or_null,
                                 artifact_refs, independence_group, claim_ceiling)
    EvidenceEnvelopeV4(Val(:trusted_evidence), evidence_id_for(content), content)
end

struct CanonicalHashesV4
    mechanism_hash::String
    field_geometry_hash::String
    realization_control_hash::String
    genome_bundle_hash::String
    physical_subject_hash::Union{Nothing,String}
    solver_input_hashes::Tuple{Vararg{String}}
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
    terminal_authority_ref::Union{Nothing,String}
    claim_ceiling::ClaimCeiling
end

function CandidateStatePackageV4(identity::AbstractString, mission::MissionContractRef,
                                 mechanism::MechanismGenomeV4, field::FieldGeometryGenomeV4,
                                 realization::RealizationControlGenomeV4, registry::GenomeContractRegistryV4;
                                 lifecycle::LifecycleStatus=proposed, applicability_records=(), compilation_records=(),
                                 proposal_lineage=(), stage_evidence_refs=(), archive_memberships=(), claim_ceiling::ClaimCeiling=none)
    matched = resolve_contract(registry, mechanism.contract_ref, :mechanism) &&
              resolve_contract(registry, field.contract_ref, :field_geometry) &&
              resolve_contract(registry, realization.contract_ref, :realization_control)
    hashes = CanonicalHashesV4(mechanism_hash(mechanism), field_geometry_hash(field), realization_control_hash(realization),
                               genome_bundle_hash(mechanism, field, realization; mission_contract=mission), nothing, ())
    CandidateStatePackageV4(String(identity), mission, mechanism, field, realization, hashes,
                            matched ? resolved : terminal_deferred, lifecycle, Tuple(applicability_records), Tuple(compilation_records),
                            Tuple(proposal_lineage), Tuple(stage_evidence_refs), Tuple(String(a) for a in archive_memberships), nothing, claim_ceiling)
end

semantic_view(x::CandidateStatePackageV4) = (mission_contract_ref=x.mission_contract_ref,
    mechanism_genome_ref=x.mechanism_genome_ref, field_geometry_genome_ref=x.field_geometry_genome_ref,
    realization_control_genome_ref=x.realization_control_genome_ref, canonical_hashes=x.canonical_hashes,
    resolution=x.resolution, lifecycle=x.lifecycle, applicability_records=x.applicability_records,
    compilation_records=x.compilation_records, proposal_lineage=x.proposal_lineage, stage_evidence_refs=x.stage_evidence_refs,
    archive_memberships=x.archive_memberships, terminal_authority_ref=x.terminal_authority_ref, claim_ceiling=x.claim_ceiling)

struct LegacyMigrationResultV4
    resolution::ResolutionStatus
    package::Union{Nothing,CandidateStatePackageV4}
    reason::String
end
semantic_view(x::LegacyMigrationResultV4) = (resolution=x.resolution, package=x.package, reason=x.reason)

"""Legacy records are never guessed into v4; incomplete mappings remain deferred."""
function migrate_legacy(record)
    required = (:mission_contract_ref, :mechanism_genome_ref, :field_geometry_genome_ref, :realization_control_genome_ref)
    all(hasproperty(record, k) for k in required) || return LegacyMigrationResultV4(terminal_deferred, nothing, "legacy record lacks lossless v4 fields")
    throw(ArgumentError("legacy migration requires an explicit v4 registry and identity mapping"))
end

function with_physical_subject(pkg::CandidateStatePackageV4, physical_hash::AbstractString, solver_hashes=())
    isempty(physical_hash) && throw(ArgumentError("physical_subject_hash cannot be empty"))
    h = pkg.canonical_hashes
    newh = CanonicalHashesV4(h.mechanism_hash, h.field_geometry_hash, h.realization_control_hash,
                             h.genome_bundle_hash, String(physical_hash), Tuple(String(s) for s in solver_hashes))
    CandidateStatePackageV4(pkg.identity_ref, pkg.mission_contract_ref, pkg.mechanism_genome_ref,
                            pkg.field_geometry_genome_ref, pkg.realization_control_genome_ref, newh, pkg.resolution,
                            pkg.lifecycle, pkg.applicability_records, pkg.compilation_records, pkg.proposal_lineage,
                            pkg.stage_evidence_refs, pkg.archive_memberships, pkg.terminal_authority_ref, pkg.claim_ceiling)
end
