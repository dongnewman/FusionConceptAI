using Test
using JSON3
using SHA
using FusionConceptAI

const G1OC_UNIT = UnitSignature((1 // 1, 1 // 2, -2 // 1, 0 // 1, 0 // 1, 0 // 1, 0 // 1))
const G1OC_CLOCK = QualifiedRefV1("clock\0🚀", "v1")
const G1OC_TYPE = PhysicalType(:scalar_field, 0, 3,
    TemporalTypeV1(discrete_time, 0, G1OC_CLOCK), G1OC_UNIT)

_g1oc_sha(text::String) = bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(text))))
_g1oc_sha(value) = Digest256(_g1oc_sha(canonical_json(value)))

function _g1oc_registry(suffix="")
    rule = ExactTypeRuleV1((G1OC_TYPE,), (G1OC_TYPE,))
    manifest = OperatorManifestV1(OperatorRefV1("G1OC_NEG" * suffix * "\0🚀", "v1"), 1, 1,
        rule, rule; pure=true, stateful=false, allowed_roles=(:governing,),
        allowed_conservation_effects=(:redistribution,))
    register_operator(default_operator_registry(), manifest)
end

function _g1oc_program(; suffix="", registry=_g1oc_registry(suffix))
    op = OperatorRefV1("G1OC_NEG" * suffix * "\0🚀", "v1")
    first = ASTApplyV1(op, (1,), (;); registry=registry, input_types=(G1OC_TYPE,))
    second = ASTApplyV1(op, (2,), (;); registry=registry, input_types=(G1OC_TYPE,))
    TypedASTProgramV1((ASTInputV1(1, G1OC_TYPE), first, second), (3,), (1,); registry=registry)
end

