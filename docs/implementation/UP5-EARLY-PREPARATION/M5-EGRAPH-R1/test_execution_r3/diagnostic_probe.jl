using SHA
const ROOT = normpath(joinpath(@__DIR__, "../../../../.."))
include(joinpath(ROOT, "src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl"))
function _typed_ast_cse_key(n::ASTApplyV1, inputs::Tuple, nodes::Vector{AbstractTypedASTNodeV1}, manifest_hash::Digest256)
    repr((operator=n.operator_ref.qualified, manifest_hash=manifest_hash, inputs=Tuple(repr(nodes[i]) for i in inputs), parameters=n.parameters, output_type=n.output_type))
end
canonical_hash(x::NamedTuple) = digest256_text(string(x))
a4 = manufactured_equation_ir_v1()
b4 = lower_manufactured_residual(a4).declaration
c4 = build_manufactured_discrete_control(b4, 2, 2, 2).control
d4 = build_manufactured_coupled_solve_control(c4, c4).control
a5 = build_manufactured_auto_composition(a4, b4, c4, d4).composition
i5 = build_inverse(d4, a5)
println("DIAGNOSTIC schema=M5-EGRAPH-R1-INVERSE-JOIN")
println("valid=$(i5.valid) status=$(i5.status)")
for f in i5.failures
    println("failure code=$(f.code) path=$(f.path) detail=$(f.detail)")
end
println("m5a_hash=$(manufactured_auto_composition_hash(a5).value)")
println("m5a_expected=$(M5I_M5A_SOURCE_SHA256_V1.value) source=$(a5.source_hashes)")
