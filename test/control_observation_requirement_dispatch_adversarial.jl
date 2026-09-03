using Test
using FusionConceptAI

const _G31_HELPER_PATH = joinpath(@__DIR__, "control_observation_requirement_tests.jl")

@testset "G3.1 closed dispatch and fresh-process authority" begin
    helper_path_literal = repr(_G31_HELPER_PATH)
    script = string(raw"""
    using FusionConceptAI
    source = read(""", helper_path_literal, raw""", String)
    include_string(Main, first(split(source, "@testset")))
    channel = ObservationChannelRefV1("channel")
    observable = _g31_observable()
    spatial_support = _g31_support()
    sampling = NonnegativeQuantityV1(1, G31_TIME)
    latency = NonnegativeQuantityV1(0, G31_TIME)
    bandwidth = NonnegativeQuantityV1(1, G31_INV_TIME)
    measurement_range = QuantityIntervalV1(ExactFiniteIntervalV1(-2, 2, false), G31_U0)
    resolution = NonnegativeQuantityV1(1 // 20, G31_U0)
    base = ObservationChannelRequirementV1(channel, observable, spatial_support, sampling, latency,
        bandwidth, measurement_range, resolution)
    apply_node = observable.sampling_program.nodes[2]
    baseline = (canonical_json(base), canonical_hash(base), getfield(base, :observable_content_hash),
        getfield(base, :spatial_support_content_hash))

    const hits = Set{Symbol}()
    _hit(name::Symbol) = (push!(hits, name); error("poison sentinel"))
    # Public authorities may be replaced; G3 consumers must use their closed private writers.
    FusionConceptAI.canonical_json(::ObservableGeneV1) = _hit(:observable_json)
    FusionConceptAI.canonical_json(::SpatialSupportGeneV1) = _hit(:support_json)
    FusionConceptAI.canonical_hash(::ObservableGeneV1) = _hit(:observable_hash)
    FusionConceptAI.canonical_hash(::SpatialSupportGeneV1) = _hit(:support_hash)
    FusionConceptAI.semantic_view(::ObservableGeneV1) = _hit(:observable_semantic)
    FusionConceptAI.semantic_view(::SpatialSupportGeneV1) = _hit(:support_semantic)
    FusionConceptAI.semantic_view(::ObservationChannelRequirementV1) = _hit(:requirement_semantic)
    Base.:(==)(::UnitSignature, ::UnitSignature) = _hit(:unit_eq)
    Base.hash(::UnitSignature, ::UInt) = _hit(:unit_hash)
    FusionConceptAI.Digest256(::String) = _hit(:digest_ctor)
    FusionConceptAI._g31_sampling_output_type(::Any) = _hit(:wide_output)
    FusionConceptAI._g31_observable_hash(::Any) = _hit(:wide_observable_hash)
    FusionConceptAI._g31_support_hash(::Any) = _hit(:wide_support_hash)
    FusionConceptAI._g31_rational_le(::Any, ::Any) = _hit(:wide_rational_le)
    FusionConceptAI._ast_program_output_type(::ASTApplyV1) = _hit(:specific_ast_apply_output)
    FusionConceptAI._g25_write_quantity(::Base.GenericIOBuffer, ::Any) = _hit(:wide_quantity_writer)
    FusionConceptAI._g25_write_interval(::Base.GenericIOBuffer, ::Any) = _hit(:wide_interval_writer)
    FusionConceptAI._g25_write_physical_type(::Base.GenericIOBuffer, ::Any) = _hit(:wide_physical_type_writer)
    fake_type = PhysicalType(:vector_field, 1, 3, :differential, UnitSignature((1, 0, 0, 0, 0, 0, 0)))
    real_output_type = getfield(apply_node, :output_type)
    fake_units = getfield(fake_type, :units)
    Base.getproperty(::ASTApplyV1, ::Symbol) = _hit(:ast_apply_getproperty)
    Base.getproperty(::ObservableGeneV1, ::Symbol) = _hit(:observable_getproperty)
    Base.getproperty(::SpatialSupportGeneV1, ::Symbol) = _hit(:support_getproperty)
    Base.getproperty(::ObservationChannelRequirementV1, ::Symbol) = _hit(:requirement_getproperty)
    probes = ((:observable_json, () -> canonical_json(observable)),
              (:support_json, () -> canonical_json(spatial_support)),
              (:observable_hash, () -> canonical_hash(observable)),
              (:support_hash, () -> canonical_hash(spatial_support)),
              (:observable_semantic, () -> semantic_view(observable)),
              (:support_semantic, () -> semantic_view(spatial_support)),
              (:requirement_semantic, () -> semantic_view(base)),
              (:unit_eq, () -> UnitSignature() == UnitSignature()),
              (:unit_hash, () -> hash(UnitSignature())),
              (:digest_ctor, () -> Digest256(repeat("0", 64))),
              (:wide_output, () -> FusionConceptAI._g31_sampling_output_type(nothing)),
              (:wide_observable_hash, () -> FusionConceptAI._g31_observable_hash(nothing)),
              (:wide_support_hash, () -> FusionConceptAI._g31_support_hash(nothing)),
              (:wide_rational_le, () -> FusionConceptAI._g31_rational_le(nothing, nothing)),
              (:specific_ast_apply_output, () -> FusionConceptAI._ast_program_output_type(apply_node)),
              (:wide_quantity_writer, () -> FusionConceptAI._g25_write_quantity(IOBuffer(), nothing)),
              (:wide_interval_writer, () -> FusionConceptAI._g25_write_interval(IOBuffer(), nothing)),
              (:wide_physical_type_writer, () -> FusionConceptAI._g25_write_physical_type(IOBuffer(), nothing)),
              (:ast_apply_getproperty, () -> getproperty(apply_node, :output_type)),
              (:observable_getproperty, () -> getproperty(observable, :observable_ref)),
              (:support_getproperty, () -> getproperty(spatial_support, :support_ref)),
              (:requirement_getproperty, () -> getproperty(base, :channel_ref)))
    for (name, probe) in probes
        try probe() catch; end
        @assert name in hits
    end

    after = ObservationChannelRequirementV1(channel, observable, spatial_support, sampling, latency,
        bandwidth, measurement_range, resolution)
    @assert (canonical_json(after), canonical_hash(after), getfield(after, :observable_content_hash),
        getfield(after, :spatial_support_content_hash)) == baseline
    stored_type = getfield(after, :measurement_type)
    @assert getfield(stored_type, :value_kind) === getfield(real_output_type, :value_kind)
    @assert getfield(stored_type, :tensor_rank) == getfield(real_output_type, :tensor_rank)
    @assert getfield(getfield(stored_type, :units), :exponents) == getfield(getfield(real_output_type, :units), :exponents)
    @assert getfield(stored_type, :value_kind) !== getfield(fake_type, :value_kind)
    fake_range = QuantityIntervalV1(ExactFiniteIntervalV1(-2, 2, false), fake_units)
    rejected = try
        ObservationChannelRequirementV1(channel, observable, spatial_support, sampling, latency,
            bandwidth, fake_range, NonnegativeQuantityV1(1 // 20, fake_units))
        false
    catch e
        e isa ArgumentError
    end
    @assert rejected
    println("g31-closed-dispatch-ok")
    """)
    cmd = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
    @test success(pipeline(cmd, stdout=stdout, stderr=stderr))
end

@testset "G3.1 tuple and public representation authority probes" begin
    if !isdefined(@__MODULE__, :_g31_requirement)
        source = read(joinpath(@__DIR__, "control_observation_requirement_tests.jl"), String)
        include_string(Main, first(split(source, "@testset")))
    end
    req = _g31_requirement()
    @test_throws MethodError Tuple(req)
    @test canonical_json(req) isa String
    @test string(req) isa String
    @test repr(req) isa String
    @test join((req,), "") isa String
    @test codeunits(canonical_json(req)) isa Base.CodeUnits
    @test ncodeunits(canonical_json(req)) > 0
end
