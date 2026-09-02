using Test
using FusionConceptAI
using JSON3

const U0 = UnitSignature((0, 0, 0, 0, 0, 0, 0))
const T0 = PhysicalType(:scalar_field, 0, 3, :differential, U0)
const BAD_TEXT = string(Char(0xd800))
mutable struct MutablePayload
    values::Vector{Int}
end
mutable struct MutableNumber <: Number
    value::Int
end
struct InjectInteger <: Integer
end
Base.string(::InjectInteger) = "0,\"injected\":true"
struct OpaqueValue
    value::Int
end
mutable struct MutableText <: AbstractString
    data::String
end
Base.ncodeunits(x::MutableText) = ncodeunits(x.data)
Base.codeunit(::Type{MutableText}) = UInt8
Base.codeunit(x::MutableText, i::Integer) = codeunit(x.data, i)
Base.codeunits(x::MutableText) = codeunits(x.data)
Base.getindex(x::MutableText, i::Int) = getindex(x.data, i)
Base.iterate(x::MutableText, state=1) = iterate(x.data, state)
Base.isvalid(x::MutableText, i::Int) = isvalid(x.data, i)
struct UnknownRule <: OperatorTypeRuleV1
end
struct AlwaysRule <: OperatorTypeRuleV1
end
struct FunctionRule <: OperatorTypeRuleV1
    executable::Function
end

function fixture_graph(; reverse=false, labels=("alpha", "beta"), ids=("n-a", "n-b"))
    ns = [node(:state, T0; id=ids[1], label=labels[1]), node(:state, T0; id=ids[2], label=labels[2])]
    ast = ast_leaf(:state, T0)
    es = [TypedHyperedge("edge-x", (1,), (2,), ast, :governing)]
    reverse ? TypedOperatorHypergraphV1(reverse(ns), [TypedHyperedge("edge-y", (2,), (1,), ast, :governing)]) : TypedOperatorHypergraphV1(ns, es)
end

@testset "P0 contract refs and independent genome hashes" begin
    refs = [GenomeContractRef("urn:test:" * string(i), "v4.0.0", repeat(string(i), 64), repeat(string(i+1), 64), "profile-v4") for i in 1:3]
    registry = GenomeContractRegistryV4(refs...)
    @test all(x -> x isa Digest256, (registry.mechanism.schema_hash, registry.field_geometry.schema_hash, registry.realization_control.schema_hash))
    g = fixture_graph()
    m = MechanismGenomeV4(1, refs[1], g)
    f = FieldGeometryGenomeV4(2, refs[2], g)
    r = RealizationControlGenomeV4(3, 4, refs[3], g, g)
    @test all(x -> length(string(x)) == 64, (mechanism_hash(m), field_geometry_hash(f), realization_control_hash(r)))
    @test mechanism_hash(m) == mechanism_hash(MechanismGenomeV4(999, refs[1], fixture_graph(labels=("other-a", "other-b"), ids=("z", "y"))))
    @test_throws ArgumentError GenomeContractRef("urn:x", "v4", "hash", "canon", "")
    @test_throws ArgumentError ApplicabilityRecord("obligation", required, "not-a-digest")
    @test_throws ArgumentError GenomeContractRef(BAD_TEXT, "v4", repeat("a", 64), repeat("b", 64), "profile")
    @test_throws ArgumentError ApplicabilityRecord(BAD_TEXT, required)
end

@testset "P0 temporal algebra and immutable operator registry" begin
    clock = QualifiedRefV1("clock", "v1")
    differential = TemporalTypeV1(differential_time)
    @test PhysicalType(:scalar_field, 0, 3, differential, U0).temporal_type == differential
    @test PhysicalType(:scalar_field, 0, 3, :differential, U0).temporal_type.kind == differential_time
    @test_throws ArgumentError PhysicalType(:scalar_field, 0, 3, :unknown_time, U0)
    registry = default_operator_registry()
    @test length(registry.operators) == 20
    t = PhysicalType(:scalar_field, 0, 3, differential, U0)
    static = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), U0)
    @test validate_operator_signature(registry, OperatorRefV1("ADD", "v1"), (t, t), (t,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("ADD", "v1"),
        (t, PhysicalType(:scalar_field, 0, 3, differential, UnitSignature((1, 0, 0, 0, 0, 0, 0)))), (t,))
    @test validate_operator_signature(registry, OperatorRefV1("SCALAR_MUL", "v1"), (static, t), (t,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("SCALAR_MUL", "v1"),
        (PhysicalType(:scalar_field, 0, 2, TemporalTypeV1(static_time), U0), t), (t,))
    dt_out = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time, UInt8(1)), UnitSignature((0, 0, -1, 0, 0, 0, 0)))
    @test validate_operator_signature(registry, OperatorRefV1("DT", "v1"), (t,), (dt_out,))
    other_clock = QualifiedRefV1("other-clock", "v1")
    @test_throws ArgumentError TemporalTypeV1(differential_time, UInt8(1), other_clock)
    discrete = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(discrete_time, UInt8(0), clock), U0)
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DT", "v1"), (discrete,), (discrete,))
    @test validate_operator_signature(registry, OperatorRefV1("SAMPLE", "v1"), (t,), (discrete,); parameters=(target_clock=clock,))
    @test validate_operator_signature(registry, OperatorRefV1("HOLD", "v1"), (discrete,), (t,); parameters=(target_kind=:differential_time,))
    @test validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (t,), (t,); parameters=(delay_seconds=0.25,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (t,), (t,); parameters=(delay_seconds=-1.0,))
    add_manifest = operator_manifest(registry, "ADD")
    @test_throws ArgumentError register_operator(registry, add_manifest)
    empty_registry = OperatorRegistryV1()
    extended = register_operator(empty_registry, add_manifest)
    @test isempty(empty_registry.operators) && length(extended.operators) == 1
    @test_throws ArgumentError OperatorManifestV1(add_manifest.operator_ref, add_manifest.input_arity, add_manifest.output_arity,
        add_manifest.input_type_rule, add_manifest.output_type_rule; manifest_hash=digest256_text("tampered"))
    @test_throws ArgumentError OperatorManifestV1(OperatorRefV1("UNKNOWN", "v1"), 1, 1, UnknownRule(), UnknownRule())
end

