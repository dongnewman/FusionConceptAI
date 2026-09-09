"""Trusted registry dispatch of the committed candidate-bound FreeGS screen."""

using FusionConceptAI

include(joinpath(@__DIR__, "runtime_v4_freegs_axisymmetric_execution.jl"))

const TrustedFreeGSRuntime = FreeGSAxisymmetricRuntime
Base.include(TrustedFreeGSRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "Capability.jl"))
Base.include(TrustedFreeGSRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "TrustedProviderRegistryV4.jl"))
Base.include(TrustedFreeGSRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4",
        "TrustedFreeGSAxisymmetricProviderV4.jl"))

const trusted_freegs_repository_root = normpath(abspath(joinpath(@__DIR__, "..")))
const trusted_freegs_empty_registry =
    TrustedFreeGSRuntime.bootstrap_trusted_provider_registry(
        Val(:trusted_repository_with_freegs_bootstrap),
        trusted_freegs_repository_root)
const trusted_freegs_capability =
    TrustedFreeGSRuntime.trusted_freegs_axisymmetric_capability(freegs_context)
const trusted_freegs_manifest =
    TrustedFreeGSRuntime.make_repository_owned_provider_manifest(
        trusted_freegs_empty_registry, freegs_context,
        TrustedFreeGSRuntime._TPR_FREEGS_PROVIDER, trusted_freegs_capability;
        model_class=TrustedFreeGSRuntime._TPR_FREEGS_MODEL_CLASS)
const trusted_freegs_registry = TrustedFreeGSRuntime.register_trusted_provider(
    trusted_freegs_empty_registry, freegs_context,
    TrustedFreeGSRuntime._TPR_FREEGS_PROVIDER, trusted_freegs_capability,
    trusted_freegs_manifest)
const trusted_freegs_input =
    TrustedFreeGSRuntime.make_trusted_freegs_axisymmetric_input(
        freegs_context, trusted_freegs_capability)
const trusted_freegs_request =
    TrustedFreeGSRuntime.build_trusted_provider_dispatch_request(
        trusted_freegs_registry, freegs_context, trusted_freegs_capability,
        trusted_freegs_input)
const trusted_freegs_receipt = TrustedFreeGSRuntime.execute_trusted_provider(
    trusted_freegs_registry, freegs_context, trusted_freegs_request)

if abspath(PROGRAM_FILE) == @__FILE__
    output = trusted_freegs_receipt.output
    freegs_receipt = output.freegs_receipt
    println("descriptors=", length(trusted_freegs_registry.descriptors))
    println("registrations=", length(trusted_freegs_registry.registrations))
    println("request_status=", trusted_freegs_request.status)
    println("trusted_status=", trusted_freegs_receipt.status)
    println("freegs_status=", freegs_receipt.status)
    println("exit_code=", trusted_freegs_receipt.exit_code)
    println("freegs_version=", freegs_receipt.freegs_version)
    println("binding_hash=", freegs_receipt.binding_hash)
    println("freegs_output_hash=", output.freegs_output_hash)
    println("freegs_receipt_hash=", output.freegs_receipt_hash)
    println("trusted_receipt_hash=", trusted_freegs_receipt.receipt_hash)
    println("claim_ceiling=", freegs_receipt.claim_ceiling)
    println("physical_validation=", freegs_receipt.physical_validation)
    println("engineering_validation=", freegs_receipt.engineering_validation)
    println("p5_ready=", freegs_receipt.p5_ready)
    println("terminal_authority=", freegs_receipt.terminal_authority)
end
