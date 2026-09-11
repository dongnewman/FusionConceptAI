"""Typed, zero-credit integration package for the dedicated G3 ECF run."""

include(joinpath(@__DIR__, "runtime_v4_trusted_engineering_control_fault_provider.jl"))
const ECFVUQ = TrustedEngineeringControlFaultRuntime
Base.include(ECFVUQ, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "EngineeringControlFaultValidationUQBridgeV4.jl"))
Base.include(ECFVUQ, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "WholeDeviceIntegrationV4.jl"))

const upstream_result_identity = ECFVUQ.UpstreamProviderResultIdentityV4(
    "engineering-control-fault", tecfe_request.request_hash,
    tecfe_receipt.result_hash;
    provider_executed=true, result_schema_validated=true)
const ecf_vuq_bridge = ECFVUQ.build_engineering_control_fault_vuq_bridge(
    tecfe_registry, ecfgo_context, tecfe_request, tecfe_receipt;
    upstream_result_identity=upstream_result_identity)
const whole_device_integration = ECFVUQ.make_whole_device_integration_request(
    ecfgo_context, tecfe_receipt, ecf_vuq_bridge;
    stage_ids=(:candidate_generation, :multi_region_coupling,
        :engineering_control_fault, :validation_uq, :whole_device))

if abspath(PROGRAM_FILE) == @__FILE__
    println("bridge_status=", ecf_vuq_bridge.status)
    println("bridge_reason=", ecf_vuq_bridge.reason)
    println("bridge_evidence_credit=", ecf_vuq_bridge.evidence_credit)
    println("whole_device_status=", whole_device_integration.status)
    println("whole_device_unresolved=", length(whole_device_integration.unresolved))
    println("whole_device_evidence_credit=", whole_device_integration.evidence_credit)
    println("WHOLE_DEVICE_INTEGRATION_EXIT_CODE=0")
end
