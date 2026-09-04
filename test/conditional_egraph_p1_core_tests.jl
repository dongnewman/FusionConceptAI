using Test
using FusionConceptAI
using JSON3
using SHA

"""Small, closed, pure programs used by the P1 conditional-rewrite tests."""
function _p1_program(op::String; registry=default_operator_registry(), port=1)
    unit = UnitSignature()
    ty = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)
    input = ASTInputV1(port, ty)
    apply = ASTApplyV1(OperatorRefV1(op, "v1"), (1,), (;);
        registry=registry, input_types=(ty,))
    TypedASTProgramV1((input, apply), (2,), (1,); registry=registry)
end

function _p1_add_program(; registry=default_operator_registry())
    unit = UnitSignature()
    ty = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)
    a = ASTInputV1(1, ty)
    b = ASTInputV1(2, ty)
    add = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;);
        registry=registry, input_types=(ty, ty))
    TypedASTProgramV1((a, b, add), (3,), (1, 2); registry=registry)
end

function _p1_condition(name="eq")
    EqualityConditionRequirementV1(QualifiedRefV1(name, "v1"),
        digest256_text("checker-" * name))
end

function _p1_rule(name, lhs, rhs; condition=_p1_condition(), registry=default_operator_registry())
    WholeProgramConditionalRewriteV1(QualifiedRefV1(name, "v1"), lhs, rhs,
        (condition,), QualifiedRefV1("checker", "v1"), digest256_text("checker-v1");
        registry=registry)
end

function _p1_fixture_rules(; registry=default_operator_registry())
    id = _p1_program("IDENTITY"; registry=registry)
    neg = _p1_program("NEG"; registry=registry)
    # A non-self-inverse 3-cycle, a diamond, and a reverse-direction edge.
    r1 = _p1_rule("cycle-a", id, neg; registry=registry)
    r2 = _p1_rule("cycle-b", neg, _p1_program("SUB"; registry=registry); registry=registry)
    # Diamond sides must have the same input/root ABI; this edge is independent.
    r3 = _p1_rule("diamond", id, _p1_program("SUB"; registry=registry); registry=registry)
    ConditionalRewriteSetV1((r3, r2, r1))
end

function _p1_get(obj, name::Symbol)
    hasproperty(obj, name) || error("P1 result is missing field $(name)")
    getproperty(obj, name)
end
_p1_artifact(x) = hasproperty(x, :artifact) ? getproperty(x, :artifact) : x
_p1_throws(f) = try f(); false catch; true end