function _g1oc_observable(; competitors=(QualifiedRefV1("z\0\"\\\u0001🚀", "v3"),
                                           QualifiedRefV1("α", "v1"),
                                           QualifiedRefV1("预测", "v2")), suffix="", sampling_program=_g1oc_program())
    interval = QuantityIntervalV1(ExactFiniteIntervalV1(-7 // 3, 11 // 5, false), G1OC_UNIT)
    ObservableGeneV1(ObservableRefV1("观测\0\"\\\u0001🚀" * suffix),
        ProgramRootRefV1(OperatorSiteRefV1("g1oc-site" * suffix), 1, G1OC_TYPE),
        QualifiedRefV1("干预\0\"\\", "v1"), sampling_program, interval,
        QualifiedRefV1("噪声\0", "v1"), NonnegativeQuantityV1(1 // 10, G1OC_UNIT),
        NonnegativeQuantityV1(1 // 20, G1OC_UNIT), NonnegativeQuantityV1(3 // 5, G1OC_UNIT), competitors)
end

function _g1oc_payload(observable=_g1oc_observable())
    interval = QuantityIntervalV1(ExactFiniteIntervalV1(-10, 10, false), G1OC_UNIT)
    state = StateGeneV1(StateGeneRefV1("state\0🚀"), G1OC_TYPE, interval, (), (), (), state_derived)
    state_b = StateGeneV1(StateGeneRefV1("state-b"), G1OC_TYPE, interval, (), (), (), state_derived)
    account = ConservationAccountRefV1("账本\0", G1OC_UNIT, :input, 1, :inflow)
    account_out = ConservationAccountRefV1("账本\0", G1OC_UNIT, :output, 1, :outflow)
    effects = (PortAccountEffectV1(account, 1 // 1), PortAccountEffectV1(account_out, -1 // 1))
    edge = AtomicMIMOHyperedgeV1("g1oc-site" * (isempty(observable.observable_ref.value) ? "" : ""),
        (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 1),), observable.sampling_program,
        governing; account_effects=effects, registry=_g1oc_registry())
    graph = TypedOperatorHypergraphV1((node(:state, G1OC_TYPE; id="state\0🚀"),
        node(:state, G1OC_TYPE; id="state-b")), (edge,))
    invariant = InvariantV1(InvariantRefV1("invariant"), QualifiedRefV1("账本\0", "v1"),
        scope_global, nothing, (InvariantTermV1(state.state_ref, 1),), (), (), (), 0, entropy_conserved)
    MechanismGenomePayloadV1((state, state_b), (invariant,), graph, (), (), (observable,), ())
end

function _g1oc_fixture_records()
    path = joinpath(@__DIR__, "fixtures", "g1_observable_closed_baseline_e3c1093.jsonl")
    [JSON3.read(line, Dict{String,Any}) for line in eachline(path) if !isempty(strip(line))]
end

@testset "G1 observable closed canonical golden" begin
    observable = _g1oc_observable()
    text = canonical_json(observable)
    parsed = JSON3.read(text)
    @test parsed.domain == "fusionconceptai:v4:g1-primitive:v1"
    @test parsed.kind == "observable_gene"
    @test parsed.canonicalization_version == "1"
    @test ncodeunits(text) >= 1000
    @test canonical_hash(observable).value == _g1oc_sha(text)
    @test length(observable.competing_prediction_refs) == 3
    @test JSON3.read(text).payload.observable_ref.value == "观测\0\"\\\u0001🚀"
    records = _g1oc_fixture_records()
    record = only(filter(r -> r["name"] == "observable_complex", records))
    @test text == record["json"]
    @test canonical_hash(observable).value == record["sha256"]
    @test _g1oc_sha(String(record["json"])) == record["sha256"]
    @test canonical_json(_g1oc_observable(competitors=reverse(observable.competing_prediction_refs))) == text
    @test canonical_hash(_g1oc_observable(competitors=reverse(observable.competing_prediction_refs))) == canonical_hash(observable)
    payload = _g1oc_payload(observable)
    payload_text = canonical_json(payload)
    payload_record = only(filter(r -> r["name"] == "payload_complex", records))
    @test payload_text == payload_record["json"]
    @test ncodeunits(payload_text) == payload_record["ncodeunits"]
    @test canonical_hash(payload).value == payload_record["sha256"]
    @test bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(payload_text)))) == payload_record["sha256"]
end

@testset "G1 observable encoded-order competitor permutations" begin
    refs = (QualifiedRefV1("a\n", "v1"), QualifiedRefV1("a0", "v1"), QualifiedRefV1("a", "v1"))
    permutations = ((refs[1], refs[2], refs[3]), (refs[1], refs[3], refs[2]),
        (refs[2], refs[1], refs[3]), (refs[2], refs[3], refs[1]),
        (refs[3], refs[1], refs[2]), (refs[3], refs[2], refs[1]))
    texts = [canonical_json(_g1oc_observable(competitors=p)) for p in permutations]
    @test length(Set(texts)) == 1
    @test occursin("a\\n", texts[1])
    @test occursin("a0", texts[1])
    parsed = JSON3.read(texts[1], Dict{String,Any})
    ordered_pairs = [(String(item["id"]), String(item["version"])) for item in parsed["payload"]["competing_prediction_refs"]]
    @test ordered_pairs == [("a", "v1"), ("a0", "v1"), ("a\n", "v1")]
end

@testset "G1 observable semantic and manifest boundaries" begin
    base = _g1oc_observable()
    @test base.expression_root.declared_type == G1OC_TYPE
    @test base.sampling_program.nodes[1].output_type == G1OC_TYPE
    @test base.sampling_program.used_manifest_bindings isa Tuple
    @test length(base.sampling_program.nodes) == 3
    @test semantic_view(base).observable_ref == base.observable_ref
    variants = (
        _g1oc_observable(suffix="-ref"),
        _g1oc_observable(competitors=(QualifiedRefV1("a", "v1"), QualifiedRefV1("b", "v1"), QualifiedRefV1("c", "v1"))),
    )
    @test all(canonical_hash(v) != canonical_hash(base) for v in variants)
    @test all(canonical_json(v) != canonical_json(base) for v in variants)
    @test_throws ArgumentError _g1oc_observable(competitors=(QualifiedRefV1("a", "v1"), QualifiedRefV1("a", "v1"), QualifiedRefV1("b", "v1")))
    @test_throws ArgumentError ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref,
        base.sampling_program, QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), UnitSignature()),
        base.noise_model_ref, base.noise_floor, base.numerical_floor, base.minimum_effect_size,
        base.competing_prediction_refs)
    @test _g1oc_payload() isa MechanismGenomePayloadV1
    @test canonical_hash(_g1oc_payload()) == canonical_hash(_g1oc_payload())
end

