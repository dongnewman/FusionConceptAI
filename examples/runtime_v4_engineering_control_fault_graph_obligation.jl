"""Manufactured current-G3-owned engineering control/fault graph contract.

The fixture compiles graph and subject ownership only. It does not run a
controller or supply engineering, validation, physical, promotion, or P5 evidence.
"""

include(joinpath(@__DIR__, "runtime_v4_declared_fixture.jl"))

module EngineeringControlFaultGraphRuntime
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Capability.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ForwardChainContext.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "EngineeringControlFaultGraphObligationV4.jl"))
end

const ECFGO = EngineeringControlFaultGraphRuntime
const ecfgo_seconds = UnitSignature((0, 0, 1, 0, 0, 0, 0))
const ecfgo_signal_type = PhysicalType(:scalar_field, 0, 0,
    TemporalTypeV1(discrete_time, 0, QualifiedRefV1("ecfgo-clock", "v1")),
    _fixture_unit)

function ecfgo_operator_registry()
    operator_registry = default_operator_registry()
    for id in ("ECFGO_OBSERVE", "ECFGO_CONTROL", "ECFGO_ACTUATE")
        manifest = OperatorManifestV1(OperatorRefV1(id, "v1"), 1, 1,
            SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
            allowed_roles=(:control,))
        operator_registry = register_operator(operator_registry, manifest)
    end
    operator_registry
end

function ecfgo_program(id, operator_registry)
    root = ASTApplyV1(OperatorRefV1(id, "v1"), (1,), (;);
        registry=operator_registry, input_types=(ecfgo_signal_type,))
    TypedASTProgramV1((ASTInputV1(1, ecfgo_signal_type), root), (2,), (1,);
        registry=operator_registry)
end

function ecfgo_control_graph()
    operator_registry = ecfgo_operator_registry()
    ids = ("ecfgo-observation-edge", "ecfgo-controller-edge",
        "ecfgo-actuator-edge")
    operators = ("ECFGO_OBSERVE", "ECFGO_CONTROL", "ECFGO_ACTUATE")
    edges = ntuple(i -> AtomicMIMOHyperedgeV1(ids[i],
        (MIMOInputBindingV1(1, i),), (MIMOOutputBindingV1(1, i + 1),),
        ecfgo_program(operators[i], operator_registry), control;
        registry=operator_registry), 3)
    TypedOperatorHypergraphV1((
        node(:plant_signal, ecfgo_signal_type; id="ecfgo-plant-signal"),
        node(:observation, ecfgo_signal_type; id="ecfgo-observation"),
        node(:controller_command, ecfgo_signal_type;
            id="ecfgo-controller-command"),
        node(:actuator_command, ecfgo_signal_type;
            id="ecfgo-actuator-command")), edges; registry=operator_registry)
end

const ecfgo_specs = (
    ECFGO.EngineeringControlEdgeSpecV4(ECFGO.observation_stage,
        "ecfgo-observation-edge", OperatorRefV1("ECFGO_OBSERVE", "v1")),
    ECFGO.EngineeringControlEdgeSpecV4(ECFGO.controller_stage,
        "ecfgo-controller-edge", OperatorRefV1("ECFGO_CONTROL", "v1")),
    ECFGO.EngineeringControlEdgeSpecV4(ECFGO.actuator_stage,
        "ecfgo-actuator-edge", OperatorRefV1("ECFGO_ACTUATE", "v1")))
const ecfgo_limit = ECFGO.make_engineering_actuator_limit(
    "ecfgo-actuator-edge", "ecfgo-actuator-command",
    QuantityIntervalV1(ExactFiniteIntervalV1(-10, 10, false), _fixture_unit))
