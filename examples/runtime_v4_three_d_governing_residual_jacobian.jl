"""Generic gap and two-state manufactured residual/Jacobian compiler fixture."""

using FusionConceptAI

module ThreeDGoverningResidualJacobianRuntime
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ForwardChainContext.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "ThreeDGoverningResidualJacobianV4.jl"))
end

module ThreeDGoverningResidualJacobianGenericFixture
using FusionConceptAI
include(joinpath(@__DIR__, "runtime_v4_g2_field_fixture.jl"))
end

const TDRJ = ThreeDGoverningResidualJacobianRuntime
const TDRJG = ThreeDGoverningResidualJacobianGenericFixture

function tdrj_make_context(candidate, registry, mission, bounds, comparison,
        scenario_scope, scenario, bindings, payload)
    compiled = TDRJ.compile_candidate(candidate, registry;
        mission_payload=mission, bounds_payload=bounds,
        comparison_scope=comparison, scenario_scope=scenario_scope)
    subject = TDRJ.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, bindings, (scenario,), payload,
        TDRJ.derive_capability_obligations(compiled))
    context = TDRJ.make_forward_chain_context(candidate, compiled, registry,
        mission, bounds, comparison, scenario_scope, subject, scenario)
    compiled, context
end

# The accepted generic G2 fixture owns no declaration set or typed binding.
const tdrj_generic_candidate = TDRJG.candidate
const tdrj_registry = TDRJG.registry
const tdrj_generic_scenario = TDRJG.scenario
const tdrj_generic_mission = (mission="generic-three-d-residual-jacobian-gap",
    contract=tdrj_generic_candidate.mission_contract_ref)
const tdrj_generic_bounds = (scope="generic-g2-residual-jacobian",)
const tdrj_generic_comparison = ("typed-three-d-residual-jacobian",)
const tdrj_generic_scenarios = (tdrj_generic_scenario.name,)
const tdrj_generic_compiled, tdrj_generic_context = tdrj_make_context(
    tdrj_generic_candidate, tdrj_registry, tdrj_generic_mission,
    tdrj_generic_bounds, tdrj_generic_comparison, tdrj_generic_scenarios,
    tdrj_generic_scenario, ((binding_kind="generic-g2-structural-only",),),
    (materialization="generic-g2-no-residual-jacobian",))
const tdrj_generic_resolution =
    TDRJ.compile_three_d_governing_residual_jacobian(tdrj_generic_context)

# Manufactured two-state graph. Each state owns a distinct registered
# governing residual and compatible Jacobian AtomicMIMO root.
const tdrj_unit = UnitSignature()
const tdrj_pressure_unit = UnitSignature((1, -1, -2, 0, 0, 0, 0))
const tdrj_magnetic_unit = UnitSignature((1, 0, -2, -1, 0, 0, 0))
const tdrj_state_types = (
    PhysicalType(:pressure_state, 0, 3, TemporalTypeV1(static_time),
        tdrj_pressure_unit),
    PhysicalType(:magnetic_state, 1, 3, TemporalTypeV1(static_time),
        tdrj_magnetic_unit))
const tdrj_residual_types = (
    PhysicalType(:governing_residual, 0, 3, TemporalTypeV1(static_time),
        tdrj_pressure_unit),
    PhysicalType(:governing_residual, 1, 3, TemporalTypeV1(static_time),
        tdrj_magnetic_unit))
const tdrj_jacobian_types = (
    PhysicalType(:residual_jacobian, 0, 3,
        TemporalTypeV1(static_time), tdrj_unit),
    PhysicalType(:residual_jacobian, 2, 3,
        TemporalTypeV1(static_time), tdrj_unit))

function tdrj_operator_manifest(id::String, role::Symbol,
        input_type::PhysicalType, output_type::PhysicalType)
    rule = ExactTypeRuleV1((input_type,), (output_type,))
    OperatorManifestV1(OperatorRefV1(id, "v1"), 1, 1, rule, rule;
        allowed_roles=(role,), locality=:local)
end

const tdrj_residual_operator_ids =
    ("TDRJ_PRESSURE_RESIDUAL", "TDRJ_MAGNETIC_RESIDUAL")
const tdrj_jacobian_operator_ids =
    ("TDRJ_PRESSURE_JACOBIAN", "TDRJ_MAGNETIC_JACOBIAN")
const tdrj_ops = let registry = OperatorRegistryV1()
    for i in 1:2
        registry = register_operator(registry, tdrj_operator_manifest(
            tdrj_residual_operator_ids[i], :governing,
            tdrj_state_types[i], tdrj_residual_types[i]))
        registry = register_operator(registry, tdrj_operator_manifest(
            tdrj_jacobian_operator_ids[i], :constraint,
            tdrj_state_types[i], tdrj_jacobian_types[i]))
    end
    registry
end

function tdrj_program(operator_id::String, input_type::PhysicalType,
        output_type::PhysicalType)
    input = ASTInputV1(1, input_type)
    root = ASTApplyV1(OperatorRefV1(operator_id, "v1"), (1,), (;);
        registry=tdrj_ops, input_types=(input_type,))
    root.output_type == output_type || error("fixture operator output mismatch")
    TypedASTProgramV1((input, root), (2,), (1,); registry=tdrj_ops)
end

const tdrj_residual_edges = ntuple(i -> AtomicMIMOHyperedgeV1(
    "tdrj-residual-edge-$i", (MIMOInputBindingV1(1, i),),
    (MIMOOutputBindingV1(1, 2 + i),),
    tdrj_program(tdrj_residual_operator_ids[i], tdrj_state_types[i],
        tdrj_residual_types[i]), governing; registry=tdrj_ops), 2)
