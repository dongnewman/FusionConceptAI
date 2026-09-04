using Test
using FusionConceptAI
using SHA
include(joinpath(@__DIR__, "conditional_egraph_p1_subprocess_helpers.jl"))

# Keep this file directly runnable while reusing the canonical fixture builders
# when it is included after the core file from test/runtests.jl.
if !isdefined(Main, :_p1_program)
    include(joinpath(@__DIR__, "conditional_egraph_p1_core_tests.jl"))
end

function _p1_reject(f)
    try
        x = f()
        return x === false || (hasproperty(x, :valid) && !x.valid)
    catch e
        return e isa ArgumentError || e isa MethodError || e isa ErrorException
    end
end

function _p1_swap_add(; registry=default_operator_registry())
    unit = UnitSignature()
    ty = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)
    a, b = ASTInputV1(1, ty), ASTInputV1(2, ty)
    op = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 1), (;);
        registry=registry, input_types=(ty, ty))
    TypedASTProgramV1((a, b, op), (3,), (1, 2); registry=registry)
end

"""Independent breadth-first oracle: full AST bytes and sorted guard sets are the key."""
function _p1_bfs_oracle(source, rules; max_steps=6)
    bytes(p) = canonical_json(p)
    guards(cs) = Tuple(sort(unique(collect(cs)), by=c ->
        (c.condition_ref.id, c.condition_ref.version, c.condition_contract_hash.value)))
    merge_guards(a, b) = guards((a..., b...))
    key(p, cs) = bytes(p) * "\0" * join((canonical_json(c) for c in guards(cs)), "\0")
    queue = Any[(source, ())]
    seen_programs = Any[(source, ())]
    seen = Set{String}([key(source, ())])
    for _ in 1:max_steps
        next = similar(queue, 0)
        for (p, cs) in queue
            pb = bytes(p)
            for r in rules.rules
                for (side, other) in ((r.lhs_program, r.rhs_program), (r.rhs_program, r.lhs_program))
                    bytes(side) == pb || continue
                    merged = merge_guards(cs, r.required_conditions)
                    member_key = key(other, merged)
                    member_key in seen && continue
                    push!(seen, member_key); push!(next, (other, merged)); push!(seen_programs, (other, merged))
                end
            end
        end
        isempty(next) && break
        append!(queue, next)
        queue = next
    end
    seen
end
_p1_member_key(m) = canonical_json(m.program) * "\0" * join((canonical_json(c) for c in m.cumulative_conditions), "\0")
_p1_graph_trace(d) = Tuple(unique(vcat((m.provenance isa ConditionalEqualityProvenanceV1 ? collect(m.provenance.trace) : ConditionalRewriteTraceStepV1[] for m in _p1_get(_p1_get(d, :eclass), :members))...)))

function _p1_delay(; registry=default_operator_registry())
    unit = UnitSignature()
    ty = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time), unit)
    input = ASTInputV1(1, ty)
    op = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=1.0,);
        registry=registry, input_types=(ty,))
    TypedASTProgramV1((input, op), (2,), (1,); registry=registry)
end

function _p1_sub_program(; registry=default_operator_registry(), order=(1, 2), roots=(3,))
    unit = UnitSignature()
    ty = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)
    a, b = ASTInputV1(1, ty), ASTInputV1(2, ty)
    op = ASTApplyV1(OperatorRefV1("SUB", "v1"), order, (;);
        registry=registry, input_types=(ty, ty))
    TypedASTProgramV1((a, b, op), roots, (1, 2); registry=registry)
end

function _p1_oversized_program(op::String; registry=default_operator_registry())
    unit = UnitSignature(); ty = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)
    nodes = Any[ASTInputV1(1, ty)]
    for i in 2:33
        opcode = i == 33 ? op : "IDENTITY"
        push!(nodes, ASTApplyV1(OperatorRefV1(opcode, "v1"), (i - 1,), (;);
            registry=registry, input_types=(ty,)))
    end
    TypedASTProgramV1(Tuple(nodes), (33,), (1,); registry=registry)
end

function _p1_child_identity(poison::Bool)
    poison_code = poison ? "FusionConceptAI.canonical_json(::Any)=\"spoof\"; FusionConceptAI.canonical_json(::TypedASTProgramV1)=\"spoof-specific\"; FusionConceptAI.canonical_hash(::TypedASTProgramV1)=Digest256(repeat(\"0\",64)); FusionConceptAI.semantic_view(::Any)=(spoof=true); FusionConceptAI._ceg_ref(io::IOBuffer,r::QualifiedRefV1)=(write(io,\"spoof\"),nothing);" : ""
    script = join((
        "using FusionConceptAI; using SHA;",
        poison_code,
        "function p(op); u=UnitSignature(); t=PhysicalType(:scalar_field,0,3,TemporalTypeV1(static_time)); i=ASTInputV1(1,t); a=ASTApplyV1(OperatorRefV1(op,\"v1\"),(1,),(;);registry=default_operator_registry(),input_types=(t,)); TypedASTProgramV1((i,a),(2,),(1,);registry=default_operator_registry()); end",
        "s=p(\"IDENTITY\"); t=p(\"NEG\"); c=EqualityConditionRequirementV1(QualifiedRefV1(\"eq\",\"v1\"),digest256_text(\"checker-eq\")); r=WholeProgramConditionalRewriteV1(QualifiedRefV1(\"identity_to_neg\",\"v1\"),s,t,(c,),QualifiedRefV1(\"checker\",\"v1\"),digest256_text(\"checker-v1\");registry=default_operator_registry()); rs=ConditionalRewriteSetV1((r,)); d=derive_conditional_program_egraph(s,rs,default_operator_registry();saturation_budget=ConditionalEGraphBudgetV1(64,4096,32,256)).artifact; uc=EqualityConditionRequirementV1(QualifiedRefV1(\"条件-μ\",\"v1\"),digest256_text(\"u\")); nc=EqualityConditionRequirementV1(QualifiedRefV1(\"bad\"*string(Char(0)),\"v1\"),digest256_text(\"n\")); print(bytes2hex(SHA.sha256(codeunits(canonical_json(rs)))),\"|\",bytes2hex(SHA.sha256(codeunits(canonical_json(d)))),\"|\",saturation_attempt_hash(d).value,\"|\",replay_conditional_rewrite_trace(s,t,rs,default_operator_registry(),query_conditional_equality(d,t).provenance),\"|\",bytes2hex(SHA.sha256(codeunits(canonical_json(uc)))),\"|\",bytes2hex(SHA.sha256(codeunits(canonical_json(nc)))))"
    ), "\n")
    _p1_child_output(script)
