using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_conservative_multiregion_execution.jl"))

const M = ConservativeMultiRegionRuntime
const CMR_H = digest256_text("cmr-adversarial-hash")

function cmr_plan_for(; balances=cmr_balances, coefficients=cmr_coefficients,
        protocol=cmr_protocol, providers=(cmr_provider,))
    M.admit_conservative_multiregion_plan(cmr_context, cmr_contract,
        balances, coefficients, protocol, providers)
end

function forge_cmr_context(context; context_hash=context.context_hash)
    M.ForwardChainContextV4(M._FORWARD_CHAIN_CONTEXT_TOKEN,
        context.candidate, context.compiled, context.registry,
        context.mission_payload, context.bounds_payload, context.comparison_scope,
        context.scenario_scope, context.subject, context.scenario,
        context.genome_bindings, context.obligations, context.candidate_hash,
        context.registry_hash, context.scenario_hash, context.obligation_hashes,
        context_hash)
end

function forge_cmr_contract(contract; context_hash=contract.context_hash,
        regions=contract.regions, interfaces=contract.interfaces,
        external_owners=contract.external_owners,
        capability=contract.capability, contract_hash=contract.contract_hash)
    M.ConservativeMultiRegionContractV4(M._CMR_TOKEN, context_hash,
        contract.region_specs, contract.interface_specs, regions, interfaces,
        external_owners, capability, contract_hash)
end

function forge_cmr_plan(plan; matrix=plan.assembled_matrix,
        balances=plan.balances, coefficients=plan.interface_coefficients,
        input_hash=plan.execution_input_hash, plan_hash=plan.plan_hash)
    M.ConservativeMultiRegionPlanV4(M._CMR_TOKEN, plan.context_hash,
        plan.contract_hash, balances, coefficients, plan.protocol, plan.provider,
        matrix, plan.right_hand_side, input_hash, plan_hash)
end

function forge_cmr_receipt(receipt; result=receipt.result,
        receipt_hash=receipt.receipt_hash)
    M.ConservativeMultiRegionReceiptV4(M._CMR_TOKEN, receipt.context_hash,
        receipt.contract_hash, receipt.plan_hash, receipt.execution_input_hash,
        receipt.provider_manifest_hash, result, receipt.claim_ceiling,
        receipt.model_class, receipt_hash)
end

@testset "candidate-bound typed multi-region ownership" begin
    @test M.validate_forward_chain_context(cmr_context) == cmr_context.context_hash
    @test cmr_contract_resolution.status === :ready
    @test isempty(cmr_contract_resolution.recoverable_gaps)
    @test canonical_hash(cmr_contract_resolution) == cmr_contract_resolution.resolution_hash
    @test M.validate_conservative_multiregion_contract(cmr_context,
        cmr_contract) === cmr_contract
    @test canonical_hash(cmr_contract) == cmr_contract.contract_hash
    @test cmr_contract.context_hash == cmr_context.context_hash
    @test length(cmr_contract.regions) == 2
    @test all(r -> !isempty(r.nodes), cmr_contract.regions)
    @test Tuple(r.region_id for r in cmr_contract.regions) == ("left", "right")
    @test all(n -> n isa M.ConservativeTypedNodeRefV4,
        (n for r in cmr_contract.regions for n in r.nodes))
    @test all(n -> n.graph_binding_hash ==
        canonical_hash(M.forward_graph_binding(cmr_context, :mechanism)),
        (n for r in cmr_contract.regions for n in r.nodes))
    @test Set(n.node_identity_hash for r in cmr_contract.regions for n in r.nodes) ==
        Set(M.forward_graph_binding(cmr_context, :mechanism).node_identity_hashes)
    @test length(cmr_contract.interfaces) == 1
    interface_ref = only(cmr_contract.interfaces)
    @test interface_ref.edge_ref.edge_role === interface
    @test interface_ref.minus_coefficient == -1 // 1
    @test interface_ref.plus_coefficient == 1 // 1
    @test interface_ref.minus_coefficient == -interface_ref.plus_coefficient
    @test interface_ref.minus_node_ref.node_id == "cmr-left-state"
    @test interface_ref.plus_node_ref.node_id == "cmr-right-state"
    @test interface_ref.ledger_identity.unit == cmr_unit
    @test length(cmr_contract.external_owners) == 3
    @test count(o -> o.edge_ref.edge_role === source,
        cmr_contract.external_owners) == 1
    @test count(o -> o.edge_ref.edge_role === boundary,
        cmr_contract.external_owners) == 2
    @test length(unique(o.owner_hash for o in cmr_contract.external_owners)) == 3
    @test all(o -> count(r -> canonical_hash(r) == o.region_ref_hash,
        cmr_contract.regions) == 1, cmr_contract.external_owners)
    @test all(o -> o.node_ref.physical_type.units == o.ledger_identity.unit,
        cmr_contract.external_owners)
    @test cmr_contract.capability.evidence_level == screen_only
    @test cmr_contract.capability.interface_relation ==
        "exact_opposite_typed_flux_pairs"
