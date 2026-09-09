"""B1 candidate-bound inputs: G2 execution and residual-plan compilation only."""

const runtime_v4_field_residual_definition_only = true
include(joinpath(@__DIR__, "runtime_v4_typed_dae_composition_fixture.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "GridapFieldResidualAdapter.jl"))

const gridap_b1_grid = FieldGridSpecV4((
    (-1.0, -0.5, 0.0, 0.5, 1.0),
    (-1.0, -0.5, 0.0, 0.5, 1.0),
    (-1.0, -0.5, 0.0, 0.5, 1.0)))
const gridap_b1_operator_registry = default_operator_registry()
const gridap_b1_plans = ntuple(root -> FusionRuntimeV4.compile_field_evaluation_plan(
    composition_candidate, composition_compiled, tdae_registry,
    gridap_b1_operator_registry; scenario=d3_g2_scenario,
    grid=gridap_b1_grid, program_site_ref=d3_g2_site, root_position=root), 2)
const gridap_b1_providers = ntuple(i -> FusionRuntimeV4.field_evaluation_provider(gridap_b1_plans[i]), 2)
const gridap_b1_reports = ntuple(i -> FusionRuntimeV4.execute_field_evaluation(
    Dict{Digest256,Any}(), composition_candidate, composition_compiled, tdae_registry,
    gridap_b1_operator_registry, gridap_b1_plans[i], d3_g2_scenario;
    provider=gridap_b1_providers[i]), 2)
const gridap_b1_protocol = StructuredGridProtocolV4()
const gridap_b1_compilation = FusionRuntimeV4.compile_gridap_field_residual_plan(
    composition_candidate, composition_compiled, tdae_registry,
    gridap_b1_operator_registry, gridap_b1_reports[1], gridap_b1_reports[2];
    scenario=d3_g2_scenario, grid=gridap_b1_grid,
    constraint_edge_hash=canonical_hash(composition_constraint),
    unknown_state_ref=StateGeneRefV1("u"), source_state_ref=StateGeneRefV1("f"),
    residual_state_ref=StateGeneRefV1("r"), affine_factors=(-1, 1, 1),
    affine_offsets=(1 // 4, -1 // 2, 2 // 3),
    native_protocol=gridap_b1_protocol)
