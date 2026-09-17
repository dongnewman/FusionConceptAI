using Test
using SHA

const SOURCE_M5 = normpath(joinpath(@__DIR__, "../../../src/RuntimeV4/M4Isolated/ManufacturedInverseFeedbackV1.jl"))
@assert isfile(SOURCE_M5) "M5 inverse source path is missing: $SOURCE_M5"
include(SOURCE_M5)

failure_codes(result) = Set(f.code for f in result.failures)
failure_signature(result) = [(f.code, f.path, f.detail) for f in result.failures]
stable_bytes(x) = sprint(show, x)

# M5-A's isolated canonical-IR builder accepts this local deterministic key
# adapter; defining it here keeps the inverse test independent of package
# entry-point canonicalization.
function _typed_ast_cse_key(n::ASTApplyV1, inputs::Tuple,
        nodes::Vector{AbstractTypedASTNodeV1}, manifest_hash::Digest256)
    repr((operator=n.operator_ref.qualified, manifest_hash=manifest_hash,
        inputs=Tuple(repr(nodes[i]) for i in inputs), parameters=n.parameters,
        output_type=n.output_type))
end

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
    d_result.control, a_result.composition
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
    @test result isa ManufacturedInverseFeedbackResultV1
    if result isa ManufacturedInverseFeedbackResultV1
        @test !result.valid
        @test result.status == :typed_failure
        @test code in failure_codes(result)
    end
    result
end

