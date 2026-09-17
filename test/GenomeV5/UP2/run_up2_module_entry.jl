using Test
using FusionConceptAI

# Focused runners in this repository may manually include one UP2 definition
# before the shared entry. The entry must reuse that exact type identity.
const _UP2_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "UP2")
const _UP2_COUNTER_SOURCE = joinpath(_UP2_ROOT, "PrecompilerInvocationCounterV1.jl")
if !isdefined(FusionConceptAI, :UP2InvocationCounterV1)
    Base.include(FusionConceptAI, _UP2_COUNTER_SOURCE)
end
const _MANUAL_COUNTER_TYPE = FusionConceptAI.UP2InvocationCounterV1
@test isdefined(FusionConceptAI, :UP2InvocationCounterV1)

FusionConceptAI.load_genome_v5_up2_components!()
include(joinpath(@__DIR__, "up2_module_entry_tests.jl"))

@test FusionConceptAI.up2_module_load_state() == :loaded
@test FusionConceptAI.up2_module_dependency_order()[1:5] ==
    (:genome_v5_components, :precompiler_counter, :precompiler_contract,
     :precompiler_validator, :e0_bound_input)
FusionConceptAI.load_genome_v5_up2_components!()
@test FusionConceptAI.up2_module_load_state() == :loaded
@test FusionConceptAI.UP2InvocationCounterV1 === _MANUAL_COUNTER_TYPE

# Exercise the terminal failed state in a genuinely fresh Julia process. The
# probe is isolated from the already-loaded FusionConceptAI module above.
const _FAILURE_PROBE = joinpath(@__DIR__, "up2_module_entry_failure_probe.jl")
run(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) $_FAILURE_PROBE $(joinpath(_UP2_ROOT, "UP2ModuleEntryV1.jl"))`)