end

function _p1_child_abi_and_digest(poison::Bool)
    poison_code = poison ? "FusionConceptAI.:(==)(a::PhysicalType,b::PhysicalType)=true; FusionConceptAI.:(==)(a::Digest256,b::Digest256)=true;" : ""
    script = join((
        "using FusionConceptAI;",
        poison_code,
        "function p(op,u); t=PhysicalType(:scalar_field,0,3,TemporalTypeV1(static_time),u); i=ASTInputV1(1,t); a=ASTApplyV1(OperatorRefV1(op,\"v1\"),(1,),(;);registry=default_operator_registry(),input_types=(t,)); TypedASTProgramV1((i,a),(2,),(1,);registry=default_operator_registry()); end",
        "u0=UnitSignature(); u1=UnitSignature((1,0,0,0,0,0,0)); s=p(\"IDENTITY\",u0); x=p(\"IDENTITY\",u1); abi=try c=EqualityConditionRequirementV1(QualifiedRefV1(\"q\",\"v1\"),digest256_text(\"q\")); WholeProgramConditionalRewriteV1(QualifiedRefV1(\"abi\",\"v1\"),s,x,(c,),QualifiedRefV1(\"checker\",\"v1\"),digest256_text(\"checker\"); registry=default_operator_registry()); false catch; true end; m=operator_manifest(default_operator_registry(),QualifiedRefV1(\"IDENTITY\",\"v1\")); mm=OperatorManifestV1(m.operator_ref,m.input_arity,m.output_arity,m.input_type_rule,m.output_type_rule;allowed_roles=m.allowed_roles,locality=:global,max_derivative_contribution=m.max_derivative_contribution,pure=m.pure,stateful=m.stateful,stochastic=m.stochastic,event=m.event,commutative_input_groups=m.commutative_input_groups,cse_allowed=m.cse_allowed,allowed_conservation_effects=m.allowed_conservation_effects,forbidden_conservation_effects=m.forbidden_conservation_effects); bad=OperatorRegistryV1((mm,(z for z in default_operator_registry().operators if z.operator_ref != m.operator_ref)...)); c=EqualityConditionRequirementV1(QualifiedRefV1(\"q\",\"v1\"),digest256_text(\"q\")); r=WholeProgramConditionalRewriteV1(QualifiedRefV1(\"stale\",\"v1\"),p(\"IDENTITY\",u0),p(\"NEG\",u0),(c,),QualifiedRefV1(\"checker\",\"v1\"),digest256_text(\"checker\"); registry=default_operator_registry()); stale=derive_conditional_program_egraph(r.lhs_program,ConditionalRewriteSetV1((r,)),bad); print(abi,\"|\",stale.artifact===nothing,\"|\",stale.reason)"
    ), "\n")
    _p1_child_output(script)
end

function _p1_child_dispatch_poison(poison::Bool)
    poison_code = poison ? """
        const _p1_hit_conditions = Ref(false)
        const _p1_hit_sort = Ref(false)
        const _p1_hit_replay_property = Ref(false)
        const _p1_hit_rule_property = Ref(false)
        FusionConceptAI._ceg_conditions(cs::Tuple{Vararg{EqualityConditionRequirementV1}}; allow_empty=false) =
            (_p1_hit_conditions[] = true; cs)
        FusionConceptAI._ceg_insertion_sorted(xs::Vector{WholeProgramConditionalRewriteV1}, key::Function) =
            (_p1_hit_sort[] = true; xs)
        Base.getproperty(x::FusionConceptAI._ConditionalTraceReplayResultV1, f::Symbol) =
            (f === :valid && (_p1_hit_replay_property[] = true); true)
        Base.getproperty(x::WholeProgramConditionalRewriteV1, f::Symbol) =
            (_p1_hit_rule_property[] = true; getfield(x, f))
    """ : ""
    hit_conditions = poison ? "_p1_hit_conditions[]" : "false"
    hit_sort = poison ? "_p1_hit_sort[]" : "false"
    hit_replay_property = poison ? "_p1_hit_replay_property[]" : "false"
    hit_rule_property = poison ? "_p1_hit_rule_property[]" : "false"
    script = join((
        "using FusionConceptAI;",
        poison_code,
        "u=UnitSignature(); t=PhysicalType(:scalar_field,0,3,TemporalTypeV1(static_time),u); i=ASTInputV1(1,t); a=ASTApplyV1(OperatorRefV1(\"IDENTITY\",\"v1\"),(1,),(;);registry=default_operator_registry(),input_types=(t,)); n=ASTApplyV1(OperatorRefV1(\"NEG\",\"v1\"),(1,),(;);registry=default_operator_registry(),input_types=(t,)); s=TypedASTProgramV1((i,a),(2,),(1,);registry=default_operator_registry()); x=TypedASTProgramV1((i,n),(2,),(1,);registry=default_operator_registry()); c=EqualityConditionRequirementV1(QualifiedRefV1(\"eq\",\"v1\"),digest256_text(\"checker-eq\")); c2=EqualityConditionRequirementV1(c.condition_ref,digest256_text(\"other\")); r=WholeProgramConditionalRewriteV1(QualifiedRefV1(\"id-to-neg\",\"v1\"),s,x,(c,),QualifiedRefV1(\"checker\",\"v1\"),digest256_text(\"checker-v1\");registry=default_operator_registry()); rs=ConditionalRewriteSetV1((r,)); d=derive_conditional_program_egraph(s,rs,default_operator_registry();saturation_budget=ConditionalEGraphBudgetV1(64,4096,32,256)); q=query_conditional_equality(d.artifact,x); empty_replay=replay_conditional_rewrite_trace(s,x,ConditionalRewriteSetV1(()),default_operator_registry(),q.provenance); duplicate_rejected=try WholeProgramConditionalRewriteV1(QualifiedRefV1(\"dup\",\"v1\"),s,x,(c,c2),QualifiedRefV1(\"checker\",\"v1\"),digest256_text(\"checker-v1\");registry=default_operator_registry()); false catch e; e isa ArgumentError end;",
        poison ? "FusionConceptAI._ceg_conditions((c,c2);allow_empty=true); FusionConceptAI._ceg_insertion_sorted([r],identity);" : "",
        poison ? "rule_probe=getproperty(r,:rule_ref); replay_probe=getproperty(FusionConceptAI._ConditionalTraceReplayResultV1(false,s,(),0),:valid);" : "rule_probe=r.rule_ref; replay_probe=FusionConceptAI._ConditionalTraceReplayResultV1(false,s,(),0).valid;",
        "print(canonical_hash(rs).value,\"|\",d.status,\"|\",empty_replay,\"|\",duplicate_rejected,\"|\"," * hit_conditions * ",\"|\"," * hit_sort * ",\"|\"," * hit_replay_property * ",\"|\"," * hit_rule_property * ")"
    ), "\n")
    _p1_child_output(script)