@testset "P0 temporal registry remediation adversarial controls" begin
    clock = QualifiedRefV1("clock", "v1")
    @test :time_kind in propertynames(T0)
    @test_throws ArgumentError TemporalTypeV1(static_time, 1)
    @test_throws ArgumentError TemporalTypeV1(static_time, 0, clock)
    @test_throws ArgumentError TemporalTypeV1(algebraic_time, 1)
    @test_throws ArgumentError TemporalTypeV1(differential_time, 0, clock)
    @test_throws ArgumentError TemporalTypeV1(discrete_time, 0)
    @test_throws ArgumentError TemporalTypeV1(discrete_time, 1, clock)
    @test_throws ArgumentError TemporalTypeV1(event_time, 0)
    @test_throws ArgumentError TemporalTypeV1(event_time, 1, clock)
    @test_throws ArgumentError TemporalTypeV1(differential_time, 256)

    registry = default_operator_registry()
    differential = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    discrete = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(discrete_time, 0, clock), U0)
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("ADD", "v1"),
        (differential, discrete), (differential,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DT", "v1"), (differential,), (differential,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("SAMPLE", "v1"), (differential,), (discrete,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("HOLD", "v1"), (discrete,), (differential,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"),
        (PhysicalType(:scalar_field, 0, 3, :static, U0),), (PhysicalType(:scalar_field, 0, 3, :static, U0),);
        parameters=(delay_seconds=1.0,))

    length_unit = UnitSignature((0, -1, 0, 0, 0, 0, 0))
    laplace_unit = UnitSignature((0, -2, 0, 0, 0, 0, 0))
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    @test validate_operator_signature(registry, OperatorRefV1("LAPLACE", "v1"), (scalar,),
        (PhysicalType(:scalar_field, 0, 3, :differential, laplace_unit),))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("LAPLACE", "v1"), (scalar,),
        (PhysicalType(:scalar_field, 0, 3, :differential, length_unit),))

    control = PhysicalType(:control_signal, 0, 3, :differential, U0)
    event = PhysicalType(:event_signal, 0, 3, TemporalTypeV1(event_time, 0, clock), U0)
    event_state = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(discrete_time, 0, clock), U0)
    @test validate_operator_signature(registry, OperatorRefV1("THRESHOLD_SWITCH", "v1"), (control, scalar), (scalar,))
    @test validate_operator_signature(registry, OperatorRefV1("EVENT_RESET", "v1"), (event, event_state), (event_state,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("EVENT_RESET", "v1"), (event, scalar), (scalar,))
    other_event_state = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(discrete_time, 0, QualifiedRefV1("other-clock", "v1")), U0)
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("EVENT_RESET", "v1"), (event, other_event_state), (other_event_state,))

    add = operator_manifest(registry, "ADD")
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        commutative_input_groups=((1, 1),))
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        commutative_input_groups=((1, 2), (2,)))
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        allowed_conservation_effects=(:energy,), forbidden_conservation_effects=(:energy,))
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        pure=false)
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        max_derivative_contribution=1)
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 3, 2, AlwaysRule(), AlwaysRule())
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, FunctionRule(identity), FunctionRule(identity))
    @test_throws ArgumentError OperatorManifestV1(OperatorRefV1("DELAY", "v1"), 1, 1, DelayRuleV1(), DelayRuleV1())
    @test_throws ArgumentError OperatorManifestV1(OperatorRefV1("SAMPLE", "v1"), 1, 1, SamplingRuleV1(false), SamplingRuleV1(false))
    @test canonical_hash(registry) == canonical_hash(OperatorRegistryV1(reverse(registry.operators)))
    dt_ok = PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time, 1), UnitSignature((0, 0, -1, 0, 0, 0, 0)))
    @test TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:dt, (1,), dt_ok)), 2, (1,)).root == 2
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), scalar),
        TypedASTNode(:dt, (1,), PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time, 1), UnitSignature((0, 0, 1, 0, 0, 0, 0))))), 2, (1,))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), scalar),
        TypedASTNode(:dt, (1,), PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(differential_time, 2), UnitSignature((0, 0, -1, 0, 0, 0, 0))))), 2, (1,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (scalar,), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (scalar,), (scalar,);
        parameters=(delay_seconds=true,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (scalar,), (scalar,);
        parameters=(delay_seconds=big(10)^10000,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"), (scalar,), (scalar,);
        parameters=(delay_seconds=1.0, unknown=:x))
    bad_symbol = Symbol(String(UInt8[0xff]))
    @test !is_canonical_value(bad_symbol)
    @test_throws ArgumentError PhysicalType(bad_symbol, 0, 3, :differential, U0)
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("HOLD", "v1"), (discrete,),
        (scalar,); parameters=(target_kind=bad_symbol,))
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        commutative_input_groups=((true, 2),))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:identity, (1,), scalar)), 2, (1,);
        registry=OperatorRegistryV1())
end

@testset "P0 sealed AST value and manifest checks" begin
    registry = default_operator_registry()
    @test_throws ArgumentError TypedASTNode(:state, (), T0, (mutable_value=Any[1],))
    @test TypedASTNode(:state, (), T0, (exact_rational=1//2,)).parameters.exact_rational == 1//2
    vector = PhysicalType(:vector_field, 1, 3, :differential, U0)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), T0),
        TypedASTNode(:add, (1, 1), vector)), 2, (1,); registry=registry)
    add = operator_manifest(registry, "ADD")
    @test_throws ArgumentError OperatorManifestV1(add.operator_ref, 2, 1, add.input_type_rule, add.output_type_rule;
        parameter_schema=(OperatorParameterSpecV1(:evil, :symbol, true),))
    @test_throws ArgumentError OperatorManifestV1(OperatorRefV1("DT_EVIL", "v1"), 1, 1,
        TimeDerivativeRuleV1(), TimeDerivativeRuleV1(); max_derivative_contribution=0)
    @test validate_operator_signature(registry, OperatorRefV1("DELAY", "v1"),
        (T0,), (T0,); parameters=(delay_seconds=1//2,))
end

@testset "P0 typed tensor operators and AST manifest bindings" begin
    registry = default_operator_registry()
    vector = PhysicalType(:vector_field, 1, 3, :differential, U0)
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    tensor = PhysicalType(:vector_field, 2, 3, :differential, U0)
    @test validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (vector, vector), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (scalar, vector), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (vector, vector), (vector,))
    rank2 = PhysicalType(:vector_field, 2, 3, :differential, U0)
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (vector, rank2), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (rank2, vector), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("DOT", "v1"), (rank2, rank2), (scalar,))
    @test validate_operator_signature(registry, OperatorRefV1("TENSOR_PRODUCT", "v1"), (vector, vector), (tensor,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("TENSOR_PRODUCT", "v1"), (vector, vector), (vector,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("TENSOR_PRODUCT", "v1"), (vector, vector),
        (PhysicalType(:vector_field, 2, 3, :differential, UnitSignature((1, 0, 0, 0, 0, 0, 0))),))
    @test validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (scalar,);
        parameters=(contraction_order=1,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (scalar,);
        parameters=(contraction_order=0,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (scalar,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (scalar,);
        parameters=(contraction_order=true,))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (scalar,);
        parameters=(contraction_order=big(1),))
    @test_throws ArgumentError validate_operator_signature(registry, OperatorRefV1("CONTRACT", "v1"), (vector, vector), (vector,);
        parameters=(contraction_order=1,))

    dot_ast = TypedAST((TypedASTNode(:state, (), vector), TypedASTNode(:dot, (1, 1), scalar)), 2, (1,); registry=registry)
    extra = OperatorManifestV1(OperatorRefV1("UNUSED", "v1"), 1, 1, SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1))
    registry_extra = register_operator(registry, extra)
    dot_ast_extra = TypedAST((TypedASTNode(:state, (), vector), TypedASTNode(:dot, (1, 1), scalar)), 2, (1,); registry=registry_extra)
    @test canonical_hash(dot_ast) == canonical_hash(dot_ast_extra)
    dot = operator_manifest(registry, "DOT")
    dot_alt = OperatorManifestV1(dot.operator_ref, 2, 1, DotProductRuleV1(), DotProductRuleV1(); allowed_roles=(:boundary,))
    registry_alt = OperatorRegistryV1(tuple((o for o in registry.operators if o.operator_ref != dot.operator_ref)..., dot_alt))
    dot_ast_alt = TypedAST((TypedASTNode(:state, (), vector), TypedASTNode(:dot, (1, 1), scalar)), 2, (1,); registry=registry_alt)
    @test canonical_hash(dot_ast) != canonical_hash(dot_ast_alt)
    @test length(dot_ast.manifest_bindings) == 1
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), vector), TypedASTNode(:dot, (1, 1), scalar)), 2, (1,);
        registry=registry, manifest_bindings=())

    add_ast = TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:add, (1, 1), scalar)), 2, (1,); registry=registry)
    add = operator_manifest(registry, "ADD")
    add_alt = OperatorManifestV1(add.operator_ref, 2, 1, SameTypeVariadicRuleV1(2, 2), SameTypeVariadicRuleV1(2, 2);
        allowed_roles=(:boundary,), commutative_input_groups=((1, 2),))
    registry_add_alt = OperatorRegistryV1(tuple((o for o in registry.operators if o.operator_ref != add.operator_ref)..., add_alt))
    add_ast_alt = TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:add, (1, 1), scalar)), 2, (1,); registry=registry_add_alt)
    @test canonical_hash(add_ast) != canonical_hash(add_ast_alt)
    @test canonical_hash(add_ast) == canonical_hash(TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:add, (1, 1), scalar)), 2, (1,); registry=registry))
    @test_throws ArgumentError operator_manifest(registry, "INTEGRAL_KERNEL")
    @test_throws ArgumentError ContractRuleV1(1)
    contract_k1 = TypedAST((TypedASTNode(:state, (), rank2), TypedASTNode(:state, (), rank2),
        TypedASTNode(:contract, (1, 2), rank2, (contraction_order=1,))), 3, (1, 2); registry=registry)
    contract_k2 = TypedAST((TypedASTNode(:state, (), rank2), TypedASTNode(:state, (), rank2),
        TypedASTNode(:contract, (1, 2), scalar, (contraction_order=2,))), 3, (1, 2); registry=registry)
    @test contract_k1.nodes[end].output_type.tensor_rank == 2
    @test contract_k2.nodes[end].output_type.tensor_rank == 0
    @test canonical_hash(contract_k1) != canonical_hash(contract_k2)
