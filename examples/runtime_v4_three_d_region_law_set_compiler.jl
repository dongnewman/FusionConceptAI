"""Generic gap and manufactured two-region exact-cover law-set fixtures."""

using FusionConceptAI

module ThreeDRegionLawSetRuntime
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ForwardChainContext.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "ThreeDRegionLawCompilerV4.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "ThreeDOrientedInterfaceInputV4.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "ThreeDRegionLawSetCompilerV4.jl"))
end

module ThreeDRegionLawSetGenericFixture
using FusionConceptAI
include(joinpath(@__DIR__, "runtime_v4_g2_field_fixture.jl"))
end

const TDRLS = ThreeDRegionLawSetRuntime
const GenericThreeDG2Fixture = ThreeDRegionLawSetGenericFixture
const generic_3d_candidate = GenericThreeDG2Fixture.candidate
const generic_3d_registry = GenericThreeDG2Fixture.registry
const generic_3d_scenario = GenericThreeDG2Fixture.scenario
const generic_3d_mission = (mission="generic-three-d-region-law-set-gap",
    contract=generic_3d_candidate.mission_contract_ref)
const generic_3d_bounds = (scope="generic-g2-region-law-set",)
const generic_3d_comparison_scope = ("typed-three-d-region-law-set",)
const generic_3d_scenario_scope = (generic_3d_scenario.name,)
const generic_3d_compiled = TDRLS.compile_candidate(generic_3d_candidate,
    generic_3d_registry; mission_payload=generic_3d_mission,
    bounds_payload=generic_3d_bounds,
    comparison_scope=generic_3d_comparison_scope,
    scenario_scope=generic_3d_scenario_scope)
const generic_3d_subject = TDRLS.ExecutablePhysicalSubjectV4(
    generic_3d_compiled.prefix_hash,
    generic_3d_candidate.canonical_hashes.genome_bundle_hash,
    generic_3d_compiled.minimality_scope.mission_hash,
    generic_3d_compiled.minimality_scope.bounds_hash,
    ((binding_kind="generic-g2-structural-only",),),
    (generic_3d_scenario,),
    (materialization="generic-g2-no-region-law-set",),
    TDRLS.derive_capability_obligations(generic_3d_compiled))
const generic_3d_context = TDRLS.make_forward_chain_context(
    generic_3d_candidate, generic_3d_compiled, generic_3d_registry,
    generic_3d_mission, generic_3d_bounds, generic_3d_comparison_scope,
    generic_3d_scenario_scope, generic_3d_subject, generic_3d_scenario)

const tdrls_generic_resolution =
    TDRLS.compile_three_d_region_law_set(generic_3d_context)

const tdrls_unit = UnitSignature()
const tdrls_state_type = PhysicalType(:scalar_field, 0, 3,
    TemporalTypeV1(static_time), tdrls_unit)
const tdrls_region_type = PhysicalType(:manufactured_region_scalar, 0, 3,
    TemporalTypeV1(static_time), tdrls_unit)

function tdrls_manifest(id, role; effects=())
    rule = SameTypeVariadicRuleV1(1, 1)
    OperatorManifestV1(OperatorRefV1(id, "v1"), 1, 1, rule, rule;
        allowed_roles=(role,),
        locality=role === :boundary ? :boundary : :local,
        allowed_conservation_effects=effects)
end

function tdrls_operator_registry()
    registry = default_operator_registry()
    registry = register_operator(registry,
        tdrls_manifest("TDRLS_INTERFACE", :interface;
            effects=(:interface_flux,)))
    registry = register_operator(registry,
        tdrls_manifest("TDRLS_CONSTITUTIVE", :governing))
    registry = register_operator(registry,
        tdrls_manifest("TDRLS_SOURCE", :source;
            effects=(:net_creation,)))
    register_operator(registry,
        tdrls_manifest("TDRLS_BOUNDARY", :boundary))
end

const tdrls_ops = tdrls_operator_registry()

function tdrls_program(id, input_type)
    input = ASTInputV1(1, input_type)
    root = ASTApplyV1(OperatorRefV1(id, "v1"), (1,), (;);
        registry=tdrls_ops, input_types=(input_type,))
    TypedASTProgramV1((input, root), (2,), (1,); registry=tdrls_ops)
