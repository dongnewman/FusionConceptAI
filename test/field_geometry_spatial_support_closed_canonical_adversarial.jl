using Test
using FusionConceptAI

const _G2SC_HELPER_PATH = joinpath(@__DIR__, "field_geometry_spatial_support_closed_canonical_tests.jl")

function _g2sc_run_child(label::String, body::String)
    helper_path_literal = repr(_G2SC_HELPER_PATH)
    script = string(raw"""
    using FusionConceptAI
    source = read(""", helper_path_literal, raw""", String)
    include_string(Main, first(split(source, "@testset")))
    support = _g2sc_support()
    before = _g2sc_private_pair(support)
    const hits = Set{Symbol}()
    _hit(name::Symbol) = (push!(hits, name); error("poison sentinel"))
    """, body, "\nprintln(\"g2sc-child-ok-", label, "\")\n")
    command = `$(Base.julia_cmd()) --startup-file=no --project=$(Base.active_project()) -e $script`
    read(pipeline(ignorestatus(command), stderr=stdout), String)
end

function _g2sc_assert_child(label, body)
    output = _g2sc_run_child(label, body)
    @test occursin("g2sc-child-ok-" * label, output)
    output
end

@testset "G2 5.2 public spatial-support authority poison" begin
    body = raw"""
    FusionConceptAI.canonical_json(::SpatialSupportGeneV1) = _hit(:public_json)
    FusionConceptAI.canonical_hash(::SpatialSupportGeneV1) = _hit(:public_hash)
    FusionConceptAI.semantic_view(::SpatialSupportGeneV1) = _hit(:public_semantic)
    Base.:(==)(::SpatialSupportGeneV1, ::SpatialSupportGeneV1) = _hit(:public_eq)
    Base.hash(::SpatialSupportGeneV1, ::UInt) = _hit(:public_hash_method)
    for (name, action) in ((:public_json, () -> canonical_json(support)),
                           (:public_hash, () -> canonical_hash(support)),
                           (:public_semantic, () -> semantic_view(support)),
                           (:public_eq, () -> support == support),
                           (:public_hash_method, () -> hash(support, UInt(0))))
        try action() catch; end
        @assert name in hits
    end
    @assert _g2sc_private_pair(support) == before
    """
    _g2sc_assert_child("public", body)
end

const _G2SC_NESTED_POISONS = (
    ("support_gene", "SpatialSupportGeneV1", "support"),
    ("support_ref", "SpatialSupportRefV1", "getfield(support, :support_ref)"),
    ("frame_ref", "CoordinateFrameRefV1", "getfield(getfield(support, :coordinate_frame_refs), 1)"),
    ("site_ref", "FieldOperatorSiteRefV1", "getfield(getfield(getfield(support, :charts), 1).coordinate_map_root, :operator_site_ref)"),
    ("root", "SpatialProgramRootRefV1", "getfield(getfield(support, :charts), 1).coordinate_map_root"),
    ("axis", "PeriodicAxisV1", "getfield(getfield(getfield(support, :charts), 2), :periodic_axes)[1]"),
    ("chart", "CoordinateChartGeneV1", "getfield(getfield(support, :charts), 1)"),
    ("transition", "ChartTransitionMapGeneV1", "getfield(getfield(support, :chart_transition_maps), 1)"),
    ("physical_type", "PhysicalType", "getfield(getfield(getfield(support, :charts), 1).coordinate_map_root, :declared_type)"),
    ("temporal_type", "TemporalTypeV1", "getfield(getfield(getfield(getfield(support, :charts), 1).coordinate_map_root, :declared_type), :temporal_type)"),
    ("unit", "UnitSignature", "getfield(getfield(getfield(getfield(support, :charts), 1).coordinate_map_root, :declared_type), :units)"),
    ("quantity", "NonnegativeQuantityV1", "getfield(getfield(getfield(support, :charts), 2).periodic_axes, 1).period"),
    ("interval", "QuantityIntervalV1", "getfield(getfield(getfield(support, :charts), 1), :chart_bounds)[1]"),
    ("finite_interval", "ExactFiniteIntervalV1", "getfield(getfield(getfield(getfield(support, :charts), 1), :chart_bounds)[1], :interval)"),
    ("chart_ref", "ChartRefV1", "getfield(getfield(support, :charts), 1).chart_ref"),
)

# QualifiedRefV1 is intentionally unreachable in a valid support graph: all
# admitted spatial roots require the static-time physical-type signatures.

