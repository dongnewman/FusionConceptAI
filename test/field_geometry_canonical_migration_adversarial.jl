using Test
using SHA

const _CCBW_PREP_ROOT = normpath(joinpath(@__DIR__, ".."))
const _CCBW_PREP_PHYSICAL_TYPES = joinpath(_CCBW_PREP_ROOT, "src", "IR", "PhysicalTypes.jl")
const _CCBW_PREP_RUNS = joinpath(_CCBW_PREP_ROOT, "runs", "goal_execution_20260926", "canonical_hash_raw_foreigncall_r1")
const _CCBW_PREP_BEFORE = joinpath(_CCBW_PREP_ROOT, "runs", "goal_execution_20260926", "canonical_hash_native_copy_r1", "ClosedCanonicalByteWriter.before.jl")
const _CCBW_PREP_AFTER = joinpath(_CCBW_PREP_RUNS, "ClosedCanonicalByteWriter.after.jl")
const _CCBW_PREP_PHYSICAL_SHA = "dc51af9c34fe95dc74b579f6901bef56eb6d4da81b89281ae2734c3c3ad3a8d4"
const _CCBW_PREP_BEFORE_SHA = "5e7937855842f918b391bffb76f800648f382f38310751b8e0b7b6da8074269b"
const _CCBW_PREP_AFTER_SHA = "927aab5b815fcb81b031a7525beb5cce8d260ab7e1d88b152b4656803e4b3f74"
const _CCBW_PREP_TARGET_SOURCE = Ref{Ptr{UInt8}}(Ptr{UInt8}(0))
const _CCBW_PREP_TARGET_COUNT = Ref{Int}(0)
const _CCBW_PREP_TARGET_POINTER_CONVERTED = Ref(false)
const _CCBW_PREP_POISON_HITS = Ref{UInt8}(0)

function _ccbw_prep_pin(path::String, expected::String)
    isfile(path) || error("closed hash prep input missing: $path")
    observed = bytes2hex(SHA.sha256(read(path)))
    observed == expected || error("closed hash prep input pin mismatch: $path ($observed)")
    observed
end

function _ccbw_prep_writer_module(name::String, writer_path::String, writer_sha::String)
    _ccbw_prep_pin(_CCBW_PREP_PHYSICAL_TYPES, _CCBW_PREP_PHYSICAL_SHA)
    _ccbw_prep_pin(writer_path, writer_sha)
    mod = Module(gensym(Symbol(name)))
    Core.eval(mod, :(using SHA))
    Base.include(mod, _CCBW_PREP_PHYSICAL_TYPES)
    Base.include(mod, writer_path)
    mod
end

function _ccbw_prep_pattern(count::Int)
    bytes = Vector{UInt8}(undef, count)
    for i in eachindex(bytes)
        bytes[i] = UInt8(mod((i - 1) * 131 + 17, 256))
    end
    String(bytes)
end

function _ccbw_prep_python_cases()
    cases = Tuple{String,String,String}[
        ("empty", String(UInt8[]), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
        ("nul", String(UInt8[0x00]), "6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d"),
        ("embedded_nul", String(UInt8[0x6c, 0x65, 0x66, 0x74, 0x00, 0x72, 0x69, 0x67, 0x68, 0x74]), "a8bf3285e2c06883247ccc859fa41ad965f343ae6579b6b6b127c5d8280c9701"),
        ("unicode_nul", "状态\0🚀", "feb66d773965ab8e2224e87ebb7d9bdb46919649703e9c9387e1191dd6c09bca"),
        ("unicode_nfc", "é", "4a99557e4033c3539de2eb65472017cad5f9557f7a0625a09f1c3f6e2ba69c4c"),
        ("unicode_nfd", "e\u0301", "bf12767b0f2a56b2190075bae8169f656e3ce8d6357d4aff184bc6c7ea48f9f6"),
        ("all_256", String(collect(UInt8(0):UInt8(255))), "40aff2e9d2d8922e47afd4648e6967497158785fbd1da870e7110266bf944880"),
    ]
    for (count, digest) in (
        (1, "4a64a107f0cb32536e5bce6c98c393db21cca7f4ea187ba8c4dca8b51d4ea80a"),
        (63, "b8e655e9e7ad413b96f0a371eb1d6db71dcca27f4eee35892517cbe4bfaa6f9a"),
        (64, "e5146be62accc56709594cb45c651b361df94f622cbb09b91ea3ca7a2060bd53"),
        (65, "4b6c6774f0cbcd776a90e187b9494e04ca880c0afe3ea1c5cad51c8bbcb41f74"),
        (4095, "d8d5daa4611f92aff29d032c9876a120ce7a4a7d19e2c4986b8c3c1af6e85c1a"),
        (4096, "c741eee93580a334bae702208e5c0595d8e32eb07d562c52d56ca5f86e78f8a8"),
        (4097, "6b828a41dabc57049f86a8a1b0ceac3e4112258b236a527395c8116c99424ffd"),
        (65535, "c6a1a875a56160beba80d5233caaf8cc4532780b37715889df1add7fc47c8282"),
        (65536, "d8f32a3b4c195f65444e342b0c61bdaf114802e84ab7821a1f88e3f66ea15100"),
        (65537, "65d80b2b0f0120bda1628b3749982090e058d2d9f4a5fad1bc70250b49bc4e96"),
        (1048576, "ea53eb498f9b7dc054aae73924bf25c569604d2c20aa9016f0b8714a1c180c7b"),
    )
        push!(cases, ("pattern_$count", _ccbw_prep_pattern(count), digest))
    end
    cases
end

function _ccbw_prep_source_pointer(value::String)
    GC.@preserve value ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), value)
