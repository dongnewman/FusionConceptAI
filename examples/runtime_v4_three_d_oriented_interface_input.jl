"""Manufactured compiler fixture for typed oriented 3-D interfaces.

The generic current G2 context remains a recoverable gap. The positive fixture
derives interface direction and exact coefficients from one real typed G2
`AtomicMIMOHyperedgeV1`. It proves input compilation only.
"""

using FusionConceptAI

# Reuse the accepted context construction and load this isolated next edge into
# the same Runtime module so its ForwardChainContextV4 identity is exact.
include(joinpath(@__DIR__, "runtime_v4_three_d_physical_provider_input.jl"))
Base.include(TDPI, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "ThreeDOrientedInterfaceInputV4.jl"))
const TDOI = TDPI

const generic_3d_oriented_interface_resolution =
    TDOI.resolve_three_d_oriented_interface_input(generic_3d_context)

const tdoi_unit = UnitSignature()
const tdoi_state_type = PhysicalType(:scalar_field, 0, 3,
    TemporalTypeV1(static_time), tdoi_unit)

function tdoi_operator_registry()
    manifest = OperatorManifestV1(OperatorRefV1("TDOI_OPEN", "v1"), 1, 1,
        SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:interface,),
        allowed_conservation_effects=(:interface_flux,))
    register_operator(default_operator_registry(), manifest)
end