end

@testset "P0 constructor dispatch closure subprocess" begin
    project = Base.active_project()
    script = """
using FusionConceptAI
FusionConceptAI._checked_int(::Int, ::String) = typemax(Int)
FusionConceptAI._validated_string(::String, ::String) = \"polluted\"
FusionConceptAI._default_manifest(::String, ::Int, ::SameTypeVariadicRuleV1; kwargs...) = error(\"polluted\")
@assert SameTypeVariadicRuleV1(2, 2).minimum_arity == 2
@assert QualifiedRefV1(\"clock\", \"v1\").id == \"clock\"
@assert length(default_operator_registry().operators) == 20
println(\"constructor-dispatch-subprocess-ok\")
"""
    @test success(`$(Base.julia_cmd()) --project=$project -e $script`)
end

@testset "P0 registry-validated multi-root typed AST programs" begin
    registry = default_operator_registry()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    vector = PhysicalType(:vector_field, 1, 3, :differential, U0)
    add_node = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, scalar))
    program = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), add_node), (3,), (1, 2); registry=registry)
    @test program.roots == (3,)
    @test length(program.used_manifest_bindings) == 1
    @test_throws MethodError ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;), scalar, ((1, 2),), true, true, nothing)
    @test_throws MethodError TypedASTProgramV1((ASTInputV1(1, scalar),), (1,), (1,), ())
    add_left = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, scalar))
    add_right = ASTApplyV1(OperatorRefV1("ADD", "v1"), (4, 3), (;); registry=registry, input_types=(scalar, scalar))
    three_to_five = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), ASTInputV1(3, scalar), add_left, add_right), (5,), (1, 2, 3); registry=registry)
    @test three_to_five.nodes[5].output_type == scalar
    duplicate_add = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, scalar))
    duplicate_add_2 = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, scalar))
    combine_duplicate = ASTApplyV1(OperatorRefV1("ADD", "v1"), (3, 4), (;); registry=registry, input_types=(scalar, scalar))
    cse_copy = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), duplicate_add, duplicate_add_2, combine_duplicate), (5,), (1, 2); registry=registry)
    cse_shared_final = ASTApplyV1(OperatorRefV1("ADD", "v1"), (3, 3), (;); registry=registry, input_types=(scalar, scalar))
    cse_shared = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), duplicate_add, cse_shared_final), (4,), (1, 2); registry=registry)
    @test length(cse_copy.nodes) == length(cse_shared.nodes)
    @test canonical_hash(cse_copy) == canonical_hash(cse_shared)
    stateful_copy_a = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=1.0,); registry=registry, input_types=(scalar,))
    stateful_copy_b = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=1.0,); registry=registry, input_types=(scalar,))
    stateful_program = TypedASTProgramV1((ASTInputV1(1, scalar), stateful_copy_a, stateful_copy_b), (2, 3), (1,); registry=registry)
    @test length(stateful_program.nodes) == 3
    program_dispatch_script = """
    using FusionConceptAI
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, UnitSignature((0,0,0,0,0,0,0)))
    registry = default_operator_registry()
    apply = ASTApplyV1(OperatorRefV1(\"ADD\", \"v1\"), (1,2), (;); registry=registry, input_types=(scalar,scalar))
    program = TypedASTProgramV1((ASTInputV1(1,scalar), ASTInputV1(2,scalar), apply), (3,), (1,2); registry=registry)
    before = canonical_hash(program)
    FusionConceptAI._canonical(::NamedTuple) = \"{}\"
    @assert canonical_hash(program) == before
    """
    @test success(`$(Base.julia_cmd()) --project=$(Base.active_project()) -e $program_dispatch_script`)
    @test canonical_hash(program) == canonical_hash(TypedASTProgramV1((ASTInputV1(2, scalar), ASTInputV1(1, scalar),
        ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 1), (;); registry=registry, input_types=(scalar, scalar))), (3,), (2, 1); registry=registry))
    mixed = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, vector)), (1, 2), (1, 2); registry=registry)
    @test mixed.roots == (1, 2)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar),), (), (1,); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar),), (1, 1), (1,); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar),), (2,), (1,); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(1, scalar)), (1,), (1, 2); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), add_node), (3,), (1,); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), add_node, ASTParameterV1(:dead, scalar)), (3,), (1, 2); registry=registry)
    cycle = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 1), (;); registry=registry, input_types=(scalar, scalar))
    @test_throws ArgumentError TypedASTProgramV1((cycle,), (1,), (); registry=registry)
    @test_throws ArgumentError ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, vector))

    roots_a = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, vector)), (1, 2), (1, 2); registry=registry)
    roots_b = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, vector)), (2, 1), (1, 2); registry=registry)
    @test canonical_hash(roots_a) != canonical_hash(roots_b)
    old = TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:identity, (1,), scalar)), 2, (1,); registry=registry)
    bridged = TypedASTProgramV1(old; registry=registry)
    @test bridged.roots == (2,) && bridged.input_ports == (1,)
    @test length(bridged.used_manifest_bindings) == 1
    old_with_metadata = TypedAST((TypedASTNode(:state, (), scalar, (state_name=:x,)),
        TypedASTNode(:parameter, (), scalar, (name=:gain, scale=2,)),
        TypedASTNode(:add, (1, 2), scalar)), 3, (1,); registry=registry)
    metadata_bridge = TypedASTProgramV1(old_with_metadata; registry=registry)
    @test metadata_bridge.nodes[1].parameters == (state_name=:x,)
    @test metadata_bridge.nodes[2].parameters == (name=:gain, scale=2)
    old_constant_without_value = TypedAST((TypedASTNode(:constant, (), scalar, (scale=2,)),), 1, (); registry=registry)
    @test_throws ArgumentError TypedASTProgramV1(old_constant_without_value; registry=registry)
    custom_identity = OperatorManifestV1(OperatorRefV1("IDENTITY", "v1"), 1, 1,
        SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1); allowed_roles=(:governing,))
    custom_registry = OperatorRegistryV1(filter(m -> m.operator_ref.qualified.id != "IDENTITY", registry.operators))
    custom_registry = register_operator(custom_registry, custom_identity)
    old_custom = TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:identity, (1,), scalar)), 2, (1,); registry=custom_registry)
    @test_throws ArgumentError TypedASTProgramV1(old_custom; registry=registry)
    grouped_manifest = OperatorManifestV1(OperatorRefV1("ADD_NONCONTIG", "v1"), 3, 1,
        SameTypeVariadicRuleV1(3, 3), SameTypeVariadicRuleV1(3, 3); commutative_input_groups=((2, 3),))
    grouped_registry = register_operator(registry, grouped_manifest)
    grouped_a = ASTApplyV1(OperatorRefV1("ADD_NONCONTIG", "v1"), (1, 2, 3), (;);
        registry=grouped_registry, input_types=(scalar, scalar, scalar))
    grouped_b = ASTApplyV1(OperatorRefV1("ADD_NONCONTIG", "v1"), (1, 3, 2), (;);
        registry=grouped_registry, input_types=(scalar, scalar, scalar))
    grouped_program_a = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), ASTInputV1(3, scalar), grouped_a), (4,), (1, 2, 3); registry=grouped_registry)
    grouped_program_b = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), ASTInputV1(3, scalar), grouped_b), (4,), (1, 2, 3); registry=grouped_registry)
    @test canonical_hash(grouped_program_a) == canonical_hash(grouped_program_b)
    interleaved_add_a = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 1), (;); registry=registry, input_types=(scalar, scalar))
    interleaved_add_b = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 1), (;); registry=registry, input_types=(scalar, scalar))
    interleaved_outer = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 4), (;); registry=registry, input_types=(scalar, scalar))
    interleaved_roots = TypedASTProgramV1((ASTInputV1(1, scalar), interleaved_add_a, interleaved_add_b,
        ASTInputV1(4, scalar), interleaved_outer), (3, 5), (1, 4); registry=registry)
    @test length(interleaved_roots.roots) == 2 && length(unique(interleaved_roots.roots)) == 2
    @test interleaved_roots.input_ports == (1, 4)
    @test canonical_hash(interleaved_roots) isa Digest256
    root_add = ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 1), (;); registry=registry, input_types=(scalar, scalar))
    root_neg = ASTApplyV1(OperatorRefV1("NEG", "v1"), (1,), (;); registry=registry, input_types=(scalar,))
    root_outer = ASTApplyV1(OperatorRefV1("ADD", "v1"), (2, 4), (;); registry=registry, input_types=(scalar, scalar))
    three_roots = TypedASTProgramV1((ASTInputV1(1, scalar), interleaved_add_a, root_add, root_neg, root_outer), (3, 4, 5), (1,); registry=registry)
    @test three_roots.roots == (3, 4, 5) && three_roots.input_ports == (1,)
    @test canonical_hash(three_roots) isa Digest256
    @test canonical_hash(three_roots) != canonical_hash(TypedASTProgramV1(three_roots.nodes, (4, 3, 5), three_roots.input_ports; registry=registry))
    shift_outer = ASTApplyV1(OperatorRefV1("ADD", "v1"), (3, 4), (;); registry=registry, input_types=(scalar, scalar))
    shift_root = ASTApplyV1(OperatorRefV1("NEG", "v1"), (2,), (;); registry=registry, input_types=(scalar,))
    shifted_two_roots = TypedASTProgramV1((ASTInputV1(1, scalar), interleaved_add_a, interleaved_add_b,
        ASTInputV1(4, scalar), shift_outer, shift_root), (5, 6), (1, 4); registry=registry)
    @test shifted_two_roots.input_ports == (1, 3) && shifted_two_roots.roots == (4, 5)
    @test canonical_hash(shifted_two_roots) isa Digest256

    delay1 = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=1.0,); registry=registry, input_types=(scalar,))
    delay2 = ASTApplyV1(OperatorRefV1("DELAY", "v1"), (1,), (delay_seconds=1.0,); registry=registry, input_types=(scalar,))
    two_delays = TypedASTProgramV1((ASTInputV1(1, scalar), delay1, delay2), (2, 3), (1,); registry=registry)
    one_delay = TypedASTProgramV1((ASTInputV1(1, scalar), delay1), (2,), (1,); registry=registry)
    @test canonical_hash(two_delays) != canonical_hash(one_delay)