@testset "G1 observable all source fields and closed types" begin
    base = _g1oc_observable()
    variants = ObservableGeneV1[
        ObservableGeneV1(ObservableRefV1("different"), base.expression_root, base.intervention_ref,
            base.sampling_program, base.expected_effect_interval, base.noise_model_ref,
            base.noise_floor, base.numerical_floor, base.minimum_effect_size, base.competing_prediction_refs),
        ObservableGeneV1(base.observable_ref, ProgramRootRefV1(OperatorSiteRefV1("different-site"), 1, G1OC_TYPE),
            base.intervention_ref, base.sampling_program, base.expected_effect_interval, base.noise_model_ref,
            base.noise_floor, base.numerical_floor, base.minimum_effect_size, base.competing_prediction_refs),
        ObservableGeneV1(base.observable_ref, base.expression_root, QualifiedRefV1("different", "v1"),
            base.sampling_program, base.expected_effect_interval, base.noise_model_ref,
            base.noise_floor, base.numerical_floor, base.minimum_effect_size, base.competing_prediction_refs),
        ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref, base.sampling_program,
            QuantityIntervalV1(ExactFiniteIntervalV1(-8 // 3, 11 // 5, false), G1OC_UNIT), base.noise_model_ref,
            base.noise_floor, base.numerical_floor, base.minimum_effect_size, base.competing_prediction_refs),
        ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref, base.sampling_program,
            base.expected_effect_interval, QualifiedRefV1("different", "v1"), base.noise_floor,
            base.numerical_floor, base.minimum_effect_size, base.competing_prediction_refs),
        ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref, base.sampling_program,
            base.expected_effect_interval, base.noise_model_ref, NonnegativeQuantityV1(1 // 9, G1OC_UNIT),
            base.numerical_floor, base.minimum_effect_size, base.competing_prediction_refs),
        ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref, base.sampling_program,
            base.expected_effect_interval, base.noise_model_ref, base.noise_floor,
            NonnegativeQuantityV1(1 // 19, G1OC_UNIT), base.minimum_effect_size, base.competing_prediction_refs),
        ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref, base.sampling_program,
            base.expected_effect_interval, base.noise_model_ref, base.noise_floor, base.numerical_floor,
            NonnegativeQuantityV1(2 // 3, G1OC_UNIT), base.competing_prediction_refs),
        ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref, base.sampling_program,
            base.expected_effect_interval, base.noise_model_ref, base.noise_floor, base.numerical_floor,
            base.minimum_effect_size, (QualifiedRefV1("one", "v1"), QualifiedRefV1("two", "v1"), QualifiedRefV1("three", "v1"))),
        ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref, _g1oc_program(suffix="-alt"),
            base.expected_effect_interval, base.noise_model_ref, base.noise_floor, base.numerical_floor,
            base.minimum_effect_size, base.competing_prediction_refs),
    ]
    @test length(variants) == 10
    @test all(canonical_hash(v) != canonical_hash(base) for v in variants)
    @test all(canonical_json(v) != canonical_json(base) for v in variants)
    @test_throws ArgumentError ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref,
        base.sampling_program, base.expected_effect_interval, base.noise_model_ref, 0.1,
        base.numerical_floor, base.minimum_effect_size, base.competing_prediction_refs)
    @test_throws ArgumentError ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref,
        base.sampling_program, base.expected_effect_interval, base.noise_model_ref, base.noise_floor,
        base.numerical_floor, BigInt(1), base.competing_prediction_refs)
    @test_throws ArgumentError ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref,
        base.sampling_program, base.expected_effect_interval, base.noise_model_ref, base.noise_floor,
        base.numerical_floor, base.minimum_effect_size, [QualifiedRefV1("a", "v1")])
end

@testset "G1 observable source scan and byte-level invariants" begin
    source_paths = (joinpath(@__DIR__, "..", "src", "Canonical", "MechanismObservableCanonical.jl"),)
    forbidden = ("sensor", "feasibility", "solver", "device_family", "unsupported", "phenotype", "metadata")
    for path in source_paths
        source = lowercase(read(path, String))
        @test all(!occursin(word, source) for word in forbidden)
    end
    value = _g1oc_observable()
    text = canonical_json(value)
    raw = Vector{UInt8}(codeunits(text))
    @test ncodeunits(text) == length(raw)
    @test bytes2hex(SHA.sha256(raw)) == canonical_hash(value).value
    @test canonical_json(value) == canonical_json(value)
    @test canonical_hash(value) == canonical_hash(value)
    @test hash(canonical_hash(value)) == hash(canonical_hash(value))
end

@testset "G1 observable numeric and temporal edge boundaries" begin
    base = _g1oc_observable()
    @test base.expected_effect_interval.interval.lower == -7 // 3
    @test base.expected_effect_interval.interval.upper == 11 // 5
    extreme_interval = QuantityIntervalV1(ExactFiniteIntervalV1(typemin(Int64), typemax(Int64), false), G1OC_UNIT)
    extreme = ObservableGeneV1(base.observable_ref, base.expression_root, base.intervention_ref,
        base.sampling_program, extreme_interval, base.noise_model_ref, base.noise_floor,
        base.numerical_floor, NonnegativeQuantityV1(1, G1OC_UNIT), base.competing_prediction_refs)
    @test canonical_hash(extreme) != canonical_hash(base)
    static_root = ProgramRootRefV1(OperatorSiteRefV1("static-site"), 1,
        PhysicalType(:scalar_field, 0, 3, TemporalTypeV1(static_time), G1OC_UNIT))
    @test_throws ArgumentError ObservableGeneV1(base.observable_ref, static_root, base.intervention_ref,
        base.sampling_program, base.expected_effect_interval, base.noise_model_ref, base.noise_floor,
        base.numerical_floor, base.minimum_effect_size, base.competing_prediction_refs)
end