const tdrj_jacobian_edges = ntuple(i -> AtomicMIMOHyperedgeV1(
    "tdrj-jacobian-edge-$i", (MIMOInputBindingV1(1, i),),
    (MIMOOutputBindingV1(1, 4 + i),),
    tdrj_program(tdrj_jacobian_operator_ids[i], tdrj_state_types[i],
        tdrj_jacobian_types[i]), constraint; registry=tdrj_ops), 2)
const tdrj_field_graph = TypedOperatorHypergraphV1(
    (node(:state, tdrj_state_types[1]; id="tdrj-pressure-state"),
     node(:state, tdrj_state_types[2]; id="tdrj-magnetic-state"),
     node(:residual, tdrj_residual_types[1]; id="tdrj-pressure-residual"),
     node(:residual, tdrj_residual_types[2]; id="tdrj-magnetic-residual"),
     node(:jacobian, tdrj_jacobian_types[1]; id="tdrj-pressure-jacobian"),
     node(:jacobian, tdrj_jacobian_types[2]; id="tdrj-magnetic-jacobian")),
    (tdrj_residual_edges..., tdrj_jacobian_edges...); registry=tdrj_ops)
const tdrj_prebinding = TDRJ._make_forward_graph_binding(
    :field_geometry, tdrj_field_graph)

# Selectors are intentionally reversed. The declaration must normalize them to
# current G2 state-node order and bind the full ordered set.
const tdrj_pair_selectors = (
    (state_node_id="tdrj-magnetic-state",
     residual_edge_id="tdrj-residual-edge-2",
     jacobian_edge_id="tdrj-jacobian-edge-2"),
    (state_node_id="tdrj-pressure-state",
     residual_edge_id="tdrj-residual-edge-1",
     jacobian_edge_id="tdrj-jacobian-edge-1"))
const tdrj_declaration =
    TDRJ.declare_three_d_governing_residual_jacobian_set(tdrj_prebinding;
        declaration_id="tdrj-manufactured-residual-jacobian-set",
        pair_selectors=tdrj_pair_selectors)

const tdrj_base = TDRJG.DeclaredFixtureDependency
const tdrj_field_genome = FieldGeometryGenomeV4(20260910,
    TDRJG._fixture_refs[2], tdrj_field_graph;
    fields=(tdrj_declaration,))
const tdrj_candidate = CandidateStatePackageV4(
    "tdrj-manufactured-residual-jacobian-set-candidate",
    tdrj_base._fixture_mission, tdrj_base._fixture_mechanism,
    tdrj_field_genome, tdrj_base._fixture_realization, tdrj_registry)
const tdrj_scenario = (name="tdrj-manufactured-scenario",
    fixture="two-state-compiler-only")
const tdrj_mission = (mission="typed-three-d-residual-jacobian-set-compiler",
    contract=tdrj_candidate.mission_contract_ref)
const tdrj_bounds = (scope="manufactured-residual-jacobian-set-only",
    declaration_hash=canonical_hash(tdrj_declaration))
const tdrj_comparison = ("typed-three-d-residual-jacobian-set-compiler",)
const tdrj_scenarios = (tdrj_scenario.name,)
const tdrj_compiled = TDRJ.compile_candidate(tdrj_candidate, tdrj_registry;
    mission_payload=tdrj_mission, bounds_payload=tdrj_bounds,
    comparison_scope=tdrj_comparison, scenario_scope=tdrj_scenarios)
const tdrj_subject_binding =
    TDRJ.make_three_d_governing_residual_jacobian_binding(
        tdrj_compiled, tdrj_registry, tdrj_mission, tdrj_bounds,
        tdrj_comparison, tdrj_scenarios, tdrj_scenario, tdrj_declaration)
const tdrj_subject = TDRJ.ExecutablePhysicalSubjectV4(
    tdrj_compiled.prefix_hash,
    tdrj_candidate.canonical_hashes.genome_bundle_hash,
    tdrj_compiled.minimality_scope.mission_hash,
    tdrj_compiled.minimality_scope.bounds_hash, (tdrj_subject_binding,),
    (tdrj_scenario,),
    (materialization="manufactured-two-state-residual-jacobian-compiler",
     declaration_hash=canonical_hash(tdrj_declaration)),
    TDRJ.derive_capability_obligations(tdrj_compiled))
const tdrj_context = TDRJ.make_forward_chain_context(tdrj_candidate,
    tdrj_compiled, tdrj_registry, tdrj_mission, tdrj_bounds,
    tdrj_comparison, tdrj_scenarios, tdrj_subject, tdrj_scenario)
const tdrj_resolution =
    TDRJ.compile_three_d_governing_residual_jacobian(tdrj_context)

if abspath(PROGRAM_FILE) == @__FILE__
    println("generic_status=", tdrj_generic_resolution.status)
    println("generic_gaps=",
        join(tdrj_generic_resolution.recoverable_gaps, ","))
    println("manufactured_status=", tdrj_resolution.status)
    println("state_pair_count=", length(tdrj_resolution.ownership.pairs))
    println("ordered_states=", join(Tuple(pair.state_node_id
        for pair in tdrj_resolution.ownership.pairs), ","))
    println("distinct_residual_roots=", length(unique(Tuple(
        pair.residual_operator.ast_root_identity_hash
        for pair in tdrj_resolution.ownership.pairs))))
    println("distinct_jacobian_roots=", length(unique(Tuple(
        pair.jacobian_operator.ast_root_identity_hash
        for pair in tdrj_resolution.ownership.pairs))))
    println("remaining_gaps=", join(tdrj_resolution.recoverable_gaps, ","))
    println("provider_executed=false")
    println("emits_evidence=false")
    println("grants_pass=false")
    println("terminal_authority=false")
end