end

@testset "P0 atomic MIMO hyperedges and conservation contracts" begin
    registry = default_operator_registry()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    vector = PhysicalType(:vector_field, 1, 3, :differential, U0)
    identity_ref = OperatorRefV1("IDENTITY", "v1")
    p1 = TypedASTProgramV1((ASTInputV1(1, scalar), ASTApplyV1(identity_ref, (1,), (;); registry=registry, input_types=(scalar,))), (2,), (1,); registry=registry)
    e1 = AtomicMIMOHyperedgeV1("one", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive; registry=registry)
    g1 = TypedOperatorHypergraphV1((node(:input, scalar; id="n1", label="visible"), node(:output, scalar; id="n2", label="visible")), (e1,))
    @test length(g1.hyperedges) == 1 && g1.hyperedges[1].program_hash isa Digest256
    @test canonical_hash(e1) == canonical_hash(AtomicMIMOHyperedgeV1("different-id", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive; registry=registry))
    @test occursin("fusionconceptai:v4:atomic-mimo-hyperedge:v1", canonical_json(e1))
    @test canonical_hash(e1) != canonical_hash(g1)
    @test canonical_hash(g1) == canonical_hash(TypedOperatorHypergraphV1((node(:input, scalar; id="x", label="hidden"), node(:output, scalar; id="y", label="hidden")),
        (AtomicMIMOHyperedgeV1("renamed", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive; registry=registry),)))

    add_ref = OperatorRefV1("ADD", "v1")
    p2 = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), ASTApplyV1(add_ref, (1, 2), (;); registry=registry, input_types=(scalar, scalar))), (3,), (1, 2); registry=registry)
    e2 = AtomicMIMOHyperedgeV1("two", (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)), (MIMOOutputBindingV1(1, 3),), p2, additive; registry=registry)
    g2 = TypedOperatorHypergraphV1((node(:input, scalar), node(:input, scalar), node(:output, scalar)), (e2,))
    @test length(g2.hyperedges) == 1
    p35_nodes = AbstractTypedASTNodeV1[ASTInputV1(1, scalar), ASTInputV1(2, scalar), ASTInputV1(3, scalar)]
    for i in 1:5
        push!(p35_nodes, ASTApplyV1(identity_ref, ((i - 1) % 3 + 1,), (;); registry=registry, input_types=(scalar,)))
    end
    p35 = TypedASTProgramV1(Tuple(p35_nodes), (4, 5, 6, 7, 8), (1, 2, 3); registry=registry)
    e35 = AtomicMIMOHyperedgeV1("five", Tuple(MIMOInputBindingV1(i, i) for i in 1:3),
        Tuple(MIMOOutputBindingV1(i, i + 3) for i in 1:5), p35, additive; registry=registry)
    g35 = TypedOperatorHypergraphV1(tuple((node(:port, scalar) for _ in 1:8)...), (e35,))
    @test length(g35.hyperedges) == 1 && canonical_hash(g35) isa Digest256
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("bad", (MIMOInputBindingV1(1, 1),), (), p1, additive; registry=registry)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("bad", (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(1, 1)), (MIMOOutputBindingV1(1, 2),), p1, additive; registry=registry)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("bad", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(2, 2),), p1, additive; registry=registry)
    @test_throws ArgumentError TypedOperatorHypergraphV1((node(:input, vector), node(:output, scalar)), (e1,))
    sub = ASTApplyV1(OperatorRefV1("SUB", "v1"), (1, 2), (;); registry=registry, input_types=(scalar, scalar))
    sub_rev = ASTApplyV1(OperatorRefV1("SUB", "v1"), (2, 1), (;); registry=registry, input_types=(scalar, scalar))
    psub = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), sub), (3,), (1, 2); registry=registry)
    psub_rev = TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), sub_rev), (3,), (1, 2); registry=registry)
    @test canonical_hash(psub) != canonical_hash(psub_rev)
    esub = AtomicMIMOHyperedgeV1("sub", (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)), (MIMOOutputBindingV1(1, 3),), psub, additive; registry=registry)
    esub_rev = AtomicMIMOHyperedgeV1("sub-rev", (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)), (MIMOOutputBindingV1(1, 3),), psub_rev, additive; registry=registry)
    @test canonical_hash(TypedOperatorHypergraphV1((node(:input, scalar), node(:input, scalar), node(:output, scalar)), (esub,))) !=
        canonical_hash(TypedOperatorHypergraphV1((node(:input, scalar), node(:input, scalar), node(:output, scalar)), (esub_rev,)))
    add_rev = ASTApplyV1(add_ref, (2, 1), (;); registry=registry, input_types=(scalar, scalar))
    @test canonical_hash(p2) == canonical_hash(TypedASTProgramV1((ASTInputV1(1, scalar), ASTInputV1(2, scalar), add_rev), (3,), (1, 2); registry=registry))

    account_a = ConservationAccountRefV1("energy", U0, :output, 1, :minus)
    account_b = ConservationAccountRefV1("energy", U0, :output, 2, :plus)
    pair = InterfaceFluxPairV1(PortAccountEffectV1(account_a, -1//1), PortAccountEffectV1(account_b, 1//1))
    iface_nodes = (ASTInputV1(1, scalar), ASTApplyV1(identity_ref, (1,), (;); registry=registry, input_types=(scalar,)), ASTApplyV1(OperatorRefV1("NEG", "v1"), (1,), (;); registry=registry, input_types=(scalar,)))
    iface_program = TypedASTProgramV1(iface_nodes, (2, 3), (1,); registry=registry)
    iface_edge = AtomicMIMOHyperedgeV1("iface", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 3)), iface_program, interface; interface_flux_pairs=(pair,), registry=registry)
    @test TypedOperatorHypergraphV1((node(:input, scalar), node(:out, scalar), node(:out, scalar)), (iface_edge,)).hyperedges[1] isa AtomicMIMOHyperedgeV1
    iface_edge_reordered = AtomicMIMOHyperedgeV1("iface-reordered", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(2, 3), MIMOOutputBindingV1(1, 2)), iface_program, interface; interface_flux_pairs=(pair,), registry=registry)
    @test canonical_hash(TypedOperatorHypergraphV1((node(:input, scalar), node(:out, scalar), node(:out, scalar)), (iface_edge,))) !=
        canonical_hash(TypedOperatorHypergraphV1((node(:input, scalar), node(:out, scalar), node(:out, scalar)), (iface_edge_reordered,)))
    @test_throws ArgumentError InterfaceFluxPairV1(PortAccountEffectV1(account_a, -1//1), PortAccountEffectV1(account_b, -1//1))
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("duplicate-pair", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 3)), iface_program, interface; interface_flux_pairs=(pair, pair), registry=registry)
    @test_throws ArgumentError PortAccountEffectV1(account_a, 1.0)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("source", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, source; registry=registry)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("iface", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2), MIMOOutputBindingV1(2, 2)), iface_program, interface; registry=registry)
    legacy = TypedHyperedge("legacy", (1,), (2,), TypedAST((TypedASTNode(:state, (), scalar), TypedASTNode(:identity, (1,), scalar)), 2, (1,); registry=registry), :additive)
    @test AtomicMIMOHyperedgeV1(legacy; registry=registry).program isa TypedASTProgramV1
    legacy_renumbered = TypedHyperedge("legacy-renumbered", (2,), (1,), legacy.ast, :additive)
    @test TypedOperatorHypergraphV1((node(:output, scalar), node(:input, scalar)),
        (AtomicMIMOHyperedgeV1(legacy_renumbered; registry=registry),)).hyperedges[1] isa AtomicMIMOHyperedgeV1
    renumbered = AtomicMIMOHyperedgeV1("renumbered", (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 1),), p1, additive; registry=registry)
    renumbered_graph = TypedOperatorHypergraphV1((node(:output, scalar), node(:input, scalar)), (renumbered,))
    @test canonical_hash(renumbered_graph) == canonical_hash(g1)
    tampered_manifest = OperatorManifestV1(identity_ref, 1, 1, SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:additive,), allowed_conservation_effects=(:net_creation,))
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("mismatch", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive;
        registry=OperatorRegistryV1((tampered_manifest,)))
    source_ref = OperatorRefV1("IDENTITY", "v1")
    source_manifest = OperatorManifestV1(source_ref, 1, 1, SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:source,), allowed_conservation_effects=(:net_creation,))
    source_registry = OperatorRegistryV1((source_manifest,))
    source_program = TypedASTProgramV1((ASTInputV1(1, scalar), ASTApplyV1(source_ref, (1,), (;); registry=source_registry, input_types=(scalar,))), (2,), (1,); registry=source_registry)
    source_account = ConservationAccountRefV1("energy", U0, :output, 1, :plus)
    source_effect = PortAccountEffectV1(source_account, 1//1)
    source_edge = AtomicMIMOHyperedgeV1("source-ok", (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 1),), source_program, source; account_effects=(source_effect,), registry=source_registry)
    @test TypedOperatorHypergraphV1((node(:output, scalar), node(:input, scalar)), (source_edge,); registry=source_registry).hyperedges[1] isa AtomicMIMOHyperedgeV1
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("nonsource", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive; account_effects=(source_effect,), registry=registry)
    particle_account = ConservationAccountRefV1("particles", U0, :output, 1, :minus)
    particle_effect = PortAccountEffectV1(particle_account, -1//1)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("cross-ledger", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), p1, additive;
        account_effects=(source_effect, particle_effect), registry=registry)
    bad_units = PhysicalType(:scalar_field, 0, 3, :differential, UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    @test_throws ArgumentError TypedOperatorHypergraphV1((node(:output, bad_units), node(:input, scalar)), (source_edge,); registry=source_registry)
    bad_endpoint = ConservationAccountRefV1("energy", U0, :output, 99, :plus)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("bad-endpoint", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), source_program, source; account_effects=(PortAccountEffectV1(bad_endpoint, 1//1),), registry=source_registry)
    policy_manifest = OperatorManifestV1(source_ref, 1, 1, SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:source,), allowed_conservation_effects=(:redistribution,), forbidden_conservation_effects=(:net_creation,))
    policy_registry = OperatorRegistryV1((policy_manifest,))
    policy_program = TypedASTProgramV1((ASTInputV1(1, scalar), ASTApplyV1(source_ref, (1,), (;); registry=policy_registry, input_types=(scalar,))), (2,), (1,); registry=policy_registry)
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("policy", (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 2),), policy_program, source; account_effects=(source_effect,), registry=policy_registry)
    sink_manifest = OperatorManifestV1(source_ref, 1, 1, SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:sink,), allowed_conservation_effects=(:net_destruction,))
    sink_registry = OperatorRegistryV1((sink_manifest,))
    sink_program = TypedASTProgramV1((ASTInputV1(1, scalar), ASTApplyV1(source_ref, (1,), (;); registry=sink_registry, input_types=(scalar,))), (2,), (1,); registry=sink_registry)
    sink_account = ConservationAccountRefV1("energy", U0, :output, 1, :minus)
    sink_effect = PortAccountEffectV1(sink_account, -1//1)
    sink_edge = AtomicMIMOHyperedgeV1("sink-ok", (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 1),), sink_program, sink; account_effects=(sink_effect,), registry=sink_registry)
    @test TypedOperatorHypergraphV1((node(:output, scalar), node(:input, scalar)), (sink_edge,); registry=sink_registry).hyperedges[1] isa AtomicMIMOHyperedgeV1
    @test_throws ArgumentError AtomicMIMOHyperedgeV1("sink-wrong-sign", (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 1),), sink_program, sink; account_effects=(source_effect,), registry=sink_registry)
