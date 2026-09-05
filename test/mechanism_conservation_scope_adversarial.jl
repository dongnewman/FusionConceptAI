using Test
using FusionConceptAI

if !isdefined(Main, :_legacy_migration_fixture)
    phaseb_source = read(joinpath(@__DIR__, "mechanism_phaseb_46_tests.jl"), String)
    include_string(Main, first(split(phaseb_source, "if get(ENV, \"FUSION_PHASEB_CHILD\"")), "mechanism_phaseb_46_tests.jl")
end

@testset "scope canonical and fresh-process authority" begin
    helper_source = read(joinpath(@__DIR__, "mechanism_hash_layers_tests.jl"), String)
    include_string(Main, first(split(helper_source, "@testset")), "mechanism_hash_layers_tests.jl")
    domain = DomainConservationScopeV1((StateGeneRefV1("z"), StateGeneRefV1("a")))
    permuted = DomainConservationScopeV1((StateGeneRefV1("a"), StateGeneRefV1("z")))
    @test canonical_json(domain) == canonical_json(permuted)
    @test canonical_hash(domain) == canonical_hash(permuted)
    hash_payload, hash_context = _hash_fixture()
    base_invariant = hash_payload.invariants[1]
    domain_invariant = InvariantV1(base_invariant.invariant_ref, base_invariant.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-a"),)), base_invariant.terms, (base_invariant.owned_ledger_occurrence_refs[1],), 0, entropy_conserved)
    domain_invariant_b = InvariantV1(InvariantRefV1("domain-scope-b"), base_invariant.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-b"),)), (InvariantTermV1(StateGeneRefV1("state-b"), 1),), (base_invariant.owned_ledger_occurrence_refs[2],), 0, entropy_conserved)
    domain_payload = MechanismGenomePayloadV1(hash_payload.states, (domain_invariant, domain_invariant_b, hash_payload.invariants[2:end]...), hash_payload.operator_graph,
        hash_payload.parameters, hash_payload.symmetries, hash_payload.observables, hash_payload.operator_holes)
    interface_edge = hash_payload.operator_graph.hyperedges[1]
    interface_edge_b = hash_payload.operator_graph.hyperedges[2]
    interface_invariant = InvariantV1(InvariantRefV1("interface-scope"), interface_edge.interface_flux_pairs[1].minus.account_ref.ledger_identity, InterfaceConservationScopeV1(OperatorSiteRefV1(interface_edge.edge_id)), base_invariant.terms, hash_payload.invariants[2].owned_ledger_occurrence_refs[1:2], 0, entropy_conserved)
    interface_invariant_b = InvariantV1(InvariantRefV1("interface-scope-b"), interface_edge_b.interface_flux_pairs[1].minus.account_ref.ledger_identity, InterfaceConservationScopeV1(OperatorSiteRefV1(interface_edge_b.edge_id)), base_invariant.terms, hash_payload.invariants[2].owned_ledger_occurrence_refs[3:4], 0, entropy_conserved)
    interface_payload = MechanismGenomePayloadV1(hash_payload.states, (hash_payload.invariants[1], interface_invariant, interface_invariant_b), hash_payload.operator_graph,
        hash_payload.parameters, hash_payload.symmetries, hash_payload.observables, hash_payload.operator_holes)
    before_global = mechanism_hash_layers(hash_payload, hash_context)
    before_domain = mechanism_hash_layers(domain_payload, hash_context)
    before_interface = mechanism_hash_layers(interface_payload, hash_context)
    scopes = (GlobalConservationScopeV1(), getfield(domain_invariant, :scope), getfield(interface_invariant, :scope))
    before_scope_json = Tuple(canonical_json(scope) for scope in scopes)
    before_scope_hash = Tuple(getfield(canonical_hash(scope), :value) for scope in scopes)
    script = raw"""
using FusionConceptAI
import FusionConceptAI
helper_source = read(only(ARGS), String)
include_string(Main, first(split(helper_source, "@testset")), "mechanism_hash_layers_tests.jl")
hash_payload, hash_context = _hash_fixture()
base_invariant = hash_payload.invariants[1]
domain_invariant = InvariantV1(base_invariant.invariant_ref, base_invariant.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-a"),)), base_invariant.terms, (base_invariant.owned_ledger_occurrence_refs[1],), 0, entropy_conserved)
domain_invariant_b = InvariantV1(InvariantRefV1("domain-scope-b"), base_invariant.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-b"),)), (InvariantTermV1(StateGeneRefV1("state-b"), 1),), (base_invariant.owned_ledger_occurrence_refs[2],), 0, entropy_conserved)
domain_payload = MechanismGenomePayloadV1(hash_payload.states, (domain_invariant, domain_invariant_b, hash_payload.invariants[2:end]...), hash_payload.operator_graph,
    hash_payload.parameters, hash_payload.symmetries, hash_payload.observables, hash_payload.operator_holes)
interface_edge = hash_payload.operator_graph.hyperedges[1]
interface_edge_b = hash_payload.operator_graph.hyperedges[2]
interface_invariant = InvariantV1(InvariantRefV1("interface-scope"), interface_edge.interface_flux_pairs[1].minus.account_ref.ledger_identity, InterfaceConservationScopeV1(OperatorSiteRefV1(interface_edge.edge_id)), base_invariant.terms, hash_payload.invariants[2].owned_ledger_occurrence_refs[1:2], 0, entropy_conserved)
interface_invariant_b = InvariantV1(InvariantRefV1("interface-scope-b"), interface_edge_b.interface_flux_pairs[1].minus.account_ref.ledger_identity, InterfaceConservationScopeV1(OperatorSiteRefV1(interface_edge_b.edge_id)), base_invariant.terms, hash_payload.invariants[2].owned_ledger_occurrence_refs[3:4], 0, entropy_conserved)
interface_payload = MechanismGenomePayloadV1(hash_payload.states, (hash_payload.invariants[1], interface_invariant, interface_invariant_b), hash_payload.operator_graph,
    hash_payload.parameters, hash_payload.symmetries, hash_payload.observables, hash_payload.operator_holes)
before_global = mechanism_hash_layers(hash_payload, hash_context)
before_domain = mechanism_hash_layers(domain_payload, hash_context)
before_interface = mechanism_hash_layers(interface_payload, hash_context)
scopes = (GlobalConservationScopeV1(), getfield(domain_invariant, :scope), getfield(interface_invariant, :scope))
before_scope_json = Tuple(canonical_json(scope) for scope in scopes)
before_scope_hash = Tuple(getfield(canonical_hash(scope), :value) for scope in scopes)
@eval FusionConceptAI begin
    canonical_json(::Any) = error("scope json poison")
    canonical_hash(::Any) = error("scope hash poison")
    semantic_view(::Any) = error("scope semantic poison")
end
@eval Base begin
    getproperty(::Main.FusionConceptAI.GlobalConservationScopeV1, ::Symbol) = error("global scope property poison")
    getproperty(::Main.FusionConceptAI.DomainConservationScopeV1, ::Symbol) = error("domain scope property poison")
    getproperty(::Main.FusionConceptAI.InterfaceConservationScopeV1, ::Symbol) = error("interface scope property poison")
    Symbol(::Main.FusionConceptAI.ConservationInvariantScopeV1) = error("scope symbol poison")
    show(::IO, ::Main.FusionConceptAI.ConservationInvariantScopeV1) = error("scope show poison")
end
@eval FusionConceptAI begin
    _g1_layer_scope_kind_global(::Any) = error("scope global helper poison")
    _g1_layer_scope_kind_domain(::Any) = error("scope domain helper poison")
    _g1_layer_scope_kind_interface(::Any) = error("scope interface helper poison")
end
@assert Tuple(canonical_json(scope) for scope in scopes) == before_scope_json
@assert Tuple(getfield(canonical_hash(scope), :value) for scope in scopes) == before_scope_hash
    after_global = mechanism_hash_layers(hash_payload, hash_context)
    after_domain = mechanism_hash_layers(domain_payload, hash_context)
    after_interface = mechanism_hash_layers(interface_payload, hash_context)
    @assert Tuple(getfield(before_global, i).value for i in 1:8) == Tuple(getfield(after_global, i).value for i in 1:8)
    @assert Tuple(getfield(before_domain, i).value for i in 1:8) == Tuple(getfield(after_domain, i).value for i in 1:8)
    @assert Tuple(getfield(before_interface, i).value for i in 1:8) == Tuple(getfield(after_interface, i).value for i in 1:8)
println("SCOPE_CLOSED_PASS")
"""
    helper_path = joinpath(@__DIR__, "mechanism_hash_layers_tests.jl")
    command = setenv(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script $helper_path`, "FUSION_SCOPE_CHILD" => "1")
    output = read(pipeline(command, stderr=stdout), String)
    @test occursin("SCOPE_CLOSED_PASS", output)
end

@testset "migration scope closure defers before payload" begin
    source, declaration, context, registry = _legacy_migration_fixture()
    resolved_result = migrate_legacy_g1(source, declaration, context, registry)
    @test resolved_result.resolution == FusionConceptAI.resolved
    base = declaration.invariants[1]
    bad_scope = InterfaceConservationScopeV1(OperatorSiteRefV1("site-a"))
    changed = InvariantV1(base.invariant_ref, base.ledger_identity, bad_scope, base.terms, tuple(base.owned_ledger_occurrence_refs..., ()..., ()...), base.tolerance_log10, base.entropy_direction)
    changed_source = LegacyMechanismGenomeV4(source.seed, source.contract_ref, source.graph,
        (changed,), source.observables)
    changed_declaration = G1LegacyMigrationDeclarationV1(declaration.mapping_ref, declaration.mode,
        declaration.source_contract_ref, canonical_hash(changed_source), declaration.target_contract_ref, declaration.states,
        (changed,), declaration.parameters, declaration.symmetries, declaration.observables,
        declaration.operator_holes, declaration.edge_completions)
    result = migrate_legacy_g1(changed_source, changed_declaration, context, registry)
    @test result.resolution == terminal_deferred
    @test result.reason == legacy_gene_semantics_unrepresentable
    @test result.genome === nothing
    @test result.mapping_hash === nothing
    outcome = FusionConceptAI._g1_migration_evaluate(changed_source, changed_declaration, context, registry)
    @test outcome.payload === nothing
    @test outcome.canonical === nothing
    @test outcome.mapping_hash === nothing
end
