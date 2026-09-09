"""Batch C fixture over the frozen 5/9/17 native and Gridap providers."""

include(joinpath(@__DIR__, "runtime_v4_gridap_field_convergence_fixture.jl"))
Base.include(FusionRuntimeV4,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "GridapFieldEvidence.jl"))
Base.include(FusionRuntimeV4,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "GridapNativeComparison.jl"))

function _gridap_c_native_execution(compilation)
    plan = compilation.plan.native_plan
    provider = FusionRuntimeV4.field_residual_provider(plan)
    source = compilation.source
    boundary = compilation.boundary
    source_snapshot = (state_ref=source.state_ref, values=source.values,
        physical_type=source.physical_type, content_hash=source.content_hash)
    boundary_snapshot = (state_ref=boundary.state_ref, values=boundary.values,
        physical_type=boundary.physical_type, content_hash=boundary.content_hash)
    input = SolverInputV4(plan.subject_hash, plan.mission.scenario_hash,
        provider.manifest_hash, provider.input_schema_hash,
        (materialized_payload=(plan=plan, plan_hash=plan.plan_hash,
            sources=(source_snapshot,), boundary=boundary_snapshot),
         numerical_configuration=(protocol_hash=plan.protocol.protocol_hash,)))
    primary_store = FieldResidualPipelineStoreV4()
    replay_store = FieldResidualPipelineStoreV4()
    primary = FusionRuntimeV4.execute_once!(primary_store, input, provider, plan)
    replay = FusionRuntimeV4.execute_once!(replay_store, input, provider, plan)
    witness = FusionRuntimeV4.make_native_field_replay_witness(plan,
        primary_store, replay_store, input.solver_input_hash)
    (plan=plan, provider=provider, input=input, primary_store=primary_store,
     replay_store=replay_store, primary=primary, replay=replay,
     witness=witness)
end

const gridap_c_native_executions = ntuple(i ->
    _gridap_c_native_execution(gridap_b2_compilations[i][1]), 3)

const gridap_c_u_reports = ntuple(i -> begin
    plan = gridap_b2_compilations[i][2]
    FusionRuntimeV4.execute_field_evaluation(Dict{Digest256,Any}(),
        composition_candidate, composition_compiled, tdae_registry,
        gridap_b1_operator_registry, plan, d3_g2_scenario;
        provider=FusionRuntimeV4.field_evaluation_provider(plan))
end, 3)

const gridap_c_native_convergence =
    FusionRuntimeV4.build_manufactured_field_convergence_receipt(
        Tuple(x.plan for x in gridap_c_native_executions),
        Tuple(x.primary for x in gridap_c_native_executions),
        gridap_c_u_reports)

const gridap_c_gridap_convergence =
    FusionRuntimeV4.run_gridap_field_convergence(gridap_b2_compilations)

const gridap_c_bundle_stores = ntuple(_ -> Dict{Digest256,Any}(), 3)
const gridap_c_gridap_bundles = ntuple(i ->
    FusionRuntimeV4.execute_gridap_field_evidence!(gridap_c_bundle_stores[i],
        gridap_b2_compilations[i][1]; candidate=composition_candidate,
        compiled=composition_compiled, genome_registry=tdae_registry,
        scenario=d3_g2_scenario), 3)

const gridap_c_native_witnesses =
    Tuple(x.witness for x in gridap_c_native_executions)

const gridap_c_report = FusionRuntimeV4.build_gridap_native_comparison(
    gridap_c_gridap_bundles, gridap_c_native_witnesses,
    gridap_c_native_convergence, gridap_c_gridap_convergence;
    compiled=composition_compiled, genome_registry=tdae_registry,
    scenario=d3_g2_scenario)