end

@testset "one global non-diagonal residual really executes coupling" begin
    @test cmr_plan_resolution.status === :ready
    @test canonical_hash(cmr_plan_resolution) == cmr_plan_resolution.resolution_hash
    @test M.validate_conservative_multiregion_plan(cmr_context, cmr_contract,
        cmr_plan) == cmr_plan.plan_hash
    @test cmr_plan.assembled_matrix == ((2.5, -0.5), (-0.5, 3.5))
    @test cmr_plan.right_hand_side == (1.0, 2.0)
    @test cmr_receipt.result.status === :pass
    @test cmr_receipt.result.off_diagonal_nonzeros == 2
    @test length(cmr_receipt.result.iteration_trace) == 2
    first_iteration = first(cmr_receipt.result.iteration_trace)
    @test first_iteration.state == (1.0, -1.0)
    @test first_iteration.global_residual == (2.0, -6.0)
    @test first_iteration.residual_inf == 6.0
    @test cmr_receipt.result.final_global_residual == (0.0, 0.0)
    @test cmr_receipt.result.interface_conservation_defect == 0.0
    @test M.validate_conservative_multiregion_result(cmr_contract, cmr_plan,
        cmr_receipt.result) == cmr_receipt.result.result_hash
    @test M.validate_conservative_multiregion_receipt(cmr_context, cmr_contract,
        cmr_plan, cmr_receipt) == cmr_receipt.receipt_hash
    @test cmr_receipt.claim_ceiling == screen_only
    @test cmr_receipt.model_class === :manufactured_control
    @test cmr_receipt.provider_manifest_hash == cmr_provider.manifest_hash
end

@testset "empty or incomplete structure is only a recoverable gap" begin
    no_regions = M.resolve_conservative_multiregion_contract(cmr_context, (), ())
    @test no_regions.status === :recoverable_gap
    @test no_regions.contract === nothing
    @test !isempty(no_regions.recoverable_gaps)
    @test !occursin("unsupported", join(no_regions.recoverable_gaps))
    one_region = M.resolve_conservative_multiregion_contract(cmr_context,
        (first(cmr_region_specs),), cmr_interface_specs)
    @test one_region.status === :recoverable_gap
    no_channel = M.resolve_conservative_multiregion_contract(cmr_context,
        cmr_region_specs, ())
    @test no_channel.status === :recoverable_gap
    missing_edge_spec = (M.ConservativeInterfaceSpecV4("missing", "absent-edge",
        "left", "right", cmr_ledger("cmr-interface-flux")),)
    missing_edge = M.resolve_conservative_multiregion_contract(cmr_context,
        cmr_region_specs, missing_edge_spec)
    @test missing_edge.status === :recoverable_gap
    @test occursin("missing interface capability edge",
        only(missing_edge.recoverable_gaps))
    @test canonical_hash(missing_edge) == missing_edge.resolution_hash
    @test_throws ArgumentError M.ConservativeRegionSpecV4("empty", ())
    @test_throws ArgumentError M.ConservativeInterfaceSpecV4("same", "edge",
        "left", "left", cmr_ledger("cmr-interface-flux"))
end