end

const tdrls_interface_ledger = ConservationLedgerIdentityV1(
    QualifiedRefV1("tdrls-interface-flux", "v1"),
    digest256_text("tdrls-interface-flux-ontology"), tdrls_unit)
const tdrls_interface_pair = InterfaceFluxPairV1(
    PortAccountEffectV1(ConservationAccountRefV1(
        tdrls_interface_ledger, :output, 1, :minus), -1 // 1),
    PortAccountEffectV1(ConservationAccountRefV1(
        tdrls_interface_ledger, :output, 2, :plus), 1 // 1))
const tdrls_interface_program = let
    left = ASTApplyV1(OperatorRefV1("TDRLS_INTERFACE", "v1"), (1,), (;);
        registry=tdrls_ops, input_types=(tdrls_state_type,))
    right = ASTApplyV1(OperatorRefV1("TDRLS_INTERFACE", "v1"), (2,), (;);
        registry=tdrls_ops, input_types=(tdrls_state_type,))
    TypedASTProgramV1((ASTInputV1(1, tdrls_state_type),
        ASTInputV1(2, tdrls_state_type), left, right), (3, 4), (1, 2);
        registry=tdrls_ops)
end
const tdrls_interface_edge = AtomicMIMOHyperedgeV1("tdrls-interface-edge",
    (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)),
    (MIMOOutputBindingV1(1, 1), MIMOOutputBindingV1(2, 2)),
    tdrls_interface_program, interface;
    interface_flux_pairs=(tdrls_interface_pair,), registry=tdrls_ops)

function tdrls_region_edges(stem, input_index, source_index, boundary_index)
    ledger = ConservationLedgerIdentityV1(
        QualifiedRefV1("tdrls-$stem-source", "v1"),
        digest256_text("tdrls-$stem-source-ontology"), tdrls_unit)
    effect = PortAccountEffectV1(ConservationAccountRefV1(
        ledger, :output, 1, :plus), 1 // 1)
    (AtomicMIMOHyperedgeV1("tdrls-$stem-constitutive-edge",
         (MIMOInputBindingV1(1, input_index),),
         (MIMOOutputBindingV1(1, input_index),),
         tdrls_program("TDRLS_CONSTITUTIVE", tdrls_region_type),
         governing; registry=tdrls_ops),
     AtomicMIMOHyperedgeV1("tdrls-$stem-source-edge",
         (MIMOInputBindingV1(1, input_index),),
         (MIMOOutputBindingV1(1, source_index),),
         tdrls_program("TDRLS_SOURCE", tdrls_region_type), source;
         account_effects=(effect,), registry=tdrls_ops),
     AtomicMIMOHyperedgeV1("tdrls-$stem-boundary-edge",
         (MIMOInputBindingV1(1, input_index),),
         (MIMOOutputBindingV1(1, boundary_index),),
         tdrls_program("TDRLS_BOUNDARY", tdrls_region_type),
         boundary; registry=tdrls_ops))
end

const tdrls_left_edges = tdrls_region_edges("left", 3, 4, 5)
const tdrls_right_edges = tdrls_region_edges("right", 6, 7, 8)
const tdrls_graph = TypedOperatorHypergraphV1(
    (node(:state, tdrls_state_type; id="tdrls-left-state"),
     node(:state, tdrls_state_type; id="tdrls-right-state"),
     node(:region, tdrls_region_type; id="left-region"),
     node(:source, tdrls_region_type; id="tdrls-left-source"),
     node(:boundary, tdrls_region_type; id="tdrls-left-boundary"),
     node(:region, tdrls_region_type; id="right-region"),
     node(:source, tdrls_region_type; id="tdrls-right-source"),
     node(:boundary, tdrls_region_type; id="tdrls-right-boundary")),
    (tdrls_interface_edge, tdrls_left_edges..., tdrls_right_edges...);
    registry=tdrls_ops)
const tdrls_prebinding = TDRLS._make_forward_graph_binding(
    :field_geometry, tdrls_graph)

const tdrls_chart_bounds = ntuple(_ -> QuantityIntervalV1(
    ExactFiniteIntervalV1(-1, 1, false), tdrls_unit), 3)
function tdrls_support(support_ref, stem)
    frame = CoordinateFrameRefV1("$stem-frame")
    SpatialSupportGeneV1(support_ref, 3, (frame,),
        (CoordinateChartGeneV1(ChartRefV1("$stem-chart"), frame,
            tdrls_chart_bounds, (), SpatialProgramRootRefV1(
                FieldOperatorSiteRefV1("$stem-coordinate-unexecuted"), 1,
                chart_coordinate_type_v1(),
                normalized_ambient_coordinate_type_v1()),
            SpatialProgramRootRefV1(
                FieldOperatorSiteRefV1("$stem-metric-unexecuted"), 1,
                chart_coordinate_type_v1(),
                normalized_covariant_metric_type_v1())),), (),
        NonnegativeQuantityV1(1,
            UnitSignature((0, 1, 0, 0, 0, 0, 0))))
end

const tdrls_left_support_ref = SpatialSupportRefV1("tdrls-left-support")
const tdrls_right_support_ref = SpatialSupportRefV1("tdrls-right-support")
const tdrls_interface_support_ref = SpatialSupportRefV1("tdrls-interface-support")
const tdrls_left_support = tdrls_support(tdrls_left_support_ref, "tdrls-left")
const tdrls_right_support = tdrls_support(tdrls_right_support_ref, "tdrls-right")
const tdrls_interface_support =
    tdrls_support(tdrls_interface_support_ref, "tdrls-interface")

tdrls_space(id, role, owner, support, family, p, q) =
    TDRLS.ThreeDDiscreteSpaceV4(id, role, owner, support,
        QualifiedRefV1(family, "v1"), tdrls_state_type, p, q)
const tdrls_oriented_declaration =
    TDRLS.ThreeDOrientedInterfaceDeclarationSetV4(
        "tdrls-two-region-oriented-interface",
        (TDRLS.ThreeDRegionSpaceDeclarationV4("left-region",
             "tdrls-left-state", tdrls_left_support_ref,
             tdrls_space("tdrls-left-volume", TDRLS.volume_space,
                 "left-region", tdrls_left_support_ref,
                 "lagrange-h1-hexahedron", 2, 4)),
         TDRLS.ThreeDRegionSpaceDeclarationV4("right-region",
             "tdrls-right-state", tdrls_right_support_ref,
             tdrls_space("tdrls-right-volume", TDRLS.volume_space,
                 "right-region", tdrls_right_support_ref,
                 "lagrange-h1-hexahedron", 2, 4))),
        (TDRLS.ThreeDOrientedInterfaceDeclarationV4(
             "left-to-right", "tdrls-interface-edge", "left-region",
             "right-region", tdrls_interface_ledger,
             tdrls_space("tdrls-left-trace", TDRLS.trace_space,
                 "left-region", tdrls_left_support_ref, "mortar-trace", 2, 4),
             tdrls_space("tdrls-right-trace", TDRLS.trace_space,
                 "right-region", tdrls_right_support_ref, "mortar-trace", 2, 4),
             tdrls_space("tdrls-interface-multiplier",
                 TDRLS.multiplier_space, "left-to-right",
                 tdrls_interface_support_ref, "mortar-multiplier", 1, 4)),))

# Reversed selector input proves that the declaration normalizes to oriented
# region order rather than trusting caller order.
const tdrls_selectors = (
    (region_id="right-region",
     constitutive_edge_id="tdrls-right-constitutive-edge",
     source_edge_id="tdrls-right-source-edge",
     boundary_edge_id="tdrls-right-boundary-edge"),
    (region_id="left-region",
     constitutive_edge_id="tdrls-left-constitutive-edge",
     source_edge_id="tdrls-left-source-edge",
     boundary_edge_id="tdrls-left-boundary-edge"))
const tdrls_declaration = TDRLS.declare_three_d_region_law_set(
    tdrls_prebinding, tdrls_oriented_declaration;
    declaration_id="tdrls-two-region-law-exact-cover",
    law_selectors=tdrls_selectors)

const tdrls_field_genome = FieldGeometryGenomeV4(20260910,
    GenericThreeDG2Fixture._fixture_refs[2], tdrls_graph;
    fields=(tdrls_left_support, tdrls_right_support,
        tdrls_interface_support, tdrls_oriented_declaration,
        tdrls_declaration))
const tdrls_base = GenericThreeDG2Fixture.DeclaredFixtureDependency
const tdrls_candidate = CandidateStatePackageV4(
    "tdrls-manufactured-two-region-candidate", tdrls_base._fixture_mission,
    tdrls_base._fixture_mechanism, tdrls_field_genome,
    tdrls_base._fixture_realization, generic_3d_registry)
const tdrls_scenario = (name="tdrls-manufactured-scenario",
    fixture="two-region-law-set-only")
const tdrls_mission = (mission="typed-three-d-region-law-exact-cover",
    contract=tdrls_candidate.mission_contract_ref)
const tdrls_bounds = (scope="manufactured-two-region-law-set-only",
    region_count=2, law_count=6)
const tdrls_comparison = ("typed-three-d-region-law-exact-cover",)
const tdrls_scenarios = (tdrls_scenario.name,)
const tdrls_compiled = TDRLS.compile_candidate(tdrls_candidate,
    generic_3d_registry; mission_payload=tdrls_mission,
    bounds_payload=tdrls_bounds, comparison_scope=tdrls_comparison,
    scenario_scope=tdrls_scenarios)
const tdrls_oriented_binding =
    TDRLS.make_three_d_oriented_interface_binding(tdrls_compiled,
        generic_3d_registry, tdrls_mission, tdrls_bounds, tdrls_comparison,
        tdrls_scenarios, tdrls_scenario, tdrls_oriented_declaration)
const tdrls_binding = TDRLS.make_three_d_region_law_set_binding(
    tdrls_compiled, generic_3d_registry, tdrls_mission, tdrls_bounds,
    tdrls_comparison, tdrls_scenarios, tdrls_scenario, tdrls_declaration,
    tdrls_oriented_binding)
const tdrls_subject = TDRLS.ExecutablePhysicalSubjectV4(
    tdrls_compiled.prefix_hash,
    tdrls_candidate.canonical_hashes.genome_bundle_hash,
    tdrls_compiled.minimality_scope.mission_hash,
    tdrls_compiled.minimality_scope.bounds_hash,
    (tdrls_oriented_binding, tdrls_binding), (tdrls_scenario,),
    (materialization="manufactured-two-region-law-set",
     law_set_binding_hash=canonical_hash(tdrls_binding)),
    TDRLS.derive_capability_obligations(tdrls_compiled))
const tdrls_context = TDRLS.make_forward_chain_context(tdrls_candidate,
    tdrls_compiled, generic_3d_registry, tdrls_mission, tdrls_bounds,
    tdrls_comparison, tdrls_scenarios, tdrls_subject, tdrls_scenario)
const tdrls_resolution =
    TDRLS.compile_three_d_region_law_set(tdrls_context)

if abspath(PROGRAM_FILE) == @__FILE__
    println("generic_status=", tdrls_generic_resolution.status)
    println("generic_gaps=", join(tdrls_generic_resolution.recoverable_gaps, ","))
    println("manufactured_status=", tdrls_resolution.status)
    println("ordered_regions=", join(tdrls_resolution.ordered_region_ids, ","))
    println("region_law_bundle_count=", length(tdrls_resolution.laws))
    println("distinct_law_edges=",
        length(unique(tdrls_resolution.ordered_edge_identity_hashes)))
    println("distinct_law_roots=",
        length(unique(tdrls_resolution.ordered_ast_root_identity_hashes)))
    println("distinct_law_outputs=",
        length(unique(tdrls_resolution.ordered_output_node_identity_hashes)))
    println("provider_selected=false")
    println("provider_executed=false")
    println("solver_executed=false")
    println("emits_evidence=false")
    println("grants_pass=false")
    println("p5_ready=false")
    println("terminal_authority=false")
end
