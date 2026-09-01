module FusionConceptAI

using SHA

include("IR/PhysicalTypes.jl")
include("IR/TypedAST.jl")
include("IR/OperatorHypergraph.jl")
include("Contracts/StatusDimensions.jl")
include("Contracts/GenomeContractRegistry.jl")
include("Genomes/MechanismGenome.jl")
include("Genomes/FieldGeometryGenome.jl")
include("Genomes/RealizationControlGenome.jl")
include("Canonical/CanonicalJSON.jl")
include("Canonical/Hashes.jl")
include("Contracts/CandidateStatePackage.jl")
include("IR/ConditionalEGraph.jl")
include("Contracts/Authority.jl")

export UnitSignature, Digest256, digest256_text, PhysicalType, ApplicabilityStatus, MatchStatus, ResolutionStatus,
       LifecycleStatus, StageOutcome, TerminalDisposition, ClaimCeiling, ApplicabilityRecord, EvidenceRef, MetricWithUnit,
       required, not_applicable, unique_match, no_match, ambiguous, out_of_domain, invalid_signature,
       resolved, terminal_deferred, proposed, compiled, proof_pruned, dormant, materialized,
       low_fidelity_evaluated, frontier_admitted, high_fidelity_pending, integrated_executed,
       terminal_classified, pass, physical_fail, numerical_fail, unknown, not_applicable_stage,
       terminal_deferred_stage, credible_within_scope, terminal_physical_fail, terminal_numerical_fail,
       terminal_unknown, terminal_unsupported, none, screen_only, candidate_bound, integrated, whole_device_vvuq, validation_vvuq,
       semantic_view,
       CanonicalizationDeferred,
       TypedASTNode, TypedAST, ast_leaf, TypedNode, TypedHyperedge, TypedOperatorHypergraphV1, node,
       MechanismGenomeV4, FieldGeometryGenomeV4, RealizationControlGenomeV4,
       GenomeContractRef, GenomeContractRegistryV4, StatusVectorV4,
       resolve_contract,
       MissionContractRef, ProposalEnvelopeV4, UncertaintyV4, EvidenceContentV4, EvidenceEnvelopeV4, evidence_envelope, evidence_id_for, CanonicalHashesV4, CandidateStatePackageV4,
       LegacyMigrationResultV4, migrate_legacy,
       derive_conditional_egraph, canonical_json, canonical_hash, mechanism_hash,
       field_geometry_hash, realization_control_hash, realization_hash, control_hash, coupled_realization_control_hash, genome_bundle_hash,
       AuthorityProtocolV4, IntermediateAuthorityProtocolV4, DerivedEGraphViewV4

end