@testset "ownership, pair, channel, and unit adversaries fail closed" begin
    overlapping_regions = (
        M.ConservativeRegionSpecV4("left", ("cmr-left-state",)),
        M.ConservativeRegionSpecV4("right", ("cmr-left-state",)))
    @test M.resolve_conservative_multiregion_contract(cmr_context,
        overlapping_regions, cmr_interface_specs).status === :recoverable_gap

    missing_node_regions = (
        M.ConservativeRegionSpecV4("left", ("cmr-left-state",)),
        M.ConservativeRegionSpecV4("right", ("absent-state",)))
    @test M.resolve_conservative_multiregion_contract(cmr_context,
        missing_node_regions, cmr_interface_specs).status === :recoverable_gap

    reversed = (M.ConservativeInterfaceSpecV4("left-right-flux",
        "cmr-interface-edge", "right", "left",
        cmr_ledger("cmr-interface-flux")),)
    @test M.resolve_conservative_multiregion_contract(cmr_context,
        cmr_region_specs, reversed).status === :recoverable_gap

    wrong_ledger = (M.ConservativeInterfaceSpecV4("left-right-flux",
        "cmr-interface-edge", "left", "right", cmr_ledger("wrong-ledger")),)
    @test M.resolve_conservative_multiregion_contract(cmr_context,
        cmr_region_specs, wrong_ledger).status === :recoverable_gap

    wrong_unit_ledger = ConservationLedgerIdentityV1(
        QualifiedRefV1("cmr-interface-flux", "v1"),
        digest256_text("cmr-ontology-cmr-interface-flux"),
        UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    wrong_unit = (M.ConservativeInterfaceSpecV4("left-right-flux",
        "cmr-interface-edge", "left", "right", wrong_unit_ledger),)
    @test M.resolve_conservative_multiregion_contract(cmr_context,
        cmr_region_specs, wrong_unit).status === :recoverable_gap

    duplicate_pair_specs = (cmr_interface_specs[1],
        M.ConservativeInterfaceSpecV4("duplicate", "cmr-interface-edge",
            "left", "right", cmr_ledger("cmr-interface-flux")))
    @test M.resolve_conservative_multiregion_contract(cmr_context,
        cmr_region_specs, duplicate_pair_specs).status === :recoverable_gap

    @test_throws ArgumentError M.make_conservative_region_balance(cmr_contract,
        "missing"; diagonal=1.0, external_values=())
    @test_throws ArgumentError M.make_conservative_region_balance(cmr_contract,
        "left"; diagonal=0.0, external_values=cmr_external_values[1:2])
    balance = first(cmr_balances)
    forged_rhs = balance.right_hand_side + 1.0
    forged_body = (revision=M._CMR_REVISION,
        region_ref_hash=balance.region_ref_hash, diagonal=balance.diagonal,
        right_hand_side=forged_rhs, initial_value=balance.initial_value,
        unit=balance.unit,
        external_value_hashes=Tuple(canonical_hash(v) for v in balance.external_values))
    forged_balance = M.ConservativeRegionBalanceV4(M._CMR_TOKEN,
        balance.region_ref_hash, balance.diagonal, forged_rhs,
        balance.initial_value, balance.unit, balance.external_values,
        canonical_hash(forged_body))
    @test_throws ArgumentError M._cmr_validate_balance(cmr_contract, forged_balance)
    @test_throws ArgumentError M.make_conservative_interface_coefficient(
        cmr_contract, "missing"; coefficient=1.0)
    @test_throws ArgumentError M.make_conservative_interface_coefficient(
        cmr_contract, "left-right-flux"; coefficient=0.0)
end

@testset "missing, ambiguous, and foreign provider are recoverable" begin
    absent = cmr_plan_for(; providers=())
    @test absent.status === :recoverable_gap
    @test absent.plan === nothing
    @test occursin("provider_gap", only(absent.recoverable_gaps))
    @test !occursin("unsupported", only(absent.recoverable_gaps))
    @test canonical_hash(absent) == absent.resolution_hash

    ambiguous = cmr_plan_for(; providers=(cmr_provider, cmr_provider))
    @test ambiguous.status === :recoverable_gap
    @test occursin("more than one exact provider", only(ambiguous.recoverable_gaps))

    foreign = M.ProviderManifestV4(cmr_contract.capability.schema,
        cmr_contract.capability.revision, cmr_contract.capability.kind,
        cmr_contract.capability,
        (bounds_hash=cmr_contract.capability.applicability_bounds,
         context_hash=cmr_contract.context_hash,
         contract_hash=cmr_contract.contract_hash,
         model_class="manufactured_control"),
        "foreign-backend", "v1", CMR_H, "foreign-control", screen_only;
        input_schema_hash=cmr_contract.capability.input_schema_hash)
    foreign_resolution = cmr_plan_for(; providers=(foreign,))
    @test foreign_resolution.status === :recoverable_gap
    @test occursin("exact local provider", only(foreign_resolution.recoverable_gaps))

    @test_throws ArgumentError cmr_plan_for(; balances=reverse(cmr_balances))
    @test_throws ArgumentError cmr_plan_for(; balances=())
    @test_throws ArgumentError cmr_plan_for(; coefficients=())
end

@testset "content-addressed cache and deterministic fresh replay" begin
    cached = M.execute_conservative_multiregion!(cmr_store, cmr_context,
        cmr_contract, cmr_plan)
    @test cached === cmr_receipt
    verified = M.verify_conservative_multiregion_cache(cmr_store, cmr_context,
        cmr_contract, cmr_plan)
    @test verified === cmr_receipt
    @test cmr_replay.result.result_hash == cmr_receipt.result.result_hash
    @test cmr_replay.receipt_hash == cmr_receipt.receipt_hash

    changed_source = M.make_conservative_external_value(cmr_contract,
        "cmr-source-edge", :output, 1; value=1.25)
    changed_balances = (
        M.make_conservative_region_balance(cmr_contract, "left";
            diagonal=2.0,
            external_values=(changed_source, cmr_external_values[2]),
            initial_value=1.0),
        cmr_balances[2])
    changed_plan = something(cmr_plan_for(; balances=changed_balances).plan)
    @test changed_plan.execution_input_hash != cmr_plan.execution_input_hash
    @test changed_plan.plan_hash != cmr_plan.plan_hash
    changed_coefficient = (M.make_conservative_interface_coefficient(cmr_contract,
        "left-right-flux"; coefficient=0.75),)
    coefficient_plan = something(cmr_plan_for(; coefficients=changed_coefficient).plan)
    @test coefficient_plan.assembled_matrix != cmr_plan.assembled_matrix
    @test coefficient_plan.execution_input_hash != cmr_plan.execution_input_hash

    @test_throws ArgumentError M.verify_conservative_multiregion_cache(
        Dict{Digest256,Any}(), cmr_context, cmr_contract, cmr_plan)
    bad_cache = Dict{Digest256,Any}(cmr_plan.execution_input_hash => :foreign)
    @test_throws ArgumentError M.verify_conservative_multiregion_cache(bad_cache,
        cmr_context, cmr_contract, cmr_plan)
end

@testset "numerical failure and caught unknown remain typed" begin
    strict_protocol = M.ConservativeMultiRegionProtocolV4(nextfloat(0.0), 1)
    strict_coefficient = (M.make_conservative_interface_coefficient(cmr_contract,
        "left-right-flux"; coefficient=0.1),)
    strict_plan = something(cmr_plan_for(; protocol=strict_protocol,
        coefficients=strict_coefficient).plan)
    strict_receipt = M.execute_conservative_multiregion!(
        Dict{Digest256,M.ConservativeMultiRegionReceiptV4}(), cmr_context,
        cmr_contract, strict_plan)
    @test strict_receipt.result.status === :numerical_fail
    @test M.validate_conservative_multiregion_receipt(cmr_context, cmr_contract,
        strict_plan, strict_receipt) == strict_receipt.receipt_hash

    overflow_balances = (
        M.make_conservative_region_balance(cmr_contract, "left";
            diagonal=floatmax(Float64),
            external_values=cmr_external_values[1:2],
            initial_value=floatmax(Float64)),
        cmr_balances[2])
    overflow_plan = something(cmr_plan_for(; balances=overflow_balances).plan)
    unknown_receipt = M.execute_conservative_multiregion!(
        Dict{Digest256,M.ConservativeMultiRegionReceiptV4}(), cmr_context,
        cmr_contract, overflow_plan)
    @test unknown_receipt.result.status === :unknown
    @test isempty(unknown_receipt.result.iteration_trace)
    @test isempty(unknown_receipt.result.final_state)
    @test isempty(unknown_receipt.result.final_global_residual)
    @test occursin("nonfinite_global_residual", unknown_receipt.result.reason)
    @test M.validate_conservative_multiregion_receipt(cmr_context, cmr_contract,
        overflow_plan, unknown_receipt) == unknown_receipt.receipt_hash
end

@testset "sealed bodies and ForwardChainContext are revalidated" begin
    bad_context = forge_cmr_context(cmr_context; context_hash=CMR_H)
    @test_throws ArgumentError M.resolve_conservative_multiregion_contract(
        bad_context, cmr_region_specs, cmr_interface_specs)

    bad_contract = forge_cmr_contract(cmr_contract; context_hash=CMR_H)
    @test_throws ArgumentError canonical_hash(bad_contract)
    @test_throws ArgumentError M.validate_conservative_multiregion_contract(
        cmr_context, bad_contract)

    region = first(cmr_contract.regions)
    bad_region = M.ConservativeRegionRefV4(M._CMR_TOKEN, region.region_id,
        region.nodes, region.unit, CMR_H)
    @test_throws ArgumentError canonical_hash(bad_region)

    interface_ref = only(cmr_contract.interfaces)
    bad_interface = M.ConservativeInterfaceRefV4(M._CMR_TOKEN,
        interface_ref.interface_id, interface_ref.edge_ref,
        interface_ref.pair_position, interface_ref.pair_hash,
        interface_ref.minus_region_ref_hash, interface_ref.plus_region_ref_hash,
        interface_ref.minus_node_ref, interface_ref.plus_node_ref,
        interface_ref.ledger_identity, interface_ref.minus_coefficient,
        interface_ref.minus_coefficient, interface_ref.ref_hash)
    @test_throws ArgumentError canonical_hash(bad_interface)

    bad_matrix = ((2.5, 0.0), (0.0, 3.5))
    bad_plan = forge_cmr_plan(cmr_plan; matrix=bad_matrix)
    @test_throws ArgumentError M.validate_conservative_multiregion_plan(
        cmr_context, cmr_contract, bad_plan)

    bad_receipt = forge_cmr_receipt(cmr_receipt; receipt_hash=CMR_H)
    @test_throws ArgumentError M.validate_conservative_multiregion_receipt(
        cmr_context, cmr_contract, cmr_plan, bad_receipt)
    bad_store = Dict{Digest256,Any}(cmr_plan.execution_input_hash => bad_receipt)
    @test_throws ArgumentError M.execute_conservative_multiregion!(bad_store,
        cmr_context, cmr_contract, cmr_plan)

    @test_throws MethodError M.ConservativeRegionRefV4("foreign", (), cmr_unit,
        CMR_H)
    @test_throws MethodError M.ConservativeMultiRegionReceiptV4(
        cmr_context.context_hash, cmr_contract.contract_hash, cmr_plan.plan_hash,
        cmr_plan.execution_input_hash, cmr_provider.manifest_hash, cmr_receipt.result,
        screen_only, :manufactured_control, CMR_H)
end

@testset "authority ceiling remains manufactured screen only" begin
    manifest = M.conservative_multiregion_manifest()
    @test manifest.model_class === :manufactured_control
    @test manifest.claim_ceiling == screen_only
    @test manifest.emits_runtime_evidence == false
    @test manifest.terminal_authority == false
    @test manifest.credible_device_count == 0
    @test !hasproperty(cmr_receipt, :evidence)
    @test !hasproperty(cmr_receipt, :promotion)
    @test !hasproperty(cmr_receipt, :terminal_classification)
end
