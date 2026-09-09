"""Generic-gap and manufactured-positive examples for the 3-D region-law compiler."""

using FusionConceptAI

module ThreeDRegionLawCompilerRuntime
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ForwardChainContext.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ThreeDPhysicalProviderInputV4.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ThreeDRegionLawCompilerV4.jl"))
end

module ThreeDRegionLawGenericFixture
using FusionConceptAI
include(joinpath(@__DIR__, "runtime_v4_g2_field_fixture.jl"))
end

const TDRL = ThreeDRegionLawCompilerRuntime
const TDRLG = ThreeDRegionLawGenericFixture

function tdrl_make_context(candidate, registry, mission, bounds, comparison,
        scenario_scope, scenario, bindings, payload)
    compiled = TDRL.compile_candidate(candidate, registry;
        mission_payload=mission, bounds_payload=bounds,
        comparison_scope=comparison, scenario_scope=scenario_scope)
    subject = TDRL.ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash,
        compiled.minimality_scope.bounds_hash, bindings, (scenario,), payload,
        TDRL.derive_capability_obligations(compiled))
    context = TDRL.make_forward_chain_context(candidate, compiled, registry,
        mission, bounds, comparison, scenario_scope, subject, scenario)
    compiled, context
end

# The existing generic G2 graph contains no typed region-law declaration.
const tdrl_generic_candidate = TDRLG.candidate
const tdrl_registry = TDRLG.registry
const tdrl_generic_scenario = TDRLG.scenario
const tdrl_generic_mission = (mission="generic-three-d-region-law-gap",
    contract=tdrl_generic_candidate.mission_contract_ref)
const tdrl_generic_bounds = (scope="generic-g2-region-law-compiler",)
const tdrl_generic_comparison = ("typed-three-d-region-laws",)
const tdrl_generic_scenarios = (tdrl_generic_scenario.name,)
const tdrl_generic_compiled, tdrl_generic_context = tdrl_make_context(
    tdrl_generic_candidate, tdrl_registry, tdrl_generic_mission,
    tdrl_generic_bounds, tdrl_generic_comparison, tdrl_generic_scenarios,
    tdrl_generic_scenario, ((binding_kind="generic-g2-structural-only",),),
    (materialization="generic-g2-no-region-laws",))
const tdrl_generic_resolution =
    TDRL.compile_three_d_region_laws(tdrl_generic_context)

# Manufactured graph.  Every law is a registered ASTApply root on an actual
# AtomicMIMOHyperedgeV1 with a distinct typed role; labels are never consulted.
const tdrl_unit = UnitSignature()
const tdrl_length_unit = UnitSignature((0, 1, 0, 0, 0, 0, 0))
const tdrl_metric_unit = UnitSignature((0, 2, 0, 0, 0, 0, 0))
const tdrl_pressure_unit = UnitSignature((1, -1, -2, 0, 0, 0, 0))
const tdrl_flux_unit = UnitSignature((1, 2, -2, -1, 0, 0, 0))
const tdrl_coordinate_type = PhysicalType(:physical_coordinate_map, 1, 3,
    TemporalTypeV1(static_time), tdrl_length_unit)
const tdrl_metric_type = PhysicalType(:covariant_metric, 2, 3,
    TemporalTypeV1(static_time), tdrl_metric_unit)
const tdrl_law_type = PhysicalType(:manufactured_region_scalar, 0, 3,
    TemporalTypeV1(static_time), tdrl_unit)

function tdrl_manifest(id::String, role::Symbol; effects=())
    rule = SameTypeVariadicRuleV1(1, 1)
    OperatorManifestV1(OperatorRefV1(id, "v1"), 1, 1, rule, rule;
        allowed_roles=(role,), locality=role === :boundary ? :boundary : :local,
        allowed_conservation_effects=effects)
end

const tdrl_ops = let registry = default_operator_registry()
    registry = register_operator(registry,
        tdrl_manifest("TDRL_CONSTITUTIVE", :governing))
    registry = register_operator(registry,
        tdrl_manifest("TDRL_SOURCE", :source; effects=(:net_creation,)))
    register_operator(registry, tdrl_manifest("TDRL_BOUNDARY", :boundary))
end

function tdrl_program(id::String)
    input = ASTInputV1(1, tdrl_law_type)
    root = ASTApplyV1(OperatorRefV1(id, "v1"), (1,), (;);
        registry=tdrl_ops, input_types=(tdrl_law_type,))
    TypedASTProgramV1((input, root), (2,), (1,); registry=tdrl_ops)
end