end

@testset "P0 MIMO authority dispatch and closed identity" begin
    project = Base.active_project()
    script = """
using FusionConceptAI
FusionConceptAI._canonical(::FusionConceptAI.PortAccountEffectV1) = "{}"
registry = default_operator_registry()
u = UnitSignature()
t = PhysicalType(:scalar_field, 0, 3, :differential, u)
r = OperatorRefV1("IDENTITY", "v1")
p = TypedASTProgramV1((ASTInputV1(1, t), ASTApplyV1(r, (1,), (;); registry=registry, input_types=(t,))), (2,), (1,); registry=registry)
e = AtomicMIMOHyperedgeV1("e", (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 1),), p, additive; registry=registry)
g = TypedOperatorHypergraphV1((node(:output, t), node(:input, t)), (e,))
    @assert canonical_hash(g) isa Digest256
    @assert canonical_hash(e) isa Digest256
    println("mimo-closed-identity-ok")
"""
    @test success(`$(Base.julia_cmd()) --project=$project -e $script`)
end

@testset "canonical identity/label and permutation invariance" begin
    a = fixture_graph(labels=("visible-a", "visible-b"), ids=("first", "second"))
    b = fixture_graph(labels=("redacted-a", "redacted-b"), ids=("other-1", "other-2"))
    @test canonical_hash(a) == canonical_hash(b)
    # Same directed relation after relabeling node order.
    ast = ast_leaf(:state, T0)
    c = TypedOperatorHypergraphV1([node(:state, T0; id="x"), node(:state, T0; id="y")], [TypedHyperedge("e", (2,), (1,), ast, :governing)])
    d = TypedOperatorHypergraphV1([node(:state, T0; id="y"), node(:state, T0; id="x")], [TypedHyperedge("e2", (1,), (2,), ast, :governing)])
    @test canonical_hash(c) == canonical_hash(d)
