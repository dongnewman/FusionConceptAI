include(joinpath(@__DIR__, "runtime_v4_conservative_multiregion_execution.jl"))
Base.include(ConservativeMultiRegionRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "PhysicalProviderAdmissionV4.jl"))
const PPA = ConservativeMultiRegionRuntime
const ppa_provider = PPA.ProviderManifestV4("external-physical", "v1",
    cmr_contract.capability.kind, cmr_contract.capability,
    (backend=:external_physics, physical=true), "external-solver", "solver-v1",
    PPA.digest256_text("external-solver-code"), "external-physical",
    PPA.screen_only)
const ppa_admission = PPA.admit_physical_provider(cmr_context, cmr_contract, ppa_provider)