end

function _ccbw_prep_set_target!(value::String)
    _CCBW_PREP_TARGET_SOURCE[] = _ccbw_prep_source_pointer(value)
    _CCBW_PREP_TARGET_COUNT[] = Core.sizeof(value)
    _CCBW_PREP_TARGET_POINTER_CONVERTED[] = false
    nothing
end

function _ccbw_prep_run_copy_only()
    old_writer = _ccbw_prep_writer_module("ClosedWriterBefore", _CCBW_PREP_BEFORE, _CCBW_PREP_BEFORE_SHA)
    new_writer = _ccbw_prep_writer_module("ClosedWriterAfter", _CCBW_PREP_AFTER, _CCBW_PREP_AFTER_SHA)
    cases = _ccbw_prep_python_cases()
    old_hash = getfield(old_writer, :_ccbw_hash_bytes)
    new_hash = getfield(new_writer, :_ccbw_hash_bytes)
    @testset "closed byte hash old/new/Python SHA equivalence" begin
        for (label, value, python_sha) in cases
            @testset "$label" begin
                expected = python_sha # Frozen independently from Python hashlib.sha256(raw_bytes).
                old_digest = Base.invokelatest(old_hash, value).value
                new_digest = Base.invokelatest(new_hash, value).value
                @test old_digest == expected
                @test new_digest == expected
                @test old_digest == new_digest
            end
        end
    end
    by_name = Dict(label => (value, digest) for (label, value, digest) in cases)
    @testset "GC-preserved source and destination under forced collections" begin
        for pass in 1:3
            churn = [Vector{UInt8}(undef, 8192) for _ in 1:8]
            for label in ("empty", "pattern_1", "pattern_65", "pattern_4097", "pattern_65537")
                value, expected = by_name[label]
                GC.gc(true)
                local_old = ""
                local_new = ""
                GC.@preserve value begin
                    local_old = Base.invokelatest(old_hash, value).value
                    GC.gc(true)
                    local_new = Base.invokelatest(new_hash, value).value
                    GC.gc(true)
                end
                @test local_old == expected
                @test local_new == expected
                @test local_old == local_new
            end
            @test sum(length, churn) == 65536
        end
    end
    println("CLOSED_HASH_COPY_ONLY=PASS")
end

