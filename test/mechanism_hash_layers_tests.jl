using Test
using SHA
using JSON3
using FusionConceptAI

"""A small, real G1 payload with two interface ledgers and one closed ledger."""
function _hash_fixture(; prefix="", constant_value=1, parameter_value=0.25,
                       interface_accounts=("flux", "flux"), ledger_account="ledger",
                       reverse_collections=false, reverse_mimo=false,
                       swap_additive_attachment=false,
                       reverse_interface_pair=false, observable_root=1,
                       symmetry_sign=(1 // 1), additive_role=additive,
                       ledger_version="v1", ledger_hash=repeat("0", 64),
                       parameter_type=nothing, contract=nothing, profile=nothing)
    unit = UnitSignature()
    ptype = parameter_type === nothing ?
        PhysicalType(:scalar_parameter, 0, 0, TemporalTypeV1(static_time), unit) : parameter_type
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), ptype.units)
    registry = default_operator_registry()

    two_output_program() = begin
        parameter = ASTParameterV1(Symbol(prefix * "gain"), ptype)
        constant = ASTConstantV1(:one, constant_value, ptype)
        left = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(ptype,))
        right = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (2,), (;);
            registry=registry, input_types=(ptype,))
        nodes = (parameter, constant, left, right)
        TypedASTProgramV1(nodes, (3, 4), (); registry=registry)
    end
    sample_program() = begin
        input = ASTInputV1(1, ptype)
        apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(ptype,))
        TypedASTProgramV1((input, apply), (2,), (1,); registry=registry)
    end

    program = two_output_program()
    ledger_for(account) = ConservationLedgerIdentityV1(QualifiedRefV1(account, ledger_version), Digest256(ledger_hash), ptype.units)
    function flux_pair(account; reverse=false)
        minus_position, plus_position = reverse ? (2, 1) : (1, 2)
        minus = PortAccountEffectV1(ConservationAccountRefV1(
            ledger_for(account), :output, minus_position, :minus), -1 // 1)
        plus = PortAccountEffectV1(ConservationAccountRefV1(
            ledger_for(account), :output, plus_position, :plus), 1 // 1)
        InterfaceFluxPairV1(minus, plus)
    end
    function interface_edge(name, account; reverse=false)
        bindings = (MIMOOutputBindingV1(1, 1), MIMOOutputBindingV1(2, 2))
        bindings = reverse_mimo ? Base.reverse(bindings) : bindings
        AtomicMIMOHyperedgeV1(name, (), bindings, program, interface;
            interface_flux_pairs=(flux_pair(account; reverse=reverse),), registry=registry)
    end
    # One additive edge supplies the account used by the invariant and closes it.
    additive_effects = (
        PortAccountEffectV1(ConservationAccountRefV1(ledger_for(ledger_account), :output, 1, :inflow), 1 // 1),
        PortAccountEffectV1(ConservationAccountRefV1(ledger_for(ledger_account), :output, 2, :outflow), -1 // 1),
    )
    additive_bindings = swap_additive_attachment ?
        (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 1)) : reverse_mimo ?
        (MIMOOutputBindingV1(2, 2), MIMOOutputBindingV1(1, 1)) :
        (MIMOOutputBindingV1(1, 1), MIMOOutputBindingV1(2, 2))
    edge_a = interface_edge(prefix * "interface-a", interface_accounts[1]; reverse=reverse_interface_pair)
    edge_b = interface_edge(prefix * "interface-b", interface_accounts[2])
    edge_c = AtomicMIMOHyperedgeV1(prefix * "additive", (), additive_bindings, program, additive_role;
        account_effects=additive_effects, registry=registry)
    edges = (edge_a, edge_b, edge_c)
    nodes = (node(:state, ptype; id=prefix * "state-a"), node(:state, ptype; id=prefix * "state-b"))
    graph = reverse_collections ? TypedOperatorHypergraphV1(nodes, reverse(edges); registry=registry) :
        TypedOperatorHypergraphV1(nodes, edges; registry=registry)

    state_a = StateGeneV1(StateGeneRefV1(prefix * "state-a"), ptype, bounds, (),
        (SymmetryRefV1(prefix * "sym"),), (), state_derived)
    state_b = StateGeneV1(StateGeneRefV1(prefix * "state-b"), ptype, bounds, (), (), (), state_derived)
    states = reverse_collections ? (state_b, state_a) : (state_a, state_b)
    matrix = ExactRationalMatrixV1(((symmetry_sign,),))
    symmetry = SymmetryGeneV1(SymmetryRefV1(prefix * "sym"), QualifiedRefV1("generator", "v1"), symmetry_continuous, matrix,
        (StateSymmetryActionV1(StateGeneRefV1(prefix * "state-a"), matrix),), nothing,
        symmetry_invariant, 0 // 1)
    invariant = InvariantV1(InvariantRefV1(prefix * "invariant"), ledger_for(ledger_account),
        GlobalConservationScopeV1(), (InvariantTermV1(StateGeneRefV1(prefix * "state-a"), 1),),
        (), (), (), 0, entropy_conserved)
    sample = sample_program()
    observable = ObservableGeneV1(ObservableRefV1(prefix * "obs"),
        ProgramRootRefV1(OperatorSiteRefV1(prefix * "interface-a"), observable_root, ptype),
        QualifiedRefV1("intervention", "v1"), sample, bounds, QualifiedRefV1("noise", "v1"),
        NonnegativeQuantityV1(1 // 10, ptype.units), NonnegativeQuantityV1(1 // 10, ptype.units),
        NonnegativeQuantityV1(1 // 2, ptype.units),
        (QualifiedRefV1("prediction", "v1"), QualifiedRefV1("prediction-2", "v1")))
    condition = IdentifiabilityConditionV1(QualifiedRefV1("intervention", "v1"),
        ObservableRefV1(prefix * "obs"), NonnegativeQuantityV1(1 // 2, ptype.units),
        NonnegativeQuantityV1(1 // 10, ptype.units))
    budget = HoleComplexityBudgetV1(1, 0, 0, 0, 0, 1)
    hole = TypedOperatorHoleV1(HoleRefV1(prefix * "hole"),
        (StateGeneRefV1(prefix * "state-a"),), (ptype,), QualifiedRefV1("causal", "v1"),
        (redistribution,), (interface_flux,), budget, QualifiedRefV1("null", "v1"),
        (QualifiedRefV1("alternative", "v1"),), (condition,),
        (ObservableRefV1(prefix * "obs"),), (QualifiedRefV1("oos", "v1"),))
    parameter = ParameterGeneV1(ParameterRefV1(prefix * "gain"), ptype.units,
        ParameterTransformSpecV1(transform_linear), bounds, parameter_value)
    observables = (observable,)
    symmetries = (symmetry,)
    payload = MechanismGenomePayloadV1(states, (invariant,), graph, (parameter,), symmetries,
        observables, (hole,))
    c = contract === nothing ? GenomeContractRef("urn:fusion:hash-test", "v1", repeat("a", 64), repeat("b", 64), "g1") : contract
    p = profile === nothing ? CanonicalizationProfileV1("hash-test", "1",
        CanonicalizationBudgetV1(500_000, 50_000, 512, 8_000_000)) : profile
    payload, MechanismCanonicalizationContextV1(c, p)
end

_layer_hashes(x) = mechanism_hash_layers(x...)
_layer_wires(x) = FusionConceptAI._g1_layer_wires(x...)
_hashes_as_tuple(h) = ntuple(i -> getfield(h, i), fieldcount(typeof(h)))

@testset "G1 4.5b independent layer regression" begin
    fixture = _hash_fixture()
    payload, context = fixture
    base = mechanism_hash_layers(payload, context)
    wires = FusionConceptAI._g1_layer_wires(payload, context)
    @test fieldnames(MechanismHashLayersV1) == (:contract_hash, :canonicalization_profile_hash,
        :operator_registry_hash, :topology_hash, :operator_program_hash, :mechanism_structure_hash,
        :decorated_mechanism_hash, :candidate_subject_hash)
    @test all(x -> x isa Digest256, _hashes_as_tuple(base))
    @test length(wires) == 8
    @test all(getfield(base, i) == digest256_text(wires[i]) for i in 1:8)
    domains = ("contract", "canonicalization-profile", "operator-registry", "topology",
        "operator-program", "mechanism-structure", "decorated-mechanism", "candidate-subject")
    @test all(JSON3.read(wires[i]).domain == "fusionconceptai:v4:g1-hash:" * domains[i] * ":v1" for i in 1:8)
    @test JSON3.read(wires[4]).dependencies.contract_hash == base.contract_hash.value
    @test JSON3.read(wires[5]).dependencies.topology_hash == base.topology_hash.value
    @test JSON3.read(wires[6]).dependencies.operator_program_hash == base.operator_program_hash.value
    @test JSON3.read(wires[7]).dependencies.mechanism_structure_hash == base.mechanism_structure_hash.value
    @test JSON3.read(wires[8]).dependencies.decorated_mechanism_hash == base.decorated_mechanism_hash.value
    @test _hashes_as_tuple(base) == _hashes_as_tuple(mechanism_hash_layers(payload, context))
end

@testset "G1 layer perturbation boundaries" begin
    p, c = _hash_fixture(); b = mechanism_hash_layers(p, c)
    cases = [
        ("AST constant", _hash_fixture(constant_value=2), (false, true, true, true, true)),
        ("edge role", _hash_fixture(additive_role=governing), (false, false, true, true, true)),
        ("MIMO attachment", _hash_fixture(swap_additive_attachment=true), (true, true, true, true, true)),
        ("observable root", _hash_fixture(observable_root=2), (false, false, true, true, true)),
        ("symmetry matrix", _hash_fixture(symmetry_sign=(-1 // 1)), (false, false, false, true, true)),
        ("ledger account rename", _hash_fixture(ledger_account="renamed-ledger"), (false, false, false, true, true)),
        ("split interface ledgers", _hash_fixture(interface_accounts=("flux-a", "flux-b")), (false, false, true, true, true)),
        ("parameter type", _hash_fixture(parameter_type=PhysicalType(:scalar_parameter, 0, 0,
            TemporalTypeV1(static_time), UnitSignature((1, 0, 0, 0, 0, 0, 0)))), (false, true, true, true, true)),
    ]
    for (name, (p2, c2), expected) in cases
        x = mechanism_hash_layers(p2, c2)
        changed = ntuple(i -> getfield(b, i) != getfield(x, i), 8)
        @testset "$name" begin
            # contract/profile/registry are unchanged for payload-only perturbations.
            @test !changed[1] && !changed[2] && !changed[3]
            @test ntuple(i -> changed[i + 3], 5) == expected
        end
    end
    p2, c2 = _hash_fixture(parameter_value=0.75)
    x = mechanism_hash_layers(p2, c2)
    @test b.topology_hash == x.topology_hash
    @test b.operator_program_hash == x.operator_program_hash
    @test b.mechanism_structure_hash == x.mechanism_structure_hash
    @test b.decorated_mechanism_hash == x.decorated_mechanism_hash
    @test b.candidate_subject_hash != x.candidate_subject_hash
end

@testset "G1 alpha, collection, and ordered-field invariance" begin
    p, c = _hash_fixture(); b = mechanism_hash_layers(p, c)
    renamed, c2 = _hash_fixture(prefix="renamed-")
    r = mechanism_hash_layers(renamed, c2)
    @test _hashes_as_tuple(b)[4:8] == _hashes_as_tuple(r)[4:8]
    permuted, c3 = _hash_fixture(reverse_collections=true, reverse_mimo=true)
    q = mechanism_hash_layers(permuted, c3)
    @test _hashes_as_tuple(b)[4:8] == _hashes_as_tuple(q)[4:8]
    reversed_pair, c4 = _hash_fixture(reverse_interface_pair=true)
    s = mechanism_hash_layers(reversed_pair, c4)
    @test b.topology_hash == s.topology_hash
    @test b.operator_program_hash == s.operator_program_hash
    @test b.mechanism_structure_hash != s.mechanism_structure_hash
    @test b.decorated_mechanism_hash != s.decorated_mechanism_hash
end

@testset "G1 contract/profile/budget and sealing" begin
    p, c = _hash_fixture(); b = mechanism_hash_layers(p, c)
    changed_contract = GenomeContractRef("urn:fusion:other", "v1", repeat("c", 64), repeat("d", 64), "g1")
    x = mechanism_hash_layers(p, MechanismCanonicalizationContextV1(changed_contract, c.profile))
    @test b.contract_hash != x.contract_hash
    @test b.topology_hash != x.topology_hash
    profile2 = CanonicalizationProfileV1("hash-test-v2", "1", c.profile.budget)
    y = mechanism_hash_layers(p, MechanismCanonicalizationContextV1(c.contract_ref, profile2))
    @test b.canonicalization_profile_hash != y.canonicalization_profile_hash
    budget_only = CanonicalizationProfileV1("hash-test", "1", CanonicalizationBudgetV1(800_000, 80_000, 512, 8_000_000))
    z = mechanism_hash_layers(p, MechanismCanonicalizationContextV1(c.contract_ref, budget_only))
    @test b.canonicalization_profile_hash == z.canonicalization_profile_hash
    @test b.candidate_subject_hash == z.candidate_subject_hash
    @test_throws MethodError MechanismHashLayersV1(ntuple(_ -> Digest256(repeat("a", 64)), 8)...)
    transport = canonicalize_mechanism_transport(p, c)
    @test_throws ArgumentError CanonicalMechanismV1(transport, b)
    @test_throws CanonicalizationDeferred mechanism_hash_layers(p,
        MechanismCanonicalizationContextV1(c.contract_ref,
            CanonicalizationProfileV1("tiny", "1", CanonicalizationBudgetV1(1, 10, 1, 100))))
end

@testset "G1 registry closure, SHA wire, and 4.5a compatibility" begin
    p, c = _hash_fixture(); wires = FusionConceptAI._g1_layer_wires(p, c)
    @test all(digest256_text(wires[i]) == getfield(mechanism_hash_layers(p, c), i) for i in 1:8)
    registry_payload = JSON3.read(wires[3]).payload
    @test length(registry_payload.manifests) >= 1
    @test all(length(String(m.manifest_hash)) == 64 for m in registry_payload.manifests)
    # The old graph canonicalizer remains callable and strong payloads reject legacy edges.
    scalar = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time), UnitSignature())
    legacy_ast = TypedAST((TypedASTNode(:state, (), scalar),), 1, (1,))
    legacy_edge = TypedHyperedge("legacy", (1,), (1,), legacy_ast, :additive)
    legacy_graph = TypedOperatorHypergraphV1((node(:state, scalar; id="legacy-state"),), (legacy_edge,))
    @test canonical_hash(legacy_graph) isa Digest256
    @test_throws ArgumentError MechanismGenomePayloadV1((), (), legacy_graph, (), (), (), ())
end

@testset "G1 cross-process constructor injection" begin
    julia = Base.julia_cmd()
    code = "using FusionConceptAI; d=Digest256(repeat(\"a\",64)); try FusionConceptAI.MechanismHashLayersV1(d,d,d,d,d,d,d,d); print(\"forged\") catch e; print(typeof(e)) end"
    output = read(`$julia --project=. -e $code`, String)
    @test occursin("MethodError", output)
end