function tdoi_field_graph()
    registry = tdoi_operator_registry()
    left = ASTApplyV1(OperatorRefV1("TDOI_OPEN", "v1"), (1,), (;);
        registry=registry, input_types=(tdoi_state_type,))
    right = ASTApplyV1(OperatorRefV1("TDOI_OPEN", "v1"), (2,), (;);
        registry=registry, input_types=(tdoi_state_type,))
    program = TypedASTProgramV1((ASTInputV1(1, tdoi_state_type),
        ASTInputV1(2, tdoi_state_type), left, right), (3, 4), (1, 2);
        registry=registry)
    ledger = ConservationLedgerIdentityV1(
        QualifiedRefV1("tdoi-interface-flux", "v1"),
        digest256_text("tdoi-interface-flux-ontology"), tdoi_unit)
    pair = InterfaceFluxPairV1(
        PortAccountEffectV1(ConservationAccountRefV1(
            ledger, :output, 1, :minus), -1 // 1),
        PortAccountEffectV1(ConservationAccountRefV1(
            ledger, :output, 2, :plus), 1 // 1))
    edge = AtomicMIMOHyperedgeV1("tdoi-interface-edge",
        (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)),
        (MIMOOutputBindingV1(1, 1), MIMOOutputBindingV1(2, 2)),
        program, interface; interface_flux_pairs=(pair,), registry=registry)
    graph = TypedOperatorHypergraphV1(
        (node(:state, tdoi_state_type; id="tdoi-left-state"),
         node(:state, tdoi_state_type; id="tdoi-right-state")),
        (edge,); registry=registry)
    graph, ledger
end

const tdoi_graph_and_ledger = tdoi_field_graph()
const tdoi_graph = tdoi_graph_and_ledger[1]
const tdoi_ledger = tdoi_graph_and_ledger[2]
const tdoi_chart_type = chart_coordinate_type_v1()
const tdoi_chart_bounds = ntuple(_ -> QuantityIntervalV1(
    ExactFiniteIntervalV1(-1, 1, false), UnitSignature()), 3)

function tdoi_support_gene(support_ref, stem)
    frame_ref = CoordinateFrameRefV1("$(stem)-frame")
    chart_ref = ChartRefV1("$(stem)-chart")
    SpatialSupportGeneV1(support_ref, 3, (frame_ref,),
        (CoordinateChartGeneV1(chart_ref, frame_ref,
            tdoi_chart_bounds, (),
            SpatialProgramRootRefV1(FieldOperatorSiteRefV1(
                "$(stem)-coordinate-map-declaration:unexecuted:v1"), 1,
                tdoi_chart_type, normalized_ambient_coordinate_type_v1()),
            SpatialProgramRootRefV1(FieldOperatorSiteRefV1(
                "$(stem)-metric-declaration:unexecuted:v1"), 1,
                tdoi_chart_type, normalized_covariant_metric_type_v1())),),
        (), NonnegativeQuantityV1(
            1, UnitSignature((0, 1, 0, 0, 0, 0, 0))))
end

const tdoi_left_support_ref = SpatialSupportRefV1("tdoi-left-support")
const tdoi_right_support_ref = SpatialSupportRefV1("tdoi-right-support")
const tdoi_interface_support_ref = SpatialSupportRefV1("tdoi-interface-support")
const tdoi_left_support = tdoi_support_gene(tdoi_left_support_ref, "tdoi-left")
const tdoi_right_support = tdoi_support_gene(tdoi_right_support_ref, "tdoi-right")
const tdoi_interface_support =
    tdoi_support_gene(tdoi_interface_support_ref, "tdoi-interface")

tdoi_space(id, role, owner, support_ref, family, p, q) =
    TDOI.ThreeDDiscreteSpaceV4(
        id, role, owner, support_ref, QualifiedRefV1(family, "v1"),
        tdoi_state_type, p, q)

const tdoi_left_volume = tdoi_space("tdoi-left-volume", TDOI.volume_space,
    "left", tdoi_left_support_ref, "lagrange-h1-hexahedron", 2, 4)
const tdoi_right_volume = tdoi_space("tdoi-right-volume", TDOI.volume_space,
    "right", tdoi_right_support_ref, "lagrange-h1-hexahedron", 2, 4)
const tdoi_left_region = TDOI.ThreeDRegionSpaceDeclarationV4(
    "left", "tdoi-left-state", tdoi_left_support_ref, tdoi_left_volume)
const tdoi_right_region = TDOI.ThreeDRegionSpaceDeclarationV4(
    "right", "tdoi-right-state", tdoi_right_support_ref, tdoi_right_volume)
const tdoi_interface = TDOI.ThreeDOrientedInterfaceDeclarationV4(
    "left-to-right", "tdoi-interface-edge", "left", "right", tdoi_ledger,
    tdoi_space("tdoi-left-trace", TDOI.trace_space, "left",
        tdoi_left_support_ref, "mortar-trace", 2, 4),
    tdoi_space("tdoi-right-trace", TDOI.trace_space, "right",
        tdoi_right_support_ref, "mortar-trace", 2, 4),
    tdoi_space("tdoi-interface-multiplier", TDOI.multiplier_space,
        "left-to-right", tdoi_interface_support_ref,
        "mortar-multiplier", 1, 4))
const tdoi_declaration = TDOI.ThreeDOrientedInterfaceDeclarationSetV4(
    "tdoi-manufactured-two-region-interface",
    (tdoi_left_region, tdoi_right_region), (tdoi_interface,))

const tdoi_field_genome = FieldGeometryGenomeV4(20260910,
    GenericThreeDG2Fixture._fixture_refs[2], tdoi_graph;
    fields=(tdoi_left_support, tdoi_right_support,
        tdoi_interface_support, tdoi_declaration))
const tdoi_candidate = CandidateStatePackageV4(
    "tdoi-manufactured-interface-candidate",
    GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_mission,
    GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_mechanism,
    tdoi_field_genome,
    GenericThreeDG2Fixture.DeclaredFixtureDependency._fixture_realization,
    generic_3d_registry)
const tdoi_mission = (mission="typed-oriented-3d-interface-input",
    contract=tdoi_candidate.mission_contract_ref)
const tdoi_bounds = (declaration_hash=canonical_hash(tdoi_declaration),
    scope="manufactured-interface-compiler-only")
const tdoi_comparison_scope = ("typed-oriented-interface-input",)
const tdoi_scenario = (name="tdoi-manufactured-scenario-scenario",
    fixture="compiler-only")
const tdoi_scenario_scope = (tdoi_scenario.name,)
const tdoi_compiled = TDOI.compile_candidate(tdoi_candidate,
    generic_3d_registry; mission_payload=tdoi_mission,
    bounds_payload=tdoi_bounds, comparison_scope=tdoi_comparison_scope,
    scenario_scope=tdoi_scenario_scope)
const tdoi_subject_binding = TDOI.make_three_d_oriented_interface_binding(
    tdoi_compiled, generic_3d_registry, tdoi_mission, tdoi_bounds,
    tdoi_comparison_scope, tdoi_scenario_scope, tdoi_scenario,
    tdoi_declaration)
const tdoi_subject = TDOI.ExecutablePhysicalSubjectV4(
    tdoi_compiled.prefix_hash, tdoi_candidate.canonical_hashes.genome_bundle_hash,
    tdoi_compiled.minimality_scope.mission_hash,
    tdoi_compiled.minimality_scope.bounds_hash, (tdoi_subject_binding,),
    (tdoi_scenario,), (materialization="manufactured-interface-input-only",
        declaration_hash=canonical_hash(tdoi_declaration)),
    TDOI.derive_capability_obligations(tdoi_compiled))
const tdoi_context = TDOI.make_forward_chain_context(tdoi_candidate,
    tdoi_compiled, generic_3d_registry, tdoi_mission, tdoi_bounds,
    tdoi_comparison_scope, tdoi_scenario_scope, tdoi_subject, tdoi_scenario)
const tdoi_resolution =
    TDOI.resolve_three_d_oriented_interface_input(tdoi_context)
const tdoi_input = something(tdoi_resolution.input)

if abspath(PROGRAM_FILE) == @__FILE__
    println("generic_status=", generic_3d_oriented_interface_resolution.status)
    println("generic_gaps=", join(
        generic_3d_oriented_interface_resolution.recoverable_gaps, ","))
    println("manufactured_status=", tdoi_resolution.status)
    println("region_count=", length(tdoi_input.regions))
    println("interface_count=", length(tdoi_input.interfaces))
    println("minus_coefficient=", only(tdoi_input.interfaces).minus_coefficient)
    println("plus_coefficient=", only(tdoi_input.interfaces).plus_coefficient)
    println("provider_selected=false")
    println("solver_executed=false")
    println("claim_ceiling=screen_only")
end
