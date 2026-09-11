include(joinpath(@__DIR__, "..", "examples", "runtime_v4_trusted_engineering_control_fault_provider.jl"))
using SHA
expected_context=Digest256(ARGS[1]); expected_request=Digest256(ARGS[2]); expected_receipt=Digest256(ARGS[3]); expected_nonbridge=Digest256(ARGS[4])
if !isdefined(TECFE, :_ECF_VUQ_BRIDGE_REVISION)
    Base.include(TECFE, joinpath(@__DIR__, "..", "src", "RuntimeV4", "EngineeringControlFaultValidationUQBridgeV4.jl"))
end
bridge=TECFE.build_engineering_control_fault_vuq_bridge(tecfe_registry,ecfgo_context,
    tecfe_request,tecfe_receipt)
bridge.bridge_hash == expected_nonbridge || error("fresh ECF nonbridge identity mismatch")
TECFE.validate_trusted_engineering_control_fault_registry(tecfe_registry)
TECFE.validate_trusted_engineering_control_fault_dispatch_request(tecfe_request,tecfe_registry,ecfgo_context)
TECFE.validate_trusted_engineering_control_fault_operational_receipt(tecfe_receipt,tecfe_request,tecfe_registry,ecfgo_context)
TECFE.validate_engineering_control_fault_vuq_bridge(tecfe_registry,ecfgo_context,tecfe_request,tecfe_receipt,bridge)
tecfe_receipt.context_hash == expected_context && tecfe_request.request_hash == expected_request &&
    tecfe_receipt.receipt_hash == expected_receipt || error("fresh ECF identity mismatch")
r=tecfe_receipt.result
ex=abspath(String(Base.julia_cmd().exec[1])); root=normpath(abspath(joinpath(@__DIR__,"..")))
sha(p)=bytes2hex(SHA.sha256(read(p)))
pm=bytes2hex(SHA.sha256(vcat(read(joinpath(root,"Project.toml")),read(joinpath(root,"Manifest.toml")))))
println("ECF_NUMERICAL_REPEATABILITY_V1|pid=$(getpid())|julia=$(ex)|julia_sha=$(sha(ex))|julia_version=$(VERSION)|project_manifest=$(pm)|child_source=$(sha(abspath(@__FILE__)))|context=$(tecfe_receipt.context_hash)|request=$(tecfe_request.request_hash)|receipt=$(tecfe_receipt.receipt_hash)|result=$(tecfe_receipt.result_hash)|trace=$(r.trace_hash)|samples=$(r.sample_count)|releases=$(r.transport_release_count)|dropouts=$(r.scheduled_dropout_sample_count)|faults=$(r.declared_fault_sample_count)|violations=$(r.actuator_bound_violation_count)")