end

function _p1_registry_with(ids)
    reg = default_operator_registry()
    for id in ids
        ref = OperatorRefV1(id, "v1")
        m = OperatorManifestV1(ref, 1, 1, SameTypeVariadicRuleV1(1, 1),
            SameTypeVariadicRuleV1(1, 1); allowed_roles=(:governing, :additive,
            :constraint, :interface))
        reg = register_operator(reg, m)
    end
    reg
end

function _p1_registry_bad(id; pure=true, stateful=false, stochastic=false, event=false, cse_allowed=true)
    (stateful || stochastic || event) && (cse_allowed = false)
    (!cse_allowed && !stateful && !event) && (stateful = true; pure = false)
    ref = OperatorRefV1(id, "v1")
    m = OperatorManifestV1(ref, 1, 1, SameTypeVariadicRuleV1(1, 1),
        SameTypeVariadicRuleV1(1, 1); allowed_roles=(:governing, :additive,
        :constraint, :interface), pure=pure, stateful=stateful,
        stochastic=stochastic, event=event, cse_allowed=cse_allowed)
    register_operator(default_operator_registry(), m)
end

@testset "P1 conditional e-graph adversarial boundaries" begin
    registry = default_operator_registry()
    source = _p1_program("IDENTITY"; registry=registry)
    target = _p1_program("NEG"; registry=registry)
    condition = _p1_condition()
    rule = _p1_rule("id-to-neg", source, target; registry=registry, condition=condition)
    rules = ConditionalRewriteSetV1((rule,))

    @testset "equivalent AST enumeration is byte/hash/trace invariant" begin
        add_a = _p1_add_program(; registry=registry)
        add_b = _p1_swap_add(; registry=registry)
        @test canonical_json(add_a) == canonical_json(add_b)
        @test canonical_hash(add_a) == canonical_hash(add_b)
        @test length(add_a.roots) == length(add_b.roots)
        d1 = _p1_artifact(derive_conditional_program_egraph(source, ConditionalRewriteSetV1((rule,)), registry))
        d2 = _p1_artifact(derive_conditional_program_egraph(source, ConditionalRewriteSetV1((rule,)), registry))
        @test canonical_json(d1) == canonical_json(d2)
        @test canonical_hash(d1) == canonical_hash(d2)
        @test saturation_attempt_hash(d1) == saturation_attempt_hash(d2)
    end

    @testset "cycles, diamonds, and duplicate paths are bounded" begin
        cycle_registry = _p1_registry_with(("P1_A", "P1_B", "P1_C"))
        pa, pb = _p1_program("P1_A"; registry=cycle_registry), _p1_program("P1_B"; registry=cycle_registry)
        pc = _p1_program("P1_C"; registry=cycle_registry)
        cycle = ConditionalRewriteSetV1((_p1_rule("a-b", pa, pb; registry=cycle_registry),
            _p1_rule("b-c", pb, pc; registry=cycle_registry),
            _p1_rule("c-a", pc, pa; registry=cycle_registry)))
        d = _p1_artifact(derive_conditional_program_egraph(pa, cycle, cycle_registry;
            saturation_budget=ConditionalEGraphBudgetV1(12, 128, 8, 128)))
        @test length(_p1_get(_p1_get(d, :eclass), :members)) <= 12
        oracle = _p1_bfs_oracle(pa, cycle; max_steps=6)
        actual_keys = Set(_p1_member_key(m) for m in _p1_get(_p1_get(d, :eclass), :members))
        @test actual_keys == oracle
        @test _p1_get(d, :usage).programs <= 12
        @test _p1_get(d, :usage).rewrite_attempts <= 32
        @test _p1_get(d, :usage).rounds <= 8
        @test _p1_get(d, :usage).trace_steps <= 32
        @test length(_p1_graph_trace(d)) <= 32
        sf = Symbol("st", "atus")
        @test _p1_get(query_conditional_equality(d, pa), sf) == reflexive_equal
        @test _p1_get(query_conditional_equality(d, pb), sf) == conditional_equal
    end

    @testset "diamond second parent has a rooted two-step proof" begin
        diamond_registry = _p1_registry_with(("P1_DA", "P1_DB", "P1_DC", "P1_DD"))
        da, db = _p1_program("P1_DA"; registry=diamond_registry), _p1_program("P1_DB"; registry=diamond_registry)
        dc, dd = _p1_program("P1_DC"; registry=diamond_registry), _p1_program("P1_DD"; registry=diamond_registry)
        dr(n, l, r) = _p1_rule(n, l, r; registry=diamond_registry)
        diamond = ConditionalRewriteSetV1((dr("da-db", da, db), dr("da-dc", da, dc),
            dr("db-dd", db, dd), dr("dc-dd", dc, dd)))
        dg = _p1_artifact(derive_conditional_program_egraph(da, diamond, diamond_registry;
            saturation_budget=ConditionalEGraphBudgetV1(64, 4096, 16, 256)))
        dp = query_conditional_equality(dg, dd).provenance
        @test dp isa ConditionalEqualityProvenanceV1
        @test Tuple(s.step for s in dp.trace) == (1, 2)
        @test replay_conditional_rewrite_trace(da, dd, diamond, diamond_registry, dp) === true
    end

    @testset "each budget is an atomic-batch stop" begin
        zero_attempt = _p1_artifact(derive_conditional_program_egraph(source, rules, registry;
            saturation_budget=ConditionalEGraphBudgetV1(64, 0, 32, 256)))
        @test zero_attempt.usage.rewrite_attempts == 0
        @test zero_attempt.usage.programs == 1
        for limit in 0:4
            edge = _p1_artifact(derive_conditional_program_egraph(source, rules, registry;
                saturation_budget=ConditionalEGraphBudgetV1(64, limit, 32, 256)))
            expected_attempts = limit < 2 ? 0 : (limit < 4 ? 2 : 4)
            @test edge.usage.rewrite_attempts == expected_attempts
            @test edge.usage.rewrite_attempts <= limit
        end
        budgets = (
            (ConditionalEGraphBudgetV1(1, 4096, 32, 256), conditional_budget_programs),
            (ConditionalEGraphBudgetV1(64, 0, 32, 256), conditional_budget_rewrite_attempts),
            (ConditionalEGraphBudgetV1(64, 4096, 0, 256), conditional_budget_rounds),
            (ConditionalEGraphBudgetV1(64, 4096, 32, 0), conditional_budget_trace_steps))
        for (b, reason) in budgets
            d = _p1_artifact(derive_conditional_program_egraph(source, rules, registry; saturation_budget=b))
            @test !_p1_get(d, :complete)
            @test_throws ArgumentError conditional_equivalence_hash(d)
            @test saturation_attempt_hash(d) isa Digest256
            @test _p1_get(d, :stop_reason) == reason
            @test _p1_get(d, :source_hash) == canonical_hash(source)
            @test _p1_get(d, :usage).programs <= b.max_programs
            @test _p1_get(d, :usage).rewrite_attempts <= b.max_rewrite_attempts
            @test _p1_get(d, :usage).rounds <= b.max_rounds
            @test _p1_get(d, :usage).trace_steps <= b.max_trace_steps
            reason == conditional_budget_rewrite_attempts && @test _p1_get(d, :usage).rewrite_attempts == 0
            reason == conditional_budget_programs && @test _p1_get(d, :usage).programs == 1
        end
    end

    @testset "interface, capability, and closed API rejection" begin
        two_input = _p1_add_program(; registry=registry)
        @test_throws ArgumentError _p1_rule("bad-input-count", source, two_input; registry=registry)
        wrong_type = begin
            u = UnitSignature((1, 0, 0, 0, 0, 0, 0))
            t = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), u)
            i = ASTInputV1(1, t)
            a = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;); registry=registry, input_types=(t,))
            TypedASTProgramV1((i, a), (2,), (1,); registry=registry)
        end
        @test_throws ArgumentError _p1_rule("bad-type", source, wrong_type; registry=registry)
        @test_throws ArgumentError _p1_rule("delay", source, _p1_delay(; registry=registry); registry=registry)
        delay_identity = try
            derive_conditional_program_egraph(_p1_delay(; registry=registry), ConditionalRewriteSetV1(()), registry)
        catch
            nothing
        end
        if delay_identity !== nothing
            @test (_p1_get(delay_identity, :status) == resolved && _p1_get(delay_identity, :artifact).complete) ||
                (_p1_get(delay_identity, :status) == terminal_deferred && _p1_get(delay_identity, :reason) == source_out_of_profile)
        end
        for (id, kwargs) in (("BAD_CSE", (cse_allowed=false,)), ("BAD_STATEFUL", (pure=false, stateful=true)),
                ("BAD_STOCHASTIC", (pure=false, stochastic=true)))
            bad_registry = _p1_registry_bad(id; kwargs...)
            @test_throws ArgumentError _p1_rule("bad-" * id,
                _p1_program(id; registry=bad_registry), source; registry=bad_registry)
        end
        @test _p1_throws(() -> _p1_program("EVENT_RESET"; registry=registry))
        @test !isdefined(FusionConceptAI, Symbol("Equivalence", "CertificateV1"))
        graph_node = node(:state, source.nodes[source.roots[1]].output_type; id="p1-real-node")
        graph_edge = AtomicMIMOHyperedgeV1("p1-real-edge", (MIMOInputBindingV1(1, 1),),
            (MIMOOutputBindingV1(1, 1),), source, governing; registry=registry)
        real_graph = TypedOperatorHypergraphV1((graph_node,), (graph_edge,); registry=registry)
        graph_hash = canonical_hash(real_graph)
        @test derive_conditional_egraph(real_graph).source_hash == graph_hash
        _ = derive_conditional_program_egraph(source, rules, registry)
        @test canonical_hash(real_graph) == graph_hash
        @test_throws MethodError DerivedEGraphViewV4(digest256_text("fake"), real_graph)
        @test_throws MethodError ConditionalRewriteTraceStepV1(0, rule.rule_ref, rule.lhs_hash,
            rewrite_forward, rule.lhs_hash, rule.rhs_hash, 1, rule.required_conditions, rule.required_conditions)
        @test_throws MethodError ConditionalEqualityProvenanceV1(rule.lhs_hash, rule.rhs_hash,
            rule.required_conditions, (nothing,))
        @test_throws MethodError ConditionalProgramENodeV1(source, digest256_text("wrong-node-hash"), (), nothing)
        @test_throws MethodError ConditionalEClassV1(rule.lhs_hash, ())
        @test_throws MethodError ConditionalEqualityQueryResultV1(conditional_equal, nothing)
        @test hasmethod(ConditionalEqualityQueryResultV1,
            Tuple{DerivedConditionalEGraphV1, TypedASTProgramV1})
        @test !hasmethod(ConditionalEqualityQueryResultV1,
            Tuple{ConditionalEqualityStatusV1, Nothing})
        @test_throws MethodError DerivedConditionalEGraphV1()
        @test !hasmethod(DerivedConditionalEGraphV1,
            Tuple{TypedASTProgramV1, Digest256, Tuple, ConditionalRewriteSetV1,
                ConditionalEClassV1, ConditionalEGraphSaturationStateV1,
                ConditionalEGraphBudgetV1, ConditionalEGraphUsageV1,
                CanonicalizationProfileV1, Bool, ConditionalEGraphStopReasonV1, OperatorRegistryV1})
        @test hasmethod(DerivedConditionalEGraphV1,
            Tuple{TypedASTProgramV1, ConditionalRewriteSetV1, OperatorRegistryV1,
                ConditionalEGraphBudgetV1, CanonicalizationProfileV1})
        @test !hasmethod(ConditionalEGraphDerivationResultV1,
            Tuple{ResolutionStatus, Union{Nothing, DerivedConditionalEGraphV1},
                ConditionalEGraphDerivationReasonV1, Digest256})
        @test !hasmethod(ConditionalEGraphDerivationResultV1,
            Tuple{DerivedConditionalEGraphV1, OperatorRegistryV1})
        @test hasmethod(ConditionalEGraphDerivationResultV1,
            Tuple{TypedASTProgramV1, ConditionalRewriteSetV1, OperatorRegistryV1,
                ConditionalEGraphBudgetV1, CanonicalizationProfileV1})
        @test !hasmethod(ConditionalEGraphDerivationResultV1,
            Tuple{Digest256, ConditionalEGraphUsageV1, Bool,
                ConditionalEGraphStopReasonV1, Digest256})
    end

    @testset "semantic identity cannot be spoofed" begin
        changed = _p1_rule("changed-rule-ref", source, target; registry=registry)
        @test canonical_hash(changed) != canonical_hash(rule)
        altered_checker = WholeProgramConditionalRewriteV1(rule.rule_ref, source, target,
            (condition,), rule.checker_ref, digest256_text("different-checker"); registry=registry)
        @test canonical_hash(altered_checker) != canonical_hash(rule)
        altered_manifest = let
            m = operator_manifest(registry, QualifiedRefV1("IDENTITY", "v1"))
            mm = OperatorManifestV1(m.operator_ref, m.input_arity, m.output_arity,
                m.input_type_rule, m.output_type_rule; allowed_roles=m.allowed_roles,
                parameter_schema=m.parameter_schema, locality=:global,
                max_derivative_contribution=m.max_derivative_contribution, pure=m.pure,
                stateful=m.stateful, stochastic=m.stochastic, event=m.event,
                commutative_input_groups=m.commutative_input_groups, cse_allowed=m.cse_allowed,
                allowed_conservation_effects=m.allowed_conservation_effects,
                forbidden_conservation_effects=m.forbidden_conservation_effects)
            OperatorRegistryV1((mm, (x for x in registry.operators if x.operator_ref != m.operator_ref)...))
        end
        altered_source = _p1_program("IDENTITY"; registry=altered_manifest)
        @test canonical_hash(altered_source) != canonical_hash(source)
        result_wrong_registry = derive_conditional_program_egraph(source, rules, altered_manifest)
        @test _p1_get(result_wrong_registry, :artifact) === nothing
        @test _p1_get(result_wrong_registry, :reason) == manifest_or_contract_incompatible
        @test_throws ArgumentError derive_conditional_program_egraph(source, rules, registry;
            canonicalization_profile=1)
        tiny_profile = CanonicalizationProfileV1("tiny-p1", "1", CanonicalizationBudgetV1(1, 1, 1, 1))
        tiny_result = derive_conditional_program_egraph(source, rules, registry;
            canonicalization_profile=tiny_profile)
        @test _p1_get(tiny_result, :status) == terminal_deferred
        @test _p1_get(tiny_result, :reason) == exact_canonicalization_deferred
        @test canonical_hash(result_wrong_registry) != canonical_hash(tiny_result)
        changed_request = derive_conditional_program_egraph(_p1_add_program(; registry=registry), rules, registry)
        @test canonical_hash(changed_request) != canonical_hash(result_wrong_registry)
        extended_registry = _p1_registry_with(("UNRELATED_P1_EXTENSION",))
        extended = _p1_artifact(derive_conditional_program_egraph(source, rules, extended_registry))
        @test canonical_json(extended) == canonical_json(_p1_artifact(derive_conditional_program_egraph(source, rules, registry)))
        @test saturation_attempt_hash(extended) == saturation_attempt_hash(_p1_artifact(
            derive_conditional_program_egraph(source, rules, registry)))
    end

    @testset "noncommutative roots, Unicode/NUL, and source immutability" begin
        sub12, sub21 = _p1_sub_program(order=(1, 2)), _p1_sub_program(order=(2, 1))
        @test canonical_json(sub12) != canonical_json(sub21)
        @test canonical_hash(sub12) != canonical_hash(sub21)
        unit = UnitSignature(); ty = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), unit)
        two_inputs = TypedASTProgramV1((ASTInputV1(1, ty), ASTInputV1(2, ty)), (1, 2), (1, 2); registry=registry)
        reversed_roots = TypedASTProgramV1(two_inputs.nodes, (2, 1), (1, 2); registry=registry)
        @test canonical_hash(two_inputs) != canonical_hash(reversed_roots)
        unicode_condition = EqualityConditionRequirementV1(QualifiedRefV1("条件-μ", "v1"), digest256_text("u"))
        @test canonical_json(unicode_condition) == canonical_json(unicode_condition)
        nul_condition = EqualityConditionRequirementV1(QualifiedRefV1("bad" * string(Char(0)), "v1"), digest256_text("n"))
        @test occursin("\\u0000", canonical_json(nul_condition))
        @test canonical_json(nul_condition) == canonical_json(nul_condition)
        source_json, source_hash = canonical_json(source), canonical_hash(source)
        d = _p1_artifact(derive_conditional_program_egraph(source, rules, registry))
        @test canonical_json(source) == source_json
        @test canonical_hash(source) == source_hash
        @test _p1_get(d, :source_hash) == source_hash
    end

    @testset "oversize and fresh-process authority" begin
        oversize = _p1_oversized_program("IDENTITY"; registry=registry)
        oversize_other = _p1_oversized_program("NEG"; registry=registry)
        oversized_result = try
            derive_conditional_program_egraph(oversize, rules, registry)
        catch e
            e
        end
        other_result = try
            derive_conditional_program_egraph(oversize_other, rules, registry)
        catch e
            e
        end
        @test oversized_result isa ConditionalEGraphDerivationResultV1
        @test other_result isa ConditionalEGraphDerivationResultV1
        if oversized_result isa ConditionalEGraphDerivationResultV1 && other_result isa ConditionalEGraphDerivationResultV1
            @test _p1_get(oversized_result, :status) == terminal_deferred
            @test _p1_get(oversized_result, :reason) == source_out_of_profile
            @test _p1_get(other_result, :status) == terminal_deferred
            @test _p1_get(other_result, :reason) == source_out_of_profile
            @test canonical_json(oversized_result) != canonical_json(other_result)
            @test _p1_get(oversized_result, :derivation_request_hash) !=
                _p1_get(other_result, :derivation_request_hash)
        end
        baseline = _p1_child_identity(false)
        poisoned = _p1_child_identity(true)
        @test baseline == poisoned
        @test occursin("|true|", baseline)
        unicode_condition = EqualityConditionRequirementV1(QualifiedRefV1("条件-μ", "v1"), digest256_text("u"))
        nul_condition = EqualityConditionRequirementV1(QualifiedRefV1("bad" * string(Char(0)), "v1"), digest256_text("n"))
        fields = split(baseline, "|")
        @test fields[end - 1] == bytes2hex(SHA.sha256(codeunits(canonical_json(unicode_condition))))
        @test fields[end] == bytes2hex(SHA.sha256(codeunits(canonical_json(nul_condition))))
        abi_baseline = _p1_child_abi_and_digest(false)
        abi_poisoned = _p1_child_abi_and_digest(true)
        @test abi_baseline == abi_poisoned
        @test startswith(abi_baseline, "true|true|")
        poison_baseline = split(strip(_p1_child_dispatch_poison(false)), "|")
        poison_result = split(strip(_p1_child_dispatch_poison(true)), "|")
        @test poison_baseline[1:4] == poison_result[1:4]
        @test poison_result[5:8] == ["true", "true", "true", "true"]
    end

    @testset "trace tampering and source preservation" begin
        d = _p1_artifact(derive_conditional_program_egraph(source, rules, registry))
        q = query_conditional_equality(d, target)
        provenance = _p1_get(q, :provenance)
        trace = _p1_get(provenance, :trace)
        t = trace[1]
        @test_throws MethodError ConditionalRewriteTraceStepV1(nothing, t.round, t.rule_ref, digest256_text("bad"),
            t.orientation, t.source_hash, t.target_hash, t.step, t.required_conditions, t.cumulative_conditions)
        @test _p1_reject(() -> replay_conditional_rewrite_trace(source, target, ConditionalRewriteSetV1(()), registry, provenance))
        @test _p1_reject(() -> replay_conditional_rewrite_trace(target, source, rules, registry, provenance))
        @test_throws MethodError DerivedConditionalEGraphV1(d.source_program,
            digest256_text("wrong-source"), d.used_manifest_bindings, d.rewrite_set, d.eclass,
            d.saturation_state, d.saturation_budget, d.usage, d.canonicalization_profile,
            d.complete, d.stop_reason, registry)
        alt_rule = _p1_rule("tampered-rule", source, target; condition=condition, registry=registry)
        tampered(step; kwargs...) = begin
            rr = get(kwargs, :rule, rule)
            orient = get(kwargs, :orientation, step.orientation)
            rp = orient === rewrite_forward ? rr.lhs_program : rr.rhs_program
            tp = orient === rewrite_forward ? rr.rhs_program : rr.lhs_program
            ConditionalRewriteTraceStepV1(get(kwargs, :round, step.round), rr, orient, rp, tp,
                get(kwargs, :step, step.step), get(kwargs, :cumulative_conditions, step.cumulative_conditions))
        end
        mkprov(ts; source_program=source, target_program=target,
            conditions=provenance.conditions) = ConditionalEqualityProvenanceV1(source_program, target_program,
                conditions, ts)
        @test _p1_reject(() -> mkprov((tampered(t;
            orientation=t.orientation === rewrite_forward ? rewrite_reverse : rewrite_forward),)))
        @test replay_conditional_rewrite_trace(source, target, rules, registry,
            mkprov((tampered(t; rule=alt_rule),))) === false
        bad_target = _p1_sub_program(; registry=registry)
        @test _p1_reject(() -> mkprov((t,); target_program=bad_target))
        @test _p1_reject(() -> mkprov((tampered(t; step=2, round=2),)))
        @test_throws ArgumentError tampered(t; round=99)
        bad_guard = EqualityConditionRequirementV1(condition.condition_ref, digest256_text("wrong-guard"))
        @test _p1_reject(() -> mkprov((tampered(t; cumulative_conditions=(bad_guard,)),), conditions=(bad_guard,)))
    end

    @testset "Sol third-audit fresh-process authority regressions" begin
        """An overriding tuple iterator may erase every guard if production uses it dynamically."""
        function condition_iterate_child(poison::Bool)
            poison_code = poison ? raw"""
                const P1_CONDITION_ITERATE_HIT = Ref(false)
                Base.iterate(xs::Tuple{Vararg{EqualityConditionRequirementV1}}) = begin
                    P1_CONDITION_ITERATE_HIT[] = true
                    nothing
                end
                Base.iterate(xs::Tuple{Vararg{EqualityConditionRequirementV1}}, state) = begin
                    P1_CONDITION_ITERATE_HIT[] = true
                    nothing
                end
            """ : "const P1_CONDITION_ITERATE_HIT = Ref(false)"
            hit = poison ? "P1_CONDITION_ITERATE_HIT[]" : "false"
            script = join((
                "using FusionConceptAI;",
                poison_code,
                "u=UnitSignature(); t=PhysicalType(:scalar_field,0,3,TemporalTypeV1(static_time),u); i=ASTInputV1(1,t); a=ASTApplyV1(OperatorRefV1(\"IDENTITY\",\"v1\"),(1,),(;);registry=default_operator_registry(),input_types=(t,)); n=ASTApplyV1(OperatorRefV1(\"NEG\",\"v1\"),(1,),(;);registry=default_operator_registry(),input_types=(t,)); s=TypedASTProgramV1((i,a),(2,),(1,);registry=default_operator_registry()); x=TypedASTProgramV1((i,n),(2,),(1,);registry=default_operator_registry()); c=EqualityConditionRequirementV1(QualifiedRefV1(\"iter-guard\",\"v1\"),digest256_text(\"iter-contract\")); r=WholeProgramConditionalRewriteV1(QualifiedRefV1(\"iter-rule\",\"v1\"),s,x,(c,),QualifiedRefV1(\"checker\",\"v1\"),digest256_text(\"checker\");registry=default_operator_registry()); rs=ConditionalRewriteSetV1((r,)); d=derive_conditional_program_egraph(s,rs,default_operator_registry()); q=query_conditional_equality(d.artifact,x);",
                poison ? "Base.iterate((c,));" : "",
                "p=q.provenance; print(canonical_hash(r).value,\"|\",canonical_hash(rs).value,\"|\",canonical_hash(c).value,\"|\",q.status,\"|\",p!==nothing,\"|\",p===nothing ? 0 : fieldcount(typeof(p.conditions)),\"|\",$hit)"
            ), "\n")
            script
        end

        condition_baseline = _p1_child_fields(condition_iterate_child(false))
        condition_poisoned = _p1_child_fields(condition_iterate_child(true))
        @test condition_baseline[1:end-1] == condition_poisoned[1:end-1]
        @test condition_baseline[end] == "false"
        @test condition_poisoned[end] == "true"  # extension is active, but not authoritative
        @test condition_poisoned[4:6] == ["conditional_equal", "true", "1"]

        """Poison proposal-vector iteration and mutation, then explicitly exercise both hooks."""
        function proposal_vector_child(poison::Bool)
            poison_code = poison ? raw"""
                const P1_PROPOSAL_ITERATE_HIT = Ref(false)
                const P1_PROPOSAL_PUSH_HIT = Ref(false)
                Base.iterate(v::Vector{FusionConceptAI._CEGProposal}) = begin
                    P1_PROPOSAL_ITERATE_HIT[] = true
                    nothing
                end
                Base.iterate(v::Vector{FusionConceptAI._CEGProposal}, state) = begin
                    P1_PROPOSAL_ITERATE_HIT[] = true
                    nothing
                end
                Base.push!(v::Vector{FusionConceptAI._CEGProposal}, x) = begin
                    P1_PROPOSAL_PUSH_HIT[] = true
                    v
                end
            """ : raw"""
                const P1_PROPOSAL_ITERATE_HIT = Ref(false)
                const P1_PROPOSAL_PUSH_HIT = Ref(false)
            """
            hits = poison ? "P1_PROPOSAL_ITERATE_HIT[],\"|\",P1_PROPOSAL_PUSH_HIT[]" : "false,\"|\",false"
            script = join((
                "using FusionConceptAI;",
                poison_code,
                "u=UnitSignature(); t=PhysicalType(:scalar_field,0,3,TemporalTypeV1(static_time),u); i=ASTInputV1(1,t); a=ASTApplyV1(OperatorRefV1(\"IDENTITY\",\"v1\"),(1,),(;);registry=default_operator_registry(),input_types=(t,)); n=ASTApplyV1(OperatorRefV1(\"NEG\",\"v1\"),(1,),(;);registry=default_operator_registry(),input_types=(t,)); s=TypedASTProgramV1((i,a),(2,),(1,);registry=default_operator_registry()); x=TypedASTProgramV1((i,n),(2,),(1,);registry=default_operator_registry()); c=EqualityConditionRequirementV1(QualifiedRefV1(\"proposal-guard\",\"v1\"),digest256_text(\"proposal-contract\")); r=WholeProgramConditionalRewriteV1(QualifiedRefV1(\"proposal-rule\",\"v1\"),s,x,(c,),QualifiedRefV1(\"checker\",\"v1\"),digest256_text(\"checker\");registry=default_operator_registry()); d=derive_conditional_program_egraph(s,ConditionalRewriteSetV1((r,)),default_operator_registry()); q=query_conditional_equality(d.artifact,x); replay=replay_conditional_rewrite_trace(s,x,ConditionalRewriteSetV1((r,)),default_operator_registry(),q.provenance);",
                poison ? "v=FusionConceptAI._CEGProposal[]; Base.iterate(v); Base.push!(v,nothing);" : "",
                "a=d.artifact; print(a.complete,\"|\",q.status,\"|\",replay,\"|\",fieldcount(typeof(a.eclass.members)),\"|\",canonical_hash(a).value,\"|\",$hits)"
            ), "\n")
            script
        end

        proposal_baseline = _p1_child_fields(proposal_vector_child(false))
        proposal_poisoned = _p1_child_fields(proposal_vector_child(true))
        @test proposal_baseline[1:end-2] == proposal_poisoned[1:end-2]
        @test proposal_baseline[end-1:end] == ["false", "false"]
        @test proposal_poisoned[end-1:end] == ["true", "true"]  # both extensions really dispatch
        @test proposal_poisoned[1:3] == ["true", "conditional_equal", "true"]
        @test proposal_poisoned[4] == "3"

        """A custom Tuple conversion must not be consulted by the public typed ruleset constructor."""
        evil_rules_child = raw"""
            using FusionConceptAI
            struct EvilRules end
            const P1_EVIL_TUPLE_HIT = Ref(false)
            Base.Tuple(::EvilRules) = begin
                P1_EVIL_TUPLE_HIT[] = true
                (nothing,)
            end
            rejected = try
                ConditionalRewriteSetV1(EvilRules())
                false
            catch e
                e isa ArgumentError
            end
            println(P1_EVIL_TUPLE_HIT[], "|", rejected)
        """
        @test _p1_child_fields(evil_rules_child) == ["false", "true"]

        """Request identity includes all four canonicalization-budget fields, not only profile id/version."""
        profile_budget_child = raw"""
            using FusionConceptAI
            u=UnitSignature(); t=PhysicalType(:scalar_field,0,3,TemporalTypeV1(static_time),u)
            i=ASTInputV1(1,t); a=ASTApplyV1(OperatorRefV1("IDENTITY","v1"),(1,),(;);registry=default_operator_registry(),input_types=(t,))
            n=ASTApplyV1(OperatorRefV1("NEG","v1"),(1,),(;);registry=default_operator_registry(),input_types=(t,))
            s=TypedASTProgramV1((i,a),(2,),(1,);registry=default_operator_registry()); x=TypedASTProgramV1((i,n),(2,),(1,);registry=default_operator_registry())
            c=EqualityConditionRequirementV1(QualifiedRefV1("budget-guard","v1"),digest256_text("budget-contract"))
            r=WholeProgramConditionalRewriteV1(QualifiedRefV1("budget-rule","v1"),s,x,(c,),QualifiedRefV1("checker","v1"),digest256_text("checker");registry=default_operator_registry())
            rs=ConditionalRewriteSetV1((r,)); reg=default_operator_registry()
            wide=CanonicalizationProfileV1("same-profile","7",CanonicalizationBudgetV1(100000,10000,512,8000000))
            narrow=CanonicalizationProfileV1("same-profile","7",CanonicalizationBudgetV1(1,1,1,1))
            rw=derive_conditional_program_egraph(s,rs,reg;canonicalization_profile=wide)
            rn=derive_conditional_program_egraph(s,rs,reg;canonicalization_profile=narrow)
            println(rw.status,"|",rw.reason,"|",rw.artifact!==nothing,"|",rn.status,"|",rn.reason,"|",rn.artifact===nothing,"|",rw.derivation_request_hash != rn.derivation_request_hash)
        """
        @test _p1_child_fields(profile_budget_child) ==
            ["resolved", "conditional_egraph_derived", "true", "terminal_deferred", "exact_canonicalization_deferred", "true", "true"]
    end

    @testset "P1 authoritative traversal and mutation static scan" begin
        p1_files = (
            joinpath(@__DIR__, "..", "src", "IR", "ConditionalEGraphTypes.jl"),
            joinpath(@__DIR__, "..", "src", "IR", "ConditionalEGraphSaturation.jl"),
            joinpath(@__DIR__, "..", "src", "Canonical", "ConditionalEGraphCanonical.jl"),
        )
        for path in p1_files
            # Remove comments before matching; approved invoke/Core spellings are
            # intentionally retained and classified separately below.
            lines = map(readlines(path)) do line
                first(split(line, "#"; limit=2))
            end
            dynamic_push = filter(lines) do line
                occursin(r"(?<![A-Za-z0-9_.])push!\s*\(", line) && !occursin("invoke(", line)
            end
            dynamic_tuple = filter(lines) do line
                occursin(r"(?<![A-Za-z0-9_.])Tuple\(\s*[A-Za-z_]", line) && !occursin("Tuple{", line)
            end
            dynamic_field_iteration = filter(lines) do line
                occursin(r"\bfor\s+[A-Za-z_]\w*\s+in\s+getfield\(", line)
            end
            @test isempty(dynamic_push)
            @test isempty(dynamic_tuple)
            @test isempty(dynamic_field_iteration)
            # These are safe by construction and must not be false-positive hits.
            @test all(!occursin(r"(?<![A-Za-z0-9_.])push!\s*\(", line) || occursin("invoke(", line) for line in lines)
            @test all(!occursin("Core.arrayref", line) || !occursin("getindex", line) for line in lines)
        end
    end
end