@testset "M5 inverse feedback manufactured v1" begin
    d, a = upstream_fixture()
    result = build_inverse(d, a)
    @test result.valid
    @test result.status == :valid
    @test isempty(result.failures)
    @test result.inverse !== nothing
    inverse_product = result.inverse::ManufacturedInverseFeedbackV1
    @test validate_inverse(inverse_product).valid
    @test is_valid_inverse(inverse_product)
    @test inverse_product.claim_ceiling == :manufactured_inverse_feedback
    @test inverse_product.evidence_scope == :screen_only

    @testset "exact Fraction-equivalent inverse and forward roundtrip" begin
        @test inverse_product.target == (M4RationalV1(2, 3), M4RationalV1(1, 3))
        @test inverse_product.recovered_alpha == M4RationalV1(2, 1)
        @test inverse_product.recovered_beta == M4RationalV1(1, 1)
        @test inverse_product.determinant == M4RationalV1(3, 1)
        @test inverse_product.eigenvalues == (M4RationalV1(1, 1), M4RationalV1(3, 1))
        @test inverse_product.eigen_margin_proxy == M4RationalV1(1, 3)
        @test inverse_product.forward.matrix == ((M4RationalV1(2, 1), M4RationalV1(-1, 1)),
            (M4RationalV1(-1, 1), M4RationalV1(2, 1)))
        @test inverse_product.forward.response == inverse_product.target
        @test inverse_product.roundtrip_residual == (M4RationalV1(0, 1), M4RationalV1(0, 1))
        @test forward(M4RationalV1(2, 1), M4RationalV1(1, 1)) == inverse_product.target
    end

    @testset "feedback deletion response and exact delta" begin
        @test inverse_product.feedback_interface_edge == "M5-interface-beta-feedback"
        @test inverse_product.feedback_active_response == (M4RationalV1(2, 3), M4RationalV1(1, 3))
        @test inverse_product.deletion_beta == M4RationalV1(0, 1)
        @test inverse_product.deletion_response == (M4RationalV1(1, 2), M4RationalV1(0, 1))
        @test inverse_product.feedback_response_delta == (M4RationalV1(1, 6), M4RationalV1(1, 3))
        @test inverse_product.response_changed
    end

    @testset "seed ledger, payload, hash, and replay determinism" begin
        @test Tuple(x.seed for x in inverse_product.multi_seed) == M5I_SEEDS_V1
        @test all(x -> x.replay && x.alpha == inverse_product.recovered_alpha &&
            x.beta == inverse_product.recovered_beta && x.response == inverse_product.target,
            inverse_product.multi_seed)
        result_2 = build_inverse(d, a, M5I_TARGET_V1)
        @test result_2.valid
        inverse_2 = result_2.inverse::ManufacturedInverseFeedbackV1
        swapped_input = build_inverse(a, d, M5I_TARGET_V1)
        @test swapped_input.valid
        inverse_swapped = swapped_input.inverse::ManufacturedInverseFeedbackV1
        @test inverse_payload(inverse_product) == inverse_payload(inverse_2)
        @test inverse_payload(inverse_product) == inverse_payload(inverse_swapped)
        @test stable_bytes(inverse_payload(inverse_product)) == stable_bytes(inverse_payload(inverse_2))
        @test manufactured_inverse_feedback_hash(inverse_product) == manufactured_inverse_feedback_hash(inverse_2)
        @test manufactured_inverse_feedback_hash(inverse_product) == manufactured_inverse_feedback_hash(inverse_swapped)
        payload = inverse_payload(inverse_product)
        @test payload.recovered == (alpha=M4RationalV1(2, 1), beta=M4RationalV1(1, 1))
        @test payload.feedback.delta == (M4RationalV1(1, 6), M4RationalV1(1, 3))
        @test manufactured_inverse_feedback_payload(inverse_product) == inverse_payload(inverse_product)
        @test is_valid_manufactured_inverse_feedback_v1(inverse_product)
    end

    @testset "typed upstream and target rejection controls" begin
        expect_typed(() -> build_inverse(nothing, a), :invalid_upstream)
        expect_typed(() -> build_inverse(d, nothing), :invalid_upstream)

        foreign_hashes = merge(a.source_hashes, (A=digest256_text("foreign-A"),))
        expect_typed(() -> build_inverse(d, clone_struct(a; source_hashes=foreign_hashes)), :foreign_hash)
        expect_typed(() -> build_inverse(clone_struct(d; source_owner="FOREIGN-OWNER"), a), :foreign_owner)
        foreign_provenance = M4ProvenanceDeclarationV1(:explicit_manufactured_or_analytic,
            :manufactured_only, :no_external_authority, false, :foreign, :screen_only)
        expect_typed(() -> build_inverse(clone_struct(d; provenance=foreign_provenance), a), :foreign_provenance)

        expect_typed(() -> build_inverse(d, a, (M4RationalV1(0, 1), M4RationalV1(0, 1))), :nonidentifiable_target)
        expect_typed(() -> build_inverse(d, a, (M4RationalV1(1, 0), M4RationalV1(1, 3))), :nonidentifiable_target)
        expect_typed(() -> build_inverse(d, a, (M4RationalV1(1, 1), M4RationalV1(1, 1))), :singular)
        expect_typed(() -> build_inverse(d, a, (M4RationalV1(1, 3), M4RationalV1(2, 3))), :impossible_target)
        expect_typed(() -> build_inverse(d, a, (M4RationalV1(1, 1), M4RationalV1(0, 1))), :non_spd)
    end

    @testset "typed corruption controls and deterministic failures" begin
        bad_roundtrip = clone_struct(inverse_product;
            roundtrip_residual=(M4RationalV1(1, 100), M4RationalV1(0, 1)))
        expect_typed(() -> validate_inverse(bad_roundtrip), :roundtrip)
        bad_seed = clone_struct(inverse_product;
            multi_seed=((seed=99, alpha=inverse_product.recovered_alpha,
                beta=inverse_product.recovered_beta, response=inverse_product.target, replay=true),
                inverse_product.multi_seed[2:end]...))
        expect_typed(() -> validate_inverse(bad_seed), :seed)
        bad_delete = clone_struct(inverse_product;
            deletion_response=inverse_product.feedback_active_response, response_changed=false)
        expect_typed(() -> validate_inverse(bad_delete), :feedback_deletion_no_effect)
        @test failure_signature(validate_inverse(bad_seed)) == failure_signature(validate_inverse(bad_seed))
    end

    @testset "repair regression: every stored derived field is replay-bound" begin
        # Outer inverse fields must be recomputed from the frozen target.
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            recovered_alpha=M4RationalV1(5, 2))), :impossible_target)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            recovered_beta=M4RationalV1(2, 1))), :impossible_target)

        # Every component of the nested forward snapshot is independently
        # corrupted. Each call must return a typed result, never throw.
        f = inverse_product.forward
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            forward=clone_struct(f; alpha=M4RationalV1(5, 2)))), :roundtrip)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            forward=clone_struct(f; beta=M4RationalV1(2, 1)))), :roundtrip)
        bad_matrix = ((M4RationalV1(9, 1), M4RationalV1(-1, 1)),
            (M4RationalV1(-1, 1), M4RationalV1(2, 1)))
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            forward=clone_struct(f; matrix=bad_matrix))), :roundtrip)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            forward=clone_struct(f; rhs=(M4RationalV1(0, 1), M4RationalV1(1, 1))))), :roundtrip)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            forward=clone_struct(f; response=(M4RationalV1(1, 1), M4RationalV1(1, 3))))), :roundtrip)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            forward=clone_struct(f; determinant=M4RationalV1(4, 1)))), :roundtrip)

        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            determinant=M4RationalV1(4, 1))), :singular)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            eigenvalues=(M4RationalV1(2, 1), M4RationalV1(3, 1)))), :non_spd)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            eigen_margin_proxy=M4RationalV1(2, 3))), :non_spd)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            roundtrip_residual=(M4RationalV1(1, 100), M4RationalV1(0, 1)))), :roundtrip)
        seed0 = inverse_product.multi_seed[1]
        bad_seed_response = (seed0, merge(inverse_product.multi_seed[2],
            (response=(M4RationalV1(1, 1), M4RationalV1(1, 3)),)),
            inverse_product.multi_seed[3])
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            multi_seed=bad_seed_response)), :seed)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            deletion_response=(M4RationalV1(2, 3), M4RationalV1(1, 3)))),
            :feedback_deletion_no_effect)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            feedback_response_delta=(M4RationalV1(0, 1), M4RationalV1(0, 1)))),
            :feedback_deletion_no_effect)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            response_changed=false)), :feedback_deletion_no_effect)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            m5a_composition_hash=digest256_text("foreign-m5a-composition"))), :foreign_hash)

        # Mutating retained nested snapshots must be rejected, even if the
        # outer identity/ledger fields remain unchanged.
        bad_m5a_hashes = merge(a.source_hashes, (A=digest256_text("foreign-nested-A"),))
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            m5a_upstream=clone_struct(a; source_hashes=bad_m5a_hashes))), :invalid_upstream)
        bad_m5a_ids = merge(a.typed_identities, (A=digest256_text("foreign-nested-identity"),))
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            m5a_upstream=clone_struct(a; typed_identities=bad_m5a_ids))), :invalid_upstream)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            m5a_upstream=clone_struct(a; source_owner="FOREIGN-NESTED-M5A-OWNER"))), :invalid_upstream)
        bad_m5a_provenance = (clone_struct(a.provenance[1]; claim_ceiling=:foreign),
            a.provenance[2:end]...)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            m5a_upstream=clone_struct(a; provenance=bad_m5a_provenance))), :invalid_upstream)

        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            m4d_upstream=clone_struct(d; source_owner="FOREIGN-NESTED-M4D-OWNER"))), :invalid_upstream)
        bad_m4d_provenance = M4ProvenanceDeclarationV1(:explicit_manufactured_or_analytic,
            :manufactured_only, :no_external_authority, false, :foreign, :screen_only)
        expect_typed(() -> validate_inverse(clone_struct(inverse_product;
            m4d_upstream=clone_struct(d; provenance=bad_m4d_provenance))), :invalid_upstream)

        # Joint owner/provenance mutations exercise the cross-snapshot joins.
        joint_m5a = clone_struct(a; source_owner="FOREIGN-JOINT-OWNER")
        joint_m4d = clone_struct(d; source_owner="FOREIGN-JOINT-OWNER")
        joint_owner_product = clone_struct(inverse_product;
            m4d_upstream=joint_m4d, m5a_upstream=joint_m5a)
        expect_typed(() -> validate_inverse(joint_owner_product), :invalid_upstream)
        joint_prov = M4ProvenanceDeclarationV1(:explicit_manufactured_or_analytic,
            :manufactured_only, :no_external_authority, false, :foreign_joint, :screen_only)
        joint_m5a_prov = (clone_struct(a.provenance[1]; claim_ceiling=:foreign_joint),
            a.provenance[2:end]...)
        joint_provenance_product = clone_struct(inverse_product;
            m4d_upstream=clone_struct(d; provenance=joint_prov),
            m5a_upstream=clone_struct(a; provenance=joint_m5a_prov))
        expect_typed(() -> validate_inverse(joint_provenance_product), :invalid_upstream)
    end

    @testset "isolated screen-only boundary" begin
        source_text = read(SOURCE_M5, String)
        @test !occursin("optimizer", lowercase(source_text))
        @test !occursin("real_reference", source_text)
        @test !occursin("CandidateStatePackage", source_text)
        @test !occursin("provider", lowercase(source_text))
        @test !occursin("solve_pde", lowercase(source_text))
        @test !isdefined(@__MODULE__, :RuntimeEvidenceV4)
        @test !isdefined(@__MODULE__, :ForwardChainContextV4)
        @test !isdefined(@__MODULE__, :iterative_solver)
        @test !isdefined(@__MODULE__, :solve_pde)
        @test !isdefined(@__MODULE__, :production_provider)
        @test !isdefined(@__MODULE__, :invoke_provider)
        @test inverse_product.provenance_bindings.source_scope == :manufactured_only
        @test inverse_product.provenance_bindings.authority_kind == :no_external_authority
    end
end

println("M5-INVERSE-FEEDBACK-TESTS PASS manufactured_inverse_feedback/screen_only")