function _ccbw_prep_run_copy_poison(mode::String)
    new_writer = _ccbw_prep_writer_module("ClosedWriterAfterCopyPoison", _CCBW_PREP_AFTER, _CCBW_PREP_AFTER_SHA)
    hash_bytes = getfield(new_writer, :_ccbw_hash_bytes)
    value = _ccbw_prep_pattern(65537)
    expected = "65d80b2b0f0120bda1628b3749982090e058d2d9f4a5fad1bc70250b49bc4e96"
    @testset "fresh-process copy and foreigncall pollution sentinels" begin
        @test Base.invokelatest(hash_bytes, value).value == expected
        if mode == "copy"
            @eval Base begin
                function memmove(destination::Ptr{UInt8}, source::Ptr{UInt8}, count::Integer)
                    if source == Main._CCBW_PREP_TARGET_SOURCE[] && count == Main._CCBW_PREP_TARGET_COUNT[]
                        Main._CCBW_PREP_POISON_HITS[] |= UInt8(0x01)
                        return destination
                    end
                    ccall(:memmove, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t), destination, source, count)
                    destination
                end
                function unsafe_copyto!(destination::Ptr{UInt8}, source::Ptr{UInt8}, count::Integer)
                    if source == Main._CCBW_PREP_TARGET_SOURCE[] && count == Main._CCBW_PREP_TARGET_COUNT[]
                        Main._CCBW_PREP_POISON_HITS[] |= UInt8(0x02)
                        return destination
                    end
                    ccall(:memmove, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Csize_t), destination, source, count)
                    destination
                end
            end
            probe_source = UInt8[0x11, 0x22, 0x33]
            probe_destination = UInt8[0x00, 0x00, 0x00]
            GC.@preserve probe_source probe_destination begin
                _CCBW_PREP_TARGET_SOURCE[] = pointer(probe_source)
                _CCBW_PREP_TARGET_COUNT[] = length(probe_source)
                Base.invokelatest(Base.memmove, pointer(probe_destination), pointer(probe_source), length(probe_source))
                hit = _CCBW_PREP_POISON_HITS[]
                _CCBW_PREP_POISON_HITS[] = 0x00
                @test hit == 0x01
                Base.invokelatest(Base.unsafe_copyto!, pointer(probe_destination), pointer(probe_source), length(probe_source))
                hit = _CCBW_PREP_POISON_HITS[]
                _CCBW_PREP_POISON_HITS[] = 0x00
                @test hit == 0x02
            end
            _ccbw_prep_set_target!(value)
            observed = Base.invokelatest(hash_bytes, value).value
            hit = _CCBW_PREP_POISON_HITS[]
            _CCBW_PREP_POISON_HITS[] = 0x00
            @test hit == 0x00
            @test observed == expected
        else
            @eval Base begin
                function cconvert(::Type{Ptr{Cvoid}}, source::Ptr{UInt8})
                    if source == Main._CCBW_PREP_TARGET_SOURCE[]
                        Main._CCBW_PREP_TARGET_POINTER_CONVERTED[] = true
                        Main._CCBW_PREP_POISON_HITS[] |= UInt8(0x01)
                    end
                    source
                end
                function unsafe_convert(::Type{Ptr{Cvoid}}, source::Ptr{UInt8})
                    if source == Main._CCBW_PREP_TARGET_SOURCE[]
                        Main._CCBW_PREP_TARGET_POINTER_CONVERTED[] = true
                        Main._CCBW_PREP_POISON_HITS[] |= UInt8(0x02)
                    end
                    reinterpret(Ptr{Cvoid}, source)
                end
                function unsafe_convert(::Type{Ptr{Cvoid}}, source::Ptr{Cvoid})
                    if source == reinterpret(Ptr{Cvoid}, Main._CCBW_PREP_TARGET_SOURCE[])
                        Main._CCBW_PREP_TARGET_POINTER_CONVERTED[] = true
                        Main._CCBW_PREP_POISON_HITS[] |= UInt8(0x04)
                    end
                    source
                end
                function cconvert(::Type{Csize_t}, count::Int64)
                    count == Main._CCBW_PREP_TARGET_COUNT[] && Main._CCBW_PREP_TARGET_POINTER_CONVERTED[] &&
                        (Main._CCBW_PREP_POISON_HITS[] |= UInt8(0x08))
                    Csize_t(count)
                end
                function unsafe_convert(::Type{Csize_t}, count::Csize_t)
                    count == Main._CCBW_PREP_TARGET_COUNT[] && Main._CCBW_PREP_TARGET_POINTER_CONVERTED[] &&
                        (Main._CCBW_PREP_POISON_HITS[] |= UInt8(0x10))
                    count
                end
            end
            @testset "foreigncall conversion poison self-trigger" begin
                pointer_probe = Ptr{UInt8}(UInt(0x1000))
                count_probe = Int64(65537)
                _CCBW_PREP_TARGET_SOURCE[] = pointer_probe
                _CCBW_PREP_TARGET_COUNT[] = count_probe
                Base.invokelatest(Base.cconvert, Ptr{Cvoid}, pointer_probe)
                hit = _CCBW_PREP_POISON_HITS[]; _CCBW_PREP_POISON_HITS[] = 0x00
                @test hit == 0x01
                Base.invokelatest(Base.unsafe_convert, Ptr{Cvoid}, pointer_probe)
                hit = _CCBW_PREP_POISON_HITS[]; _CCBW_PREP_POISON_HITS[] = 0x00
                @test hit == 0x02
                Base.invokelatest(Base.unsafe_convert, Ptr{Cvoid}, reinterpret(Ptr{Cvoid}, pointer_probe))
                hit = _CCBW_PREP_POISON_HITS[]; _CCBW_PREP_POISON_HITS[] = 0x00
                @test hit == 0x04
                _CCBW_PREP_TARGET_POINTER_CONVERTED[] = true
                Base.invokelatest(Base.cconvert, Csize_t, count_probe)
                hit = _CCBW_PREP_POISON_HITS[]; _CCBW_PREP_POISON_HITS[] = 0x00
                @test hit == 0x08
                Base.invokelatest(Base.unsafe_convert, Csize_t, Csize_t(count_probe))
                hit = _CCBW_PREP_POISON_HITS[]; _CCBW_PREP_POISON_HITS[] = 0x00
                @test hit == 0x10
                _CCBW_PREP_TARGET_POINTER_CONVERTED[] = false
            end
            _ccbw_prep_set_target!(value)
            observed = Base.invokelatest(hash_bytes, value).value
            hit = _CCBW_PREP_POISON_HITS[]
            _CCBW_PREP_POISON_HITS[] = 0x00
            @test hit == 0x00
            @test observed == expected

            empty_value = ""
            _ccbw_prep_set_target!(empty_value)
            empty_observed = Base.invokelatest(hash_bytes, empty_value).value
            empty_hit = _CCBW_PREP_POISON_HITS[]
            _CCBW_PREP_POISON_HITS[] = 0x00
            @test empty_hit == 0x00
            @test empty_observed == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        end
    end
    println("CLOSED_HASH_COPY_POISON=$mode=PASS")
