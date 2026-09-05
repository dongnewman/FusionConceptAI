module FusionRuntimeV4

using FusionConceptAI

include("Contracts.jl")
include("Compiler.jl")
include("Capability.jl")
include("Execution.jl")
include("DeterministicScreenProvider.jl")
include("RuntimePipeline.jl")

export MinimalityScopeV4, CapabilitySignatureV4, ProviderManifestV4,
       CompiledCandidatePrefixV4, ProviderMatchResultV4,
       ExecutablePhysicalSubjectV4, SolverInputV4, RuntimeEvidenceV4,
       compile_candidate, derive_capability_obligations, match_provider,
       materialize, compile_solver_input, execute_once!,
       deterministic_screen_execute, deterministic_screen_manifest,
       deterministic_screen_provider, screen_capability, screen_execution_count,
       reset_screen_execution_count!, VerticalSliceReportV4,
       run_v4_vertical_slice, vertical_slice_manifest

end
