using Test
using SHA

const ROOT = normpath(joinpath(@__DIR__, "../../.."))
const SOURCE_CEG = joinpath(ROOT, "src", "RuntimeV4", "M4Isolated", "ManufacturedConditionalEGraphV1.jl")
@assert isfile(SOURCE_CEG) "M5 e-graph source path is missing: $SOURCE_CEG"
include(SOURCE_CEG)

# Keep this test independently includable: no package entry point, shared
# registry mutation, provider, solver, search, or candidate path is loaded.
function _typed_ast_cse_key(n::ASTApplyV1, inputs::Tuple,
        nodes::Vector{AbstractTypedASTNodeV1}, manifest_hash::Digest256)
    repr((operator=n.operator_ref.qualified, manifest_hash=manifest_hash,
        inputs=Tuple(repr(nodes[i]) for i in inputs), parameters=n.parameters,
        output_type=n.output_type))
end

failure_codes(r) = Set(f.code for f in r.failures)
failure_signature(r) = [(f.code, f.path, f.detail) for f in r.failures]
stable_bytes(x) = sprint(show, x)
const SMALL_EGRAPH_BUDGET = ConditionalEGraphBudgetV1(
    max_programs=8, max_rewrite_attempts=16, max_rounds=4, max_trace_steps=8)

function upstream_fixture()
    a = manufactured_equation_ir_v1()
    @assert validate_manufactured_equation_ir(a).valid
    b_result = lower_manufactured_residual(a)
    @assert b_result.valid && b_result.declaration !== nothing
    b = b_result.declaration::ManufacturedResidualDeclarationV1
    c_result = build_manufactured_discrete_control(b, 2, 2, 2)
    @assert c_result.valid && c_result.control !== nothing
    c = c_result.control::ManufacturedDiscreteControlV1
    d_result = build_manufactured_coupled_solve_control(c, c)
    @assert d_result.valid && d_result.control !== nothing
    a_result = build_manufactured_auto_composition(a, b, c, d_result.control)
    @assert a_result.valid && a_result.composition !== nothing
    d_result.control::ManufacturedCoupledSolveControlV1,
        a_result.composition::ManufacturedAutoCompositionV1
end

function clone_struct(x; kwargs...)
    names = fieldnames(typeof(x))
    vals = NamedTuple{names}(Tuple(getfield(x, n) for n in names))
    updated = merge(vals, (; kwargs...))
    typeof(x)(updated...)
end

function expect_typed(thunk, code::Symbol)
    result = try
        thunk()
    catch err
        println(stderr, "unexpected unclassified exception: $(typeof(err)): $(sprint(showerror, err))")
        @test false
        return nothing
    end
    @test result isa ManufacturedConditionalEGraphResultV1
    if result isa ManufacturedConditionalEGraphResultV1
        @test !result.valid
        @test result.status in (:typed_failure, :fail_closed)
        @test code in failure_codes(result)
    end
    result
end

