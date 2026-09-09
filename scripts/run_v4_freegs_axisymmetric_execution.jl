using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_freegs_axisymmetric_execution.jl"))

const F = FreeGSAxisymmetricRuntime
const output_directory = abspath(joinpath(@__DIR__, "..", "runs",
    "runtime_v4_freegs_axisymmetric_current_fixture_v1"))
const artifacts = F.execute_freegs_axisymmetric_screen(freegs_context;
    artifact_directory=output_directory)
const receipt = artifacts.receipt
F.validate_freegs_axisymmetric_receipt(freegs_context, receipt)

println("status=", receipt.status)
println("exit_code=", receipt.exit_code)
println("freegs_version=", receipt.freegs_version)
println("context_hash=", receipt.context_hash)
println("binding_hash=", receipt.binding_hash)
println("runner_code_hash=", receipt.runner_code_hash)
println("environment_hash=", receipt.environment_hash)
println("input_hash=", receipt.input_hash)
println("output_hash=", receipt.output_hash)
println("receipt_hash=", receipt.receipt_hash)
println("claim_ceiling=", receipt.claim_ceiling)
println("physical_validation=", receipt.physical_validation)
println("engineering_validation=", receipt.engineering_validation)
println("p5_ready=", receipt.p5_ready)
println("artifact_directory=", output_directory)
if receipt.summary !== nothing
    println("iterations=", receipt.summary.iterations)
    println("final_relative_change=", receipt.summary.final_relative_change)
    println("plasma_residual_l2_relative=", receipt.summary.plasma_residual_l2_relative)
    println("magnetic_axis_r_m=", receipt.summary.magnetic_axis_r_m)
    println("magnetic_axis_z_m=", receipt.summary.magnetic_axis_z_m)
    println("plasma_current_a=", receipt.summary.plasma_current_a)
    println("plasma_volume_m3=", receipt.summary.plasma_volume_m3)
    println("q_95=", receipt.summary.q_95)
    println("beta_n=", receipt.summary.beta_n)
else
    println("gap_kind=", receipt.gap_kind)
    println("reason=", receipt.reason)
end

exit(receipt.status === :physical_model_screen ? 0 : 2)