end

@testset "independent status dimensions and authority" begin
    @test StatusVectorV4(required, no_match, terminal_deferred, proposed, terminal_deferred_stage).match_status == no_match
    @test StatusVectorV4(required, no_match, terminal_deferred, proposed, terminal_deferred_stage).applicability == required
    @test_throws ArgumentError ApplicabilityRecord("obligation", not_applicable)
    @test_throws ArgumentError ApplicabilityRecord("", required)
    @test IntermediateAuthorityProtocolV4(:compiler) isa AuthorityProtocolV4
    @test !(:FinalWholeDeviceAuthorityV4 in names(FusionConceptAI, all=false))
    @test !(:AuthorityToken in names(FusionConceptAI, all=false))
    @test !(:TerminalDecisionV4 in names(FusionConceptAI, all=false))
end

@testset "typed Proposal/Evidence isolation and six hashes" begin
    refs = [GenomeContractRef("urn:test:" * string(i), "v4.0.0", digest256_text("s" * string(i)), digest256_text("c" * string(i)), "profile") for i in 1:3]
    registry = GenomeContractRegistryV4(refs...)
    g = fixture_graph()
    m = MechanismGenomeV4(1, refs[1], g); f = FieldGeometryGenomeV4(2, refs[2], g); r = RealizationControlGenomeV4(3, 4, refs[3], g, g)
    p = ProposalEnvelopeV4("p", "candidate", (), :mcts, (), "cell", (;), (;), 1.0, digest256_text("model"), :compile)
    econtent = EvidenceContentV4(digest256_text("physical"), digest256_text("scenario"), digest256_text("solver"), digest256_text("provider"), "backend", digest256_text("numeric"), required, nothing, unique_match, resolved, unknown, (MetricWithUnit(:x, 1.0, U0),), nothing, (), "", screen_only)
    e = evidence_envelope(econtent)
    mission = MissionContractRef("urn:mission", "v4", digest256_text("schema"), digest256_text("canon"))
    pkg = CandidateStatePackageV4("display", mission, m, f, r, registry; proposal_lineage=(p,))
    @test length(pkg.canonical_hashes.solver_input_hashes) == 0
    @test pkg.proposal_lineage[1] isa ProposalEnvelopeV4
    @test isempty(pkg.stage_evidence_refs)
    @test canonical_hash(pkg) == canonical_hash(CandidateStatePackageV4("different-display", mission, m, f, r, registry; proposal_lineage=(p,)))
    @test_throws MethodError CandidateStatePackageV4("display", refs[1], m, f, r, registry; stage_evidence_refs=(p,))
    @test e isa EvidenceEnvelopeV4
    @test e.evidence_id == evidence_id_for(e.content)
end

@testset "conditional e-graph is P1-deferred" begin
    g = fixture_graph()
    eg = derive_conditional_egraph(g)
    @test eg.source_hash == canonical_hash(g)
    @test_throws ArgumentError derive_conditional_egraph(g, (; self_attested=true))
    @test !(:EquivalenceCertificateV1 in names(FusionConceptAI, all=false))
end

