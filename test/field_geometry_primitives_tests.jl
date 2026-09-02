using Test
using SHA
using FusionConceptAI

# G2 is deliberately exercised through its public, frozen constructors.  The
# small constructor adapters below tolerate either tuple-valued or positional
# 3-vector/index constructors while keeping the same contract assertions.
const G2_REF_TYPES = (
    SpatialSupportRefV1, ChartRefV1, CoordinateFrameRefV1, PhaseFieldRefV1,
    ImplicitFieldTermRefV1, PotentialFieldRefV1, SourceFieldRefV1,
    InterfaceOperatorRefV1, GeometryEvolutionRefV1, FieldParameterRefV1,
    SourceBudgetRefV1, TopologyEventRefV1,
)
const G2_REF_DOMAINS = (
    "fusionconceptai:v4:g2:spatial_support_ref:v1",
    "fusionconceptai:v4:g2:chart_ref:v1",
    "fusionconceptai:v4:g2:coordinate_frame_ref:v1",
    "fusionconceptai:v4:g2:phase_field_ref:v1",
    "fusionconceptai:v4:g2:implicit_field_term_ref:v1",
    "fusionconceptai:v4:g2:potential_field_ref:v1",
    "fusionconceptai:v4:g2:source_field_ref:v1",
    "fusionconceptai:v4:g2:interface_operator_ref:v1",
    "fusionconceptai:v4:g2:geometry_evolution_ref:v1",
    "fusionconceptai:v4:g2:field_parameter_ref:v1",
    "fusionconceptai:v4:g2:source_budget_ref:v1",
    "fusionconceptai:v4:g2:topology_event_ref:v1",
)
const G2_EXTRA_DOMAINS = (
    "fusionconceptai:v4:g2:spatial_multi_index:v1",
    "fusionconceptai:v4:g2:exact_spatial_vector:v1",
    "fusionconceptai:v4:g2:field_parameter_gene:v1",
)

_g2_index(args...) = try
    SpatialMultiIndex3V1(args)
catch err
    err isa MethodError || rethrow()
    SpatialMultiIndex3V1(args...)
end

_g2_vector(a, b, c, unit) = try
    ExactSpatialVector3V1((a, b, c), unit)
catch err
    err isa MethodError || rethrow()
    ExactSpatialVector3V1(a, b, c, unit)
end

_g2_bytes(x) = Vector{UInt8}(codeunits(canonical_json(x)))
_g2_expected_hash(x) = Digest256(bytes2hex(SHA.sha256(_g2_bytes(x))))
_g2_domain(x) = match(r"\"domain\":\"([^\"]+)\"", canonical_json(x)).captures[1]

function _g2_invalid_utf8()
    try
        String(UInt8[0xff])
    catch
        nothing
    end
end

function _g2_field_value(x)
    names = fieldnames(typeof(x))
    length(names) == 1 && return getfield(x, 1)
    ntuple(i -> getfield(x, i), fieldcount(typeof(x)))
end

