"""Repository-owned operational execution of the manufactured ECF contract."""

include(joinpath(@__DIR__, "runtime_v4_engineering_control_fault_graph_obligation.jl"))

const TrustedEngineeringControlFaultRuntime = ECFGO
Base.include(TrustedEngineeringControlFaultRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "TrustedProviderRegistryV4.jl"))
Base.include(TrustedEngineeringControlFaultRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4",
        "TrustedEngineeringControlFaultProviderV4.jl"))

const TECFE = TrustedEngineeringControlFaultRuntime
const tecfe_repository_root = normpath(abspath(joinpath(@__DIR__, "..")))
const tecfe_base_registry = TECFE.bootstrap_trusted_provider_registry(
    Val(:trusted_repository_with_engineering_control_fault_bootstrap),
    tecfe_repository_root)
const tecfe_registry =
    TECFE.register_trusted_engineering_control_fault_provider(
        tecfe_base_registry, ecfgo_context)
const tecfe_request =
    TECFE.build_trusted_engineering_control_fault_dispatch_request(
        tecfe_registry, ecfgo_context)
const tecfe_receipt =
    TECFE.execute_trusted_engineering_control_fault_provider(
        tecfe_registry, ecfgo_context, tecfe_request)

if abspath(PROGRAM_FILE) == @__FILE__
    result = tecfe_receipt.result
    dropout_window = filter(step -> step.dropout_window_active, result.trace)
    println("provider_id=", TECFE._TPR_ENGINEERING_CONTROL_FAULT_PROVIDER)
    println("descriptors=", length(tecfe_base_registry.descriptors))
    println("registration_input_hash=", tecfe_registry.registration.input_hash)
    println("request_status=", tecfe_request.status)
    println("receipt_status=", tecfe_receipt.status)
    println("sample_count=", result.sample_count)
    println("transport_releases=", result.transport_release_count)
    println("dropout_samples=", result.scheduled_dropout_sample_count)
    println("dropout_window_draws=",
        Tuple(step.dropout_draw for step in dropout_window))
    println("dropout_window_decisions=",
        Tuple(step.scheduled_dropout_active for step in dropout_window))
    println("fault_samples=", result.declared_fault_sample_count)
    println("actuator_bound_violations=", result.actuator_bound_violation_count)
    println("trace_hash=", result.trace_hash)
    println("receipt_hash=", tecfe_receipt.receipt_hash)
    println("claim_ceiling=", tecfe_receipt.claim_ceiling)
    println("credible_device_count=", tecfe_receipt.credible_device_count)
    println("emits_evidence=", tecfe_receipt.emits_evidence)
    println("terminal_authority=", tecfe_receipt.terminal_authority)
end
