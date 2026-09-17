include(joinpath(@__DIR__, "..", "examples", "runtime_v4_physical_provider_admission.jl"))
using Test
@test ppa_admission.status in (:admitted, :recoverable)
@test PPA.validate_physical_provider_admission(ppa_admission, cmr_context, cmr_contract, ppa_provider)
@test !PPA.validate_physical_provider_admission(ppa_admission)
@test PPA.admit_physical_provider(cmr_context, cmr_contract,
    PPA.ProviderManifestV4("manufactured", "v1", cmr_contract.capability.kind,
        cmr_contract.capability, (backend=:manufactured,), "fixture", "v1",
        PPA.digest256_text("fixture"), "manufactured-control", PPA.screen_only)).status === :recoverable_gap
@test_throws ArgumentError PPA.admit_physical_provider(cmr_context, cmr_contract,
    PPA.ProviderManifestV4("foreign", "v1", cmr_contract.capability.kind,
        cmr_contract.capability, (backend=:external,), "external", "v1",
        PPA.digest256_text("x"), "external-physical", PPA.screen_only;
        input_schema_hash=PPA.digest256_text("wrong")))
println("PHYSICAL_PROVIDER_ADMISSION_FOCUSED_EXIT_CODE=0")
