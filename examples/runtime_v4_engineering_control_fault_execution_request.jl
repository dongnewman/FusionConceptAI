include(joinpath(@__DIR__, "runtime_v4_conservative_multiregion_execution.jl"))
Base.include(ConservativeMultiRegionRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "EngineeringControlFaultExecutionRequestV4.jl"))
const ECF = ConservativeMultiRegionRuntime
const ecf_case = ECF.make_engineering_control_fault_case(cmr_context,
    "cmr-nominal-fault", (current=(0.0, 10.0),); delay_ms=1.0,
    dropout_probability=0.01, recovery_timeout_ms=50.0,
    fault_mode=:sensor_dropout)
const ecf_capability = first(cmr_context.obligations)
const ecf_obligation = ECF.make_engineering_control_fault_obligation(cmr_context,
    "control-loop", :control, :manufactured_control, :control)
const ecf_provider = ECF.ProviderManifestV4("external-control", "v1",
    ecf_capability.kind, ecf_capability, (backend=:external, subject=cmr_context.subject.physical_subject_hash),
    "external-controller", "v1", ECF.digest256_text("external-code"),
    "external-control", ECF.screen_only)
const ecf_request = ECF.make_engineering_control_fault_execution_request(
    cmr_context, ecf_case, (ecf_obligation,), (ecf_provider,))
