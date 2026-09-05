using Test
using FusionConceptAI
import FusionConceptAI

@testset "exact ledger identity closure and layer boundaries" begin
    payload = _exact_ref_payload()
    identity = payload.invariants[1].ledger_identity
    terms = payload.invariants[1].terms
    same_id_wrong_version = ConservationLedgerIdentityV1(
        QualifiedRefV1(identity.account_kind_ref.id, "v2"), identity.ontology_hash, identity.unit)
    wrong_hash = ConservationLedgerIdentityV1(identity.account_kind_ref, Digest256(repeat("b", 64)), identity.unit)
    wrong_id = ConservationLedgerIdentityV1(QualifiedRefV1("other-energy", identity.account_kind_ref.version), identity.ontology_hash, identity.unit)
    wrong_unit = ConservationLedgerIdentityV1(identity.account_kind_ref, identity.ontology_hash,
        UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    for bad in (wrong_id, same_id_wrong_version, wrong_hash, wrong_unit)
        invariant = InvariantV1(InvariantRefV1("bad"), bad, GlobalConservationScopeV1(), terms, tuple(()..., ()..., ()...), 0, entropy_conserved)
        @test_throws ArgumentError MechanismGenomePayloadV1(payload.states, (invariant,),
            payload.operator_graph, payload.parameters, payload.symmetries, payload.observables,
            payload.operator_holes)
    end
    interface_payload, _ = _hash_fixture()
    @test FusionConceptAI._g1_payload_ledger_ownership_closure(
        interface_payload.invariants, interface_payload.states, interface_payload.operator_graph)
    @test any(arc -> arc[3] == "invariant_to_ledger",
        FusionConceptAI._g1_layer_extended_incidence(payload, :decorated).arcs)
    @test !any(arc -> arc[3] == "invariant_to_ledger",
        FusionConceptAI._g1_layer_extended_incidence(payload, :topology).arcs)
end

@testset "unit identity follows endpoint physical type" begin
    base_payload, base_context = _hash_fixture()
    changed_unit = UnitSignature((1, 0, 0, 0, 0, 0, 0))
    wrong_endpoint_identity = ConservationLedgerIdentityV1(
        QualifiedRefV1("ledger", "v1"), Digest256(repeat("0", 64)), changed_unit)
    wrong_effect = PortAccountEffectV1(ConservationAccountRefV1(wrong_endpoint_identity, :output, 1, :inflow), 1 // 1)
    edge = base_payload.operator_graph.hyperedges[3]
    @test_throws ArgumentError AtomicMIMOHyperedgeV1(edge.edge_id, edge.input_bindings, edge.output_bindings,
        edge.program, edge.role; account_effects=(wrong_effect,), registry=edge.registry)
end

@testset "fresh-process closed identity authority" begin
    script = raw"""
using FusionConceptAI
import FusionConceptAI
u = UnitSignature(); d = Digest256("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
x = ConservationLedgerIdentityV1(QualifiedRefV1("ab", "c"), d, u)
y = ConservationLedgerIdentityV1(QualifiedRefV1("a", "bc"), d, u)
w = FusionConceptAI._ledger_identity_wire(x); k = FusionConceptAI._ledger_identity_full_key(x); h = FusionConceptAI._ledger_identity_hash(x)
cw = canonical_json(x); ch = canonical_hash(x)
@eval FusionConceptAI begin
    semantic_view(::Any) = error("semantic poison")
    canonical_json(::Any) = error("json poison")
    canonical_hash(::Any) = error("hash poison")
end
@eval Base begin
    (==)(::Main.FusionConceptAI.ConservationLedgerIdentityV1, ::Main.FusionConceptAI.ConservationLedgerIdentityV1) = error("equality poison")
    getproperty(::Main.FusionConceptAI.ConservationLedgerIdentityV1, ::Symbol) = error("identity property poison")
    getproperty(::Main.FusionConceptAI.QualifiedRefV1, ::Symbol) = error("ref property poison")
    getproperty(::Main.FusionConceptAI.Digest256, ::Symbol) = error("digest property poison")
    getproperty(::Main.FusionConceptAI.UnitSignature, ::Symbol) = error("unit property poison")
end
@assert FusionConceptAI._ledger_identity_wire(x) == w
@assert FusionConceptAI._ledger_identity_full_key(x) == k
@assert getfield(FusionConceptAI._ledger_identity_hash(x), :value) == getfield(h, :value)
@assert canonical_json(x) == cw
@assert getfield(canonical_hash(x), :value) == getfield(ch, :value)
@assert FusionConceptAI._ledger_identity_full_key(x) != FusionConceptAI._ledger_identity_full_key(y)
@assert FusionConceptAI._ledger_identity_wire(x) != FusionConceptAI._ledger_identity_wire(y)
println("LEDGER_CLOSED_PASS")
"""
    command = setenv(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`, "FUSION_LEDGER_CHILD" => "1")
    output = read(pipeline(command, stderr=stdout), String)
    @test occursin("LEDGER_CLOSED_PASS", output)
end

@testset "interface pair exact identity closure" begin
    payload, _ = _hash_fixture()
    edge = payload.operator_graph.hyperedges[1]
    pair = edge.interface_flux_pairs[1]
    minus = pair.minus
    plus = pair.plus
    base = minus.account_ref.ledger_identity
    identities = (
        ConservationLedgerIdentityV1(QualifiedRefV1(base.account_kind_ref.id * "-other", base.account_kind_ref.version), base.ontology_hash, base.unit),
        ConservationLedgerIdentityV1(QualifiedRefV1(base.account_kind_ref.id, "v2"), base.ontology_hash, base.unit),
        ConservationLedgerIdentityV1(base.account_kind_ref, Digest256(repeat("1", 64)), base.unit),
        ConservationLedgerIdentityV1(base.account_kind_ref, base.ontology_hash, UnitSignature((1, 0, 0, 0, 0, 0, 0))))
    for bad in identities
        bad_minus = PortAccountEffectV1(ConservationAccountRefV1(bad, :output, minus.account_ref.port_index, :minus), minus.coefficient)
        @test_throws ArgumentError InterfaceFluxPairV1(bad_minus, plus)
    end
    @test_throws ArgumentError AtomicMIMOHyperedgeV1(edge.edge_id, edge.input_bindings, edge.output_bindings,
        edge.program, edge.role; interface_flux_pairs=(pair, pair), registry=edge.registry)
    other = ConservationLedgerIdentityV1(QualifiedRefV1("other-flux", "v1"), base.ontology_hash, base.unit)
    other_pair = InterfaceFluxPairV1(
        PortAccountEffectV1(ConservationAccountRefV1(other, :output, 1, :minus), -1 // 1),
        PortAccountEffectV1(ConservationAccountRefV1(other, :output, 2, :plus), 1 // 1))
    distinct = AtomicMIMOHyperedgeV1(edge.edge_id * "-distinct", edge.input_bindings, edge.output_bindings,
        edge.program, edge.role; interface_flux_pairs=(pair, other_pair), registry=edge.registry)
    distinct_keys = Set{FusionConceptAI.ConservationLedgerKeyV1}(
        (FusionConceptAI._ledger_identity_full_key(effect.account_ref.ledger_identity)
         for pair_value in distinct.interface_flux_pairs for effect in (pair_value.minus, pair_value.plus)))
    @test length(distinct_keys) == 2
end

@testset "consistent full ledger identity rebinding changes structure" begin
    base_payload, base_context = _hash_fixture(ledger_account="ledger", ledger_version="v1", ledger_hash=repeat("0", 64))
    base_hashes = mechanism_hash_layers(base_payload, base_context)
    for kwargs in ((ledger_account="other-ledger", ledger_version="v1", ledger_hash=repeat("0", 64)),
                   (ledger_account="ledger", ledger_version="v2", ledger_hash=repeat("0", 64)),
                   (ledger_account="ledger", ledger_version="v1", ledger_hash=repeat("1", 64)))
        changed_payload, changed_context = _hash_fixture(; kwargs...)
        changed_hashes = mechanism_hash_layers(changed_payload, changed_context)
        @test changed_hashes.topology_hash == base_hashes.topology_hash
        @test changed_hashes.operator_program_hash == base_hashes.operator_program_hash
        @test changed_hashes.mechanism_structure_hash != base_hashes.mechanism_structure_hash
        @test changed_hashes.decorated_mechanism_hash != base_hashes.decorated_mechanism_hash
        @test changed_hashes.candidate_subject_hash != base_hashes.candidate_subject_hash
    end
end

@testset "migration defers every exact ledger mismatch" begin
    source, declaration, context, registry = _legacy_migration_fixture()
    resolved_result = migrate_legacy_g1(source, declaration, context, registry)
    @test resolved_result.resolution == resolved
    @test resolved_result.genome !== nothing
    @test resolved_result.mapping_hash !== nothing
    base = declaration.invariants[1]
    identities = (
        ConservationLedgerIdentityV1(QualifiedRefV1("missing-ledger", "v1"), base.ledger_identity.ontology_hash, base.ledger_identity.unit),
        ConservationLedgerIdentityV1(QualifiedRefV1("energy", "v2"), base.ledger_identity.ontology_hash, base.ledger_identity.unit),
        ConservationLedgerIdentityV1(base.ledger_identity.account_kind_ref, Digest256(repeat("f", 64)), base.ledger_identity.unit),
        ConservationLedgerIdentityV1(base.ledger_identity.account_kind_ref, base.ledger_identity.ontology_hash,
            UnitSignature((1, 0, 0, 0, 0, 0, 0))))
    for changed_identity in identities
        @test_throws ArgumentError InvariantV1(base.invariant_ref, changed_identity,
            base.scope, base.terms, base.owned_ledger_occurrence_refs,
            base.tolerance_log10, base.entropy_direction)
        changed_occurrences = Tuple(ConservationLedgerOccurrenceRefV1(
            occurrence.operator_site_ref, occurrence.port_side, occurrence.port_index,
            occurrence.direction, occurrence.occurrence_kind, changed_identity)
            for occurrence in base.owned_ledger_occurrence_refs)
        changed = InvariantV1(base.invariant_ref, changed_identity, base.scope,
            base.terms, changed_occurrences, base.tolerance_log10,
            base.entropy_direction)
        changed_source = LegacyMechanismGenomeV4(source.seed, source.contract_ref, source.graph,
            (changed,), source.observables)
        changed_source_hash = canonical_hash(changed_source)
        changed_declaration = G1LegacyMigrationDeclarationV1(declaration.mapping_ref, declaration.mode,
            declaration.source_contract_ref, changed_source_hash, declaration.target_contract_ref, declaration.states,
            (changed,), declaration.parameters, declaration.symmetries, declaration.observables,
            declaration.operator_holes, declaration.edge_completions)
        result = migrate_legacy_g1(changed_source, changed_declaration, context, registry)
        @test result.resolution == terminal_deferred
        @test result.genome === nothing
        @test result.mapping_ref == changed_declaration.mapping_ref
        @test result.source_mechanism_hash !== nothing
        @test result.mapping_hash === nothing
        @test FusionConceptAI.semantic_view(result).mechanism_subject_hash === nothing
        @test result.reason == legacy_gene_semantics_unrepresentable
        outcome = FusionConceptAI._g1_migration_evaluate(changed_source, changed_declaration, context, registry)
        @test outcome.payload === nothing
        @test outcome.canonical === nothing
        @test outcome.mapping_hash === nothing
    end
end