@testset "G2 field/geometry primitive closed contracts" begin
    @testset "refs are typed, nonempty, valid UTF-8, and domain separated" begin
        same = map(T -> T("同一🚀"), G2_REF_TYPES)
        @test all(x -> fieldnames(typeof(x)) == (:value,), same)
        @test all(x -> getfield(x, :value) == "同一🚀" && isvalid(getfield(x, :value)), same)
        @test length(unique(canonical_json(x) for x in same)) == length(G2_REF_TYPES)
        @test length(unique(canonical_hash(x) for x in same)) == length(G2_REF_TYPES)
        @test all(occursin("\"domain\":\"fusionconceptai:v4:g2:", canonical_json(x)) for x in same)
        @test all(occursin(r"fusionconceptai:v4:g2:[a-z0-9_]+:v1", canonical_json(x)) for x in same)
        @test [_g2_domain(x) for x in same] == collect(G2_REF_DOMAINS)
        @test all(canonical_hash(x) == _g2_expected_hash(x) for x in same)

        bad = _g2_invalid_utf8()
        if bad !== nothing
            for T in G2_REF_TYPES
                @test_throws ArgumentError T(bad)
            end
        end
        for T in G2_REF_TYPES
            @test_throws ArgumentError T("")
            @test_throws ArgumentError T(1)
            @test_throws ArgumentError T(Symbol("wrong"))
        end
        for (i, T) in enumerate(G2_REF_TYPES)
            for (j, _) in enumerate(G2_REF_TYPES)
                j == i && continue
                @test_throws ArgumentError T(same[j])
            end
        end
        # A mutable AbstractString must not be accepted as a String-like value.
        mutable_text = Vector{UInt8}(codeunits("mutable"))
        for T in G2_REF_TYPES
            @test_throws ArgumentError T(mutable_text)
        end
    end

    @testset "exact index/vector domains and ordering" begin
        i = _g2_index(Int64(1), Int64(-2), Int64(3))
        j = _g2_index(Int64(1), Int64(3), Int64(-2))
        @test i isa SpatialMultiIndex3V1
        @test fieldcount(typeof(i)) in (1, 3)
        @test i.indices == (Int64(1), Int64(-2), Int64(3))
        @test canonical_hash(i) == _g2_expected_hash(i)
        @test canonical_hash(i) != canonical_hash(j)
        @test canonical_json(i) != canonical_json(j)
        @test isimmutable(i) && isimmutable(i.indices)
        for bad in ((1, 2), (1, 2, 3, 4), (1.0, 2, 3), (true, 2, 3),
                    (big(1), 2, 3), (UInt8(1), 2, 3))
            @test_throws ArgumentError _g2_index(bad...)
        end
        @test_throws ArgumentError SpatialMultiIndex3V1([1, 2, 3])
        @test_throws ArgumentError SpatialMultiIndex3V1(Int64[1, 2, 3])
        @test_throws ArgumentError _g2_index(Int128(typemax(Int64)) + 1, 2, 3)

        u0 = UnitSignature()
        v = _g2_vector(1 // 3, -2 // 5, 7 // 11, u0)
        w = _g2_vector(1 // 3, 7 // 11, -2 // 5, u0)
        @test v isa ExactSpatialVector3V1
        @test v.components == (1 // 3, -2 // 5, 7 // 11)
        @test canonical_hash(v) == _g2_expected_hash(v)
        @test canonical_hash(v) != canonical_hash(w)
        @test canonical_json(v) != canonical_json(w)
        @test isimmutable(v) && isimmutable(v.components) && isimmutable(v.unit)
        @test canonical_hash(v) != canonical_hash(_g2_vector(1 // 3, -2 // 5, 7 // 11,
            UnitSignature((1, 0, 0, 0, 0, 0, 0))))
        @test_throws ArgumentError _g2_vector(1.0, 2 // 1, 3 // 1, u0)
        @test_throws ArgumentError _g2_vector(true, 2 // 1, 3 // 1, u0)
        @test_throws ArgumentError _g2_vector(big(1) // big(3), 2 // 1, 3 // 1, u0)
        @test_throws ArgumentError _g2_vector(Int128(typemax(Int64)) + 1, 2 // 1, 3 // 1, u0)
        @test_throws ArgumentError ExactSpatialVector3V1([1 // 1, 2 // 1, 3 // 1], u0)
        @test_throws ArgumentError _g2_vector(1 // 1, 2 // 1, 3 // 1, [u0])
    end

    @testset "field parameter transforms, exact bounds, and finite gene" begin
        u0 = UnitSignature()
        u1 = UnitSignature((1, 0, 0, 0, 0, 0, 0))
        linear_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-2, 4, false), u0)
        linear = FieldParameterGeneV1(FieldParameterRefV1("linear"), u0,
            ParameterTransformSpecV1(transform_linear), linear_bounds, -0.0)
        @test linear.normalized_gene == 0.0 && !signbit(linear.normalized_gene)
        @test field_parameter_value(linear, -1.0) === (-2 // 1)
        @test field_parameter_value(linear, 1.0) === (4 // 1)
        @test field_parameter_value(linear, 0.0) == 1.0
        @test field_parameter_value(linear, -0.0) == field_parameter_value(linear, 0.0)

        log_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(1, 100, false), u0)
        log_gene = FieldParameterGeneV1(FieldParameterRefV1("log"), u0,
            ParameterTransformSpecV1(transform_log), log_bounds, 0.0)
        @test field_parameter_value(log_gene, -1.0) === (1 // 1)
        @test field_parameter_value(log_gene, 1.0) === (100 // 1)
        @test isapprox(field_parameter_value(log_gene, 0.0), 10.0; rtol=0, atol=eps(10.0))

        signed_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-3, 3, false), u0)
        signed_gene = FieldParameterGeneV1(FieldParameterRefV1("signed-log"), u0,
            ParameterTransformSpecV1(transform_signed_log, NonnegativeQuantityV1(1, u0)),
            signed_bounds, 0.0)
        @test field_parameter_value(signed_gene, -1.0) === (-3 // 1)
        @test field_parameter_value(signed_gene, 1.0) === (3 // 1)
        @test field_parameter_value(signed_gene, 0.0) == 0.0
        @test derive_field_parameter_value(signed_gene) == field_parameter_value(signed_gene)

        for f in (derive_field_parameter_value, field_parameter_value)
            @test_throws ArgumentError f(linear, Float32(0.25))
            @test_throws ArgumentError f(linear, Int64(0))
            @test_throws ArgumentError f(linear, true)
            @test_throws ArgumentError f(linear, 1 // 4)
            @test f(linear) == f(linear, Float64(0.0))
        end

        @test_throws ArgumentError ParameterTransformSpecV1(transform_linear,
            NonnegativeQuantityV1(1, u0))
        @test_throws ArgumentError ParameterTransformSpecV1(transform_log,
            NonnegativeQuantityV1(1, u0))
        @test_throws ArgumentError ParameterTransformSpecV1(transform_signed_log, nothing)

        @test_throws ArgumentError FieldParameterGeneV1(FieldParameterRefV1("bad-unit"), u0,
            ParameterTransformSpecV1(transform_linear), QuantityIntervalV1(linear_bounds.interval, u1), 0.0)
        @test_throws ArgumentError FieldParameterGeneV1(FieldParameterRefV1("bad-order"), u0,
            ParameterTransformSpecV1(transform_linear), QuantityIntervalV1(ExactFiniteIntervalV1(1, 1, true), u0), 0.0)
        @test_throws ArgumentError FieldParameterGeneV1(FieldParameterRefV1("bad-log"), u0,
            ParameterTransformSpecV1(transform_log), QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), u0), 0.0)
        @test_throws ArgumentError FieldParameterGeneV1(FieldParameterRefV1("bad-scale"), u0,
            ParameterTransformSpecV1(transform_signed_log, NonnegativeQuantityV1(0, u0)), signed_bounds, 0.0)
        @test_throws ArgumentError FieldParameterGeneV1(FieldParameterRefV1("bad-scale-unit"), u0,
            ParameterTransformSpecV1(transform_signed_log, NonnegativeQuantityV1(1, u1)), signed_bounds, 0.0)
        @test_throws ArgumentError FieldParameterGeneV1(FieldParameterRefV1("nan"), u0,
            ParameterTransformSpecV1(transform_linear), linear_bounds, NaN)
        @test_throws ArgumentError FieldParameterGeneV1(FieldParameterRefV1("inf"), u0,
            ParameterTransformSpecV1(transform_linear), linear_bounds, Inf)
        @test_throws ArgumentError FieldParameterGeneV1(FieldParameterRefV1("range"), u0,
            ParameterTransformSpecV1(transform_linear), linear_bounds, 1.000001)
        @test_throws ArgumentError field_parameter_value(linear, NaN)
        @test_throws ArgumentError field_parameter_value(linear, Inf)
        @test_throws ArgumentError field_parameter_value(linear, -1.000001)
        @test canonical_hash(linear) == _g2_expected_hash(linear)
        linear_zero = FieldParameterGeneV1(FieldParameterRefV1("linear"), u0,
            ParameterTransformSpecV1(transform_linear), linear_bounds, 0.0)
        @test canonical_hash(linear) == canonical_hash(linear_zero)
        @test canonical_json(linear) == canonical_json(linear_zero)
        @test_throws ArgumentError FieldParameterGeneV1(FieldParameterRefV1("mutable-bounds"), u0,
            ParameterTransformSpecV1(transform_linear), Any[linear_bounds], 0.0)
        @test_throws ArgumentError FieldParameterGeneV1(FieldParameterRefV1("mutable-transform"), u0,
            Any[ParameterTransformSpecV1(transform_linear)], linear_bounds, 0.0)
        @test_throws ArgumentError invoke(SpatialMultiIndex3V1, Tuple{Any}, [1, 2, 3])
        @test_throws ArgumentError invoke(ExactSpatialVector3V1, Tuple{Any,Any}, [1 // 1, 2 // 1, 3 // 1], u0)
        @test all(isimmutable, (linear, linear.ref, linear.unit, linear.transform,
            linear.bounds, linear.bounds.interval, linear.normalized_gene))
    end

    @testset "closed canonical wire has no ambient metadata" begin
        u0 = UnitSignature()
        gene_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-2, 4, false), u0)
        gene = FieldParameterGeneV1(FieldParameterRefV1("same-gene"), u0,
            ParameterTransformSpecV1(transform_linear), gene_bounds, 0.0)
        values = Any[map(T -> T("same"), G2_REF_TYPES)...,
            _g2_index(1, -2, 3), _g2_vector(1 // 2, -3 // 4, 5 // 6, u0), gene]
        @test [_g2_domain(x) for x in values] == collect((G2_REF_DOMAINS..., G2_EXTRA_DOMAINS...))
        for x in values
            text = canonical_json(x)
            @test all(occursin(key, text) for key in ("canonicalization_version", "domain", "kind", "payload"))
            @test !occursin("metadata", text)
            @test !occursin("family", text)
            @test !occursin("seed", text)
            @test !occursin("solver", text)
            @test !occursin("evidence", text)
            @test !occursin("status", text)
            @test !occursin("phenotype", text)
            @test !occursin("pass", text)
            @test canonical_hash(x) == _g2_expected_hash(x)
        end
        @test semantic_view(values[1]) isa NamedTuple
        @test _g2_field_value(values[1]) == "same"
    end
end

@testset "G2 canonical/helper/semantic-view dispatch closure" begin
    script = raw"""
    using FusionConceptAI
    using SHA
    refs = (SpatialSupportRefV1("same"), ChartRefV1("same"), CoordinateFrameRefV1("same"),
        PhaseFieldRefV1("same"), ImplicitFieldTermRefV1("same"), PotentialFieldRefV1("same"),
        SourceFieldRefV1("same"), InterfaceOperatorRefV1("same"), GeometryEvolutionRefV1("same"),
        FieldParameterRefV1("same"), SourceBudgetRefV1("same"), TopologyEventRefV1("same"))
    u = UnitSignature()
    idx = try SpatialMultiIndex3V1((1,-2,3)) catch; SpatialMultiIndex3V1(1,-2,3) end
    vec = try ExactSpatialVector3V1((1//2,-3//4,5//6),u) catch; ExactSpatialVector3V1(1//2,-3//4,5//6,u) end
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-2,4,false), u)
    gene = FieldParameterGeneV1(FieldParameterRefV1("p"), u,
        ParameterTransformSpecV1(transform_linear), bounds, 0.25)
    values = Any[refs..., idx, vec, gene]
    before = (map(canonical_json, values), map(canonical_hash, values), map(semantic_view, values),
        field_parameter_value(gene, 0.25))
    expected_sha256 = map(text -> bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(text)))), before[1])
    # These are intentionally hostile extensions.  Production G2 serializers
    # must use their closed methods and exact fields, not ambient dispatch.
    if isdefined(FusionConceptAI, :_canonical)
            @eval FusionConceptAI._canonical(::NamedTuple) = "poison"
    end
    if isdefined(FusionConceptAI, :_g2_quote)
        @eval FusionConceptAI._g2_quote(::AbstractString) = "poison"
    end
    if isdefined(FusionConceptAI, :_g2_rational)
        @eval FusionConceptAI._g2_rational(::Any) = "poison"
    end
    if isdefined(FusionConceptAI, :_g2_unit)
        @eval FusionConceptAI._g2_unit(::Any) = "poison"
    end
    if isdefined(FusionConceptAI, :_g2_wrap)
        @eval FusionConceptAI._g2_wrap(::Any, ::Any, ::Any) = "poison"
    end
    # The public two-argument methods are Float64-only.  Broad ambient methods
    # must not replace their exact entry points, and the sealed helper's more
    # specific Float64 extension must be bypassed by invoke(..., Tuple{...,Any}).
    if isdefined(FusionConceptAI, :derive_field_parameter_value)
        @eval FusionConceptAI.derive_field_parameter_value(::Any, ::Any) = 999.0
        @eval FusionConceptAI._g2_derive_field_parameter_value_sealed(::FieldParameterGeneV1, ::Float64) = 999.0
    end
    if isdefined(FusionConceptAI, :field_parameter_value)
        @eval FusionConceptAI.field_parameter_value(::Any, ::Any) = 999.0
    end
    for T in typeof.(values)
        @eval FusionConceptAI.semantic_view(::$T) = (poison=true,)
    end
    @assert before[1] == map(canonical_json, values)
    @assert before[2] == map(canonical_hash, values)
    @assert before[4] == derive_field_parameter_value(gene, 0.25)
    @assert before[4] == field_parameter_value(gene, 0.25)
    @assert before[4] == derive_field_parameter_value(gene)
    @assert before[4] == field_parameter_value(gene)

    # A more-specific Digest256(String) constructor is a realistic ambient
    # hijack for implementations that do not close their hash constructor.
    @eval FusionConceptAI begin
        Digest256(::String) = invoke(Digest256, Tuple{AbstractString}, repeat("0", 64))
    end
    @assert Digest256("probe").value == repeat("0", 64)
    poisoned_hashes = map(canonical_hash, values)
    @assert all(h.value == expected for (h, expected) in zip(poisoned_hashes, expected_sha256))
    @assert all(h.value == old.value for (h, old) in zip(poisoned_hashes, before[2]))
    println("g2-primitive-dispatch-closed-ok")
    """
    @test success(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`)
end
