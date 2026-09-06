using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4
Base.include(FusionRuntimeV4,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "TypedDAEInitializationContracts.jl"))
Base.include(FusionRuntimeV4,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "TypedDAEInitialization.jl"))
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_typed_dae_initialization_fixture.jl"))

dae_plan = FusionRuntimeV4.compile_typed_dae_initialization_plan(
    tdae_compiled, tdae_registry;
    differential_refs=tdae_drefs, algebraic_refs=tdae_arefs,
    row_bindings=tdae_rows, scenario=dae_scenario)
dae_store = FusionRuntimeV4.TypedDAEInitializationStoreV4()
dae_report = FusionRuntimeV4.execute_once!(
    dae_store, dae_plan.input, dae_plan.provider, dae_plan)
result = dae_report.artifact
result === nothing && error("D2.1 fixture did not produce an artifact")
validated = FusionRuntimeV4.validate_typed_dae_initialization_report(dae_plan, dae_report)
execution_count = dae_store.execution_counts[dae_plan.input.solver_input_hash]

println("partition=", (differential=dae_plan.differential_refs,
    algebraic=dae_plan.algebraic_refs))
println("initial_values=", result.initial_values, " final_values=", result.final_values)
println("scaled_Md=", result.mass_matrix, " scaled_Jzz=", result.jacobian_zz)
println("scaled_initial_algebraic_residual=", result.initial_algebraic_residual,
    " scaled_final_algebraic_residual=", result.final_algebraic_residual)
println("initial_derivative=", result.initial_derivative,
    " scaled_mass_residual=", result.differential_mass_residual)
println("scaled_correction=", result.correction_norm,
    " differential_unchanged=", result.differential_unchanged)
println("capability_hash=", canonical_hash(dae_plan.capability))
println("subject_hash=", dae_plan.subject.physical_subject_hash)
println("solver_input_hash=", dae_plan.input.solver_input_hash)
println("provider_hash=", dae_plan.provider.manifest_hash)
println("source_hash=", dae_plan.source_hash)
println("plan_hash=", dae_plan.plan_hash)
println("artifact_hash=", canonical_hash(result))
println("evidence_hash=", dae_report.evidence.evidence_id)
println("receipt_hash=", dae_report.receipt.receipt_hash)
println("report_hash=", dae_report.report_hash)
println("execution_count=", execution_count, " validation=", validated ? "PASS" : "FAIL")
println("claim_ceiling=", dae_report.claim_ceiling,
    " credible_physical_candidates=", dae_report.credible_physical_candidate_count,
    " p5_ready=", dae_report.p5_ready,
    " unsupported=", dae_report.unsupported_emitted,
    " trajectory=", dae_report.trajectory)
