"""D4.1 combined field-residual fixture (candidate-bound, screen-only)."""

const runtime_v4_field_residual_definition_only = true
include(joinpath(@__DIR__, "runtime_v4_typed_dae_composition_fixture.jl"))

const field_residual_candidate = composition_candidate
const field_residual_compiled = composition_compiled

const field_residual_grid_sizes = (5, 9, 17)
function field_residual_grid(n)
    a = ntuple(i -> -1.0 + 2.0 * (i - 1) / (n - 1), n)
    FieldGridSpecV4((a, a, a))
end

function field_residual_case(n)
    grid = field_residual_grid(n)
    operator_registry = default_operator_registry()
    plans = ntuple(root -> FusionRuntimeV4.compile_field_evaluation_plan(
        field_residual_candidate, field_residual_compiled, tdae_registry,
        operator_registry; scenario=d3_g2_scenario, grid=grid,
        program_site_ref=d3_g2_site, root_position=root), 2)
    providers = ntuple(i -> FusionRuntimeV4.field_evaluation_provider(plans[i]), 2)
    reports = ntuple(i -> FusionRuntimeV4.execute_field_evaluation(
        Dict{Digest256,Any}(), field_residual_candidate, field_residual_compiled,
        tdae_registry, operator_registry, plans[i], d3_g2_scenario;
        provider=providers[i]), 2)
    protocol = StructuredGridProtocolV4()
    plan = compile_field_residual_plan(
        composition_candidate, composition_compiled, tdae_registry,
        operator_registry, reports[1], reports[2];
        scenario=d3_g2_scenario, grid=grid,
        constraint_edge_hash=canonical_hash(composition_constraint),
        unknown_state_ref=StateGeneRefV1("u"),
        source_state_ref=StateGeneRefV1("f"),
        residual_state_ref=StateGeneRefV1("r"),
        affine_factors=(1, 1, 1), affine_offsets=(0, 0, 0), protocol=protocol)
    source = FieldResidualPayloadV4(StateGeneRefV1("f"), grid,
        reports[2].result.values, composition_static3d)
    boundary = FieldResidualPayloadV4(StateGeneRefV1("u"), grid,
        reports[1].result.values, composition_static3d)
    pipeline_provider = field_residual_provider(plan)
    source_snapshot = (state_ref=source.state_ref, values=source.values,
        physical_type=source.physical_type, content_hash=source.content_hash)
    boundary_snapshot = (state_ref=boundary.state_ref, values=boundary.values,
        physical_type=boundary.physical_type, content_hash=boundary.content_hash)
    input = SolverInputV4(plan.subject_hash,
        plan.mission.scenario_hash, pipeline_provider.manifest_hash,
        pipeline_provider.input_schema_hash,
        (materialized_payload=(plan=plan, plan_hash=plan.plan_hash,
            sources=(source_snapshot,), boundary=boundary_snapshot),
         numerical_configuration=(protocol_hash=protocol.protocol_hash,)))
    store = FieldResidualPipelineStoreV4()
    report = execute_once!(store, input, pipeline_provider, plan)
    (n=n, grid=grid, plans=plans, reports=reports, plan=plan,
     source=source, boundary=boundary, providers=providers, provider=pipeline_provider,
     input=input, store=store, report=report)
end

const field_residual_cases = Tuple(field_residual_case(n) for n in field_residual_grid_sizes)
const field_residual_reports = Tuple(c.report for c in field_residual_cases)
const field_residual_u_reports = Tuple(c.reports[1] for c in field_residual_cases)
const field_residual_plans = Tuple(c.plan for c in field_residual_cases)
const field_residual_convergence = build_manufactured_field_convergence_receipt(
    field_residual_plans, field_residual_reports, field_residual_u_reports)