const ecfgo_timing = ECFGO.make_engineering_control_fault_timing(
    NonnegativeQuantityV1(2//1000, ecfgo_seconds), 1//100,
    NonnegativeQuantityV1(1//1, ecfgo_seconds),
    NonnegativeQuantityV1(1//10, ecfgo_seconds),
    NonnegativeQuantityV1(2//1, ecfgo_seconds),
    NonnegativeQuantityV1(5//2, ecfgo_seconds), ECFGO.observation_dropout)
const ecfgo_declaration = ECFGO.declare_engineering_control_fault_graph(
    "ecfgo-manufactured-declaration", ecfgo_specs, ecfgo_limit, ecfgo_timing)

const ecfgo_control_graph_value = ecfgo_control_graph()
const ecfgo_g3 = RealizationControlGenomeV4(3, 4, _fixture_refs[3],
    _fixture_graph(), ecfgo_control_graph_value; control=(ecfgo_declaration,))
const ecfgo_candidate = CandidateStatePackageV4("ecfgo-manufactured-candidate",
    _fixture_mission, _fixture_mechanism, _fixture_field, ecfgo_g3, registry)
const ecfgo_mission =
    (mission="ecfgo-manufactured-contract", contract=_fixture_mission)
const ecfgo_bounds_payload = (scope="ecfgo-manufactured-contract",
    actuator_lower=-10//1, actuator_upper=10//1)
const ecfgo_comparison_scope = ("ecfgo-typed-control-chain",)
const ecfgo_scenarios = ((name="ecfgo-nominal", fixture="manufactured"),)
const ecfgo_scenario_scope = ("ecfgo-nominal",)
const ecfgo_compiled = ECFGO.compile_candidate(ecfgo_candidate, registry;
    mission_payload=ecfgo_mission, bounds_payload=ecfgo_bounds_payload,
    comparison_scope=ecfgo_comparison_scope,
    scenario_scope=ecfgo_scenario_scope)
const ecfgo_subject_binding =
    ECFGO.make_engineering_control_fault_subject_binding(ecfgo_compiled,
        registry, ecfgo_mission, ecfgo_bounds_payload, ecfgo_comparison_scope,
        ecfgo_scenario_scope, first(ecfgo_scenarios), ecfgo_declaration)
const ecfgo_subject = ECFGO.ExecutablePhysicalSubjectV4(
    ecfgo_compiled.prefix_hash,
    ecfgo_candidate.canonical_hashes.genome_bundle_hash,
    ecfgo_compiled.minimality_scope.mission_hash,
    ecfgo_compiled.minimality_scope.bounds_hash,
    (ecfgo_subject_binding,), ecfgo_scenarios,
    (model="typed-control-chain", revision="v1"),
    ECFGO.derive_capability_obligations(ecfgo_compiled))
const ecfgo_context = ECFGO.make_forward_chain_context(ecfgo_candidate,
    ecfgo_compiled, registry, ecfgo_mission, ecfgo_bounds_payload,
    ecfgo_comparison_scope, ecfgo_scenario_scope, ecfgo_subject,
    first(ecfgo_scenarios))
const ecfgo_resolution =
    ECFGO.resolve_engineering_control_fault_graph_obligation(ecfgo_context)

# The unchanged generic fixture owns neither declaration nor subject binding.
const ecfgo_generic_mission =
    (mission="runtime-declared-fixture", contract=_fixture_mission)
const ecfgo_generic_bounds =
    (scope="runtime-declared-fixture", lower=-1//1, upper=1//1)
const ecfgo_generic_comparison_scope = ("runtime-structural",)
const ecfgo_generic_scenario_scope = ("runtime-nominal",)
const ecfgo_generic_scenarios = ((name="runtime-nominal", fixture="generic"),)
const ecfgo_generic_compiled = ECFGO.compile_candidate(candidate, registry;
    mission_payload=ecfgo_generic_mission,
    bounds_payload=ecfgo_generic_bounds,
    comparison_scope=ecfgo_generic_comparison_scope,
    scenario_scope=ecfgo_generic_scenario_scope)
const ecfgo_generic_subject = ECFGO.ExecutablePhysicalSubjectV4(
    ecfgo_generic_compiled.prefix_hash,
    candidate.canonical_hashes.genome_bundle_hash,
    ecfgo_generic_compiled.minimality_scope.mission_hash,
    ecfgo_generic_compiled.minimality_scope.bounds_hash,
    ((binding_kind="generic-declared-fixture",),), ecfgo_generic_scenarios,
    (model="generic-declared", revision="v1"),
    ECFGO.derive_capability_obligations(ecfgo_generic_compiled))
const ecfgo_generic_context = ECFGO.make_forward_chain_context(candidate,
    ecfgo_generic_compiled, registry, ecfgo_generic_mission,
    ecfgo_generic_bounds, ecfgo_generic_comparison_scope,
    ecfgo_generic_scenario_scope, ecfgo_generic_subject,
    first(ecfgo_generic_scenarios))
const ecfgo_generic_gap =
    ECFGO.resolve_engineering_control_fault_graph_obligation(ecfgo_generic_context)

if abspath(PROGRAM_FILE) == @__FILE__
    println("status=", ecfgo_resolution.status)
    println("declaration_owned_by_current_g3=",
        count(x -> x isa ECFGO.EngineeringControlFaultDeclarationV4,
            ecfgo_candidate.realization_control_genome_ref.control) == 1)
    println("subject_binding_owned=",
        count(x -> x isa ECFGO.EngineeringControlFaultSubjectBindingV4,
            ecfgo_subject.bindings) == 1)
    println("edge_ids=",
        Tuple(e.edge_id for e in ecfgo_resolution.subject_binding.edges))
    println("generic_status=", ecfgo_generic_gap.status)
    println("claim_ceiling=", ecfgo_resolution.claim_ceiling)
    println("execution_authority=", ecfgo_resolution.execution_authority)
    println("credible_device_count=",
        ECFGO.engineering_control_fault_graph_obligation_manifest().credible_device_count)
end
