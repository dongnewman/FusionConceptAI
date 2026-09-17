using Test
using FusionConceptAI

const _G1D_ROOT = joinpath(@__DIR__, "..", "..", "..", "src", "GenomeV5", "G1")
Base.include(FusionConceptAI, joinpath(_G1D_ROOT, "DiffusionDeclarationV1.jl"))
const G = FusionConceptAI

const _U = G.UnitSignature((0, 0, 0, 0, 0, 0, 0))
const _GRAD_U = G.UnitSignature((-1, 0, 0, 0, 0, 0, 0))
const _DIV_GRAD_U = G.UnitSignature((-2, 0, 0, 0, 0, 0, 0))
const _SCALAR = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), _U)
const _GRAD = G.PhysicalType(:vector_field, 1, 3, G.TemporalTypeV1(G.static_time), _GRAD_U)
const _TENSOR = G.PhysicalType(:tensor_field, 2, 3, G.TemporalTypeV1(G.static_time), _U)
const _F = G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.static_time), _DIV_GRAD_U)
const _CANDIDATE = G.QualifiedRefV1("fusionconceptai://GenomeV5/candidate/up2-01-g1-fixture", "v5")
const _SOURCE = G.QualifiedRefV1("fusionconceptai://source/candidate-up2-01-g1-fixture", "v1")
function _declaration(; K_lower=1 // 1000, K_upper=1000 // 1, source=_SOURCE)
    u = G.G1DiffusionScalarFieldV1("u_candidate", _SCALAR, source;
        source_expression="u_candidate(x)=x1+x2+x3")
    k_expression = G.G1DiffusionDiagonalAffineKFieldV1("K_candidate_x_affine";
        domain_min=(0 // 1, 0 // 1, 0 // 1), domain_max=(1 // 1, 1 // 1, 1 // 1),
        base_diag=(2 // 1, 3 // 1, 4 // 1), slope_diag=(1 // 10, 1 // 20, 1 // 30))
    k = G.G1DiffusionCoefficientFieldV1("K_candidate_x", _TENSOR, source;
        lower_bound=K_lower == 1 // 1000 ? 2 // 1 : K_lower,
        upper_bound=K_upper == 1000 // 1 ? 121 // 30 : K_upper,
        expression=k_expression)
    f = G.G1DiffusionScalarFieldV1("f_candidate", _F, source;
        source_expression="f_candidate(x)=1")
    grad = G.G1TypedGradV1(G.QualifiedRefV1("fusionconceptai://GenomeV5/G1/operator/GRAD", "v1"),
        "u_candidate", "grad_u", _SCALAR, _GRAD)
    k_apply = G.G1TypedKApplyV1(G.QualifiedRefV1("fusionconceptai://GenomeV5/G1/operator/K_APPLY", "v1"),
        "grad_u", "flux_u", _GRAD, _GRAD, "K_candidate_x")
    div = G.G1TypedDivV1(G.QualifiedRefV1("fusionconceptai://GenomeV5/G1/operator/DIV", "v1"),
        "flux_u", "f_candidate", _GRAD, _F)
    chain = G.G1DiffusionOperatorChainV1(grad, k_apply, div, "f_candidate")
    payload = G.G1DiffusionSourcePayloadV1(_CANDIDATE, source, "candidate-source-v1", u, k, f)
    G.g1_diffusion_declaration_v1(_CANDIDATE, source, "candidate-source-v1",
        G.g1_diffusion_source_hash_v1(payload),
        u, k, f, chain, G.QualifiedRefV1("fusionconceptai://GenomeV5/G1/closure/diffusion", "v1"),
        G.QualifiedRefV1(G.G1_DIFFUSION_APPLICABILITY_ID_V1, "v1"),
        "bounded-3d-candidate-domain", (:missing_authoritative_source, :manufactured_solution_as_authority);
        source_payload=payload)
end

@testset "UP2-01 G1 diffusion V1 positive declaration and typed receipt" begin
    d = _declaration()
    @test G.g1_diffusion_validate(d)[1] == :valid
    @test d.u.physical_type.tensor_rank == 0
    @test d.u.physical_type.spatial_dimension == 3
    @test d.K.spatial_dependency == :spatial
    @test d.K.positive_definite
    @test d.ownership == :candidate_owned
    @test d.K.lower_bound == 2 // 1 && d.K.upper_bound == 121 // 30
    @test d.K.expression.slope_diag != (0 // 1, 0 // 1, 0 // 1)
    @test G.g1_diffusion_k_eval(d.K.expression, (1 // 2, 1 // 2, 1 // 2))[1][1] == 41 // 20
    @test G.g1_diffusion_k_enclosure(d.K.expression).lower == 2 // 1
    @test G.g1_diffusion_k_enclosure(d.K.expression).upper == 121 // 30
    @test_throws ArgumentError G.g1_diffusion_k_eval(d.K.expression, (2 // 1, 0 // 1, 0 // 1))
    @test d.source_hash == G.g1_diffusion_source_hash_v1(d.source_payload)
    @test d.source_payload.candidate_ref == d.candidate_ref
    @test d.operators.grad.input_field_id == d.u.field_id
    @test d.operators.div.output_field_id == d.f.field_id
    @test d.operators.residual_sign == -1
    @test G.g1_diffusion_receipt_v1(d).resolution == :terminal_deferred
    @test !G.g1_diffusion_receipt_v1(d).accepted
    @test G.g1_diffusion_receipt_v1(d).claim_ceiling == :contract_only
    @test G.g1_diffusion_receipt_v1(d).physical_evidence == false
    receipt = G.g1_diffusion_receipt_v1(d)
    @test receipt.schema_hash == G.g1_diffusion_schema_hash_v1()
    @test receipt.canonicalization_hash == G.g1_diffusion_canonicalization_hash_v1()
    @test receipt.profile_hash == G.g1_diffusion_profile_hash_v1()
    @test receipt.gaps == G.G1_DIFFUSION_REQUIRED_GAPS_V1
    @test receipt.compile_calls == 0
    @test receipt.provider_calls == 0
    @test receipt.mesh_calls == 0
    @test receipt.solver_calls == 0
    @test G.g1_diffusion_receipt_hash_v1(receipt) == G.canonical_hash(receipt)
    @test G.g1_diffusion_authority_check(d).status == :terminal_deferred
    admitted = G.g1_diffusion_admit_v1(d)
    @test admitted.status == :terminal_deferred
    @test admitted.error_code == :missing_external_authority
    @test admitted.error_path == "/authority/source"
    @test admitted.declaration === d
    @test admitted.exception_type === nothing
    program_fault = G._g1d_admit_v1_fault_probe(d)
    @test program_fault.status == :program_exception
    @test program_fault.error_code == :unexpected_exception
    @test program_fault.error_path == "/declaration"
    @test program_fault.declaration === nothing
    @test program_fault.exception_type !== nothing
end

@testset "UP2-01 G1 diffusion V1 fail-closed negative controls" begin
    d = _declaration()
    @test_throws ArgumentError _declaration(K_lower=1 // 1)
    @test_throws ArgumentError G.G1DiffusionDiagonalAffineKFieldV1("constant"; slope_diag=(0 // 1, 0 // 1, 0 // 1))
    @test_throws ArgumentError G.G1DiffusionDiagonalAffineKFieldV1("negative"; base_diag=(-1 // 1, 2 // 1, 3 // 1))
    @test_throws ArgumentError G.G1TypedGradV1(G.QualifiedRefV1("grad", "v1"), "u_candidate", "grad_u", _SCALAR,
        G.PhysicalType(:vector_field, 1, 3, G.TemporalTypeV1(G.static_time), _U))
    @test_throws ArgumentError G.G1TypedGradV1(G.QualifiedRefV1(G.G1_DIFFUSION_GRAD_OPERATOR_ID_V1, "v1"), "u_candidate", "grad_u",
        G.PhysicalType(:scalar_field, 0, 3, G.TemporalTypeV1(G.algebraic_time), _U), _GRAD)
    @test_throws ArgumentError G.G1TypedGradV1(G.QualifiedRefV1(G.G1_DIFFUSION_GRAD_OPERATOR_ID_V1, "v1"), "u_candidate", "grad_u", _SCALAR,
        G.PhysicalType(:wrong_vector_kind, 1, 3, G.TemporalTypeV1(G.static_time), _GRAD_U))
    @test_throws ArgumentError G.G1TypedKApplyV1(G.QualifiedRefV1("K_APPLY_WRONG", "v1"), "grad_u", "flux_u", _GRAD, _GRAD, "K_candidate_x")
    @test_throws ArgumentError G.G1TypedDivV1(G.QualifiedRefV1("DIV_WRONG", "v1"), "flux_u", "f_candidate", _GRAD, _F)
    @test_throws ArgumentError G.G1DiffusionOperatorChainV1(d.operators.grad, d.operators.coefficient_apply,
        G.G1TypedDivV1(G.QualifiedRefV1("div", "v1"), "flux_u", "wrong_f", _GRAD, _F), "f_candidate")
    @test_throws ArgumentError G.G1DiffusionOperatorChainV1(d.operators.grad, d.operators.coefficient_apply,
        d.operators.div, "f_candidate"; residual_sign=1)
    @test_throws ArgumentError G.g1_diffusion_edit_source(d, :K, "K_candidate_x")
    @test_throws ArgumentError G.g1_diffusion_declaration_v1(_CANDIDATE, _SOURCE, "candidate-source-v1",
        G.digest256_text("forged"), d.u, d.K, d.f, d.operators, d.closure_ref, d.applicability_ref,
        d.applicability_domain, d.negative_controls; source_payload=d.source_payload)
    foreign_candidate = G.QualifiedRefV1("fusionconceptai://GenomeV5/candidate/foreign", "v5")
    @test_throws ArgumentError G.g1_diffusion_declaration_v1(foreign_candidate, d.source_ref, d.source_version,
        d.source_hash, d.u, d.K, d.f, d.operators, d.closure_ref, d.applicability_ref,
        d.applicability_domain, d.negative_controls; source_payload=d.source_payload)
    @test_throws ArgumentError G.G1DiffusionSourcePayloadV1(d.source_ref, d.source_version, d.u, d.K, d.f)
    @test_throws ArgumentError G.g1_diffusion_declaration_v1(d.candidate_ref, d.source_ref, d.source_version,
        d.source_hash, d.u, d.K, d.f, d.operators,
        G.QualifiedRefV1("foreign://closure", "v1"), d.applicability_ref,
        d.applicability_domain, d.negative_controls; source_payload=d.source_payload)
    @test_throws ArgumentError G.g1_diffusion_declaration_v1(d.candidate_ref, d.source_ref, d.source_version,
        d.source_hash, d.u, d.K, d.f, d.operators, d.closure_ref,
        G.QualifiedRefV1(G.G1_DIFFUSION_APPLICABILITY_ID_V1, "v2"),
        d.applicability_domain, d.negative_controls; source_payload=d.source_payload)
    forged = G.g1_diffusion_admit_source_v1(d.source_payload, G.digest256_text("forged"))
    @test forged.status == :fail_closed
    @test forged.error_code == :source_hash_mismatch
    @test forged.error_path == "/source_hash"
    @test forged.declaration === nothing
    bad_bound = G.g1_diffusion_admit_k_v1(d.K.expression;
        lower_bound=1 // 1, upper_bound=d.K.upper_bound)
    @test bad_bound.status == :fail_closed
    @test bad_bound.error_code == :K_lower_bound_mismatch
    @test bad_bound.error_path == "/K/lower_bound"
    bad_domain = G.g1_diffusion_admit_k_v1(d.K.expression;
        probe_point=(2 // 1, 0 // 1, 0 // 1))
    @test bad_domain.status == :fail_closed
    @test bad_domain.error_code == :K_domain_out_of_bounds
    @test bad_domain.error_path == "/K/probe_point"
    malformed_probe = G.g1_diffusion_admit_k_v1(d.K.expression;
        probe_point=(0 // 1, 0 // 1))
    @test malformed_probe.status == :fail_closed
    @test malformed_probe.error_code == :K_probe_point_malformed
    @test malformed_probe.error_path == "/K/probe_point"
    @test malformed_probe.declaration === nothing
    @test malformed_probe.exception_type === nothing
    bad_sign = G.g1_diffusion_admit_chain_v1(d.operators; expected_residual_sign=1)
    @test bad_sign.status == :fail_closed
    @test bad_sign.error_code == :expected_residual_sign_not_negative
    @test bad_sign.error_path == "/operators/residual_sign"
    bad_units = G.g1_diffusion_admit_chain_v1(d.operators;
        expected_grad_input_units=_GRAD_U)
    @test bad_units.status == :fail_closed
    @test bad_units.error_code == :grad_unit_mismatch
    @test bad_units.error_path == "/operators/grad/input_type/units"
    bad_type = G.g1_diffusion_admit_source_v1(d.source_payload, "forged")
    @test bad_type.status == :fail_closed
    @test bad_type.error_code == :source_hash_type
    @test bad_type.error_path == "/source_hash"
    @test G.g1_diffusion_authority_check(d; authoritative_source=true).status == :terminal_deferred
    tampered = G.G1DiffusionDeclarationV1(d.candidate_ref, d.source_ref, d.source_version, d.source_hash,
        d.u, d.K, d.f, d.operators, d.closure_ref, d.applicability_ref, d.applicability_domain,
        d.negative_controls; ownership=d.ownership, source_payload=d.source_payload,
        declaration_hash=G.digest256_text("tampered-declaration"))
    @test G.g1_diffusion_validate(tampered)[1] == :fail_closed
end

@testset "UP2-01 G1 diffusion V1 source edit changes identity" begin
    d = _declaration()
    edited_k = G.G1DiffusionCoefficientFieldV1("K_candidate_x", _TENSOR, _SOURCE;
        lower_bound=2 // 1, upper_bound=121 // 30,
        expression=G.G1DiffusionDiagonalAffineKFieldV1("K_candidate_x_affine_edited";
            slope_diag=(1 // 5, 1 // 20, 1 // 30)))
    edited = G.g1_diffusion_edit_source(d, :K, edited_k)
    @test G.g1_diffusion_declaration_hash_v1(edited) != G.g1_diffusion_declaration_hash_v1(d)
    @test edited.source_hash != d.source_hash
    @test G.g1_diffusion_validate(edited)[1] == :valid
    edited_u = G.G1DiffusionScalarFieldV1("u_candidate", _SCALAR, _SOURCE;
        source_expression="u_candidate(x)=x1-x2+x3")
    @test G.g1_diffusion_edit_source(d, :u, edited_u).source_hash != d.source_hash
    edited_f = G.G1DiffusionScalarFieldV1("f_candidate", _F, _SOURCE;
        source_expression="f_candidate(x)=2")
    @test G.g1_diffusion_edit_source(d, :f, edited_f).source_hash != d.source_hash
end
