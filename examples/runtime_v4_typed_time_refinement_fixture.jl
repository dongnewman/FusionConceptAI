using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "TypedTimeResidual.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "TypedTimeRefinement.jl"))
include(joinpath(@__DIR__, "runtime_v4_typed_time_fixture.jl"))
const TimeRefinementProtocolV4 = FusionRuntimeV4.TimeRefinementProtocolV4
const TimeRefinementReceiptV4 = FusionRuntimeV4.TimeRefinementReceiptV4
const run_typed_time_refinement = FusionRuntimeV4.run_typed_time_refinement
const tref_protocol = TimeRefinementProtocolV4(0.2, (40, 80, 160))
const tref_receipt = run_typed_time_refinement(ttr_plan, ttr_scenario, tref_protocol)
