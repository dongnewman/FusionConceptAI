ENV["FUSION_FREEGS_AUTHORED_SOURCES"] = "1"
include(joinpath(@__DIR__, "..", "..", "examples", "runtime_v4_freegs_axisymmetric_execution.jl"))

const F = FreeGSAxisymmetricRuntime
const basis = F.FreeGSTFHardwareBasisV1(
    18, 134, 60_000.0, 68_000.0, 6.2, 5.3,
    "https://www.iter.org/node/20687/toroidal-field-coil-manufacturing-gains-momentum",
    "https://www.iter.org/node/20687/toroidal-field-coil-manufacturing-gains-momentum",
    "https://www.iter.org/node/20687/toroidal-field-coil-manufacturing-gains-momentum",
    "https://www.iter.org/sites/default/files/education/L06_Tsunematsu.pdf")
const hardware_genomes = F.build_freegs_authored_source_genomes(
    _fixture_mechanism, _fixture_realization,
    freegs_base_axisymmetric_declaration.domain; tf_hardware_basis=basis)
const values = hardware_genomes.values
const ni_edge = only(e for e in hardware_genomes.realization.realization_graph.hyperedges
    if e.edge_id == F._FREEGS_TF_SITES[1])
const ni_program = ni_edge.program
const input_node = only(n for n in ni_program.nodes if n isa F.ASTInputV1)
const count_nodes = Tuple(n for n in ni_program.nodes if n isa F.ASTConstantV1)
const multiplies = Tuple(n for n in ni_program.nodes if n isa F.ASTApplyV1)
@assert ni_program.input_ports == (1,)
@assert input_node.output_type.units == F._FREEGS_SOURCE_UNITS.current
@assert input_node.parameters.role === :unknown_tf_conductor_current_A
@assert length(count_nodes) == 2
@assert Set(n.value for n in count_nodes) == Set((18.0, 134.0))
@assert all(n.output_type.units == F._FREEGS_SOURCE_UNITS.dimensionless for n in count_nodes)
@assert Set(n.parameters.source_ref for n in count_nodes) ==
    Set((basis.coil_count_source_ref, basis.turns_source_ref))
@assert length(multiplies) == 2
@assert !any(n -> n isa F.ASTConstantV1 && n.value == basis.B0_T*basis.R0_m, ni_program.nodes)
# A mathematically commutative but structurally different NI AST must be rejected.
const reg = F.default_operator_registry()
const bad_final = F.ASTApplyV1(ni_program.nodes[5].operator_ref, (3,4),
    ni_program.nodes[5].parameters; registry=reg,
    input_types=(ni_program.nodes[3].output_type,ni_program.nodes[4].output_type))
const bad_ni_program = F.TypedASTProgramV1(
    (ni_program.nodes[1],ni_program.nodes[2],ni_program.nodes[3],ni_program.nodes[4],bad_final),
    (5,),(1,);registry=reg)
const bad_shape_rejected = try
    F._freegs_validate_tf_hardware_programs(bad_ni_program,
        F._freegs_validate_source_ast(values.TF_coefficient_edge),
        F._freegs_validate_source_ast(values.TF_field_edge),basis)
    false
catch err
    err isa ArgumentError
end
@assert bad_shape_rejected
const source_at_seed = F.evaluate_freegs_authored_sources(values;
    sample_RZ=(), current_A=basis.current_seed_A, source_only_R_m=(basis.R0_m,))
@assert source_at_seed.NI_A_turn == 2_412*basis.current_seed_A
@assert source_at_seed.effective_turns == 2_412
@assert source_at_seed.current_A == basis.current_seed_A
@assert isapprox(source_at_seed.vacuum_f_tm,
    source_at_seed.current_A*source_at_seed.effective_turns*F._FREEGS_SOURCE_MU0/(2pi);
    rtol=64eps(Float64), atol=0.0)
@assert !isapprox(source_at_seed.vacuum_f_tm, basis.B0_T*basis.R0_m;
    rtol=64eps(Float64), atol=0.0)
@assert source_at_seed.status === :evaluated_authored_G1_G3_sources
@assert isapprox(only(source_at_seed.source_only_Bphi_T),
    source_at_seed.vacuum_f_tm/basis.R0_m; rtol=64eps(Float64), atol=0.0)
