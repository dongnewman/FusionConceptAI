using SHA

const M5_SOURCE = normpath(joinpath(@__DIR__, "../../../../../../src/RuntimeV4/M4Isolated/ManufacturedInverseFeedbackV1.jl"))
include(M5_SOURCE)

function _typed_ast_cse_key(n::ASTApplyV1, inputs::Tuple,
        nodes::Vector{AbstractTypedASTNodeV1}, manifest_hash::Digest256)
    repr((operator=n.operator_ref.qualified, manifest_hash=manifest_hash,
        inputs=Tuple(repr(nodes[i]) for i in inputs), parameters=n.parameters,
        output_type=n.output_type))
end

function clone_struct(x; kwargs...)
    names = fieldnames(typeof(x))
    vals = NamedTuple{names}(Tuple(getfield(x, n) for n in names))
    updated = merge(vals, (; kwargs...))
    typeof(x)(updated...)
end

function fixture()
    a = manufactured_equation_ir_v1()
    b = lower_manufactured_residual(a).declaration::ManufacturedResidualDeclarationV1
    c = build_manufactured_discrete_control(b, 2, 2, 2).control::ManufacturedDiscreteControlV1
    d = build_manufactured_coupled_solve_control(c, c).control::ManufacturedCoupledSolveControlV1
    comp = build_manufactured_auto_composition(a, b, c, d).composition::ManufacturedAutoCompositionV1
    d, comp
end

function probe(label, thunk)
    try
        r = thunk()
        ok = r isa ManufacturedInverseFeedbackResultV1 && !r.valid && r.status == :typed_failure
        ok || error("not typed failure: $(typeof(r)) $(r)")
        println("PROBE $label typed_failure codes=$(join((string(f.code) for f in r.failures), ","))")
    catch err
        println(stderr, "PROBE_EXCEPTION $label $(typeof(err)): $(sprint(showerror, err))")
        exit(2)
    end
end

d, a = fixture()
base = build_inverse(d, a).inverse::ManufacturedInverseFeedbackV1
f = base.forward
probe("recovered_alpha", () -> validate_inverse(clone_struct(base; recovered_alpha=M4RationalV1(5, 2))))
probe("recovered_beta", () -> validate_inverse(clone_struct(base; recovered_beta=M4RationalV1(2, 1))))
probe("forward_alpha", () -> validate_inverse(clone_struct(base; forward=clone_struct(f; alpha=M4RationalV1(5, 2)))))
probe("forward_beta", () -> validate_inverse(clone_struct(base; forward=clone_struct(f; beta=M4RationalV1(2, 1)))))
probe("forward_matrix", () -> validate_inverse(clone_struct(base; forward=clone_struct(f; matrix=((M4RationalV1(9,1),M4RationalV1(-1,1)),(M4RationalV1(-1,1),M4RationalV1(2,1)))))))
probe("forward_rhs", () -> validate_inverse(clone_struct(base; forward=clone_struct(f; rhs=(M4RationalV1(0,1),M4RationalV1(1,1))))))
probe("forward_response", () -> validate_inverse(clone_struct(base; forward=clone_struct(f; response=(M4RationalV1(1,1),M4RationalV1(1,3))))))
probe("forward_determinant", () -> validate_inverse(clone_struct(base; forward=clone_struct(f; determinant=M4RationalV1(4,1)))))
probe("determinant", () -> validate_inverse(clone_struct(base; determinant=M4RationalV1(4,1))))
probe("eigenvalues", () -> validate_inverse(clone_struct(base; eigenvalues=(M4RationalV1(2,1),M4RationalV1(3,1)))))
probe("eigen_margin", () -> validate_inverse(clone_struct(base; eigen_margin_proxy=M4RationalV1(2,3))))
probe("roundtrip", () -> validate_inverse(clone_struct(base; roundtrip_residual=(M4RationalV1(1,100),M4RationalV1(0,1)))))
seed = base.multi_seed[1]
probe("seed_response", () -> validate_inverse(clone_struct(base; multi_seed=(seed, merge(base.multi_seed[2], (response=(M4RationalV1(1,1),M4RationalV1(1,3)),)), base.multi_seed[3]))))
probe("deletion_response", () -> validate_inverse(clone_struct(base; deletion_response=(M4RationalV1(2,3),M4RationalV1(1,3)))))
probe("feedback_delta", () -> validate_inverse(clone_struct(base; feedback_response_delta=(M4RationalV1(0,1),M4RationalV1(0,1)))))
probe("response_changed", () -> validate_inverse(clone_struct(base; response_changed=false)))
probe("m5a_composition_hash", () -> validate_inverse(clone_struct(base; m5a_composition_hash=digest256_text("foreign-m5a-composition"))))
probe("m5a_source_hash", () -> validate_inverse(clone_struct(base; m5a_upstream=clone_struct(a; source_hashes=merge(a.source_hashes, (A=digest256_text("foreign-nested-A"),))))))
probe("m5a_typed_identity", () -> validate_inverse(clone_struct(base; m5a_upstream=clone_struct(a; typed_identities=merge(a.typed_identities, (A=digest256_text("foreign-nested-identity"),))))))
probe("m5a_owner", () -> validate_inverse(clone_struct(base; m5a_upstream=clone_struct(a; source_owner="FOREIGN-NESTED-M5A-OWNER"))))
bad_m5a_prov = (clone_struct(a.provenance[1]; claim_ceiling=:foreign), a.provenance[2:end]...)
probe("m5a_provenance", () -> validate_inverse(clone_struct(base; m5a_upstream=clone_struct(a; provenance=bad_m5a_prov))))
probe("m4d_owner", () -> validate_inverse(clone_struct(base; m4d_upstream=clone_struct(d; source_owner="FOREIGN-NESTED-M4D-OWNER"))))
bad_m4d_prov = M4ProvenanceDeclarationV1(:explicit_manufactured_or_analytic,:manufactured_only,:no_external_authority,false,:foreign,:screen_only)
probe("m4d_provenance", () -> validate_inverse(clone_struct(base; m4d_upstream=clone_struct(d; provenance=bad_m4d_prov))))
joint_m5a = clone_struct(a; source_owner="FOREIGN-JOINT-OWNER")
joint_m4d = clone_struct(d; source_owner="FOREIGN-JOINT-OWNER")
probe("joint_owner", () -> validate_inverse(clone_struct(base; m4d_upstream=joint_m4d, m5a_upstream=joint_m5a)))
joint_prov = M4ProvenanceDeclarationV1(:explicit_manufactured_or_analytic,:manufactured_only,:no_external_authority,false,:foreign_joint,:screen_only)
joint_m5a_prov = (clone_struct(a.provenance[1]; claim_ceiling=:foreign_joint), a.provenance[2:end]...)
probe("joint_provenance", () -> validate_inverse(clone_struct(base; m4d_upstream=clone_struct(d; provenance=joint_prov), m5a_upstream=clone_struct(a; provenance=joint_m5a_prov))))
println("M5-INVERSE-FEEDBACK-REPAIR-PROBE PASS cases=25 exceptions=0")
println("M5A_COMPOSITION_HASH ", manufactured_auto_composition_hash(a).value)
