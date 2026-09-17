using SHA
const ROOT = normpath(joinpath(@__DIR__, "../../../../.."))
include(joinpath(ROOT, "src/RuntimeV4/M4Isolated/ManufacturedAutoCompositionV1.jl"))
function _typed_ast_cse_key(n::ASTApplyV1, inputs::Tuple,
        nodes::Vector{AbstractTypedASTNodeV1}, manifest_hash::Digest256)
    repr((operator=n.operator_ref.qualified, manifest_hash=manifest_hash,
        inputs=Tuple(repr(nodes[i]) for i in inputs), parameters=n.parameters,
        output_type=n.output_type))
end
a4 = manufactured_equation_ir_v1()
b4 = lower_manufactured_residual(a4).declaration
c4 = build_manufactured_discrete_control(b4, 2, 2, 2).control
d4 = build_manufactured_coupled_solve_control(c4, c4).control
a5 = build_manufactured_auto_composition(a4, b4, c4, d4)
println("BUILD_STATUS=$(a5.status) BUILD_VALID=$(a5.valid)")
for f in a5.failures
    println("BUILD_FAILURE code=$(f.code) path=$(f.path) detail=$(f.detail)")
end
@assert a5.valid && a5.composition !== nothing
composition = a5.composition::ManufacturedAutoCompositionV1
payload_before = manufactured_auto_composition_payload(composition)
hash_before = manufactured_auto_composition_hash(composition)
println("BEFORE_CANONICAL_LOAD valid=$(a5.valid) payload_type=$(typeof(payload_before)) hash=$(hash_before.value)")
include(joinpath(ROOT, "src/RuntimeV4/M4Isolated/ManufacturedConditionalEGraphV1.jl"))
payload_after = manufactured_auto_composition_payload(composition)
hash_after = manufactured_auto_composition_hash(composition)
println("AFTER_CANONICAL_LOAD payload_equal=$(payload_before == payload_after) hash=$(hash_after.value)")
println("HASH_EQUAL=$(hash_before == hash_after)")
println("EXPECTED_722E=$(hash_after.value == "722e59e841d6551fe9001e1279266e1aaf5a798ca0d16625d5a4fd81a59ab694")")
