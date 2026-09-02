using Test
using SHA
using FusionConceptAI

const G2SA_U = UnitSignature()
const G2SA_L = UnitSignature((0, 1, 0, 0, 0, 0, 0))

function _g2sa_bounds(lo=-1 // 1, hi=1 // 1)
    QuantityIntervalV1(ExactFiniteIntervalV1(lo, hi, false), G2SA_U)
end

@testset "G2 5.2 fresh-process ref size probe" begin
    script = raw"""
    using FusionConceptAI
    valid64 = repeat("a",64)
    invalid63 = repeat("a",63)
    invalid65 = repeat("a",65)
    uppercase64 = repeat("A",64)
    nonhex64 = repeat("g",64)
    ref_value = "nonempty"
    @eval Base.ncodeunits(::String) = 0
    @assert FieldOperatorSiteRefV1(ref_value).value === ref_value
    @assert Digest256(valid64).value === valid64
    rejects(value) = try Digest256(value); false catch err; err isa ArgumentError end
    @assert rejects(invalid63)
    @assert rejects(invalid65)
    @assert rejects(uppercase64)
    @assert rejects(nonhex64)
    @eval Base.ncodeunits(value::String) = Core.sizeof(value)
    println("g2-spatial-ref-size-closed-ok")
    """
    command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
    output = read(pipeline(ignorestatus(command), stderr=stdout), String)
    occursin("g2-spatial-ref-size-closed-ok", output) || println(output)
    @test occursin("g2-spatial-ref-size-closed-ok", output)
end

@testset "G2 5.2 fresh-process closed writer and integer probes" begin
    script = raw"""
    using FusionConceptAI
    using SHA
    u = UnitSignature()
    l = UnitSignature((0,1,0,0,0,0,0))
    cc = chart_coordinate_type_v1()
    ambient = normalized_ambient_coordinate_type_v1()
    metric = normalized_covariant_metric_type_v1()
    bounds() = QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),u)
    root(site,pos,input,output) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site),pos,input,output)
    tag = String(vcat(UInt8[0xce,0xa9,0x61,0xcc,0x81],UInt8.(0:0x1f),UInt8[0x22,0x5c]))
    chart = CoordinateChartGeneV1(ChartRefV1(tag),CoordinateFrameRefV1(tag),
        (bounds(),bounds(),bounds()),(),root(tag,typemax(Int64),cc,ambient),root("metric",1,cc,metric))
    chart2 = CoordinateChartGeneV1(ChartRefV1("other"),CoordinateFrameRefV1(tag),
        (bounds(),bounds(),bounds()),(),root("coord2",1,cc,ambient),root("metric2",1,cc,metric))
    site = FieldOperatorSiteRefV1(tag)
    axis = PeriodicAxisV1(1,NonnegativeQuantityV1(2,u))
    transition = ChartTransitionMapGeneV1(chart.chart_ref,ChartRefV1("other"),root("transition",1,cc,cc))
    support = SpatialSupportGeneV1(SpatialSupportRefV1(tag),3,(CoordinateFrameRefV1(tag),),(chart,chart2),(transition,),NonnegativeQuantityV1(1,l))
    values = Any[site,root(tag,typemax(Int64),cc,ambient),axis,chart,transition,support]
    before_json = map(canonical_json,values)
    before_hash = map(canonical_hash,values)
    expected = map(text -> bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(text)))), before_json)
    @assert occursin("Ω",before_json[1])
    @assert occursin("\\u0000",before_json[1])
    @assert occursin(String(UInt8[0x5c,0x22]),before_json[1])
    @assert occursin(String(UInt8[0x5c,0x5c]),before_json[1])

    io = IOBuffer()
    invoke(FusionConceptAI._g25_write_int64,Tuple{Base.GenericIOBuffer,Int64},io,typemin(Int64))
    @assert FusionConceptAI._g25_finish(io) == "-9223372036854775808"
    for (kind,expected_kind) in ((static_time,String(UInt8[0x22,0x73,0x74,0x61,0x74,0x69,0x63,0x5f,0x74,0x69,0x6d,0x65,0x22])),(algebraic_time,String(UInt8[0x22,0x61,0x6c,0x67,0x65,0x62,0x72,0x61,0x69,0x63,0x5f,0x74,0x69,0x6d,0x65,0x22])),(differential_time,String(UInt8[0x22,0x64,0x69,0x66,0x66,0x65,0x72,0x65,0x6e,0x74,0x69,0x61,0x6c,0x5f,0x74,0x69,0x6d,0x65,0x22])),(discrete_time,String(UInt8[0x22,0x64,0x69,0x73,0x63,0x72,0x65,0x74,0x65,0x5f,0x74,0x69,0x6d,0x65,0x22])),(event_time,String(UInt8[0x22,0x65,0x76,0x65,0x6e,0x74,0x5f,0x74,0x69,0x6d,0x65,0x22])))
        let io = IOBuffer()
            invoke(FusionConceptAI._g25_write_time_kind,Tuple{Base.GenericIOBuffer,TimeKindV1},io,kind)
            @assert FusionConceptAI._g25_finish(io) == expected_kind
        end
    end
    io = IOBuffer()
    invoke(FusionConceptAI._g25_write_int64,Tuple{Base.GenericIOBuffer,Int64},io,typemax(Int64))
    @assert FusionConceptAI._g25_finish(io) == "9223372036854775807"
    negative_interval = QuantityIntervalV1(ExactFiniteIntervalV1(-2 // 3, 1 // 2, false),u)
    negative_json = canonical_json(negative_interval)
    @assert occursin(String(UInt8[0x22,0x64,0x65,0x6e,0x6f,0x6d,0x69,0x6e,0x61,0x74,0x6f,0x72,0x22,0x3a,0x33]),negative_json)
    @assert occursin(String(UInt8[0x22,0x6e,0x75,0x6d,0x65,0x72,0x61,0x74,0x6f,0x72,0x22,0x3a,0x2d,0x32]),negative_json)
    io = IOBuffer()
    invoke(FusionConceptAI._g25_write_symbol,Tuple{Base.GenericIOBuffer,Symbol},io,Symbol("Ωá"))
    @assert FusionConceptAI._g25_finish(io) == String(UInt8[0x22,0xce,0xa9,0x61,0xcc,0x81,0x22])
    io = IOBuffer()
    invoke(FusionConceptAI._g25_write_byte,Tuple{Base.GenericIOBuffer,UInt8},io,UInt8(0))
    invoke(FusionConceptAI._g25_write_byte,Tuple{Base.GenericIOBuffer,UInt8},io,UInt8(255))
    @assert Vector{UInt8}(FusionConceptAI._g25_finish(io)) == UInt8[0,255]
    controls = String(UInt8.(0:0x1f))
    expected_control_bytes = UInt8[0x22]
    for byte in UInt8.(0:0x1f)
        if byte == 0x08
            append!(expected_control_bytes,UInt8[0x5c,0x62])
        elseif byte == 0x0c
            append!(expected_control_bytes,UInt8[0x5c,0x66])
        elseif byte == 0x0a
            append!(expected_control_bytes,UInt8[0x5c,0x6e])
        elseif byte == 0x0d
            append!(expected_control_bytes,UInt8[0x5c,0x72])
        elseif byte == 0x09
            append!(expected_control_bytes,UInt8[0x5c,0x74])
        else
            append!(expected_control_bytes,UInt8[0x5c,0x75,0x30,0x30])
            high = byte >>> 4
            low = byte & 0x0f
            append!(expected_control_bytes,UInt8[high < 0x0a ? 0x30 + high : 0x61 + high - 0x0a,
                low < 0x0a ? 0x30 + low : 0x61 + low - 0x0a])
        end
    end
    push!(expected_control_bytes,0x22)
    actual_control = FusionConceptAI._g25_quote(controls)
    @assert actual_control == String(expected_control_bytes)

    @eval Base.print(::IOBuffer, ::String) = :poison_print_string
    @eval Base.print(::IOBuffer, ::Char) = :poison_print_char
    @eval Base.:*(::String, ::String) = "poison_string_multiply"
    @eval Base.string(::Int64) = "poison_int64_string"
    @eval Base.string(::UInt8) = "poison_uint8_string"
    @eval Base.string(::UInt32) = "poison_uint32_string"
    @eval Base.numerator(::Rational{Int64}) = typemax(Int64)
    @eval Base.denominator(::Rational{Int64}) = typemax(Int64)
    @eval Base.ncodeunits(::String) = 0
    @assert print(IOBuffer(),"x") === :poison_print_string
    @assert print(IOBuffer(),'x') === :poison_print_char
    @assert "a" * "b" == "poison_string_multiply"
    @assert Base.string(Int64(1)) == "poison_int64_string"
    @assert Base.string(UInt8(1)) == "poison_uint8_string"
    @assert Base.string(UInt32(1)) == "poison_uint32_string"
    @assert numerator(1 // 2) == typemax(Int64)
    @assert denominator(1 // 2) == typemax(Int64)
    @assert ncodeunits(tag) == 0
    @assert FieldOperatorSiteRefV1(tag).value === tag
    after_json = map(canonical_json,values)
    after_hash = map(canonical_hash,values)
    @assert before_json == after_json
    @assert before_hash == after_hash
    @assert all(h.value == x for (h,x) in zip(after_hash,expected))
    @eval Base.write(::IOBuffer, ::UInt8) = :poison_iobuffer_byte_write
    @assert write(IOBuffer(),UInt8(1)) === :poison_iobuffer_byte_write
    @assert map(canonical_json,values) == before_json
    @eval Base.ncodeunits(value::String) = Core.sizeof(value)
    println("g2-spatial-writer-closed-ok")
    """
    command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
    output = read(pipeline(ignorestatus(command), stderr=stdout), String)
    occursin("g2-spatial-writer-closed-ok", output) || println(output)
    @test occursin("g2-spatial-writer-closed-ok", output)
end

@testset "G2 5.2 real Base.iterate regression probes" begin
    @testset "dimensionless half-length cannot be hidden by tuple iteration" begin
        script = raw"""
        using FusionConceptAI
        half = UnitSignature((0//1,1//2,0//1,0//1,0//1,0//1,0//1))
        period = NonnegativeQuantityV1(2, half)
        @eval Base.iterate(x::NTuple{7,Rational{Int64}}) = (x[1], 8)
        @eval Base.iterate(x::NTuple{7,Rational{Int64}}, ::Int) = nothing
        @assert Base.iterate(half.exponents) == (half.exponents[1], 8)
        @assert Base.iterate(half.exponents, 8) === nothing
        rejected = try PeriodicAxisV1(1, period); false catch err; err isa ArgumentError end
        @assert rejected
        println("g2-spatial-iterate-axis-ok")
        """
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
        output = read(pipeline(ignorestatus(command), stderr=stdout), String)
        occursin("g2-spatial-iterate-axis-ok", output) || println(output)
        @test occursin("g2-spatial-iterate-axis-ok", output)
    end

    @testset "conflicting root signature cannot be hidden by vector iteration" begin
        script = raw"""
        using FusionConceptAI
        u = UnitSignature(); l = UnitSignature((0,1,0,0,0,0,0))
        b() = QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),u)
        cc, ambient, metric = chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1(), normalized_covariant_metric_type_v1()
        root(site,pos,input,output) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site),pos,input,output)
        coordinate = root("same",1,cc,ambient); metric_root = root("same",1,cc,metric)
        chart = CoordinateChartGeneV1(ChartRefV1("chart"),CoordinateFrameRefV1("frame"),(b(),b(),b()),(),coordinate,metric_root)
        frames = (CoordinateFrameRefV1("frame"),); charts = (chart,)
        roots = SpatialProgramRootRefV1[coordinate,metric_root]
        @eval Base.iterate(x::Vector{SpatialProgramRootRefV1}) = (x[1], 2)
        @eval Base.iterate(::Vector{SpatialProgramRootRefV1}, ::Int) = nothing
        @assert Base.iterate(roots) == (roots[1], 2)
        @assert Base.iterate(roots, 2) === nothing
        rejected = try SpatialSupportGeneV1(SpatialSupportRefV1("support"),3,frames,charts,(),NonnegativeQuantityV1(1,l)); false catch err; err isa ArgumentError end
        @assert rejected
        println("g2-spatial-iterate-roots-ok")
        """
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
        output = read(pipeline(ignorestatus(command), stderr=stdout), String)
        occursin("g2-spatial-iterate-roots-ok", output) || println(output)
        @test occursin("g2-spatial-iterate-roots-ok", output)
    end

    @testset "frame tuple iteration cannot alter canonical bytes or hash" begin
        script = raw"""
        using FusionConceptAI
        u = UnitSignature(); l = UnitSignature((0,1,0,0,0,0,0))
        b() = QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),u)
        cc, ambient, metric = chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1(), normalized_covariant_metric_type_v1()
        root(site,pos,input,output) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site),pos,input,output)
        chart(name,frame) = CoordinateChartGeneV1(ChartRefV1(name),CoordinateFrameRefV1(frame),(b(),b(),b()),(),root("coord-"*name,1,cc,ambient),root("metric-"*name,1,cc,metric))
        frames = (CoordinateFrameRefV1("frame-a"),CoordinateFrameRefV1("frame-b"))
        charts = (chart("a","frame-a"),chart("b","frame-b"))
        support = SpatialSupportGeneV1(SpatialSupportRefV1("support"),3,frames,charts,(),NonnegativeQuantityV1(1,l))
        before_json, before_hash = canonical_json(support), canonical_hash(support)
        @eval Base.iterate(x::Tuple{CoordinateFrameRefV1,CoordinateFrameRefV1}) = (x[1], 2)
        @eval Base.iterate(::Tuple{CoordinateFrameRefV1,CoordinateFrameRefV1}, ::Int) = nothing
        @assert Base.iterate(frames) == (frames[1], 2)
        @assert Base.iterate(frames, 2) === nothing
        @assert canonical_json(support) == before_json
        @assert canonical_hash(support) == before_hash
        println("g2-spatial-iterate-frames-ok")
        """
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
        output = read(pipeline(ignorestatus(command), stderr=stdout), String)
        occursin("g2-spatial-iterate-frames-ok", output) || println(output)
        @test occursin("g2-spatial-iterate-frames-ok", output)
    end
end

@testset "G2 5.2 real Base.getindex regression probes" begin
    @testset "tuple signature indexing cannot hide a conflicting root" begin
        script = raw"""
        using FusionConceptAI
        u = UnitSignature(); l = UnitSignature((0,1,0,0,0,0,0))
        b() = QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),u)
        cc, ambient, metric = chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1(), normalized_covariant_metric_type_v1()
        root(site,pos,input,output) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site),pos,input,output)
        coordinate = root("same",1,cc,ambient); metric_root = root("same",1,cc,metric)
        chart = CoordinateChartGeneV1(ChartRefV1("chart"),CoordinateFrameRefV1("frame"),(b(),b(),b()),(),coordinate,metric_root)
        frames = (CoordinateFrameRefV1("frame"),); charts = (chart,)
        probe = Vector{Tuple{String,Int64,Any}}([("clean",Int64(1),nothing)])
        @eval Base.getindex(v::Vector{Tuple{String,Int64,Any}}, i::Int) = ("poison",Int64(0),nothing)
        @assert getindex(probe,1) == ("poison",Int64(0),nothing)
        rejected = try SpatialSupportGeneV1(SpatialSupportRefV1("support"),3,frames,charts,(),NonnegativeQuantityV1(1,l)); false catch err; err isa ArgumentError end
        @assert rejected
        println("g2-spatial-getindex-roots-ok")
        """
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
        output = read(pipeline(ignorestatus(command), stderr=stdout), String)
        occursin("g2-spatial-getindex-roots-ok", output) || println(output)
        @test occursin("g2-spatial-getindex-roots-ok", output)
    end

    @testset "general and periodic sorting cannot be poisoned" begin
        script = raw"""
        using FusionConceptAI
        u = UnitSignature(); l = UnitSignature((0,1,0,0,0,0,0))
        b() = QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),u)
        cc, ambient, metric = chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1(), normalized_covariant_metric_type_v1()
        root(site,pos,input,output) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site),pos,input,output)
        chart(name,frame) = CoordinateChartGeneV1(ChartRefV1(name),CoordinateFrameRefV1(frame),(b(),b(),b()),(),root("coord-"*name,1,cc,ambient),root("metric-"*name,1,cc,metric))
        frames = (CoordinateFrameRefV1("frame-b"),CoordinateFrameRefV1("frame-a"))
        charts = (chart("b","frame-b"),chart("a","frame-a"))
        support = SpatialSupportGeneV1(SpatialSupportRefV1("support"),3,frames,charts,(),NonnegativeQuantityV1(1,l))
        before_json, before_hash = canonical_json(support), canonical_hash(support)
        @eval Base.getindex(v::Vector{Any}, i::Int) = Core.arrayref(true,v,1)
        probe = Any["first","second"]
        @assert getindex(probe,2) == "first"
        @assert length(support.coordinate_frame_refs) == 2
        @assert length(support.charts) == 2
        @assert support.coordinate_frame_refs[1].value != support.coordinate_frame_refs[2].value
        @assert support.charts[1].chart_ref.value != support.charts[2].chart_ref.value
        @assert canonical_json(support) == before_json
        @assert canonical_hash(support) == before_hash

        # The periodic-axis sorter has a separately typed work buffer.
        periodic = (PeriodicAxisV1(2,NonnegativeQuantityV1(2,u)),PeriodicAxisV1(1,NonnegativeQuantityV1(2,u)))
        @eval Base.getindex(v::Vector{PeriodicAxisV1}, i::Int) = Core.arrayref(true,v,1)
        axis_probe = PeriodicAxisV1[periodic[1],periodic[2]]
        @assert getindex(axis_probe,2) === axis_probe[1]
        periodic_chart = CoordinateChartGeneV1(ChartRefV1("periodic"),CoordinateFrameRefV1("frame-a"),(b(),b(),b()),periodic,root("periodic-coord",1,cc,ambient),root("periodic-metric",1,cc,metric))
        @assert periodic_chart.periodic_axes[1].axis_position === 1
        @assert periodic_chart.periodic_axes[2].axis_position === 2
        println("g2-spatial-getindex-sorting-ok")
        """
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
        output = read(pipeline(ignorestatus(command), stderr=stdout), String)
        occursin("g2-spatial-getindex-sorting-ok", output) || println(output)
        @test occursin("g2-spatial-getindex-sorting-ok", output)
    end
end

@testset "G2 5.2 fresh-process SHA dispatch probe" begin
    script = raw"""
    using FusionConceptAI
    using SHA
    u = UnitSignature()
    l = UnitSignature((0,1,0,0,0,0,0))
    bounds() = QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),u)
    root(site, pos, input, output) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site),pos,input,output)
    cc, ambient, metric = chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1(), normalized_covariant_metric_type_v1()
    chart = CoordinateChartGeneV1(ChartRefV1("chart"),CoordinateFrameRefV1("frame"),(bounds(),bounds(),bounds()),(),root("coord",1,cc,ambient),root("metric",1,cc,metric))
    site = FieldOperatorSiteRefV1("site")
    periodic = PeriodicAxisV1(1,NonnegativeQuantityV1(2,u))
    transition = ChartTransitionMapGeneV1(chart.chart_ref,ChartRefV1("other"),root("transition",1,cc,cc))
    support = SpatialSupportGeneV1(SpatialSupportRefV1("support"),3,(CoordinateFrameRefV1("frame"),),(chart,),(),NonnegativeQuantityV1(1,l))
    values = Any[site,root("transition",1,cc,cc),periodic,chart,transition,support]
    before_json = map(canonical_json,values)
    before_hash = map(canonical_hash,values)
    expected = map(text -> bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(text)))), before_json)
    @eval SHA.sha256(::Base.CodeUnits{UInt8,String}) = fill(UInt8(0),32)
    @assert SHA.sha256(codeunits("probe")) == fill(UInt8(0),32)
    after_hash = map(canonical_hash,values)
    @assert all(a.value == b.value for (a,b) in zip(after_hash,before_hash))
    @assert all(a.value == b for (a,b) in zip(after_hash,expected))
    @assert all(a.value != repeat("0",64) for a in after_hash)
    println("g2-spatial-sha-closed-ok")
    """
    command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
    output = read(pipeline(ignorestatus(command), stderr=stdout), String)
    occursin("g2-spatial-sha-closed-ok", output) || println(output)
    @test occursin("g2-spatial-sha-closed-ok", output)
end

@testset "G2 5.2 fresh-process string dispatch probes" begin
    @testset "String indexing cannot alter escaping or hashes" begin
        script = raw"""
        using FusionConceptAI
        using SHA
        u = UnitSignature(); l = UnitSignature((0,1,0,0,0,0,0))
        tag = "Ωá\0"
        bounds() = QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),u)
        root(site, pos, input, output) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site),pos,input,output)
        cc, ambient, metric = chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1(), normalized_covariant_metric_type_v1()
        chart_ref = ChartRefV1(tag*"chart")
        frame_ref = CoordinateFrameRefV1(tag*"frame")
        chart = CoordinateChartGeneV1(chart_ref,frame_ref,(bounds(),bounds(),bounds()),(),root(tag*"coord",1,cc,ambient),root(tag*"metric",1,cc,metric))
        site = FieldOperatorSiteRefV1(tag*"site")
        periodic = PeriodicAxisV1(1,NonnegativeQuantityV1(2,u))
        transition = ChartTransitionMapGeneV1(chart_ref,ChartRefV1(tag*"other"),root(tag*"transition",1,cc,cc))
        support = SpatialSupportGeneV1(SpatialSupportRefV1(tag*"support"),3,(frame_ref,),(chart,),(),NonnegativeQuantityV1(1,l))
        values = Any[site,root(tag*"root",1,cc,cc),periodic,chart,transition,support]
        before_json = map(canonical_json,values)
        before_hash = map(canonical_hash,values)
        expected = map(text -> bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(text)))), before_json)
        @assert any(occursin("\\u0000", text) for text in before_json)
        @assert any(occursin("Ω", text) for text in before_json)
        @eval Base.getindex(::String, ::Int) = '\0'
        @assert getindex("probe",1) == '\0'
        after_json = map(canonical_json,values)
        after_hash = map(canonical_hash,values)
        @assert before_json == after_json
        @assert all(a.value == b for (a,b) in zip(after_hash,expected))
        @assert all(a.value == b.value for (a,b) in zip(after_hash,before_hash))
        println("g2-spatial-string-index-closed-ok")
        """
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
        output = read(pipeline(ignorestatus(command), stderr=stdout), String)
        occursin("g2-spatial-string-index-closed-ok", output) || println(output)
        @test occursin("g2-spatial-string-index-closed-ok", output)
    end

    @testset "String codeunits cannot alter canonical JSON or hashes" begin
        script = raw"""
        using FusionConceptAI
        using SHA
        u = UnitSignature(); l = UnitSignature((0,1,0,0,0,0,0))
        tag = "Ωá\0"
        bounds() = QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),u)
        root(site, pos, input, output) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site),pos,input,output)
        cc, ambient, metric = chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1(), normalized_covariant_metric_type_v1()
        chart_ref = ChartRefV1(tag*"chart")
        frame_ref = CoordinateFrameRefV1(tag*"frame")
        chart = CoordinateChartGeneV1(chart_ref,frame_ref,(bounds(),bounds(),bounds()),(),root(tag*"coord",1,cc,ambient),root(tag*"metric",1,cc,metric))
        site = FieldOperatorSiteRefV1(tag*"site")
        periodic = PeriodicAxisV1(1,NonnegativeQuantityV1(2,u))
        transition = ChartTransitionMapGeneV1(chart_ref,ChartRefV1(tag*"other"),root(tag*"transition",1,cc,cc))
        support = SpatialSupportGeneV1(SpatialSupportRefV1(tag*"support"),3,(frame_ref,),(chart,),(),NonnegativeQuantityV1(1,l))
        values = Any[site,root(tag*"root",1,cc,cc),periodic,chart,transition,support]
        before_json = map(canonical_json,values)
        before_hash = map(canonical_hash,values)
        expected = map(text -> bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(text)))), before_json)
        @assert any(occursin("\\u0000", text) for text in before_json)
        @eval Base.codeunits(::String) = UInt8[0xde,0xad]
        @assert codeunits("probe") == UInt8[0xde,0xad]
        after_json = map(canonical_json,values)
        after_hash = map(canonical_hash,values)
        @assert before_json == after_json
        @assert all(a.value == b for (a,b) in zip(after_hash,expected))
        @assert all(a.value == b.value for (a,b) in zip(after_hash,before_hash))
        println("g2-spatial-codeunits-closed-ok")
        """
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
        output = read(pipeline(ignorestatus(command), stderr=stdout), String)
        occursin("g2-spatial-codeunits-closed-ok", output) || println(output)
        @test occursin("g2-spatial-codeunits-closed-ok", output)
    end

    @testset "bytes2hex cannot replace independent SHA output" begin
        script = raw"""
        using FusionConceptAI
        using SHA
        u = UnitSignature(); l = UnitSignature((0,1,0,0,0,0,0))
        tag = "Ωá\0"
        bounds() = QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),u)
        root(site, pos, input, output) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site),pos,input,output)
        cc, ambient, metric = chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1(), normalized_covariant_metric_type_v1()
        chart_ref = ChartRefV1(tag*"chart")
        frame_ref = CoordinateFrameRefV1(tag*"frame")
        chart = CoordinateChartGeneV1(chart_ref,frame_ref,(bounds(),bounds(),bounds()),(),root(tag*"coord",1,cc,ambient),root(tag*"metric",1,cc,metric))
        site = FieldOperatorSiteRefV1(tag*"site")
        periodic = PeriodicAxisV1(1,NonnegativeQuantityV1(2,u))
        transition = ChartTransitionMapGeneV1(chart_ref,ChartRefV1(tag*"other"),root(tag*"transition",1,cc,cc))
        support = SpatialSupportGeneV1(SpatialSupportRefV1(tag*"support"),3,(frame_ref,),(chart,),(),NonnegativeQuantityV1(1,l))
        values = Any[site,root(tag*"root",1,cc,cc),periodic,chart,transition,support]
        before_json = map(canonical_json,values)
        before_hash = map(canonical_hash,values)
        expected = map(text -> bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(text)))), before_json)
        @assert any(occursin("\\u0000", text) for text in before_json)
        @eval Base.bytes2hex(::Vector{UInt8}) = repeat("0",64)
        @assert Base.bytes2hex(UInt8[1,2,3]) == repeat("0",64)
        after_hash = map(canonical_hash,values)
        @assert all(a.value == b for (a,b) in zip(after_hash,expected))
        @assert all(a.value == b.value for (a,b) in zip(after_hash,before_hash))
        @assert all(a.value != repeat("0",64) for a in after_hash)
        println("g2-spatial-bytes2hex-closed-ok")
        """
        command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
        output = read(pipeline(ignorestatus(command), stderr=stdout), String)
        occursin("g2-spatial-bytes2hex-closed-ok", output) || println(output)
        @test occursin("g2-spatial-bytes2hex-closed-ok", output)
    end
end

function _g2sa_root(site, position, input, output)
    SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site), position, input, output)