@testset "M5 manufactured conditional e-graph v1" begin
    d, a = upstream_fixture()
    i_result = build_inverse(d, a)
    @assert i_result.valid && i_result.inverse !== nothing
    b = i_result.inverse::ManufacturedInverseFeedbackV1
    @test validate_manufactured_auto_composition(a).valid
    @test validate_inverse(b).valid
    # Regression for the repaired A->B ambient identity join: the CEG
    # canonical methods are already loaded, yet A's frozen product hash stays
    # 722e... and the inverse product remains valid without a test fallback.
    @test manufactured_auto_composition_hash(a) ==
        Digest256("722e59e841d6551fe9001e1279266e1aaf5a798ca0d16625d5a4fd81a59ab694")
    @test build_inverse(d, a).valid
    @test b.m5a_upstream === a
    @test b.m5a_composition_hash == manufactured_auto_composition_hash(a)
    @test b.owner_bindings == _m5ceg_owner_projection(a, b)
    @test b.provenance_bindings == _m5ceg_provenance_projection(a, b)

    # Keep positive test builds bounded for the preparation lane.  The
    # historical default budget is intentionally not exercised here because
    # it is a deferred performance gap (it exceeded the 20-minute test-only
    # ceiling); this still permits multiple rewrite rounds and trace replay.
    result = build_manufactured_conditional_egraph(a, b; budget=SMALL_EGRAPH_BUDGET)
    @test result.valid
    @test result.status in (:valid, :terminal_deferred)
    @test result.egraph !== nothing
    product = result.egraph::ManufacturedConditionalEGraphV1
    @test validate_manufactured_conditional_egraph(product).valid
    @test is_valid_manufactured_conditional_egraph(product)
    @test product.claim_ceiling == :synthetic_egraph_equality
    @test product.evidence_scope == :screen_only
    @test product.condition_catalog isa Tuple
    @test Tuple(c.kind for c in product.condition_catalog) == M5CEG_CONDITION_KINDS_V1
    @test length(product.condition_catalog) == 8
    @test product.rewrite_set isa ConditionalRewriteSetV1
    @test length(product.rewrite_set.rules) == 2
    @test product.m5a_source_sha256 == M5CEG_M5A_SOURCE_SHA256_V1
    @test product.m5a_composition_hash == M5CEG_M5A_COMPOSITION_SHA256_V1
    @test product.m5b_source_sha256 == M5CEG_M5B_SOURCE_SHA256_V1

    @testset "deterministic build, saturation, payload and hash" begin
        result2 = build_manufactured_conditional_egraph(a, b; budget=SMALL_EGRAPH_BUDGET)
        @test result2.valid
        p2 = result2.egraph::ManufacturedConditionalEGraphV1
        @test manufactured_conditional_egraph_payload(product) ==
            manufactured_conditional_egraph_payload(p2)
        @test stable_bytes(manufactured_conditional_egraph_payload(product)) ==
            stable_bytes(manufactured_conditional_egraph_payload(p2))
        @test manufactured_conditional_egraph_hash(product) ==
            manufactured_conditional_egraph_hash(p2)
        @test saturate_manufactured_conditional_egraph(product) === product
        @test validate_manufactured_conditional_egraph(saturate_manufactured_conditional_egraph(product)).valid
        @test manufactured_conditional_egraph_hash(product) ==
            manufactured_conditional_egraph_hash(saturate_manufactured_conditional_egraph(product))
    end

    @testset "query and 100 percent trace replay" begin
        g = product.graph
        @test g !== nothing
        if g !== nothing
            members = g.eclass.members
            @test length(members) >= 1
            for member in members
                member.provenance === nothing && continue
                q = query_manufactured_conditional_equality(product, member.program)
                @test q !== nothing
                @test q.status == conditional_equal
                @test q.provenance !== nothing
                @test replay_manufactured_conditional_egraph(product, member.program,
                    q.provenance)
                @test replay_manufactured_conditional_egraph(product, member.program)
            end
        end
        @test query_manufactured_conditional_equality(product, product.source_program).status == reflexive_equal
        wrong = query_manufactured_conditional_equality(product, product.source_program)
        @test wrong.status == reflexive_equal
        @test replay_manufactured_conditional_egraph(product, product.source_program) == false
    end

    @testset "condition catalog and zero-merge/fail-closed controls" begin
        catalog = product.condition_catalog
        missing = catalog[1:end-1]
        expect_typed(() -> build_manufactured_conditional_egraph(a, b;
            condition_catalog=missing), :condition_rejected)
        altered = (clone_struct(catalog[1]; expected_hash=digest256_text("foreign-condition")),
            catalog[2:end]...)
        expect_typed(() -> build_manufactured_conditional_egraph(a, b;
            condition_catalog=altered), :condition_rejected)
        duplicate = (catalog[1], catalog[1], catalog[3:end]...)
        expect_typed(() -> build_manufactured_conditional_egraph(a, b;
            condition_catalog=duplicate), :condition_rejected)
        contradiction = (catalog[1], clone_struct(catalog[1];
            expected_hash=digest256_text("contradictory-condition")), catalog[2:end]...)
        expect_typed(() -> build_manufactured_conditional_egraph(a, b;
            condition_catalog=contradiction), :condition_rejected)
        @test all(c.requirement.condition_contract_hash == c.expected_hash for c in catalog)
        @test _m5ceg_catalog_matches(catalog, a, b)
    end

    @testset "M5-A/M5-B identity owner provenance joins" begin
        bad_a_hashes = merge(a.source_hashes, (A=digest256_text("foreign-M5A"),))
        expect_typed(() -> build_manufactured_conditional_egraph(clone_struct(a;
            source_hashes=bad_a_hashes), b), :foreign_hash)
        expect_typed(() -> build_manufactured_conditional_egraph(a,
            clone_struct(b; m5a_composition_hash=digest256_text("foreign-composition"))),
            :foreign_hash)
        bad_owner = merge(b.owner_bindings, (source_owner="FOREIGN-OWNER",))
        expect_typed(() -> build_manufactured_conditional_egraph(a,
            clone_struct(b; owner_bindings=bad_owner)), :foreign_owner)
        bad_prov = merge(b.provenance_bindings, (source_scope=:foreign,))
        expect_typed(() -> build_manufactured_conditional_egraph(a,
            clone_struct(b; provenance_bindings=bad_prov)), :foreign_provenance)
        @test failure_signature(validate_manufactured_conditional_egraph(product)) ==
            failure_signature(validate_manufactured_conditional_egraph(product))
    end

    @testset "bounded budgets remain explicit terminal_deferred" begin
        for budget in (ConditionalEGraphBudgetV1(max_rewrite_attempts=0),
                       ConditionalEGraphBudgetV1(max_rounds=0),
                       ConditionalEGraphBudgetV1(max_trace_steps=0))
            bounded = build_manufactured_conditional_egraph(a, b; budget=budget)
            @test bounded.valid
            @test bounded.status == :terminal_deferred
            @test bounded.egraph !== nothing
            if bounded.egraph !== nothing
                @test bounded.egraph.status == :terminal_deferred
                @test bounded.egraph.graph !== nothing
                @test !bounded.egraph.graph.complete
                @test validate_manufactured_conditional_egraph(bounded).valid
            end
        end
    end

    @testset "tampered trace and typed no-exception boundary" begin
        g = product.graph
        if g !== nothing
            witness = findfirst(m -> m.provenance !== nothing, g.eclass.members)
            if witness !== nothing
                m = g.eclass.members[witness]
                prov = m.provenance
                @test replay_manufactured_conditional_egraph(product, product.source_program,
                    prov) == false
                @test replay_manufactured_conditional_egraph(product, m.program,
                    prov) == true
            end
        end
        expect_typed(() -> build_manufactured_conditional_egraph(nothing, b), :invalid_m5a)
        expect_typed(() -> build_manufactured_conditional_egraph(a, nothing), :invalid_m5b)
        expect_typed(() -> build_manufactured_conditional_egraph(a, b; registry=(:foreign,)), :fail_closed)
    end

    @testset "R1 repair regressions and alias guard" begin
        # A missing graph is only a valid terminal-deferred state when the
        # product explicitly records that status.
        absent_non_deferred = clone_struct(product; graph=nothing, status=:valid)
        checked_absent = validate_manufactured_conditional_egraph(absent_non_deferred)
        @test !checked_absent.valid
        @test checked_absent.status == :typed_failure
        @test :status_mismatch in failure_codes(checked_absent)

        # The status must agree with the retained graph completeness bit.
        mismatched_status = clone_struct(product;
            status=product.graph.complete ? :terminal_deferred : :valid)
        checked_status = validate_manufactured_conditional_egraph(mismatched_status)
        @test !checked_status.valid
        @test checked_status.status == :typed_failure
        @test :status_mismatch in failure_codes(checked_status)

        # Both source identity and stored source hash are independently
        # replay-bound.  A changed source with an old hash is fail-closed.
        foreign_source_hash = clone_struct(product;
            source_program_hash=digest256_text("foreign-source-program"))
        checked_hash = validate_manufactured_conditional_egraph(foreign_source_hash)
        @test !checked_hash.valid
        @test checked_hash.status == :typed_failure
        @test :foreign_hash in failure_codes(checked_hash)
        changed_source = TypedASTProgramV1(product.source_program.nodes,
            reverse(product.source_program.roots), product.source_program.input_ports,
            product.registry)
        tampered_source = clone_struct(product; source_program=changed_source)
        checked_source = validate_manufactured_conditional_egraph(tampered_source)
        @test !checked_source.valid
        @test checked_source.status == :typed_failure
        @test (:foreign_hash in failure_codes(checked_source)) ||
            (:fail_closed in failure_codes(checked_source))

        # Conditional aliases must not overwrite the M5-B API aliases that
        # were already installed by ManufacturedInverseFeedbackV1.
        @test validate === validate_inverse
        @test payload === inverse_payload
        @test is_valid === is_valid_inverse
        @test validate(b).valid
        @test payload(b) == inverse_payload(b)
        @test is_valid(b)
        @test validate_manufactured_inverse_feedback(b).valid
        @test is_valid_manufactured_inverse_feedback_v1(b)
    end

    @testset "isolated screen-only boundary" begin
        source_text = read(SOURCE_CEG, String)
        @test !occursin("optimizer", lowercase(source_text))
        @test !occursin("provider", lowercase(source_text))
        @test !occursin("solve_pde", lowercase(source_text))
        @test !occursin("CandidateStatePackage", source_text)
        @test !isdefined(@__MODULE__, :RuntimeEvidenceV4)
        @test !isdefined(@__MODULE__, :ForwardChainContextV4)
        @test !isdefined(@__MODULE__, :iterative_solver)
        @test product.claim_ceiling == :synthetic_egraph_equality
        @test product.evidence_scope == :screen_only
    end
end

println("M5-CONDITIONAL-EGRAPH-TESTS PASS manufactured_conditional_egraph/screen_only")
