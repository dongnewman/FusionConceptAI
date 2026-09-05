module FusionRuntimeV4

using FusionConceptAI

include("Contracts.jl")
include("Compiler.jl")
include("Capability.jl")
include("Execution.jl")
include("AlgebraicResidual.jl")
include("DeterministicScreenProvider.jl")
include("RuntimePipeline.jl")
include("Frontier.jl")
include("WholeDevice.jl")
include("Authority.jl")
include("Campaign.jl")

export MinimalityScopeV4, CapabilitySignatureV4, ProviderManifestV4,
       CompiledCandidatePrefixV4, ProviderMatchResultV4,
       ExecutablePhysicalSubjectV4, SolverInputV4, RuntimeEvidenceV4,
       compile_candidate, derive_capability_obligations, match_provider,
       materialize, compile_solver_input, execute_once!,
       StateValueV4, AlgebraicScenarioV4,
       AlgebraicResidualCompilationV4, AlgebraicResidualPlanV4,
       AlgebraicResidualResultV4, AlgebraicSliceReportV4,
       compile_algebraic_residual_plan, evaluate_algebraic_residual,
       solve_algebraic_residual, algebraic_residual_manifest,
       execute_algebraic_once!,
       deterministic_screen_execute, deterministic_screen_manifest,
       deterministic_screen_provider, screen_capability, screen_execution_count,
       reset_screen_execution_count!, VerticalSliceReportV4,
       run_v4_vertical_slice, vertical_slice_manifest,
       AbstractStageRequirementV4, ExactCapabilityRequirementV4,
       UnresolvedStageDeclarationV4, StageSpecV4, StageDecisionV4,
       derive_stage_gaps, derive_provider_gaps,
       StageEvidenceBindingV4, admit_frontier,
       close_frontier, WholeDeviceClosureV4, admit_whole_device,
       audit_whole_device, AuthorityClassificationV4, classify_authority,
       FrozenCampaignV4, SpineReportV4, freeze_campaign, default_stage_specs, run_v4_spine

end
