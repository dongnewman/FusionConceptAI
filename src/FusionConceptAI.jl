module FusionConceptAI

using SHA

include("IR/PhysicalTypes.jl")
include("Canonical/ClosedCanonicalByteWriter.jl")
include("IR/ConservationLedger.jl")
include("IR/OperatorRegistry.jl")
include("IR/TypedAST.jl")
include("IR/OperatorHypergraph.jl")
include("Genomes/MechanismGenes.jl")
include("Contracts/StatusDimensions.jl")
include("Contracts/GenomeContractRegistry.jl")
include("Genomes/MechanismGenesV1.jl")
include("Genomes/FieldGeometryPrimitives.jl")
include("Genomes/FieldGeometrySpatialSupport.jl")
include("Genomes/FieldGeometryFieldPrograms.jl")
include("Genomes/FieldGeometryPhaseFields.jl")
include("Genomes/FieldGeometryGenome.jl")
include("Genomes/RealizationControlGenome.jl")
include("Canonical/CanonicalJSON.jl")
canonical_json(x::TypedASTProgramV1) = invoke(_typed_ast_program_json, Tuple{TypedASTProgramV1}, x)
include("Canonical/ExactGraphCanonicalization.jl")
include("Canonical/TypedASTProgramCanonical.jl")
include("Genomes/MechanismGeneCanonical.jl")
include("Canonical/FieldGeometryPrimitiveCanonical.jl")
include("Canonical/FieldGeometrySpatialSupportCanonical.jl")
include("Canonical/FieldGeometryFieldProgramCanonical.jl")
include("Canonical/FieldGeometryPhaseFieldCanonical.jl")
include("Genomes/MechanismObservablesHoles.jl")
include("Canonical/MechanismObservableCanonical.jl")
include("Genomes/ControlPrimitives.jl")
include("Genomes/ControlObservationRequirements.jl")
include("Canonical/ControlObservationRequirementCanonical.jl")
include("Genomes/MechanismGenomePayload.jl")
include("Canonical/MechanismCanonicalTransport.jl")
include("Canonical/MechanismHashLayers.jl")
include("Genomes/MechanismGenome.jl")
include("Canonical/Hashes.jl")
include("Genomes/MechanismLegacyMigration.jl")
include("Contracts/CandidateStatePackage.jl")
include("IR/ConditionalEGraph.jl")
include("IR/ConditionalEGraphTypes.jl")
include("Canonical/ConditionalEGraphCanonical.jl")
include("IR/ConditionalEGraphSaturation.jl")
include("Contracts/Authority.jl")

