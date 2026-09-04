using Test
using FusionConceptAI

"""Small valid payload used only by the adversarial layer tests."""
function _adversarial_fixture(; parameter_type=nothing, additive_role=additive,
                               interface_accounts=("flux", "flux"),
                               ledger_account="ledger", parameter_value=0.25,
                               constant_value=1)
    unit = UnitSignature()
    ptype = parameter_type === nothing ?
        PhysicalType(:scalar_parameter, 0, 0, TemporalTypeV1(static_time), unit) : parameter_type
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), ptype.units)
    registry = default_operator_registry()
    program = let
        parameter = ASTParameterV1(:gain, ptype)
        constant = ASTConstantV1(:one, constant_value, ptype)
        left = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(ptype,))
        right = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (2,), (;);
            registry=registry, input_types=(ptype,))
        TypedASTProgramV1((parameter, constant, left, right), (3, 4), (); registry=registry)
    end
    sample = let
        input = ASTInputV1(1, ptype)
        apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(ptype,))
        TypedASTProgramV1((input, apply), (2,), (1,); registry=registry)
    end
    ledger_for(account) = ConservationLedgerIdentityV1(QualifiedRefV1(account, "v1"), Digest256(repeat("0", 64)), ptype.units)
    flux_pair(account) = InterfaceFluxPairV1(
        PortAccountEffectV1(ConservationAccountRefV1(ledger_for(account), :output, 1, :minus), -1 // 1),
        PortAccountEffectV1(ConservationAccountRefV1(ledger_for(account), :output, 2, :plus), 1 // 1))
    edge(id, account; role=interface) = AtomicMIMOHyperedgeV1(id, (),
        (MIMOOutputBindingV1(1, 1), MIMOOutputBindingV1(2, 2)), program, role;
        interface_flux_pairs=(flux_pair(account),), registry=registry)
    additive_effects = (
        PortAccountEffectV1(ConservationAccountRefV1(ledger_for(ledger_account), :output, 1, :inflow), 1 // 1),
        PortAccountEffectV1(ConservationAccountRefV1(ledger_for(ledger_account), :output, 2, :outflow), -1 // 1))
    additive = AtomicMIMOHyperedgeV1("additive", (),
        (MIMOOutputBindingV1(1, 1), MIMOOutputBindingV1(2, 2)), program, additive_role;
        account_effects=additive_effects, registry=registry)
    nodes = (node(:state, ptype; id="state-a"), node(:state, ptype; id="state-b"))
    graph = TypedOperatorHypergraphV1(nodes,
        (edge("interface-a", interface_accounts[1]), edge("interface-b", interface_accounts[2]), additive);
        registry=registry)
    state_a = StateGeneV1(StateGeneRefV1("state-a"), ptype, bounds, (), (), (), state_derived)
    state_b = StateGeneV1(StateGeneRefV1("state-b"), ptype, bounds, (), (), (), state_derived)
    matrix = ExactRationalMatrixV1(((1 // 1,),))
    symmetry = SymmetryGeneV1(SymmetryRefV1("sym"), QualifiedRefV1("generator", "v1"), symmetry_continuous, matrix,
        (StateSymmetryActionV1(StateGeneRefV1("state-a"), matrix),), nothing,
        symmetry_invariant, 0 // 1)
    invariant = InvariantV1(InvariantRefV1("invariant"), ledger_for(ledger_account),
        scope_global, nothing, (InvariantTermV1(StateGeneRefV1("state-a"), 1),),
        (), (), (), 0, entropy_conserved)
    observable = ObservableGeneV1(ObservableRefV1("obs"),
        ProgramRootRefV1(OperatorSiteRefV1("interface-a"), 1, ptype),
        QualifiedRefV1("intervention", "v1"), sample, bounds, QualifiedRefV1("noise", "v1"),
        NonnegativeQuantityV1(1 // 10, ptype.units), NonnegativeQuantityV1(1 // 10, ptype.units),
        NonnegativeQuantityV1(1 // 2, ptype.units),
        (QualifiedRefV1("prediction", "v1"),))
    condition = IdentifiabilityConditionV1(QualifiedRefV1("intervention", "v1"),
        ObservableRefV1("obs"), NonnegativeQuantityV1(1 // 2, ptype.units),
        NonnegativeQuantityV1(1 // 10, ptype.units))
    hole = TypedOperatorHoleV1(HoleRefV1("hole"), (StateGeneRefV1("state-a"),), (ptype,),
        QualifiedRefV1("causal", "v1"), (redistribution,), (interface_flux,),
        HoleComplexityBudgetV1(1, 0, 0, 0, 0, 1), QualifiedRefV1("null", "v1"),
        (QualifiedRefV1("alternative", "v1"),), (condition,), (ObservableRefV1("obs"),),
        (QualifiedRefV1("oos", "v1"),))
    parameter = ParameterGeneV1(ParameterRefV1("gain"), ptype.units,
        ParameterTransformSpecV1(transform_linear), bounds, parameter_value)
    payload = MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (parameter,),
        (symmetry,), (observable,), (hole,))
    contract = GenomeContractRef("urn:fusion:adversarial", "v1", repeat("a", 64), repeat("b", 64), "g1")
    profile = CanonicalizationProfileV1("adversarial", "1",
        CanonicalizationBudgetV1(500_000, 50_000, 512, 8_000_000))
    payload, MechanismCanonicalizationContextV1(contract, profile)
end

_adversarial_hashes(x) = mechanism_hash_layers(x...)
_fields(h) = ntuple(i -> getfield(h, i), fieldcount(typeof(h)))
_profile(c, b) = MechanismCanonicalizationContextV1(c.contract_ref,
    CanonicalizationProfileV1("adversarial", "1", b))
function _deferred_message(f)
    try
        f()
        return nothing
    catch err
        err isa CanonicalizationDeferred || rethrow()
        return err.message
    end
end

# This branch is used by the parent process for a genuinely fresh Julia probe.
if get(ENV, "FUSION_HASH_ADVERSARIAL_CHILD", "0") == "1"
    payload, context = _adversarial_fixture()
    h = mechanism_hash_layers(payload, context)
    print(join((string(getfield(h, i).value) for i in 1:8), ","))
else
    @testset "G1 adversarial layer boundaries" begin
        base_payload, base_context = _adversarial_fixture()
        base = _adversarial_hashes((base_payload, base_context))

        @testset "type, attachment, and normalized-only" begin
            changed_type = _adversarial_hashes(_adversarial_fixture(parameter_type=
                PhysicalType(:scalar_parameter, 0, 0, TemporalTypeV1(static_time), UnitSignature((1, 0, 0, 0, 0, 0, 0)))))
            @test base.topology_hash == changed_type.topology_hash
            @test base.operator_program_hash != changed_type.operator_program_hash
            @test base.mechanism_structure_hash != changed_type.mechanism_structure_hash
            @test base.decorated_mechanism_hash != changed_type.decorated_mechanism_hash
            @test base.candidate_subject_hash != changed_type.candidate_subject_hash

            role = _adversarial_hashes(_adversarial_fixture(additive_role=governing))
            @test base.topology_hash == role.topology_hash
            @test base.operator_program_hash == role.operator_program_hash
            @test base.mechanism_structure_hash != role.mechanism_structure_hash
            @test base.decorated_mechanism_hash != role.decorated_mechanism_hash
            @test base.candidate_subject_hash != role.candidate_subject_hash

            normalized = _adversarial_hashes(_adversarial_fixture(parameter_value=0.75))
            @test base.topology_hash == normalized.topology_hash
            @test base.operator_program_hash == normalized.operator_program_hash
            @test base.mechanism_structure_hash == normalized.mechanism_structure_hash
            @test base.decorated_mechanism_hash == normalized.decorated_mechanism_hash
            @test base.candidate_subject_hash != normalized.candidate_subject_hash
        end

        @testset "ledger grouping versus account alpha" begin
            split = _adversarial_hashes(_adversarial_fixture(interface_accounts=("flux-a", "flux-b")))
            @test base.topology_hash == split.topology_hash
            @test base.operator_program_hash == split.operator_program_hash
            @test base.mechanism_structure_hash != split.mechanism_structure_hash

            renamed = _adversarial_hashes(_adversarial_fixture(ledger_account="renamed-ledger"))
            @test base.topology_hash == renamed.topology_hash
            @test base.operator_program_hash == renamed.operator_program_hash
            @test base.mechanism_structure_hash == renamed.mechanism_structure_hash
            @test base.decorated_mechanism_hash != renamed.decorated_mechanism_hash
        end

        @testset "each budget is a typed defer" begin
            budgets = (
                CanonicalizationBudgetV1(1, 50_000, 512, 8_000_000),
                CanonicalizationBudgetV1(500_000, 1, 512, 8_000_000),
                CanonicalizationBudgetV1(500_000, 50_000, 1, 8_000_000),
                CanonicalizationBudgetV1(500_000, 50_000, 512, 1))
            expected_messages = ("layer search budget exhausted",
                "canonicalization refinement budget exhausted",
                "layer vertex budget exhausted",
                "layer wire byte budget exhausted")
            for (budget, expected) in zip(budgets, expected_messages)
                @test _deferred_message(() -> mechanism_hash_layers(base_payload,
                    _profile(base_context, budget))) == expected
            end
        end
    end

    @testset "G1 fresh process hardening" begin
        julia = Base.julia_cmd()
        project = dirname(@__DIR__)
        fixture = replace(joinpath(@__DIR__, "mechanism_hash_layers_adversarial.jl"), "\\" => "/")
        script = "using FusionConceptAI; FusionConceptAI._g1_layer_rule(::FusionConceptAI.SameTypeVariadicRuleV1)=\"injected\"; Base.isequal(::FusionConceptAI.SameTypeVariadicRuleV1,::FusionConceptAI.SameTypeVariadicRuleV1)=false; Base.hash(::FusionConceptAI.SameTypeVariadicRuleV1,h::UInt)=xor(h,UInt(0x1234)); Base.first(::Tuple{String,FusionConceptAI.Digest256})=\"poison\"; include(raw\"$fixture\")"
        injected = read(setenv(`$julia --project=$project -e $script`, "FUSION_HASH_ADVERSARIAL_CHILD" => "1"), String)
        normal_script = "include(raw\"$fixture\")"
        normal = read(setenv(`$julia --project=$project -e $normal_script`, "FUSION_HASH_ADVERSARIAL_CHILD" => "1"), String)
        @test injected == normal
        @test length(split(normal, ',')) == 8
        @test all(length(x) == 64 for x in split(normal, ','))
    end
end