const tdrl_coordinate_site = FieldOperatorSiteRefV1("tdrl-coordinate-root")
const tdrl_metric_site = FieldOperatorSiteRefV1("tdrl-metric-root")
const tdrl_coordinate_ast = ast_leaf(:constant, tdrl_coordinate_type;
    parameters=(value=(0.0, 0.0, 0.0),))
const tdrl_metric_ast = ast_leaf(:constant, tdrl_metric_type;
    parameters=(value=(1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0),))
const tdrl_ledger = ConservationLedgerIdentityV1(
    QualifiedRefV1("manufactured-region-source", "v1"),
    digest256_text("tdrl-manufactured-source-ontology"), tdrl_unit)
const tdrl_source_effect = PortAccountEffectV1(
    ConservationAccountRefV1(tdrl_ledger, :output, 1, :plus), 1 // 1)
const tdrl_constitutive_edge = AtomicMIMOHyperedgeV1("tdrl-constitutive-edge",
    (MIMOInputBindingV1(1, 3),), (MIMOOutputBindingV1(1, 3),),
    tdrl_program("TDRL_CONSTITUTIVE"), governing; registry=tdrl_ops)
const tdrl_source_edge = AtomicMIMOHyperedgeV1("tdrl-source-edge",
    (MIMOInputBindingV1(1, 3),), (MIMOOutputBindingV1(1, 4),),
    tdrl_program("TDRL_SOURCE"), source;
    account_effects=(tdrl_source_effect,), registry=tdrl_ops)
const tdrl_boundary_edge = AtomicMIMOHyperedgeV1("tdrl-boundary-edge",
    (MIMOInputBindingV1(1, 3),), (MIMOOutputBindingV1(1, 5),),
    tdrl_program("TDRL_BOUNDARY"), boundary; registry=tdrl_ops)
const tdrl_field_graph = TypedOperatorHypergraphV1(
    (node(:coordinate, tdrl_coordinate_type; id="tdrl-coordinate"),
     node(:metric, tdrl_metric_type; id="tdrl-metric"),
     node(:region, tdrl_law_type; id="tdrl-plasma-region"),
     node(:source, tdrl_law_type; id="tdrl-heating-source"),
     node(:boundary, tdrl_law_type; id="tdrl-wall-boundary")),
    (TypedHyperedge(tdrl_coordinate_site.value, (), (1,),
         tdrl_coordinate_ast, :constraint),
     TypedHyperedge(tdrl_metric_site.value, (), (2,),
         tdrl_metric_ast, :constraint),
     tdrl_constitutive_edge, tdrl_source_edge, tdrl_boundary_edge);
    registry=tdrl_ops)
const tdrl_prebinding = TDRL._make_forward_graph_binding(
    :field_geometry, tdrl_field_graph)
const tdrl_declaration = TDRL.declare_three_d_region_laws(tdrl_prebinding;
    declaration_id="tdrl-manufactured-region-laws",
    region_node_id="tdrl-plasma-region",
    constitutive_edge_id="tdrl-constitutive-edge",
    source_edge_id="tdrl-source-edge",
    boundary_edge_id="tdrl-boundary-edge")

const tdrl_chart_bounds = ntuple(_ -> QuantityIntervalV1(
    ExactFiniteIntervalV1(-1, 1, false), tdrl_unit), 3)
const tdrl_support_ref = SpatialSupportRefV1("tdrl-support")
const tdrl_chart_ref = ChartRefV1("tdrl-chart")
const tdrl_support = SpatialSupportGeneV1(tdrl_support_ref, 3,
    (CoordinateFrameRefV1("tdrl-frame"),),
    (CoordinateChartGeneV1(tdrl_chart_ref, CoordinateFrameRefV1("tdrl-frame"),
        tdrl_chart_bounds, (),
        SpatialProgramRootRefV1(tdrl_coordinate_site, 1,
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1()),
        SpatialProgramRootRefV1(tdrl_metric_site, 1,
            chart_coordinate_type_v1(), normalized_covariant_metric_type_v1())),),
    (), NonnegativeQuantityV1(1, tdrl_length_unit))
const tdrl_coordinate_metric = TDRL.ThreeDCoordinateMetricV4(
    tdrl_support_ref, tdrl_chart_ref, tdrl_coordinate_site, tdrl_metric_site,
    tdrl_prebinding.ast_root_identity_hashes[1],
    tdrl_prebinding.ast_root_identity_hashes[2], tdrl_coordinate_type,
    tdrl_metric_type, tdrl_chart_bounds)
const tdrl_fourier_boundary = TDRL.ThreeDFourierBoundaryV4(
    "tdrl-manufactured-fourier-boundary", 5, true,
    (TDRL.ThreeDFourierCoefficientV4(0, 0, 5.5),
     TDRL.ThreeDFourierCoefficientV4(1, 0, 0.5)),
    (TDRL.ThreeDFourierCoefficientV4(1, 0, 0.5),))
const tdrl_radial_domain = QuantityIntervalV1(
    ExactFiniteIntervalV1(0, 1, false), tdrl_unit)
const tdrl_pressure = TDRL.ThreeDRadialProfileV4("tdrl-pressure", :pressure,
    (1000.0, -1000.0), tdrl_pressure_unit, tdrl_radial_domain)
const tdrl_iota = TDRL.ThreeDRadialProfileV4("tdrl-iota", :iota,
    (0.4, 0.1), tdrl_unit, tdrl_radial_domain)
const tdrl_profiles = TDRL.ThreeDProfilesFluxV4("tdrl-profiles",
    tdrl_pressure, tdrl_iota, 1.0, tdrl_flux_unit)
const tdrl_input = TDRL.ThreeDPhysicalProviderInputV4(
    "tdrl-manufactured-geometry-profile", tdrl_fourier_boundary,
    tdrl_coordinate_metric, tdrl_profiles)

const tdrl_base = TDRLG.DeclaredFixtureDependency
const tdrl_field_genome = FieldGeometryGenomeV4(20260910,
    TDRLG._fixture_refs[2], tdrl_field_graph;
    fields=(tdrl_support, tdrl_input, tdrl_declaration))
const tdrl_candidate = CandidateStatePackageV4(
    "tdrl-manufactured-region-law-candidate", tdrl_base._fixture_mission,
    tdrl_base._fixture_mechanism, tdrl_field_genome,
    tdrl_base._fixture_realization, tdrl_registry)
const tdrl_scenario = (name="tdrl-manufactured-scenario",
    fixture="compiler-only")
const tdrl_mission = (mission="typed-three-d-region-law-compiler",
    contract=tdrl_candidate.mission_contract_ref)
const tdrl_bounds = (scope="manufactured-region-law-only",
    declaration_hash=canonical_hash(tdrl_declaration))
const tdrl_comparison = ("typed-three-d-region-law-compiler",)
const tdrl_scenarios = (tdrl_scenario.name,)
const tdrl_compiled = TDRL.compile_candidate(tdrl_candidate, tdrl_registry;
    mission_payload=tdrl_mission, bounds_payload=tdrl_bounds,
    comparison_scope=tdrl_comparison, scenario_scope=tdrl_scenarios)
const tdrl_binding = TDRL.make_three_d_region_law_binding(tdrl_compiled,
    tdrl_registry, tdrl_mission, tdrl_bounds, tdrl_comparison,
    tdrl_scenarios, tdrl_scenario, tdrl_declaration)
const tdrl_subject = TDRL.ExecutablePhysicalSubjectV4(tdrl_compiled.prefix_hash,
    tdrl_candidate.canonical_hashes.genome_bundle_hash,
    tdrl_compiled.minimality_scope.mission_hash,
    tdrl_compiled.minimality_scope.bounds_hash, (tdrl_binding,),
    (tdrl_scenario,),
    (materialization="manufactured-region-law-compiler-only",
     declaration_hash=canonical_hash(tdrl_declaration),
     binding_hash=canonical_hash(tdrl_binding)),
    TDRL.derive_capability_obligations(tdrl_compiled))
const tdrl_context = TDRL.make_forward_chain_context(tdrl_candidate,
    tdrl_compiled, tdrl_registry, tdrl_mission, tdrl_bounds,
    tdrl_comparison, tdrl_scenarios, tdrl_subject, tdrl_scenario)
const tdrl_resolution = TDRL.compile_three_d_region_laws(tdrl_context)

if abspath(PROGRAM_FILE) == @__FILE__
    println("generic_status=", tdrl_generic_resolution.status)
    println("generic_gaps=", join(tdrl_generic_resolution.recoverable_gaps, ","))
    println("manufactured_status=", tdrl_resolution.status)
    println("subject_binding_hash=", tdrl_resolution.binding_hash)
    println("compiled_law_roots=", length(tdrl_resolution.compiled_law_root_hashes))
    println("remaining_gaps=", join(tdrl_resolution.recoverable_gaps, ","))
    println("provider_executed=false")
    println("emits_evidence=false")
    println("grants_pass=false")
    println("terminal_authority=false")
end
