using Test
using JSON3
using SHA
using FusionConceptAI

const G31_U0 = UnitSignature()
const G31_TIME = UnitSignature((0, 0, 1, 0, 0, 0, 0))
const G31_INV_TIME = UnitSignature((0, 0, -1, 0, 0, 0, 0))
const G31_OBSERVATION_REF_DOMAIN = "fusionconceptai:v4:g3:observation_channel_ref:v1"
const G31_REQUIREMENT_DOMAIN = "fusionconceptai:v4:g3:observation_channel_requirement:v1"

_g31_bytes(x) = Vector{UInt8}(codeunits(canonical_json(x)))
_g31_sha(x) = Digest256(bytes2hex(SHA.sha256(_g31_bytes(x))))

function _g31_fixture_records()
    path = joinpath(@__DIR__, "fixtures", "g3_61_fixed_canonical.jsonl")
    [JSON3.read(line, Dict{String,Any}) for line in eachline(path) if !isempty(strip(line))]
end

function _g31_sampling_program(measurement_type=PhysicalType(:scalar_field, 0, 3, :differential, G31_U0))
    scalar = measurement_type
    registry = default_operator_registry()
    apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
        registry=registry, input_types=(scalar,))
    TypedASTProgramV1((ASTInputV1(1, scalar), apply), (2,), (1,); registry=registry)
end

function _g31_nonidentity_observable()
    input_type = PhysicalType(:scalar_field, 0, 3, :differential, G31_U0)
    output_type = PhysicalType(:vector_field, 1, 3, :differential, G31_U0)
    ref = OperatorRefV1("G31_NON_IDENTITY", "v1")
    rule = ExactTypeRuleV1((input_type,), (output_type,))
    digest = FusionConceptAI._operator_manifest_digest(ref, 1, 1, rule, rule,
        (:governing,), (), :local, UInt8(0), true, false, false, false, (), true, (), ())
    manifest = OperatorManifestV1(ref, digest, 1, 1, rule, rule, (:governing,), (),
        :local, UInt8(0), true, false, false, false, (), true, (), ())
    registry = register_operator(default_operator_registry(), manifest)
    apply = ASTApplyV1(ref, (1,), (;); registry=registry, input_types=(input_type,))
    program = TypedASTProgramV1((ASTInputV1(1, input_type), apply), (2,), (1,); registry=registry)
    ObservableGeneV1(ObservableRefV1("nonidentity-observable"),
        ProgramRootRefV1(OperatorSiteRefV1("nonidentity-site"), 1, input_type),
        QualifiedRefV1("intervention", "v1"), program,
        QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), G31_U0),
        QualifiedRefV1("noise", "v1"), NonnegativeQuantityV1(1 // 10, G31_U0),
        NonnegativeQuantityV1(1 // 10, G31_U0), NonnegativeQuantityV1(1 // 2, G31_U0),
        (QualifiedRefV1("prediction", "v1"),))
end

function _g31_observable(; suffix="", measurement_type=PhysicalType(:scalar_field, 0, 3, :differential, G31_U0), minimum=1 // 2)
    scalar = measurement_type
    interval = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), G31_U0)
    ObservableGeneV1(ObservableRefV1("observable" * suffix),
        ProgramRootRefV1(OperatorSiteRefV1("observation-site" * suffix), 1, scalar),
        QualifiedRefV1("intervention", "v1"), _g31_sampling_program(scalar), interval,
        QualifiedRefV1("noise", "v1"), NonnegativeQuantityV1(1 // 10, G31_U0),
        NonnegativeQuantityV1(1 // 10, G31_U0), NonnegativeQuantityV1(minimum, G31_U0),
        (QualifiedRefV1("prediction", "v1"),))
end

function _g31_support(; suffix="")
    chart = chart_coordinate_type_v1()
    interval = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), G31_U0)
    frame = CoordinateFrameRefV1("frame" * suffix)
    chart_gene = CoordinateChartGeneV1(ChartRefV1("chart" * suffix), frame,
        (interval, interval, interval), (),
        SpatialProgramRootRefV1(FieldOperatorSiteRefV1("coordinate" * suffix), 1,
            chart, normalized_ambient_coordinate_type_v1()),
        SpatialProgramRootRefV1(FieldOperatorSiteRefV1("metric" * suffix), 1,
            chart, normalized_covariant_metric_type_v1()))
    SpatialSupportGeneV1(SpatialSupportRefV1("support" * suffix), 3, (frame,),
        (chart_gene,), (), NonnegativeQuantityV1(1, UnitSignature((0, 1, 0, 0, 0, 0, 0))))
