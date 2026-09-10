# Real DESC execution for the already accepted dgpi candidate/context.
include(joinpath(@__DIR__, "runtime_v4_desc_geometry_compatibility_proof.jl"))
const DGRPE = DGCP
Base.include(DGRPE, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCRequestProviderExecutionV4.jl"))

const dgrpe_probe = DGRPE.probe_desc_environment()
const dgrpe_certificate = dgcp_certificate
const dgrpe_controls = DGRPE.DESCExecutionControlsV4(2,2,1,4,4,3,1,1e-3,1e-3,1e-3)
const dgrpe_request = DGRPE.make_desc_execution_request(dgpi_context,
    dgpi_bridge_resolution, dgpi_evaluation, dgcp_resolution, dgrpe_controls)
const dgrpe_run_dir = get(ENV, "DGRPE_RUN_DIR", joinpath(dirname(@__DIR__), "runs", "desc_request_provider_execution"))
const dgrpe_result = DGRPE.execute_desc_request_provider(dgpi_context,
    dgrpe_request, dgpi_bridge_resolution, dgpi_evaluation, dgcp_resolution,
    dgrpe_probe; run_dir=dgrpe_run_dir)
const dgrpe_receipt = something(dgrpe_result.receipt)

function run_desc_request_provider_execution_example(io::IO=stdout)
    println(io,"executable=",dgrpe_probe.executable)
    println(io,"provider_executable=",dgrpe_probe.provider_executable)
    println(io,"desc_version=",dgrpe_probe.desc_version)
    println(io,"candidate_hash=",dgrpe_result.candidate_hash)
    println(io,"compatibility_certificate_hash=",dgrpe_result.compatibility_certificate_hash)
    println(io,"request_hash=",dgrpe_result.request_hash)
    println(io,"input_path=",dgrpe_receipt.input_path)
    println(io,"output_path=",dgrpe_receipt.output_path)
    println(io,"provider_exit_code=",dgrpe_receipt.exit_code)
    println(io,"inspection_exit_code=",dgrpe_receipt.inspection_exit_code)
    println(io,"output_schema_validated=",dgrpe_receipt.output_schema_validated)
    println(io,"provider_executed=",dgrpe_result.provider_executed)
    println(io,"solver_executed=",dgrpe_result.solver_executed)
    println(io,"physical_validation=",dgrpe_result.physical_validation)
    println(io,"engineering_validation=",dgrpe_result.engineering_validation)
    println(io,"credible_physical_device_count=",dgrpe_result.credible_physical_device_count)
    println(io,"request_emitted=",dgrpe_result.request_emitted)
    println(io,"status=",dgrpe_result.status)
    println(io,"claim_ceiling=",dgrpe_result.claim_ceiling)
    println(io,"DESC_REQUEST_PROVIDER_EXECUTION_OK")
    dgrpe_result
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_desc_request_provider_execution_example()
end