end

function _g2sa_chart(name, frame)
    cc = chart_coordinate_type_v1()
    ambient = normalized_ambient_coordinate_type_v1()
    metric = normalized_covariant_metric_type_v1()
    CoordinateChartGeneV1(ChartRefV1(name), CoordinateFrameRefV1(frame),
        (_g2sa_bounds(), _g2sa_bounds(), _g2sa_bounds()), (),
        _g2sa_root("coord", 1, cc, ambient), _g2sa_root("metric", 1, cc, metric))
end

function _g2sa_values()
    cc = chart_coordinate_type_v1()
    chart = _g2sa_chart("chart", "frame")
    site = FieldOperatorSiteRefV1("site")
    root = _g2sa_root("transition", 1, cc, cc)
    transition = ChartTransitionMapGeneV1(chart.chart_ref, ChartRefV1("other"), root)
    support = SpatialSupportGeneV1(SpatialSupportRefV1("support"), 3,
        (CoordinateFrameRefV1("frame"),), (chart,), (), NonnegativeQuantityV1(1, G2SA_L))
    Any[site, root, PeriodicAxisV1(1, NonnegativeQuantityV1(2, G2SA_U)), chart, transition, support]
end

function _g2sa_hex(text)
    bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(text))))
end

@testset "G2 5.2 fresh-process adversarial dispatch closure" begin
    script = raw"""
    using FusionConceptAI
    using SHA
    u = UnitSignature()
    l = UnitSignature((0,1,0,0,0,0,0))
    bounds() = QuantityIntervalV1(ExactFiniteIntervalV1(-1,1,false),u)
    root(site, pos, input, output) = SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site),pos,input,output)
    cc, ambient, metric = chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1(), normalized_covariant_metric_type_v1()
    chart = CoordinateChartGeneV1(ChartRefV1("chart"),CoordinateFrameRefV1("frame"),(bounds(),bounds(),bounds()),(),root("coord",1,cc,ambient),root("metric",1,cc,metric))
    site = FieldOperatorSiteRefV1("site")
    periodic = PeriodicAxisV1(1,NonnegativeQuantityV1(2,u))
    transition = ChartTransitionMapGeneV1(chart.chart_ref,ChartRefV1("other"),root("transition",1,cc,cc))
    support = SpatialSupportGeneV1(SpatialSupportRefV1("support"),3,(CoordinateFrameRefV1("frame"),),(chart,),(),NonnegativeQuantityV1(1,l))
    values = Any[site,root("transition",1,cc,cc),periodic,chart,transition,support]
    before_json = map(canonical_json,values)
    before_hash = map(canonical_hash,values)
    expected = map(text -> bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(text)))), before_json)

    # Broad or less-specific ambient additions must not replace closed exact
    # helper dispatches; semantic_view and Base equality/hash are display-only.
    @eval FusionConceptAI._g25_ref_text(::String, ::AbstractString) = error("poison ref")
    @eval FusionConceptAI._g25_signed_int64(::Integer, ::AbstractString) = error("poison integer")
    @eval FusionConceptAI._g25_unit(::Any) = error("poison unit")
    @eval FusionConceptAI._g25_type_key(::Any) = error("poison type")
    @eval FusionConceptAI._g25_root_key(::Any) = error("poison root key")
    @eval FusionConceptAI._g25_sorted(::Tuple, ::Any) = error("poison sort")
    @eval FusionConceptAI._g25_quote(::AbstractString) = error("poison quote")
    @eval FusionConceptAI._g25_hash_bytes(::AbstractString) = error("poison hash")
    @eval FusionConceptAI.semantic_view(::Any) = (poison=true,)
    @eval FusionConceptAI.chart_coordinate_type_v1(::Any) = error("poison factory")
    @eval FusionConceptAI.normalized_ambient_coordinate_type_v1(::Any) = error("poison factory")
    @eval FusionConceptAI.normalized_covariant_metric_type_v1(::Any) = error("poison factory")
    @eval Base.:(==)(::CoordinateChartGeneV1, ::Any) = false
    @eval Base.hash(::SpatialSupportGeneV1, ::Any) = UInt(0)
    @eval FusionConceptAI.Digest256(::String) = invoke(FusionConceptAI.Digest256, Tuple{AbstractString}, repeat("0",64))
    @assert Digest256("probe").value == repeat("0",64)

    after_json = map(canonical_json,values)
    after_hash = map(canonical_hash,values)
    @assert before_json == after_json
    @assert before_hash == after_hash
    @assert all(h.value == x for (h,x) in zip(after_hash,expected))
    @assert all(h.value != repeat("0",64) for h in after_hash)
    bad_ref = try FieldOperatorSiteRefV1(""); false catch err; err isa ArgumentError end
    @assert bad_ref
    bad_support = try SpatialSupportGeneV1(SpatialSupportRefV1("bad"),2,(CoordinateFrameRefV1("frame"),),(chart,),(),NonnegativeQuantityV1(1,l)); false catch err; err isa ArgumentError end
    @assert bad_support
    println("g2-spatial-dispatch-closed-ok")
    """
    command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
    output = read(pipeline(ignorestatus(command), stderr=stdout), String)
    occursin("g2-spatial-dispatch-closed-ok", output) || println(output)
    @test occursin("g2-spatial-dispatch-closed-ok", output)
end