end

function _g31_requirement(; suffix="", channel="channel", observable=_g31_observable(), support=_g31_support(),
                           sampling=NonnegativeQuantityV1(1, G31_TIME), latency=NonnegativeQuantityV1(0, G31_TIME),
                           bandwidth=NonnegativeQuantityV1(1, G31_INV_TIME), range=QuantityIntervalV1(ExactFiniteIntervalV1(-2, 2, false), G31_U0),
                           resolution=NonnegativeQuantityV1(1 // 20, G31_U0))
    ObservationChannelRequirementV1(ObservationChannelRefV1(channel * suffix), observable, support,
        sampling, latency, bandwidth, range, resolution)
end

function _g31_legacy_graph()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, G31_U0)
    ast = ast_leaf(:state, scalar)
    TypedOperatorHypergraphV1((node(:state, scalar; id="n-a", label="alpha"),
        node(:state, scalar; id="n-b", label="beta")),
        (TypedHyperedge("edge-x", (1,), (2,), ast, :governing),))
end

@testset "G3.1 observation channel reference and requirement contract" begin
    ref = ObservationChannelRefV1("观测\0🚀")
    @test ref.value == "观测\0🚀"
    @test fieldnames(typeof(ref)) == (:value,)
    @test JSON3.read(canonical_json(ref)).domain == G31_OBSERVATION_REF_DOMAIN
    @test JSON3.read(canonical_json(ref)).kind == "observation_channel_ref"
    @test JSON3.read(canonical_json(ref)).canonicalization_version == "1"
    @test canonical_hash(ref) == _g31_sha(ref)
    records = _g31_fixture_records()
    ref_record = only(filter(r -> r["name"] == "observation_channel_ref_unicode_nul", records))
    @test canonical_json(ref) == ref_record["json"]
    @test canonical_hash(ref).value == ref_record["sha256"]
    ref_bytes = Vector{UInt8}(codeunits(String(ref_record["json"])))
    @test bytes2hex(SHA.sha256(ref_bytes)) == ref_record["sha256"]
    @test_throws ArgumentError ObservationChannelRefV1("")
    @test_throws ArgumentError ObservationChannelRefV1(:symbol)
    raw_invalid_utf8 = UInt8[0xff, 0xfe]
    invalid_utf8 = GC.@preserve raw_invalid_utf8 unsafe_string(pointer(raw_invalid_utf8), length(raw_invalid_utf8))
    @test invalid_utf8 isa String
    @test_throws ArgumentError ObservationChannelRefV1(invalid_utf8)

    observable = _g31_observable()
    support = _g31_support()
    requirement = _g31_requirement(observable=observable, support=support)
    parsed = JSON3.read(canonical_json(requirement))
    @test parsed.domain == G31_REQUIREMENT_DOMAIN
    @test parsed.kind == "observation_channel_requirement"
    @test parsed.canonicalization_version == "1"
    @test Set(String.(keys(parsed.payload))) == Set(("channel_ref", "observable_ref", "observable_content_hash",
        "spatial_support_ref", "spatial_support_content_hash", "measurement_type",
        "maximum_sampling_period", "maximum_latency", "minimum_bandwidth",
        "required_measurement_range", "maximum_resolution"))
    @test canonical_hash(requirement) == _g31_sha(requirement)
    req_record = only(filter(r -> r["name"] == "observation_channel_requirement", records))
    @test canonical_json(requirement) == req_record["json"]
    @test canonical_hash(requirement).value == req_record["sha256"]
    req_bytes = Vector{UInt8}(codeunits(String(req_record["json"])))
    @test bytes2hex(SHA.sha256(req_bytes)) == req_record["sha256"]
    @test requirement.observable_ref == observable.observable_ref
    @test requirement.spatial_support_ref == support.support_ref
    @test requirement.observable_content_hash == canonical_hash(observable)
    @test requirement.spatial_support_content_hash == canonical_hash(support)
    @test requirement.measurement_type == observable.expression_root.declared_type
    @test fieldnames(typeof(requirement)) == (:channel_ref, :observable_ref, :observable_content_hash,
        :spatial_support_ref, :spatial_support_content_hash, :measurement_type,
        :maximum_sampling_period, :maximum_latency, :minimum_bandwidth,
        :required_measurement_range, :maximum_resolution)
    @test keys(semantic_view(requirement)) == fieldnames(typeof(requirement))
    @test_throws MethodError ObservationChannelRequirementV1(requirement.channel_ref,
        requirement.observable_ref, requirement.observable_content_hash, requirement.spatial_support_ref,
        requirement.spatial_support_content_hash, requirement.measurement_type,
        requirement.maximum_sampling_period, requirement.maximum_latency, requirement.minimum_bandwidth,
        requirement.required_measurement_range, requirement.maximum_resolution)
end

@testset "G3.1 temporal, measurement and strict effect gates" begin
    good = _g31_requirement()
    @test good.maximum_sampling_period.value > 0
    @test good.maximum_latency.value == 0
    @test good.minimum_bandwidth.value >= 0
    @test _g31_requirement(sampling=NonnegativeQuantityV1(typemax(Int64), G31_TIME)) isa ObservationChannelRequirementV1
    @test_throws ArgumentError _g31_requirement(sampling=NonnegativeQuantityV1(0, G31_TIME))
    @test_throws ArgumentError _g31_requirement(sampling=NonnegativeQuantityV1(1, G31_U0))
    @test_throws ArgumentError _g31_requirement(latency=NonnegativeQuantityV1(1, G31_U0))
    @test_throws ArgumentError _g31_requirement(bandwidth=NonnegativeQuantityV1(1, G31_TIME))
    @test_throws ArgumentError _g31_requirement(range=QuantityIntervalV1(ExactFiniteIntervalV1(-1 // 2, 2, false), G31_U0))
    @test_throws ArgumentError _g31_requirement(range=QuantityIntervalV1(ExactFiniteIntervalV1(-2, 1 // 2, false), G31_U0))
    @test_throws ArgumentError _g31_requirement(range=QuantityIntervalV1(ExactFiniteIntervalV1(-2, 2, false), G31_TIME))
    @test_throws ArgumentError _g31_requirement(resolution=NonnegativeQuantityV1(1, G31_TIME))
    @test_throws ArgumentError _g31_requirement(resolution=NonnegativeQuantityV1(3 // 10, G31_U0))

    interval = QuantityIntervalV1(ExactFiniteIntervalV1(typemin(Int64), typemax(Int64), false), G31_U0)
    extreme = _g31_observable()
    extreme = ObservableGeneV1(extreme.observable_ref, extreme.expression_root, extreme.intervention_ref,
        extreme.sampling_program, interval, extreme.noise_model_ref, extreme.noise_floor,
        extreme.numerical_floor, NonnegativeQuantityV1(typemax(Int64), G31_U0), extreme.competing_prediction_refs)
    @test_throws ArgumentError _g31_requirement(observable=extreme, range=interval,
        resolution=NonnegativeQuantityV1(typemax(Int64), G31_U0))
    @test _g31_requirement(range=QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, true), G31_U0)) isa ObservationChannelRequirementV1
    @test _g31_requirement(bandwidth=NonnegativeQuantityV1(0, G31_INV_TIME)) isa ObservationChannelRequirementV1
end

@testset "G3.1 measurement type follows non-identity sampling root" begin
    observable = _g31_nonidentity_observable()
    requirement = _g31_requirement(observable=observable,
        range=QuantityIntervalV1(ExactFiniteIntervalV1(-2, 2, false), G31_U0),
        resolution=NonnegativeQuantityV1(1 // 20, G31_U0))
    @test requirement.measurement_type == observable.sampling_program.nodes[2].output_type
    @test requirement.measurement_type != observable.expression_root.declared_type
    @test requirement.measurement_type != observable.sampling_program.nodes[1].output_type
    @test requirement.measurement_type.units == observable.sampling_program.nodes[1].output_type.units
end

@testset "G3.1 exact types, closed binding and identity sensitivity" begin
    base = _g31_requirement()
    for bad in ("channel", Symbol("channel"), 1, 1.0, big(1), true, ("channel",), ["channel"])
        @test_throws ArgumentError ObservationChannelRequirementV1(bad, _g31_observable(), _g31_support(),
            NonnegativeQuantityV1(1, G31_TIME), NonnegativeQuantityV1(0, G31_TIME),
            NonnegativeQuantityV1(1, G31_INV_TIME), QuantityIntervalV1(ExactFiniteIntervalV1(-2, 2, false), G31_U0),
            NonnegativeQuantityV1(1 // 20, G31_U0))
    end
    @test_throws ArgumentError ObservationChannelRequirementV1(ObservationChannelRefV1("c"),
        canonical_json(_g31_observable()), _g31_support(), base.maximum_sampling_period,
        base.maximum_latency, base.minimum_bandwidth, base.required_measurement_range, base.maximum_resolution)
    @test_throws ArgumentError ObservationChannelRequirementV1(ObservationChannelRefV1("c"), _g31_observable(),
        canonical_json(_g31_support()), base.maximum_sampling_period, base.maximum_latency, base.minimum_bandwidth,
        base.required_measurement_range, base.maximum_resolution)
    @test_throws ArgumentError ObservationChannelRequirementV1(ObservationChannelRefV1("c"), _g31_observable(), _g31_support(),
        1, base.maximum_latency, base.minimum_bandwidth, base.required_measurement_range, base.maximum_resolution)
    @test_throws ArgumentError ObservationChannelRequirementV1(ObservationChannelRefV1("c"), _g31_observable(), _g31_support(),
        base.maximum_sampling_period, 0, base.minimum_bandwidth, base.required_measurement_range, base.maximum_resolution)
    @test_throws ArgumentError ObservationChannelRequirementV1(ObservationChannelRefV1("c"), _g31_observable(), _g31_support(),
        base.maximum_sampling_period, base.maximum_latency, 1, base.required_measurement_range, base.maximum_resolution)
    @test_throws ArgumentError ObservationChannelRequirementV1(ObservationChannelRefV1("c"), Dict(), _g31_support(),
        base.maximum_sampling_period, base.maximum_latency, base.minimum_bandwidth, base.required_measurement_range, base.maximum_resolution)
    @test_throws ArgumentError ObservationChannelRequirementV1(ObservationChannelRefV1("c"), _g31_observable(), [1],
        base.maximum_sampling_period, base.maximum_latency, base.minimum_bandwidth, base.required_measurement_range, base.maximum_resolution)
    @test_throws ArgumentError ObservationChannelRequirementV1(ObservationChannelRefV1("c"), _g31_observable(), _g31_support(),
        base.maximum_sampling_period, base.maximum_latency, base.minimum_bandwidth, ( -2, 2), base.maximum_resolution)
    @test_throws ArgumentError ObservationChannelRequirementV1(ObservationChannelRefV1("c"), _g31_observable(), _g31_support(),
        base.maximum_sampling_period, base.maximum_latency, base.minimum_bandwidth, base.required_measurement_range, 1)

    variants = ObservationChannelRequirementV1[
        _g31_requirement(channel="other"),
        _g31_requirement(observable=_g31_observable(suffix="-other")),
        _g31_requirement(support=_g31_support(suffix="-other")),
        _g31_requirement(observable=_g31_observable(suffix="-vector",
            measurement_type=PhysicalType(:vector_field, 1, 3, :differential, G31_U0))),
        _g31_requirement(sampling=NonnegativeQuantityV1(2, G31_TIME)),
        _g31_requirement(latency=NonnegativeQuantityV1(1, G31_TIME)),
        _g31_requirement(bandwidth=NonnegativeQuantityV1(2, G31_INV_TIME)),
        _g31_requirement(range=QuantityIntervalV1(ExactFiniteIntervalV1(-3, 2, false), G31_U0)),
        _g31_requirement(resolution=NonnegativeQuantityV1(1 // 10, G31_U0)),
    ]
    @test all(canonical_hash(v) != canonical_hash(base) for v in variants)
    @test all(canonical_json(v) != canonical_json(base) for v in variants)
    support_base = _g31_support()
    support_same_ref_changed_content = SpatialSupportGeneV1(support_base.support_ref,
        support_base.ambient_dimension, support_base.coordinate_frame_refs, support_base.charts,
        support_base.chart_transition_maps,
        NonnegativeQuantityV1(2, UnitSignature((0, 1, 0, 0, 0, 0, 0))))
    @test support_same_ref_changed_content.support_ref == support_base.support_ref
    @test canonical_hash(support_same_ref_changed_content) != canonical_hash(support_base)
    @test _g31_requirement(support=support_same_ref_changed_content).spatial_support_content_hash !=
        base.spatial_support_content_hash
    @test variants[4].measurement_type != base.measurement_type
    same_ref = _g31_observable()
    altered_content = ObservableGeneV1(same_ref.observable_ref, same_ref.expression_root, same_ref.intervention_ref,
        same_ref.sampling_program, same_ref.expected_effect_interval, same_ref.noise_model_ref,
        same_ref.noise_floor, same_ref.numerical_floor, NonnegativeQuantityV1(3 // 5, G31_U0),
        same_ref.competing_prediction_refs)
    @test same_ref.observable_ref == altered_content.observable_ref
    @test canonical_hash(same_ref) != canonical_hash(altered_content)
    @test _g31_requirement(observable=altered_content).observable_content_hash != base.observable_content_hash
    @test _g31_requirement(observable=_g31_observable(), support=_g31_support()) == base
    @test hash(_g31_requirement()) == hash(base)
end

@testset "G3.1 legacy realization-control compatibility golden" begin
    refs = [GenomeContractRef("urn:g31:" * string(i), "v4", digest256_text("s" * string(i)),
        digest256_text("c" * string(i)), "profile") for i in 1:3]
    graph = _g31_legacy_graph()
    legacy = RealizationControlGenomeV4(11, 12, refs[3], graph, graph;
        realization=(; basis=:a), control=(; basis=:b))
    @test fieldnames(typeof(legacy)) == (:seed, :control_seed, :contract_ref, :realization_graph,
        :control_graph, :realization, :control)
    @test legacy.seed == UInt64(11) && legacy.control_seed == UInt64(12)
    @test semantic_view(legacy) == (contract_ref=refs[3], realization_graph=graph,
        control_graph=graph, realization=legacy.realization, control=legacy.control)
    @test realization_hash(legacy) != control_hash(legacy)
    @test coupled_realization_control_hash(legacy) isa Digest256
    @test_throws ArgumentError RealizationControlGenomeV4(11, 11, refs[3], graph, graph)
    @test_throws MethodError RealizationControlGenomeV4(11, 12, refs[3], graph, graph, realization=(;), control=(;), extra=(;))
end

@testset "G3.1 detached e3c1093 realization-control full golden" begin
    refs = [GenomeContractRef("urn:g31:" * string(i), "v4", digest256_text("s" * string(i)),
        digest256_text("c" * string(i)), "profile") for i in 1:3]
    graph = _g31_legacy_graph()
    legacy = RealizationControlGenomeV4(11, 12, refs[3], graph, graph;
        realization=(; basis=:a), control=(; basis=:b))
    record = only(filter(r -> r["name"] == "realization_control_genome_e3c1093", _g31_fixture_records()))
    @test record["provenance"] == "e3c1093"
    @test canonical_json(legacy) == record["json"]
    @test bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(canonical_json(legacy))))) == record["sha256"]
    @test realization_control_hash(legacy).value == record["sha256"]
    @test realization_hash(legacy).value == record["realization_sha256"]
    @test control_hash(legacy).value == record["control_sha256"]
    @test coupled_realization_control_hash(legacy).value == record["coupled_sha256"]
    @test legacy.seed == UInt64(record["seed"]) && legacy.control_seed == UInt64(record["control_seed"])
end

@testset "G3.1 source vocabulary boundary" begin
    files = (joinpath(@__DIR__, "..", "src", "Genomes", "ControlPrimitives.jl"),
             joinpath(@__DIR__, "..", "src", "Genomes", "ControlObservationRequirements.jl"),
             joinpath(@__DIR__, "..", "src", "Canonical", "ControlObservationRequirementCanonical.jl"))
    banned = ("family", "device", "solver", "evidence", "status", "unsupported", "phenotype",
              "material", "partition", "feasibility", "sensor")
    for path in files
        source = lowercase(read(path, String))
        @test all(!occursin(token, source) for token in banned)
    end
end
