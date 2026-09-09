"""Two-region manufactured control for ConservativeMultiRegionExecution.

The example proves typed ownership, exact opposite interface flux, and one
global non-diagonal residual iteration.  It is not physical evidence.
"""

using FusionConceptAI

module ConservativeMultiRegionRuntime
using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Contracts.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Compiler.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "Capability.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ForwardChainContext.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "ConservativeMultiRegionExecution.jl"))
end

const CMR = ConservativeMultiRegionRuntime
const cmr_unit = UnitSignature()
const cmr_type = PhysicalType(:scalar_field, 0, 0, TemporalTypeV1(static_time), cmr_unit)
const cmr_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-10, 10, false), cmr_unit)

function cmr_operator_registry()
    manifest = OperatorManifestV1(OperatorRefV1("CMR_OPEN", "v1"), 1, 1,
        SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:governing, :additive, :interface, :boundary, :source, :sink),
        allowed_conservation_effects=(:redistribution, :interface_flux,
            :net_creation, :net_destruction))
    register_operator(default_operator_registry(), manifest)
end

function cmr_program(registry)
    left = ASTApplyV1(OperatorRefV1("CMR_OPEN", "v1"), (1,), (;);
        registry=registry, input_types=(cmr_type,))
    right = ASTApplyV1(OperatorRefV1("CMR_OPEN", "v1"), (2,), (;);
        registry=registry, input_types=(cmr_type,))
    TypedASTProgramV1((ASTInputV1(1, cmr_type), ASTInputV1(2, cmr_type),
        left, right), (3, 4), (1, 2); registry=registry)
end

cmr_ledger(name) = ConservationLedgerIdentityV1(QualifiedRefV1(name, "v1"),
    digest256_text("cmr-ontology-" * name), cmr_unit)