export UnitSignature, Digest256, digest256_text, TimeKindV1, static_time, algebraic_time, differential_time, discrete_time, event_time,
       TemporalTypeV1, QualifiedRefV1, PhysicalType, ApplicabilityStatus, MatchStatus, ResolutionStatus,
       LifecycleStatus, StageOutcome, TerminalDisposition, ClaimCeiling, ApplicabilityRecord, EvidenceRef, MetricWithUnit,
       required, not_applicable, unique_match, no_match, ambiguous, out_of_domain, invalid_signature,
       resolved, terminal_deferred, proposed, compiled, proof_pruned, dormant, materialized,
       low_fidelity_evaluated, frontier_admitted, high_fidelity_pending, integrated_executed,
       terminal_classified, pass, physical_fail, numerical_fail, unknown, not_applicable_stage,
       terminal_deferred_stage, credible_within_scope, terminal_physical_fail, terminal_numerical_fail,
       terminal_unknown, terminal_unsupported, none, screen_only, candidate_bound, integrated, whole_device_vvuq, validation_vvuq,
       semantic_view, is_canonical_value,
       CanonicalizationDeferred, CanonicalizationBudgetV1, CanonicalizationProfileV1, default_canonicalization_profile,
       TypedASTNode, TypedAST, ast_leaf, AbstractTypedASTNodeV1, ASTInputV1, ASTParameterV1, ASTConstantV1,
       ASTApplyV1, TypedASTProgramV1, typed_ast_program, TypedNode, TypedHyperedge, HyperedgeRoleV1,
       MIMOInputBindingV1, MIMOOutputBindingV1, ConservationLedgerIdentityV1, ConservationAccountRefV1, PortAccountEffectV1,
       InterfaceFluxPairV1, AtomicMIMOHyperedgeV1, TypedOperatorHypergraphV1, node,
       governing, additive, constraint, interface, boundary, source, sink, control, event,
       OperatorRefV1, OperatorParameterSpecV1, OperatorTypeRuleV1, ExactTypeRuleV1, SameTypeVariadicRuleV1,
       ScalarProductRuleV1, DotProductRuleV1, TensorProductRuleV1, ContractRuleV1,
       SpatialDerivativeRuleV1, TimeDerivativeRuleV1, SamplingRuleV1, DelayRuleV1,
       EventTransitionRuleV1,
       OperatorManifestV1, OperatorRegistryV1, register_operator, operator_manifest, validate_operator_signature,
       default_operator_registry,
       StateGeneRefV1, InvariantRefV1, ParameterRefV1, SymmetryRefV1, ObservableRefV1, OperatorSiteRefV1,
       ConstraintRefV1, HoleRefV1, ExactFiniteIntervalV1, QuantityIntervalV1, NonnegativeQuantityV1,
       ExactRationalMatrixV1, StateEpistemicV1, ParitySignV1, InvariantScopeV1, EntropyDirectionV1,
       ParameterTransformKindV1, SymmetryGroupKindV1, SymmetryBehaviorV1, ConservationEffectKindV1,
       state_derived, state_measured, state_declared_known, state_hypothesized, state_learned,
       state_empirical_prior, state_unknown_placeholder, state_not_applicable, even, odd,
       scope_global, scope_domain, scope_interface, entropy_not_applicable, entropy_nondecreasing,
       entropy_nonincreasing, entropy_conserved, transform_linear, transform_log, transform_signed_log,
       symmetry_discrete, symmetry_continuous, symmetry_invariant, symmetry_equivariant,
       redistribution, interface_flux, net_creation, net_destruction, ParityActionV1,
       StateGeneV1, InvariantTermV1, InvariantV1, ParameterTransformSpecV1, ParameterGeneV1,
       StateSymmetryActionV1, SymmetryGeneV1, derive_parameter_value, parameter_value,
       SpatialSupportRefV1, ChartRefV1, CoordinateFrameRefV1, PhaseFieldRefV1,
       ImplicitFieldTermRefV1, PotentialFieldRefV1, SourceFieldRefV1,
       InterfaceOperatorRefV1, GeometryEvolutionRefV1, FieldParameterRefV1,
       SourceBudgetRefV1, TopologyEventRefV1, SpatialMultiIndex3V1,
       ExactSpatialVector3V1, FieldParameterGeneV1, derive_field_parameter_value,
       field_parameter_value,
       FieldOperatorSiteRefV1, SpatialProgramRootRefV1, PeriodicAxisV1,
       CoordinateChartGeneV1, ChartTransitionMapGeneV1, SpatialSupportGeneV1,
       chart_coordinate_type_v1, normalized_ambient_coordinate_type_v1,
       normalized_covariant_metric_type_v1, chart_count,
       ObservationChannelRefV1, ObservationChannelRequirementV1,
       FieldProgramParameterBindingV1, TypedFieldProgramGeneV1,
       PhaseFieldDeclarationV1, PhaseFieldSetGeneV1, phase_logit_type_v1,
       ProgramRootRefV1, ObservableGeneV1, HoleComplexityBudgetV1, IdentifiabilityConditionV1,
       TypedOperatorHoleV1, MechanismGenomePayloadV1,
       MechanismCanonicalizationContextV1, CanonicalMechanismTransportV1,
       canonicalize_mechanism_transport, canonical_mechanism_transport_json,
       MechanismHashLayersV1, CanonicalMechanismV1, mechanism_hash_layers, canonicalize_mechanism,
       G1LegacyEdgeCompletionV1, G1LegacyMigrationDeclarationV1, G1LegacyMigrationReasonV1,
       migration_lossless, missing_mapping_resource, mapping_not_applicable, contract_incompatible,
       legacy_ast_unrepresentable, legacy_gene_semantics_unrepresentable, legacy_edge_completion_missing,
       canonicalization_budget_exhausted, G1LegacyMigrationResultV1, migrate_legacy_g1,
       LegacyMechanismGenomeV4, MechanismGenomeV4, FieldGeometryGenomeV4, RealizationControlGenomeV4,
       GenomeContractRef, GenomeContractRegistryV4, StatusVectorV4,
       resolve_contract,
       MissionContractRef, ProposalEnvelopeV4, UncertaintyV4, EvidenceContentV4, EvidenceEnvelopeV4, evidence_envelope, evidence_id_for, CanonicalHashesV4, CandidateStatePackageV4,
       LegacyMigrationResultV4, migrate_legacy,
       derive_conditional_egraph, canonical_json, canonical_hash, mechanism_hash, mechanism_subject_hash,
       field_geometry_hash, realization_control_hash, realization_hash, control_hash, coupled_realization_control_hash, genome_bundle_hash,
       AuthorityProtocolV4, IntermediateAuthorityProtocolV4, DerivedEGraphViewV4,
       EqualityConditionRequirementV1, WholeProgramConditionalRewriteV1, ConditionalRewriteSetV1,
       ConditionalEGraphBudgetV1, RewriteOrientationV1, rewrite_forward, rewrite_reverse,
       ConditionalEGraphStopReasonV1, conditional_fixed_point, conditional_budget_programs,
       conditional_budget_rewrite_attempts, conditional_budget_rounds, conditional_budget_trace_steps,
       ConditionalRewriteTraceStepV1, ConditionalProgramENodeV1, ConditionalEClassV1,
       ConditionalEGraphUsageV1, ConditionalEqualityProvenanceV1, ConditionalEqualityStatusV1,
       reflexive_equal, conditional_equal, equality_unknown, ConditionalEqualityQueryResultV1,
       DerivedConditionalEGraphV1, ConditionalEGraphDerivationResultV1,
       ConditionalEGraphSaturationStateV1, saturation_complete, saturation_incomplete,
       ConditionalEGraphDerivationReasonV1, conditional_egraph_derived, saturation_budget_exhausted,
       manifest_or_contract_incompatible, source_out_of_profile, exact_canonicalization_deferred,
       derive_conditional_program_egraph, query_conditional_equality, replay_conditional_rewrite_trace,
       conditional_equivalence_hash, saturation_attempt_hash

end