end

const _CCBW_COPY_ONLY_FLAG = "--closed-hash-copy-only"
const _CCBW_POISON_PREFIX = "--closed-hash-copy-poison="
const _CCBW_POISON_ARGS = filter(x -> startswith(x, _CCBW_POISON_PREFIX), ARGS)
if _CCBW_COPY_ONLY_FLAG in ARGS || !isempty(_CCBW_POISON_ARGS)
    length(_CCBW_POISON_ARGS) <= 1 || error("only one closed hash poison mode is allowed")
    (_CCBW_COPY_ONLY_FLAG in ARGS && !isempty(_CCBW_POISON_ARGS)) && error("copy-only and poison modes are mutually exclusive")
    if _CCBW_COPY_ONLY_FLAG in ARGS
        _ccbw_prep_run_copy_only()
    else
        mode = String(split(first(_CCBW_POISON_ARGS), "=", limit=2)[2])
        mode in ("copy", "foreigncall") || error("unsupported closed hash poison mode: $mode")
        _ccbw_prep_run_copy_poison(mode)
    end
    exit(0)
end

using JSON3
using FusionConceptAI

const _MIG_U0 = UnitSignature()
const _MIG_LEN = UnitSignature((0, 1, 0, 0, 0, 0, 0))

function _mig_bounds(lo, hi; unit=_MIG_U0)
    QuantityIntervalV1(ExactFiniteIntervalV1(lo, hi, false), unit)
end
function _mig_root(site, position, input, output)
    SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site), position, input, output)