function cmr_mechanism_payload()
    registry = cmr_operator_registry()
    program = cmr_program(registry)
    inputs = (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2))
    outputs = (MIMOOutputBindingV1(1, 1), MIMOOutputBindingV1(2, 2))
    source_ledger = cmr_ledger("cmr-source")
    boundary_ledger = cmr_ledger("cmr-boundary")
    flux_ledger = cmr_ledger("cmr-interface-flux")
    source_effect = PortAccountEffectV1(
        ConservationAccountRefV1(source_ledger, :output, 1, :plus), 1 // 1)
    boundary_effects = (
        PortAccountEffectV1(ConservationAccountRefV1(boundary_ledger,
            :output, 1, :inflow), 1 // 1),
        PortAccountEffectV1(ConservationAccountRefV1(boundary_ledger,
            :output, 2, :outflow), -1 // 1))
    pair = InterfaceFluxPairV1(
        PortAccountEffectV1(ConservationAccountRefV1(flux_ledger,
            :output, 1, :minus), -1 // 1),
        PortAccountEffectV1(ConservationAccountRefV1(flux_ledger,
            :output, 2, :plus), 1 // 1))
    source_edge = AtomicMIMOHyperedgeV1("cmr-source-edge", inputs, outputs,
        program, source; account_effects=(source_effect,), registry=registry)
    boundary_edge = AtomicMIMOHyperedgeV1("cmr-boundary-edge", inputs, outputs,
        program, boundary; account_effects=boundary_effects, registry=registry)
    interface_edge = AtomicMIMOHyperedgeV1("cmr-interface-edge", inputs, outputs,
        program, interface; interface_flux_pairs=(pair,), registry=registry)
    graph = TypedOperatorHypergraphV1(
        (node(:state, cmr_type; id="cmr-left-state"),
         node(:state, cmr_type; id="cmr-right-state")),
        (source_edge, boundary_edge, interface_edge); registry=registry)
    left_ref = StateGeneRefV1("cmr-left-state")
    right_ref = StateGeneRefV1("cmr-right-state")
    states = (
        StateGeneV1(left_ref, cmr_type, cmr_bounds, (), (), (), state_derived),
        StateGeneV1(right_ref, cmr_type, cmr_bounds, (), (), (), state_derived))
    occurrence(site, port, direction, kind, ledger) =
        ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1(site), :output,
            port, direction, kind, ledger)
    source_invariant = InvariantV1(InvariantRefV1("cmr-source-owner"),
        source_ledger, DomainConservationScopeV1((left_ref,)),
        (InvariantTermV1(left_ref, 1),),
        (occurrence("cmr-source-edge", 1, :plus,
            occurrence_source_effect, source_ledger),), 0, entropy_conserved)
    boundary_invariant = InvariantV1(InvariantRefV1("cmr-boundary-owner"),
        boundary_ledger, GlobalConservationScopeV1(),
        (InvariantTermV1(left_ref, 1), InvariantTermV1(right_ref, 1)),
        (occurrence("cmr-boundary-edge", 1, :inflow,
             occurrence_boundary_effect, boundary_ledger),
         occurrence("cmr-boundary-edge", 2, :outflow,
             occurrence_boundary_effect, boundary_ledger)),
        0, entropy_conserved)
    interface_invariant = InvariantV1(InvariantRefV1("cmr-interface-owner"),
        flux_ledger, InterfaceConservationScopeV1(
            OperatorSiteRefV1("cmr-interface-edge")),
        (InvariantTermV1(left_ref, 1), InvariantTermV1(right_ref, 1)),
        (occurrence("cmr-interface-edge", 1, :minus,
             occurrence_interface_minus, flux_ledger),
         occurrence("cmr-interface-edge", 2, :plus,
             occurrence_interface_plus, flux_ledger)),
        0, entropy_conserved)
    observable = ObservableGeneV1(ObservableRefV1("cmr-left-observable"),
        ProgramRootRefV1(OperatorSiteRefV1("cmr-source-edge"), 1, cmr_type),
        QualifiedRefV1("cmr-observation-intervention", "v1"),
        TypedASTProgramV1((ASTInputV1(1, cmr_type),
            ASTApplyV1(OperatorRefV1("CMR_OPEN", "v1"), (1,), (;);
                registry=registry, input_types=(cmr_type,))),
            (2,), (1,); registry=registry),
        cmr_bounds, QualifiedRefV1("cmr-noise", "v1"),
        NonnegativeQuantityV1(1 // 100, cmr_unit),
        NonnegativeQuantityV1(1 // 100, cmr_unit),
        NonnegativeQuantityV1(1 // 10, cmr_unit),
        (QualifiedRefV1("cmr-prediction", "v1"),))
    MechanismGenomePayloadV1(states,
        (source_invariant, boundary_invariant, interface_invariant), graph,
        (), (), (observable,), ())
end

function cmr_auxiliary_graph(registry)
    TypedOperatorHypergraphV1(
        (node(:region, cmr_type; id="cmr-declared-region"),
         node(:boundary, cmr_type; id="cmr-declared-boundary")), (),
        registry=registry)
end

const cmr_mechanism_payload_value = cmr_mechanism_payload()
const cmr_operator_registry_value = first(cmr_mechanism_payload_value.operator_graph.hyperedges).registry
const cmr_contract_refs = (
    g1_occurrence_ownership_contract_ref("urn:fusion:cmr:mechanism"),
    GenomeContractRef("urn:fusion:cmr:field", "v4",
        digest256_text("cmr-field-schema"), digest256_text("cmr-field-canon"), "runtime"),
    GenomeContractRef("urn:fusion:cmr:realization", "v4",
        digest256_text("cmr-realization-schema"), digest256_text("cmr-realization-canon"), "runtime"))
const cmr_registry = GenomeContractRegistryV4(cmr_contract_refs...)
const cmr_mechanism = MechanismGenomeV4(1, cmr_contract_refs[1], cmr_mechanism_payload_value)
const cmr_field = FieldGeometryGenomeV4(2, cmr_contract_refs[2],
    cmr_auxiliary_graph(cmr_operator_registry_value))
const cmr_realization = RealizationControlGenomeV4(3, 4, cmr_contract_refs[3],
    cmr_auxiliary_graph(cmr_operator_registry_value),
    cmr_auxiliary_graph(cmr_operator_registry_value))
const cmr_mission_ref = MissionContractRef("urn:fusion:cmr:mission", "v4",
    digest256_text("cmr-mission-schema"), digest256_text("cmr-mission-canon"))
const cmr_candidate = CandidateStatePackageV4("cmr-manufactured-candidate",
    cmr_mission_ref, cmr_mechanism, cmr_field, cmr_realization, cmr_registry)
const cmr_mission = (mission="cmr-manufactured-control", contract=cmr_mission_ref)
const cmr_bounds_payload = (scope="cmr-manufactured-control", lower=-10.0, upper=10.0)
const cmr_comparison_scope = ("cmr-typed-global-residual",)
const cmr_scenarios = ((name="cmr-nominal", fixture="manufactured"),)
const cmr_scenario_scope = ("cmr-nominal",)
const cmr_compiled = CMR.compile_candidate(cmr_candidate, cmr_registry;
    mission_payload=cmr_mission, bounds_payload=cmr_bounds_payload,
    comparison_scope=cmr_comparison_scope, scenario_scope=cmr_scenario_scope)
const cmr_subject = CMR.ExecutablePhysicalSubjectV4(cmr_compiled.prefix_hash,
    cmr_candidate.canonical_hashes.genome_bundle_hash,
    cmr_compiled.minimality_scope.mission_hash,
    cmr_compiled.minimality_scope.bounds_hash,
    ((binding_kind="cmr-manufactured-materialization",),), cmr_scenarios,
    (model="two-region-linear-balance", revision="v1"),
    CMR.derive_capability_obligations(cmr_compiled))
const cmr_context = CMR.make_forward_chain_context(cmr_candidate, cmr_compiled,
    cmr_registry, cmr_mission, cmr_bounds_payload, cmr_comparison_scope,
    cmr_scenario_scope, cmr_subject, first(cmr_scenarios))

const cmr_region_specs = (
    CMR.ConservativeRegionSpecV4("left", ("cmr-left-state",)),
    CMR.ConservativeRegionSpecV4("right", ("cmr-right-state",)))
const cmr_interface_specs = (
    CMR.ConservativeInterfaceSpecV4("left-right-flux", "cmr-interface-edge",
        "left", "right", cmr_ledger("cmr-interface-flux")),)
const cmr_contract_resolution = CMR.resolve_conservative_multiregion_contract(
    cmr_context, cmr_region_specs, cmr_interface_specs)
const cmr_contract = something(cmr_contract_resolution.contract)
const cmr_external_values = (
    CMR.make_conservative_external_value(cmr_contract, "cmr-source-edge",
        :output, 1; value=1.0),
    CMR.make_conservative_external_value(cmr_contract, "cmr-boundary-edge",
        :output, 1; value=0.0),
    CMR.make_conservative_external_value(cmr_contract, "cmr-boundary-edge",
        :output, 2; value=-2.0))
const cmr_balances = (
    CMR.make_conservative_region_balance(cmr_contract, "left";
        diagonal=2.0, external_values=cmr_external_values[1:2],
        initial_value=1.0),
    CMR.make_conservative_region_balance(cmr_contract, "right";
        diagonal=3.0, external_values=(cmr_external_values[3],),
        initial_value=-1.0))
const cmr_coefficients = (
    CMR.make_conservative_interface_coefficient(cmr_contract,
        "left-right-flux"; coefficient=0.5),)
const cmr_protocol = CMR.ConservativeMultiRegionProtocolV4(1e-12, 4)
const cmr_provider = CMR.conservative_multiregion_manifest(cmr_contract)
const cmr_plan_resolution = CMR.admit_conservative_multiregion_plan(cmr_context,
    cmr_contract, cmr_balances, cmr_coefficients, cmr_protocol, (cmr_provider,))
const cmr_plan = something(cmr_plan_resolution.plan)
const cmr_store = Dict{Digest256,CMR.ConservativeMultiRegionReceiptV4}()
const cmr_receipt = CMR.execute_conservative_multiregion!(cmr_store,
    cmr_context, cmr_contract, cmr_plan)
const cmr_replay = CMR.rerun_conservative_multiregion(cmr_context,
    cmr_contract, cmr_plan, cmr_receipt)

if abspath(PROGRAM_FILE) == @__FILE__
    println("contract_status=", cmr_contract_resolution.status)
    println("plan_status=", cmr_plan_resolution.status)
    println("result_status=", cmr_receipt.result.status)
    println("off_diagonal_nonzeros=", cmr_receipt.result.off_diagonal_nonzeros)
    println("iterations=", length(cmr_receipt.result.iteration_trace) - 1)
    println("residual_inf=", maximum(abs, cmr_receipt.result.final_global_residual))
    println("interface_conservation_defect=", cmr_receipt.result.interface_conservation_defect)
    println("fresh_replay_equal=", cmr_replay.receipt_hash == cmr_receipt.receipt_hash)
    println("claim_ceiling=", cmr_receipt.claim_ceiling)
    println("credible_device_count=", CMR.conservative_multiregion_manifest().credible_device_count)
end