@testset "G2 5.2 nested getproperty poison isolation" begin
    for (label, type_name, expression) in _G2SC_NESTED_POISONS
        poison = string("Base.getproperty(::", type_name, ", ::Symbol) = _hit(:", label, ")\n",
                        "nested = ", expression, "\n",
                        "try getproperty(nested, :value) catch; end\n",
                        "@assert :", label, " in hits\n",
                        "@assert _g2sc_private_pair(support) == before")
        output = _g2sc_run_child(label, poison)
        @test occursin("g2sc-child-ok-" * label, output)
    end
end

@testset "G2 5.2 wider helper and digest poison isolation" begin
    body = raw"""
    FusionConceptAI._g25_write_support_wire(::Base.GenericIOBuffer, ::Any) = _hit(:wide_support_wire)
    FusionConceptAI._g25_support_json(::Any) = _hit(:wide_support_json)
    FusionConceptAI._g25_write_wrap_start(::Base.GenericIOBuffer, ::Any, ::Any) = _hit(:wide_wrap_start)
    FusionConceptAI._g25_write_wrap_end(::IOBuffer) = _hit(:specific_wrap_end)
    FusionConceptAI._g25_write_transition_wire(::Base.GenericIOBuffer, ::Any) = _hit(:wide_transition_wire)
    FusionConceptAI._g25_write_chart_wire(::Base.GenericIOBuffer, ::Any) = _hit(:wide_chart_wire)
    FusionConceptAI._g25_write_root_wire(::Base.GenericIOBuffer, ::Any) = _hit(:wide_root_wire)
    FusionConceptAI._g25_write_axis_wire(::Base.GenericIOBuffer, ::Any) = _hit(:wide_axis_wire)
    FusionConceptAI._g25_write_quantity(::Base.GenericIOBuffer, ::Any) = _hit(:wide_quantity)
    FusionConceptAI._g25_write_interval(::Base.GenericIOBuffer, ::Any) = _hit(:wide_interval)
    FusionConceptAI._g25_write_physical_type(::Base.GenericIOBuffer, ::Any) = _hit(:wide_physical)
    FusionConceptAI._g25_write_temporal(::Base.GenericIOBuffer, ::Any) = _hit(:wide_temporal)
    FusionConceptAI._g25_write_time_kind(::Base.GenericIOBuffer, ::Any) = _hit(:wide_time_kind)
    FusionConceptAI._g25_write_symbol(::Base.GenericIOBuffer, ::Any) = _hit(:wide_symbol)
    FusionConceptAI._g25_write_unit(::Base.GenericIOBuffer, ::Any) = _hit(:wide_unit)
    FusionConceptAI._g25_write_rational(::Base.GenericIOBuffer, ::Rational) = _hit(:wide_rational)
    FusionConceptAI._g25_write_ref_wire(::Base.GenericIOBuffer, ::AbstractString, ::AbstractString, ::AbstractString) = _hit(:wide_ref_wire)
    FusionConceptAI._g25_write_quoted(::Base.GenericIOBuffer, ::AbstractString) = _hit(:wide_quoted)
    FusionConceptAI._g25_write_ascii(::Base.GenericIOBuffer, ::AbstractString) = _hit(:wide_ascii)
    FusionConceptAI._g25_write_int64(::Base.GenericIOBuffer, ::Integer) = _hit(:wide_int64)
    FusionConceptAI._g25_write_uint64(::Base.GenericIOBuffer, ::Integer) = _hit(:wide_uint64)
    FusionConceptAI._g25_write_byte(::Base.GenericIOBuffer, ::Integer) = _hit(:wide_byte)
    FusionConceptAI._g25_write_hex2(::Base.GenericIOBuffer, ::Integer) = _hit(:wide_hex2)
    FusionConceptAI._g25_finish(::IOBuffer) = _hit(:specific_iobuffer_finish)
    FusionConceptAI._g25_type_key(::Any) = _hit(:wide_type_key)
    FusionConceptAI._g25_chart_structural_key(::Any) = _hit(:wide_chart_key)
    FusionConceptAI._g25_support_canonical_hash(::Any) = _hit(:wide_support_hash)
    FusionConceptAI.canonical_hash(::Tuple) = _hit(:specific_tuple_hash)
    sub = SubString("x", 1, 1)
    probes = ((:wide_support_wire, () -> FusionConceptAI._g25_write_support_wire(IOBuffer(), nothing)),
              (:wide_support_json, () -> FusionConceptAI._g25_support_json(nothing)),
              (:wide_wrap_start, () -> FusionConceptAI._g25_write_wrap_start(IOBuffer(), nothing, nothing)),
              (:specific_wrap_end, () -> FusionConceptAI._g25_write_wrap_end(IOBuffer())),
              (:wide_transition_wire, () -> FusionConceptAI._g25_write_transition_wire(IOBuffer(), nothing)),
              (:wide_chart_wire, () -> FusionConceptAI._g25_write_chart_wire(IOBuffer(), nothing)),
              (:wide_root_wire, () -> FusionConceptAI._g25_write_root_wire(IOBuffer(), nothing)),
              (:wide_axis_wire, () -> FusionConceptAI._g25_write_axis_wire(IOBuffer(), nothing)),
              (:wide_quantity, () -> FusionConceptAI._g25_write_quantity(IOBuffer(), nothing)),
              (:wide_interval, () -> FusionConceptAI._g25_write_interval(IOBuffer(), nothing)),
              (:wide_physical, () -> FusionConceptAI._g25_write_physical_type(IOBuffer(), nothing)),
              (:wide_temporal, () -> FusionConceptAI._g25_write_temporal(IOBuffer(), nothing)),
              (:wide_time_kind, () -> FusionConceptAI._g25_write_time_kind(IOBuffer(), nothing)),
              (:wide_symbol, () -> FusionConceptAI._g25_write_symbol(IOBuffer(), nothing)),
              (:wide_unit, () -> FusionConceptAI._g25_write_unit(IOBuffer(), nothing)),
              (:wide_rational, () -> FusionConceptAI._g25_write_rational(IOBuffer(), Rational{Int32}(Int32(1), Int32(2)))),
              (:wide_ref_wire, () -> FusionConceptAI._g25_write_ref_wire(IOBuffer(), sub, sub, sub)),
              (:wide_quoted, () -> FusionConceptAI._g25_write_quoted(IOBuffer(), sub)),
              (:wide_ascii, () -> FusionConceptAI._g25_write_ascii(IOBuffer(), sub)),
              (:wide_int64, () -> FusionConceptAI._g25_write_int64(IOBuffer(), Int32(1))),
              (:wide_uint64, () -> FusionConceptAI._g25_write_uint64(IOBuffer(), Int32(1))),
              (:wide_byte, () -> FusionConceptAI._g25_write_byte(IOBuffer(), 1)),
              (:wide_hex2, () -> FusionConceptAI._g25_write_hex2(IOBuffer(), 1)),
              (:specific_iobuffer_finish, () -> FusionConceptAI._g25_finish(IOBuffer())),
              (:wide_type_key, () -> FusionConceptAI._g25_type_key(nothing)),
              (:wide_chart_key, () -> FusionConceptAI._g25_chart_structural_key(nothing)),
              (:wide_support_hash, () -> FusionConceptAI._g25_support_canonical_hash(nothing)),
              (:specific_tuple_hash, () -> canonical_hash((1,))))
    for (name, action) in probes
        try action() catch; end
        @assert name in hits "missing helper sentinel: $(name), hits=$(hits)"
    end
    @assert _g2sc_private_pair(support) == before
    """
    _g2sc_assert_child("helpers", body)

    body = raw"""
    FusionConceptAI.Digest256(::String) = _hit(:digest_string)
    FusionConceptAI.canonical_hash(::SpatialSupportGeneV1) = _hit(:public_hash)
    FusionConceptAI._g25_hash_bytes(::AbstractString) = _hit(:wide_hash_bytes)
    FusionConceptAI._ccbw_hash_bytes(::AbstractString) = _hit(:wide_ccbw_hash_bytes)
    import SHA
    SHA.sha256(::Vector{UInt8}) = _hit(:sha256_vector)
    sub = SubString("x", 1, 1)
    probes = ((:digest_string, () -> FusionConceptAI.Digest256(repeat("0", 64))),
              (:public_hash, () -> canonical_hash(support)),
              (:wide_hash_bytes, () -> FusionConceptAI._g25_hash_bytes(sub)),
              (:wide_ccbw_hash_bytes, () -> FusionConceptAI._ccbw_hash_bytes(sub)),
              (:sha256_vector, () -> SHA.sha256(UInt8[1, 2, 3])))
    for (name, action) in probes
        try action() catch; end
        @assert name in hits
    end
    @assert _g2sc_private_pair(support) == before
    """
    _g2sc_assert_child("digest", body)
end