@testset "P0 negative controls and bounded large-graph canonicalization" begin
    @test occursin("\\u0001", canonical_json((control="\u0001",)))
    @test_throws ArgumentError canonical_json(InjectInteger())
    for value in (Float16(1.5), Float32(1.5), Float64(1.5), Float32(1.0e-6), Float64(1.0e20))
        encoded = canonical_json((value=value,))
        parsed = JSON3.read(encoded)
        @test parsed.value == Float64(value)
    end
    @test canonical_json((value=-0.0,)) == canonical_json((value=0.0,))
    @test JSON3.read(canonical_json((value=-0.0,))).value == 0
    @test_throws ArgumentError canonical_json((value=NaN,))
    @test_throws ArgumentError canonical_json((value=Inf,))
    malformed_utf8 = String(UInt8[0xff])
    lone_surrogate = string(Char(0xd800))
    @test_throws ArgumentError canonical_json((value=malformed_utf8,))
    @test_throws ArgumentError canonical_json((value=lone_surrogate,))
    unicode_json = canonical_json((汉字="磁约束", emoji="🚀", separator=string(Char(0x2028)), control="\u0001"))
    unicode_value = JSON3.read(unicode_json, Dict{String,Any})
    @test unicode_value["汉字"] == "磁约束"
    @test unicode_value["emoji"] == "🚀"
    @test unicode_value["separator"] == string(Char(0x2028))
    @test unicode_value["control"] == "\u0001"
    @test_throws ArgumentError canonical_json(Dict{Any,Any}(1 => :a, "1" => :b))
    matrix_json = canonical_json(reshape([1, 2, 3, 4], 2, 2))
    @test occursin("shape", matrix_json) && occursin("values", matrix_json)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), T0), TypedASTNode(:add, (1, 1), PhysicalType(:scalar_field, 0, 3, :differential, UnitSignature((1, 0, 0, 0, 0, 0, 0))))), 2)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), T0), TypedASTNode(:identity, (1,), PhysicalType(:vector_field, 1, 3, :differential, U0))), 2)
    @test ast_leaf(:parameter, T0).input_ports == ()
    @test_throws ArgumentError TypedASTNode(:operator_hole, (), T0)
    state1 = TypedASTNode(:state, (), T0)
    state2 = TypedASTNode(:state, (), T0)
    @test_throws ArgumentError TypedAST((state1,), 1, (1, 1))
    @test_throws ArgumentError TypedAST((state1, state2), 1, (1,))
    @test_throws ArgumentError TypedAST((state1, state2), 1, (1, 2))
    @test_throws ArgumentError TypedAST((state1, state2, TypedASTNode(:identity, (1,), T0)), 3, (1, 2))
    @test_throws ArgumentError TypedAST((state1, TypedASTNode(:parameter, (), T0)), 1, (1,))
    @test_throws ArgumentError TypedAST((state1, TypedASTNode(:identity, (1,), T0)), 1, (1,))
    t1 = PhysicalType(:vector_field, 1, 3, :differential, U0)
    @test_throws ArgumentError TypedOperatorHypergraphV1((node(:state, t1), node(:state, T0)),
        (TypedHyperedge("bad-port", (1,), (2,), ast_leaf(:state, T0), :governing),))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), T0), TypedASTNode(:dt, (1,), T0)), 2, (1,))
    static3d = PhysicalType(:scalar_field, 0, 3, :static, U0)
    static_dt = PhysicalType(:scalar_field, 0, 3, :static, UnitSignature((0, 0, -1, 0, 0, 0, 0)))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), static3d), TypedASTNode(:dt, (1,), static_dt)), 2, (1,))
    t2 = PhysicalType(:scalar_field, 0, 2, :differential, U0)
    t3 = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), t2), TypedASTNode(:state, (), t3),
        TypedASTNode(:mul, (1, 2), t2)), 3, (1, 2))
    inv_length = UnitSignature((0, -1, 0, 0, 0, 0, 0))
    scalar3d = PhysicalType(:open_value, 0, 3, :differential, U0)
    vector3d = PhysicalType(:open_value, 1, 3, :differential, U0)
    gradient_bad = PhysicalType(:open_value, 1, 2, :static, inv_length)
    divergence_bad = PhysicalType(:open_value, 0, 2, :static, inv_length)
    curl_bad = PhysicalType(:open_value, 1, 2, :static, inv_length)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), scalar3d), TypedASTNode(:gradient, (1,), gradient_bad)), 2, (1,))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), vector3d), TypedASTNode(:divergence, (1,), divergence_bad)), 2, (1,))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), vector3d), TypedASTNode(:curl, (1,), curl_bad)), 2, (1,))
    vector0d = PhysicalType(:open_value, 1, 0, :differential, U0)
    curl0d = PhysicalType(:open_value, 1, 0, :differential, inv_length)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), vector0d), TypedASTNode(:curl, (1,), curl0d)), 2, (1,))
    scalar0d = PhysicalType(:scalar_field, 0, 0, :differential, U0)
    gradient0d = PhysicalType(:vector_field, 1, 0, :differential, inv_length)
    divergence0d = PhysicalType(:scalar_field, 0, 0, :differential, inv_length)
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), scalar0d), TypedASTNode(:gradient, (1,), gradient0d)), 2, (1,))
    @test_throws ArgumentError TypedAST((TypedASTNode(:state, (), vector0d), TypedASTNode(:divergence, (1,), divergence0d)), 2, (1,))
    scalar3d_field = PhysicalType(:scalar_field, 0, 3, :differential, U0)
    vector3d_field = PhysicalType(:vector_field, 1, 3, :differential, U0)
    gradient_ok = PhysicalType(:vector_field, 1, 3, :differential, inv_length)
    divergence_ok = PhysicalType(:scalar_field, 0, 3, :differential, inv_length)
    curl_ok = PhysicalType(:vector_field, 1, 3, :differential, inv_length)
    @test TypedAST((TypedASTNode(:state, (), scalar3d_field), TypedASTNode(:gradient, (1,), gradient_ok)), 2, (1,)).root == 2
    @test TypedAST((TypedASTNode(:state, (), vector3d_field), TypedASTNode(:divergence, (1,), divergence_ok)), 2, (1,)).root == 2
    @test TypedAST((TypedASTNode(:state, (), vector3d_field), TypedASTNode(:curl, (1,), curl_ok)), 2, (1,)).root == 2
    refs = [GenomeContractRef("urn:test:" * string(i), "v4", digest256_text("s" * string(i)), digest256_text("c" * string(i)), "profile") for i in 1:3]
    g = fixture_graph(); r1 = RealizationControlGenomeV4(11, 12, refs[3], g, g; realization=(; basis=:a), control=(;))
    r2 = RealizationControlGenomeV4(11, 12, refs[3], g, g; realization=(; basis=:b), control=(;))
    @test realization_hash(r1) != realization_hash(r2)
    @test control_hash(r1) == control_hash(r2)
    @test coupled_realization_control_hash(r1) != coupled_realization_control_hash(r2)
    registry = GenomeContractRegistryV4(refs...)
    m = MechanismGenomeV4(1, refs[1], g); f = FieldGeometryGenomeV4(2, refs[2], g)
    foreign = GenomeContractRef("urn:foreign", "v4", digest256_text("foreign"), digest256_text("foreign-canon"), "profile")
    rf = RealizationControlGenomeV4(3, 4, foreign, g, g)
    mission = MissionContractRef("urn:mission", "v4", digest256_text("ms"), digest256_text("mc"))
    deferred = CandidateStatePackageV4("id", mission, m, f, rf, registry)
    @test deferred.resolution == terminal_deferred
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, rf, registry; lifecycle=compiled)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, rf, registry; applicability_records=(ApplicabilityRecord("obligation", required),))
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, rf, registry; claim_ceiling=screen_only)
    @test migrate_legacy((; old_status=:pass)).resolution == terminal_deferred
    @test migrate_legacy((; mission_contract_ref=:m, mechanism_genome_ref=:a, field_geometry_genome_ref=:b, realization_control_genome_ref=:c, status=:pass)).resolution == terminal_deferred
    p = ProposalEnvelopeV4("p", "c", (), :search, (), "cell", (;), (;), 0.0, digest256_text("model"), :compile)
    @test_throws ArgumentError ProposalEnvelopeV4("p", "c", (), :search, (Any[1],), "cell", (;), (;), 0.0, digest256_text("model"), :compile)
    @test_throws ArgumentError MechanismGenomeV4(1, refs[1], g; invariants=(Any[1],))
    @test_throws ArgumentError FieldGeometryGenomeV4(2, refs[2], g; fields=(Dict(:mutable => true),))
    @test_throws ArgumentError MechanismGenomeV4(UInt64(1), refs[1], g, (MutablePayload([1]),), ())
    @test_throws ArgumentError MechanismGenomeV4(UInt64(1), refs[1], g, (MutableNumber(1),), ())
    @test_throws ArgumentError MechanismGenomeV4(UInt64(1), refs[1], g, (MutableText("mutable"),), ())
    @test_throws ArgumentError RealizationControlGenomeV4(8, 8, refs[3], g, g)
    @test_throws ArgumentError MetricWithUnit(:huge, big(10)^10000, U0)
    @test_throws ArgumentError ProposalEnvelopeV4("huge", "c", (), :search, (), "cell", (;), (;), big(10)^10000, digest256_text("model"), :compile)
    @test_throws Exception evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=unique_match, resolution_status=resolved, stage_outcome=unknown, metrics_with_units=(p,))
    nodes9 = [node(Symbol("kind_", i), T0; id=string(i)) for i in 1:9]
    nodes16 = [node(Symbol("kind_", i), T0; id=string(i)) for i in 1:16]
    g9 = TypedOperatorHypergraphV1(nodes9, ()); g9p = TypedOperatorHypergraphV1(reverse(nodes9), ())
    g16 = TypedOperatorHypergraphV1(nodes16, ()); g16p = TypedOperatorHypergraphV1(reverse(nodes16), ())
    t = @elapsed begin
        @test canonical_hash(g9) == canonical_hash(g9p)
        @test canonical_hash(g16) == canonical_hash(g16p)
    end
    @test t < 5.0
    cyc_nodes = [node(:same, T0; id=string(i)) for i in 1:9]
    cyc_ast = ast_leaf(:state, T0)
    cyc_edges = [TypedHyperedge("cycle-" * string(i), (i,), (mod1(i + 1, 9),), cyc_ast, :additive) for i in 1:9]
    cyc = TypedOperatorHypergraphV1(cyc_nodes, cyc_edges)
    elapsed = @elapsed @test_throws CanonicalizationDeferred canonical_hash(cyc)
    @test elapsed < 2.0
    @test_throws ArgumentError EvidenceRef("not-a-hash")
    @test_throws ArgumentError EvidenceRef(repeat("a", 64) * "0")
    @test_throws Exception evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=no_match, resolution_status=resolved, stage_outcome=pass, metrics_with_units=(MetricWithUnit(:x, 1.0, U0),))
    @test_throws Exception evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=no_match, resolution_status=resolved, stage_outcome=unknown, metrics_with_units=(MetricWithUnit(:x, 1.0, U0),))
    @test_throws Exception evidence_envelope(physical_subject_hash="p", scenario_hash="s", solver_input_hash="i", provider_manifest_hash="m", backend_revision="b", numerical_configuration_hash="n", applicability=required, match_status=unique_match, resolution_status=resolved, stage_outcome=unknown, claim_ceiling=validation_vvuq, metrics_with_units=(MetricWithUnit(:x, 1.0, U0),))
    @test_throws Exception CandidateStatePackageV4("id", mission, m, f, r1, CanonicalHashesV4("a", "b", "c", "d", nothing, ()), resolved, terminal_classified, (), (), (), (), (), "authority", none)
    @test_throws Exception CandidateStatePackageV4("id", mission, m, f, r1, CanonicalHashesV4("a", "b", "c", "d", nothing, ()), resolved, proposed, (), (), (), (), (), nothing, validation_vvuq)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry, terminal_classified, (), (), (), (), (), none)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry, proposed, (), (), (), (), (), validation_vvuq)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; applicability_records=(ApplicabilityRecord("", required),))
    opaque = OpaqueValue(1)
    @test_throws ArgumentError MechanismGenomeV4(1, refs[1], g; invariants=(opaque,))
    @test_throws ArgumentError ProposalEnvelopeV4("opaque", "c", (), :search, (opaque,), "cell", (;), (;), 0.0, digest256_text("model"), :compile)
    @test_throws ArgumentError TypedASTNode(:state, (), T0, (opaque=opaque,))
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; lifecycle=compiled)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; lifecycle=dormant)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; lifecycle=proof_pruned)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; compilation_records=(; compiled=true,))
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; claim_ceiling=screen_only)
    @test_throws ArgumentError TypedNode(BAD_TEXT, :state, T0, "")
    @test_throws ArgumentError TypedHyperedge(BAD_TEXT, (1,), (2,), ast_leaf(:state, T0), :governing)
    @test_throws ArgumentError ProposalEnvelopeV4(BAD_TEXT, "c", (), :search, (), "cell", (;), (;), 0.0, digest256_text("model"), :compile)
    @test_throws ArgumentError CandidateStatePackageV4(BAD_TEXT, mission, m, f, r1, registry)
    @test_throws ArgumentError CandidateStatePackageV4("id", mission, m, f, r1, registry; archive_memberships=(BAD_TEXT,))
    @test_throws ArgumentError LegacyMigrationResultV4(resolved, nothing, "forged")
    @test_throws ArgumentError FusionConceptAI.LegacyMigrationResultV4(resolved, nothing, "forged")
    h = digest256_text("evidence-negative")
    metric = (MetricWithUnit(:x, 1.0, U0),)
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, BAD_TEXT, h, required, nothing, unique_match, resolved, unknown, metric, nothing, (), "", screen_only)
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, required, nothing, no_match, terminal_deferred, unknown, metric, nothing, (), "", screen_only)
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, required, nothing, unique_match, terminal_deferred, pass, metric, nothing, (), "", screen_only)
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, not_applicable, nothing, unique_match, resolved, not_applicable_stage, metric, nothing, (), "", screen_only)
    @test_throws Exception EvidenceContentV4(h, h, h, h, "backend", h, required, nothing, unique_match, resolved, unknown, (Any[1],), nothing, (), "", screen_only)
    @test_throws ArgumentError StatusVectorV4(required, no_match, resolved, proposed, unknown)
    @test_throws ArgumentError StatusVectorV4(required, no_match, terminal_deferred, proposed, unknown)
    @test_throws ArgumentError StatusVectorV4(required, no_match, terminal_deferred, proposed, physical_fail)
    @test_throws ArgumentError StatusVectorV4(required, unique_match, resolved, proposed, terminal_deferred_stage)
    @test StatusVectorV4(required, no_match, terminal_deferred, proposed, terminal_deferred_stage).resolution == terminal_deferred
    for outcome in (unknown, physical_fail, numerical_fail, pass)
        @test_throws ArgumentError StatusVectorV4(not_applicable, unique_match, resolved, proposed, outcome)
    end
    @test_throws ArgumentError StatusVectorV4(required, unique_match, resolved, proposed, not_applicable_stage)
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, not_applicable, nothing, unique_match, resolved, unknown, metric, nothing, (), "", screen_only)
    na_record = ApplicabilityRecord("not-applicable-obligation", not_applicable, h)
    @test EvidenceContentV4(h, h, h, h, "backend", h, not_applicable, na_record, unique_match, resolved, not_applicable_stage, metric, nothing, (), "", screen_only).applicability == not_applicable
    for outcome in (unknown, physical_fail, numerical_fail, pass)
        @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, not_applicable, na_record, unique_match, resolved, outcome, metric, nothing, (), "", screen_only)
    end
    @test_throws ArgumentError EvidenceContentV4(h, h, h, h, "backend", h, required, nothing, unique_match, resolved, not_applicable_stage, metric, nothing, (), "", screen_only)
    @test_throws MethodError StatusVectorV4()
    @test_throws MethodError DerivedEGraphViewV4(digest256_text("fake-source"), g)
end