end
function _mig_values()
    cc = chart_coordinate_type_v1(); ambient = normalized_ambient_coordinate_type_v1(); metric = normalized_covariant_metric_type_v1()
    refs = Any[SpatialSupportRefV1("状态\0🚀"), ChartRefV1("é"), CoordinateFrameRefV1("é"), PhaseFieldRefV1("phase"),
        ImplicitFieldTermRefV1("implicit"), PotentialFieldRefV1("potential"), SourceFieldRefV1("source"),
        InterfaceOperatorRefV1("interface"), GeometryEvolutionRefV1("evo"), FieldParameterRefV1("param"),
        SourceBudgetRefV1("budget"), TopologyEventRefV1("topology"),
        SpatialMultiIndex3V1(typemax(Int64), typemin(Int64), -17),
        ExactSpatialVector3V1((1//3, -7//11, 13//17), UnitSignature((1, 0, -1, 0, 0, 0, 0)))]
    push!(refs, FieldParameterGeneV1(FieldParameterRefV1("linear\"x"), _MIG_U0,
        ParameterTransformSpecV1(transform_linear), _mig_bounds(-2, 4), -0.0))
    push!(refs, FieldParameterGeneV1(FieldParameterRefV1("log"), _MIG_U0,
        ParameterTransformSpecV1(transform_log), _mig_bounds(1, 100), 0.25))
    push!(refs, FieldParameterGeneV1(FieldParameterRefV1("signed"), _MIG_U0,
        ParameterTransformSpecV1(transform_signed_log, NonnegativeQuantityV1(1, _MIG_U0)), _mig_bounds(-3, 3), -0.5))
    axis1 = PeriodicAxisV1(1, NonnegativeQuantityV1(7, _MIG_U0)); axis3 = PeriodicAxisV1(3, NonnegativeQuantityV1(7, _MIG_U0))
    chart_a = CoordinateChartGeneV1(ChartRefV1("chart\"b"), CoordinateFrameRefV1("frame-b"),
        (_mig_bounds(-2, 5), _mig_bounds(-3, 4), _mig_bounds(-1, 6)), (axis3, axis1),
        _mig_root("coord-b", 2, cc, ambient), _mig_root("metric-b", 7, cc, metric))
    chart_b = CoordinateChartGeneV1(ChartRefV1("chart-a"), CoordinateFrameRefV1("frame-a"),
        (_mig_bounds(-2, 5), _mig_bounds(-3, 4), _mig_bounds(-1, 6)), (),
        _mig_root("coord-a", 2, cc, ambient), _mig_root("metric-a", 7, cc, metric))
    transition = ChartTransitionMapGeneV1(ChartRefV1("chart-a"), ChartRefV1("chart\"b"), _mig_root("transition", 9, cc, cc))
    support = SpatialSupportGeneV1(SpatialSupportRefV1("support\0"), 3,
        (CoordinateFrameRefV1("frame-b"), CoordinateFrameRefV1("frame-a")), (chart_a, chart_b), (transition,),
        NonnegativeQuantityV1(2, _MIG_LEN))
    (refs..., FieldOperatorSiteRefV1("site\0"), _mig_root("root\0", 11, cc, ambient), _mig_root("root-metric", 12, cc, metric), axis1, chart_a, transition, support)
end

@testset "G2 canonical migration fixed goldens and closed writer" begin
    # Frozen from detached baseline bc5f61da4b3ce7ecf746a304c7396e466626634a;
    # these bytes are never regenerated by the implementation under test.
    values = _mig_values()
    lines = readlines(joinpath(@__DIR__, "fixtures", "g2_migration_baseline.jsonl"))
    @test fieldcount(typeof(values)) == 24
    @test length(lines) == 48
    @test length(lines) == 2 * fieldcount(typeof(values))
    i = 1
    while i <= fieldcount(typeof(values))
        value = getfield(values, i)
        @test JSON3.read(lines[2i - 1]) !== nothing
        @test canonical_json(value) === lines[2i - 1]
        @test canonical_hash(value).value === lines[2i]
        i += 1
    end

    @testset "shared float writer fixed text and SHA" begin
        cases = ((Float64(0.0), "0.0", "8aed642bf5118b9d3c859bd4be35ecac75b6e873cce34e7b6f554b06f75550d7"),
            (Float64(-0.0), "0.0", "8aed642bf5118b9d3c859bd4be35ecac75b6e873cce34e7b6f554b06f75550d7"),
            (Float64(0.25), "0.25", "a30a043314fa89294fa2c1c989a01fbb5329e5c085a5c5a8d27317656de24ae0"),
            (nextfloat(0.0), "5.0e-324", "c5a1c1cc25110bf3657a3dd6c1a3a088d062041b703c62717011b8dca6b8f084"),
            (floatmax(Float64), "1.7976931348623157e308", "217ab4b30c6f536b285884e38da73315e3c6e694910dbbd5ae36f396b6f835bb"))
        for case in cases
            io = FusionConceptAI._ccbw_new(); FusionConceptAI._ccbw_float!(io, case[1])
            @test FusionConceptAI._ccbw_finish(io) === case[2]
            @test bytes2hex(sha256(Vector{UInt8}(codeunits(case[2])))) === case[3]
            @test FusionConceptAI._ccbw_hash_bytes(case[2]).value === case[3]
        end
    end

    @testset "fresh process broad dispatch pollution" begin
        function probe(definition, trigger)
            script = raw"""
            using FusionConceptAI
            using SHA
            const HIT = Ref(false)
            u0 = UnitSignature(); ulen = UnitSignature((0,1,0,0,0,0,0))
            cc = chart_coordinate_type_v1(); ambient = normalized_ambient_coordinate_type_v1(); metric = normalized_covariant_metric_type_v1()
            root(s,p,i,o) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(s),p,i,o)
            b(l,h; u=u0) = QuantityIntervalV1(ExactFiniteIntervalV1(l,h,false),u)
            axis = PeriodicAxisV1(1, NonnegativeQuantityV1(7,u0))
            chart = CoordinateChartGeneV1(ChartRefV1("chart"),CoordinateFrameRefV1("frame"),(b(-2,5),b(-3,4),b(-1,6)),(axis,),root("coord",2,cc,ambient),root("metric",7,cc,metric))
            chart2 = CoordinateChartGeneV1(ChartRefV1("chart2"),CoordinateFrameRefV1("other-frame"),(b(-2,5),b(-3,4),b(-1,6)),(),root("coord2",2,cc,ambient),root("metric2",7,cc,metric))
            transition = ChartTransitionMapGeneV1(ChartRefV1("chart"),ChartRefV1("chart2"),root("transition",9,cc,cc))
            support = SpatialSupportGeneV1(SpatialSupportRefV1("support"),3,(CoordinateFrameRefV1("frame"),CoordinateFrameRefV1("other-frame")),(chart,chart2), (transition,), NonnegativeQuantityV1(2,ulen))
            gene = FieldParameterGeneV1(FieldParameterRefV1("param"),u0,ParameterTransformSpecV1(transform_linear),b(-2,5),0.25)
            objects = (SpatialSupportRefV1("ref"), SpatialMultiIndex3V1(1,-2,3), ExactSpatialVector3V1((1//3,-2//5,7//11),u0), gene, root("root",1,cc,ambient), chart, transition, support)
            baseline1 = canonical_json(getfield(objects, 1)); baseline2 = canonical_hash(getfield(objects, 1)).value
            baseline3 = canonical_json(getfield(objects, 2)); baseline4 = canonical_hash(getfield(objects, 2)).value
            baseline5 = canonical_json(getfield(objects, 3)); baseline6 = canonical_hash(getfield(objects, 3)).value
            baseline7 = canonical_json(getfield(objects, 4)); baseline8 = canonical_hash(getfield(objects, 4)).value
            baseline9 = canonical_json(getfield(objects, 5)); baseline10 = canonical_hash(getfield(objects, 5)).value
            baseline11 = canonical_json(getfield(objects, 6)); baseline12 = canonical_hash(getfield(objects, 6)).value
            baseline13 = canonical_json(getfield(objects, 7)); baseline14 = canonical_hash(getfield(objects, 7)).value
            baseline15 = canonical_json(getfield(objects, 8)); baseline16 = canonical_hash(getfield(objects, 8)).value
            __DEFINITION__
            __TRIGGER__
            @assert HIT[]
            if !(baseline1 === canonical_json(getfield(objects, 1)) && baseline2 === canonical_hash(getfield(objects, 1)).value); println("MISMATCH1"); exit(3); end
            if !(baseline3 === canonical_json(getfield(objects, 2)) && baseline4 === canonical_hash(getfield(objects, 2)).value); println("MISMATCH2"); exit(3); end
            if !(baseline5 === canonical_json(getfield(objects, 3)) && baseline6 === canonical_hash(getfield(objects, 3)).value); println("MISMATCH3"); exit(3); end
            if !(baseline7 === canonical_json(getfield(objects, 4)) && baseline8 === canonical_hash(getfield(objects, 4)).value); println("MISMATCH4"); exit(3); end
            if !(baseline9 === canonical_json(getfield(objects, 5)) && baseline10 === canonical_hash(getfield(objects, 5)).value); println("MISMATCH5"); exit(3); end
            if !(baseline11 === canonical_json(getfield(objects, 6)) && baseline12 === canonical_hash(getfield(objects, 6)).value); println("MISMATCH6"); exit(3); end
            if !(baseline13 === canonical_json(getfield(objects, 7)) && baseline14 === canonical_hash(getfield(objects, 7)).value); println("MISMATCH7"); exit(3); end
            if !(baseline15 === canonical_json(getfield(objects, 8)) && baseline16 === canonical_hash(getfield(objects, 8)).value); println("MISMATCH8"); exit(3); end
            exit(0)
            """
            script = replace(script, "__DEFINITION__" => definition, "__TRIGGER__" => trigger)
            command = Cmd(`$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`; windows_hide=true)
            result = try
                run(command); true
            catch err
                showerror(stderr, err, catch_backtrace()); println(stderr); false
            end
            result || println(stderr, "FAILED migration poison: ", definition, " / ", trigger)
            result
        end
        probes = (
            ("@eval Base.print(::IOBuffer,::String)=(HIT[]=true;nothing)", "Base.print(IOBuffer(),\"x\")"),
            ("@eval Base.:*(::String,::String)=(HIT[]=true;\"x\")", "Base.:*(\"a\",\"b\")"),
            ("@eval Base.:*(::String,::String,::String...)=(HIT[]=true;\"x\")", "Base.:*(\"a\",\"b\",\"c\")"),
            ("@eval Base.string(::Int64)=(HIT[]=true;\"x\")", "string(Int64(1))"),
            ("@eval Base.join(::Tuple,::AbstractString)=(HIT[]=true;\"x\")", "Base.join((1,2),\",\")"),
            ("@eval Base.repr(::Float64)=(HIT[]=true;\"x\")", "repr(1.0)"),
            ("@eval Base.getindex(::String,::Int)=(HIT[]=true;error(\"x\"))", "try \"x\"[1] catch; end"),
            ("@eval Base.iterate(::String,::Int)=(HIT[]=true;nothing)", "Base.iterate(\"x\",1)"),
            ("@eval Base.iterate(::Tuple,::Int)=(HIT[]=true;nothing)", "Base.iterate((1,),1)"),
            ("@eval Base.getindex(::NTuple{3,Int64},::Int)=(HIT[]=true;0)", "getindex((Int64(1),Int64(2),Int64(3)),1)"),
            ("@eval Base.getindex(::Vector{UInt8},::Int)=(HIT[]=true;0)", "UInt8[1][1]"),
            ("@eval Base.iterate(::Vector{Int},::Int)=(HIT[]=true;nothing)", "Base.iterate(Int[1],1)"),
            ("@eval Base.codeunits(::String)=(HIT[]=true;UInt8[])", "Base.codeunits(\"x\")"),
            ("@eval Base.ncodeunits(::String)=(HIT[]=true;0)", "Base.ncodeunits(\"x\")"),
            ("@eval Base.bytes2hex(::Vector{UInt8})=(HIT[]=true;\"x\")", "Base.bytes2hex(UInt8[1])"),
            ("@eval SHA.sha256(::Base.CodeUnits{UInt8,String})=(HIT[]=true;UInt8[])", "SHA.sha256(codeunits(\"x\"))"),
            ("@eval Base.hash(::String,::UInt)=(HIT[]=true;UInt(0))", "Base.hash(\"x\",UInt(0))"),
            ("@eval FusionConceptAI.canonical_json(::Any)=(HIT[]=true;\"x\")", "FusionConceptAI.canonical_json(1)"),
            ("@eval FusionConceptAI.canonical_hash(::Any)=(HIT[]=true;objects[1])", "FusionConceptAI.canonical_hash(1)"),
            ("@eval FusionConceptAI.semantic_view(::Any)=(HIT[]=true;\"x\")", "FusionConceptAI.semantic_view(1)"),
            ("@eval FusionConceptAI._g2_quote(::String)=(HIT[]=true;\"x\")", "FusionConceptAI._g2_quote(\"x\")"),
            ("@eval FusionConceptAI._g25_quote(::String)=(HIT[]=true;\"x\")", "FusionConceptAI._g25_quote(\"x\")"),
        )
        for probe_case in probes
            @test probe(probe_case[1], probe_case[2])
        end
    end
end
