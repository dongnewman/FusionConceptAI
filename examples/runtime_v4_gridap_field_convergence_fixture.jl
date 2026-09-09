"""B2 fixture: independently rederived real G2 reports at 5/9/17 nodes."""
const runtime_v4_field_residual_definition_only = true
include(joinpath(@__DIR__, "runtime_v4_gridap_field_fixture.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4", "GridapFieldConvergence.jl"))

const gridap_b2_grids = tuple((FieldGridSpecV4((Tuple(range(-1.0, 1.0; length=n)),
    Tuple(range(-1.0, 1.0; length=n)), Tuple(range(-1.0, 1.0; length=n))))
    for n in (5, 9, 17))...)
const gridap_b2_compilations = ntuple(i -> begin
    g = gridap_b2_grids[i]
    us = FusionRuntimeV4.compile_field_evaluation_plan(composition_candidate, composition_compiled,
        tdae_registry, gridap_b1_operator_registry; scenario=d3_g2_scenario, grid=g,
        program_site_ref=d3_g2_site, root_position=1)
    fs = FusionRuntimeV4.compile_field_evaluation_plan(composition_candidate, composition_compiled,
        tdae_registry, gridap_b1_operator_registry; scenario=d3_g2_scenario, grid=g,
        program_site_ref=d3_g2_site, root_position=2)
    ur = FusionRuntimeV4.execute_field_evaluation(Dict{Digest256,Any}(), composition_candidate,
        composition_compiled, tdae_registry, gridap_b1_operator_registry, us, d3_g2_scenario;
        provider=FusionRuntimeV4.field_evaluation_provider(us))
    fr = FusionRuntimeV4.execute_field_evaluation(Dict{Digest256,Any}(), composition_candidate,
        composition_compiled, tdae_registry, gridap_b1_operator_registry, fs, d3_g2_scenario;
        provider=FusionRuntimeV4.field_evaluation_provider(fs))
    (FusionRuntimeV4.compile_gridap_field_residual_plan(composition_candidate, composition_compiled,
        tdae_registry, gridap_b1_operator_registry, ur, fr; scenario=d3_g2_scenario, grid=g,
        constraint_edge_hash=canonical_hash(composition_constraint), unknown_state_ref=StateGeneRefV1("u"),
        source_state_ref=StateGeneRefV1("f"), residual_state_ref=StateGeneRefV1("r"),
        affine_factors=(-1,1,1), affine_offsets=(1//4,-1//2,2//3), native_protocol=gridap_b1_protocol), us, fs)
end, 3)