@assert isapprox(only(source_at_seed.source_only_Bphi_T),
    values.winding_orientation*abs(source_at_seed.vacuum_f_tm)/basis.R0_m;
    rtol=64eps(Float64), atol=0.0)
@assert source_at_seed.TF_Bphi_T == ()
@assert source_at_seed.TF_is_internal_plasma_total_Bphi === false
@assert source_at_seed.source_only_g2_geometry === :typed_absent
@assert source_at_seed.source_only_polarity === :typed_absent
@assert source_at_seed.source_only_plasma_total_Bphi === :typed_absent
@assert source_at_seed.sensitivity_method === :known_graph_analytic_derivative
@assert only(source_at_seed.source_only_evaluation_kind) === :algebraic_source_law_extrapolation
@assert source_at_seed.source_only_geometry_validity === :typed_absent
@assert source_at_seed.fixture_winding_R_range_m == (0.08,2.1)
@assert only(source_at_seed.source_R_outside_fixture_winding)
const step = F.freegs_authored_tf_source_inverse_step(values; initial_current_A=60_000.0)
@assert step.status === :screen_only
@assert step.claim_ceiling === :screen_only
@assert step.objective_unit === :T2
@assert step.uncertainty === :typed_absent
@assert step.tolerance === :not_declared
@assert step.hardware_current_constraint === :typed_absent
@assert step.current_reference_use === :exposed_consistency_only_not_blind_holdout
@assert step.polarity === :typed_absent
@assert step.G2_pack_geometry === :typed_absent
@assert step.plasma_total_Bphi === :typed_absent
@assert step.sensitivity_method === :known_graph_analytic_derivative
@assert step.source_evaluation_kind === :algebraic_source_law_extrapolation
@assert step.geometry_validity === :typed_absent
@assert step.fixture_winding_R_range_m == (0.08,2.1)
@assert step.source_R_outside_fixture_winding
@assert step.exposed_current_reference_A == basis.published_current_reference_A
@assert step.exposed_current_delta_A == step.current_updated_A-basis.published_current_reference_A
@assert isapprox(step.H_initial_T, 4.668387096774193; rtol=64eps(Float64), atol=0.0)
@assert isapprox(step.objective_initial_T2, 0.3989348595213322; rtol=64eps(Float64), atol=0.0)
@assert isapprox(step.gauss_newton_step_A, 8117.744610281923; rtol=64eps(Float64), atol=0.0)
@assert isapprox(step.current_updated_A, 68117.74461028192; rtol=64eps(Float64), atol=0.0)
@assert isapprox(step.H_updated_T, 5.3; rtol=64eps(Float64), atol=0.0)

# Existing fixture callers retain their old value/evaluator tuple fields.
const default_genomes = F.build_freegs_authored_source_genomes(
    _fixture_mechanism, _fixture_realization,
    freegs_base_axisymmetric_declaration.domain)
@assert !hasproperty(default_genomes.values, :tf_hardware_basis)
@assert !hasproperty(default_genomes.values, :TF_NI_edge)
@assert !hasproperty(default_genomes, :tf_hardware_basis)
@assert default_genomes.values.NI_A_turn == default_genomes.values.declared_NI_A_turn
const default_evaluation = F.evaluate_freegs_authored_sources(
    default_genomes.values; sample_RZ=())
@assert !hasproperty(default_evaluation, :current_A)
@assert !hasproperty(default_evaluation, :source_only_R_m)
println((status=step.status, effective_turns=source_at_seed.effective_turns,
    H_initial_T=step.H_initial_T, residual_initial_T=step.residual_initial_T,
    objective_initial_T2=step.objective_initial_T2,
    gauss_newton_step_A=step.gauss_newton_step_A,
    current_updated_A=step.current_updated_A, H_updated_T=step.H_updated_T,
    exposed_current_reference_A=step.exposed_current_reference_A,
    exposed_current_delta_A=step.exposed_current_delta_A,
    tolerance=step.tolerance, uncertainty=step.uncertainty,
    polarity=step.polarity, G2_pack_geometry=step.G2_pack_geometry,
    plasma_total_Bphi=step.plasma_total_Bphi,
    source_evaluation_kind=step.source_evaluation_kind,
    geometry_validity=step.geometry_validity,
    fixture_winding_R_range_m=step.fixture_winding_R_range_m,
    source_R_outside_fixture_winding=step.source_R_outside_fixture_winding))