@testset "P1 conditional e-graph core" begin
    registry = default_operator_registry()
    source = _p1_program("IDENTITY"; registry=registry)
    target = _p1_program("NEG"; registry=registry)
    condition = _p1_condition()
    rule = _p1_rule("id-to-neg", source, target; condition=condition, registry=registry)
    rules = ConditionalRewriteSetV1((rule,))
    budget = ConditionalEGraphBudgetV1()

    @testset "constructors and deterministic canonical fixture" begin
        fixture_line = readline(joinpath(@__DIR__, "fixtures", "conditional_egraph_p1_core_v1.jsonl"))
        fixture = JSON3.read(fixture_line)
        @test fixture.name == "identity_to_neg"
        @test canonical_hash(source).value == String(fixture.source_program_sha256)
        @test canonical_hash(target).value == String(fixture.target_program_sha256)
        fixture_rule = _p1_rule("identity_to_neg", source, target; registry=registry)
        fixture_set = ConditionalRewriteSetV1((fixture_rule,))
        fixture_graph = _p1_artifact(derive_conditional_program_egraph(source, fixture_set, registry;
            saturation_budget=ConditionalEGraphBudgetV1(64, 4096, 32, 256)))
        fixture_fields = ((:condition_json, :condition_sha256, :condition_ncodeunits),
            (:rule_json, :rule_sha256, :rule_ncodeunits),
            (:ruleset_json, :ruleset_sha256, :ruleset_ncodeunits),
            (:graph_json, :graph_sha256, :graph_ncodeunits),
            (:equivalence_json, :equivalence_sha256, :equivalence_ncodeunits),
            (:attempt_json, :attempt_sha256, :attempt_ncodeunits))
        for (json_name, sha_name, len_name) in fixture_fields
            bytes = Vector{UInt8}(codeunits(String(fixture[json_name])))
            @test length(bytes) == Int(fixture[len_name])
            @test bytes2hex(SHA.sha256(bytes)) == String(fixture[sha_name])
        end
        @test String(fixture.condition_json) == canonical_json(fixture_rule.required_conditions[1])
        @test String(fixture.rule_json) == canonical_json(fixture_rule)
        @test String(fixture.ruleset_json) == canonical_json(fixture_set)
        @test String(fixture.graph_json) == canonical_json(fixture_graph)
        @test String(fixture.equivalence_json) == FusionConceptAI._ceg_equivalence_bytes(fixture_graph)
        @test String(fixture.attempt_json) == FusionConceptAI._ceg_attempt_bytes(fixture_graph)
        @test String(fixture.equivalence_sha256) == conditional_equivalence_hash(fixture_graph).value
        @test String(fixture.attempt_sha256) == saturation_attempt_hash(fixture_graph).value
        @test fixture.complete == true
        @test_throws ArgumentError WholeProgramConditionalRewriteV1(
            QualifiedRefV1("empty", "v1"), source, target, (),
            QualifiedRefV1("checker", "v1"), digest256_text("checker-v1"); registry=registry)
        @test _p1_throws(() -> WholeProgramConditionalRewriteV1(
            QualifiedRefV1("duplicate-condition", "v1"), source, target,
            (_p1_condition(), _p1_condition()), QualifiedRefV1("checker", "v1"),
            digest256_text("checker-v1"); registry=registry))
        @test canonical_json(rule) == canonical_json(WholeProgramConditionalRewriteV1(
            rule.rule_ref, source, target, (condition,), rule.checker_ref,
            rule.checker_contract_hash; registry=registry))
        @test canonical_hash(rule) == Digest256(bytes2hex(SHA.sha256(
            Vector{UInt8}(codeunits(canonical_json(rule))))))
        @test ConditionalEGraphBudgetV1(1, 0, 0, 0).max_programs == 1
        @test_throws ArgumentError ConditionalEGraphBudgetV1(0, 0, 0, 0)
        @test_throws ArgumentError ConditionalEGraphBudgetV1(65, 0, 0, 0)
        @test_throws ArgumentError ConditionalEGraphBudgetV1(1, 4097, 0, 0)
        @test_throws ArgumentError ConditionalEGraphBudgetV1(1, 0, 33, 0)
        @test_throws ArgumentError ConditionalEGraphBudgetV1(1, 0, 0, 257)
        @test _p1_throws(() -> ConditionalEGraphBudgetV1(big(1), 0, 0, 0))
        @test _p1_throws(() -> ConditionalEGraphBudgetV1(true, 0, 0, 0))
        @test _p1_throws(() -> ConditionalEGraphBudgetV1(1.0, 0, 0, 0))
        @test _p1_throws(() -> ConditionalRewriteSetV1((rule, rule)))
        many_rules = ntuple(i -> _p1_rule("many-" * string(i), source, target; registry=registry), 33)
        @test_throws ArgumentError ConditionalRewriteSetV1(many_rules)
        too_many_conditions = ntuple(i -> _p1_condition("condition-" * string(i)), 17)
        @test_throws ArgumentError WholeProgramConditionalRewriteV1(QualifiedRefV1("too-many", "v1"),
            source, target, too_many_conditions, rule.checker_ref, rule.checker_contract_hash; registry=registry)
        same_ref_other_digest = EqualityConditionRequirementV1(condition.condition_ref, digest256_text("other"))
        @test_throws ArgumentError WholeProgramConditionalRewriteV1(QualifiedRefV1("same-ref", "v1"),
            source, target, (condition, same_ref_other_digest), rule.checker_ref,
            rule.checker_contract_hash; registry=registry)
    end

    @testset "rule and condition order are canonical" begin
        r2 = _p1_rule("id-to-neg-2", source, target;
            condition=_p1_condition("z"), registry=registry)
        r3 = _p1_rule("id-to-neg-3", source, target;
            condition=_p1_condition("a"), registry=registry)
        @test canonical_hash(ConditionalRewriteSetV1((r2, r3))) == canonical_hash(ConditionalRewriteSetV1((r3, r2)))
        ordered_conditions = WholeProgramConditionalRewriteV1(QualifiedRefV1("ordered", "v1"), source, target,
            (_p1_condition("z"), _p1_condition("a")), rule.checker_ref, rule.checker_contract_hash; registry=registry)
        reversed_conditions = WholeProgramConditionalRewriteV1(ordered_conditions.rule_ref, source, target,
            (_p1_condition("a"), _p1_condition("z")), rule.checker_ref, rule.checker_contract_hash; registry=registry)
        @test canonical_json(ordered_conditions) == canonical_json(reversed_conditions)
        @test canonical_hash(ordered_conditions) == canonical_hash(reversed_conditions)
        d_order_a = _p1_artifact(derive_conditional_program_egraph(source,
            ConditionalRewriteSetV1((r2, r3)), registry))
        d_order_b = _p1_artifact(derive_conditional_program_egraph(source,
            ConditionalRewriteSetV1((r3, r2)), registry))
        @test canonical_json(d_order_a) == canonical_json(d_order_b)
        @test saturation_attempt_hash(d_order_a) == saturation_attempt_hash(d_order_b)
        @test canonical_hash(WholeProgramConditionalRewriteV1(r2.rule_ref, source, target,
            (r2.required_conditions[1],), r2.checker_ref, r2.checker_contract_hash; registry=registry)) == canonical_hash(r2)
        multi_a = WholeProgramConditionalRewriteV1(QualifiedRefV1("multi", "v1"), source, target,
            (_p1_condition("a"), _p1_condition("z")), rule.checker_ref, rule.checker_contract_hash; registry=registry)
        multi_b = WholeProgramConditionalRewriteV1(multi_a.rule_ref, source, target,
            (_p1_condition("z"), _p1_condition("a")), rule.checker_ref, rule.checker_contract_hash; registry=registry)
        @test canonical_json(multi_a) == canonical_json(multi_b)
        @test canonical_hash(multi_a) == canonical_hash(multi_b)
        set_a = ConditionalRewriteSetV1((multi_a, r2, r3))
        set_b = ConditionalRewriteSetV1((r3, multi_b, r2))
        da = _p1_artifact(derive_conditional_program_egraph(source, set_a, registry;
            saturation_budget=ConditionalEGraphBudgetV1(16, 256, 16, 128)))
        db = _p1_artifact(derive_conditional_program_egraph(source, set_b, registry;
            saturation_budget=ConditionalEGraphBudgetV1(16, 256, 16, 128)))
        @test Tuple(canonical_json(m) for m in da.eclass.members) == Tuple(canonical_json(m) for m in db.eclass.members)
        @test canonical_json(da) == canonical_json(db)
    end

    @testset "conditions accumulate and target members remain distinct" begin
        ca = _p1_condition("a")
        cz = _p1_condition("z")
        ra = _p1_rule("conditional-a", source, target; condition=ca, registry=registry)
        rz = _p1_rule("conditional-z", source, target; condition=cz, registry=registry)
        d = _p1_artifact(derive_conditional_program_egraph(source, ConditionalRewriteSetV1((ra, rz)), registry;
            saturation_budget=ConditionalEGraphBudgetV1(8, 64, 8, 64)))
        ec = _p1_get(d, :eclass)
        target_members = filter(m -> canonical_hash(m.program) == canonical_hash(target), ec.members)
        @test length(target_members) >= 2
        @test length(Set(m.cumulative_conditions for m in target_members)) == length(target_members)
        q = query_conditional_equality(d, target)
        @test _p1_get(q, Symbol("st", "atus")) == conditional_equal
        @test !isempty(_p1_get(_p1_get(q, :provenance), :conditions))
    end

    @testset "derivation, query, trace replay, and identity" begin
        derivation = derive_conditional_program_egraph(source, rules, registry; saturation_budget=budget)
        @test_throws MethodError query_conditional_equality(derivation, target)
        derived = _p1_artifact(derivation)
        @test _p1_get(derived, :source_hash) == canonical_hash(source)
        @test canonical_hash(_p1_get(derived, :rewrite_set)) == canonical_hash(rules)
        @test _p1_get(derived, :complete) isa Bool
        @test saturation_attempt_hash(derived) isa Digest256
        @test conditional_equivalence_hash(derived) == Digest256(bytes2hex(SHA.sha256(
            Vector{UInt8}(codeunits(FusionConceptAI._ceg_equivalence_bytes(derived))))))
        sf = Symbol("st", "atus")
        qsame = query_conditional_equality(derived, source)
        @test _p1_get(qsame, sf) == reflexive_equal
        q = query_conditional_equality(derived, target)
        @test _p1_get(q, sf) == conditional_equal
        provenance = _p1_get(q, :provenance)
        trace = _p1_get(provenance, :trace)
        @test !isempty(trace)
        replay = replay_conditional_rewrite_trace(source, target, rules, registry, provenance)
        @test replay === true
    end

    @testset "no-match is a complete fixed point" begin
        no_match_source = _p1_add_program(; registry=registry)
        unrelated = _p1_rule("unrelated", _p1_program("NEG"; registry=registry),
            _p1_program("IDENTITY"; registry=registry); registry=registry)
        d = _p1_artifact(derive_conditional_program_egraph(no_match_source, ConditionalRewriteSetV1((unrelated,)), registry))
        @test _p1_get(d, :complete)
        @test _p1_get(d, :stop_reason) == conditional_fixed_point
        sf = Symbol("st", "atus")
        @test _p1_get(query_conditional_equality(d, target), sf) == equality_unknown
    end

    @testset "interface ordering and root ABI are closed" begin
        port_two = _p1_program("IDENTITY"; registry=registry, port=2)
        @test_throws ArgumentError _p1_rule("port-number", source, port_two; registry=registry)
        unit = UnitSignature()
        scalar = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)
        two_roots = TypedASTProgramV1((ASTInputV1(1, scalar),
            ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
                registry=registry, input_types=(scalar,))), (1, 2), (1,); registry=registry)
        @test_throws ArgumentError _p1_rule("root-count", source, two_roots; registry=registry)
        @test_throws ArgumentError _p1_rule("root-type", source,
            TypedASTProgramV1((ASTInputV1(1, PhysicalType(:vector_field, 1, 3,
                TemporalTypeV1(static_time), unit)),), (1,), (1,); registry=registry);
            registry=registry)
    end

    @testset "P1 production vocabulary scan" begin
        fragments = (("fam", "ily"), ("dev", "ice"), ("see", "d"), ("sol", "ver"),
            ("evi", "dence"), ("pa", "ss"), ("pheno", "type"), ("unsup", "ported"),
            ("feasi", "bility"), ("proof_", "pruned"))
        banned = Tuple(join(x) for x in fragments)
        for path in (joinpath(@__DIR__, "..", "src", "IR", "ConditionalEGraphTypes.jl"),
                     joinpath(@__DIR__, "..", "src", "IR", "ConditionalEGraphSaturation.jl"),
                     joinpath(@__DIR__, "..", "src", "Canonical", "ConditionalEGraphCanonical.jl"))
            body = lowercase(read(path, String))
            @test all(!occursin(word, body) for word in banned)
        end
    end
end
