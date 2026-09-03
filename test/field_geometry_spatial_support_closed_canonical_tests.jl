using Test
using SHA
using JSON3
using FusionConceptAI

const G2SC_U = UnitSignature()
const G2SC_LENGTH = UnitSignature((0, 1, 0, 0, 0, 0, 0))
const G2SC_SCALE = NonnegativeQuantityV1(7 // 3, G2SC_LENGTH)
const G2SC_SUPPORT_DOMAIN = "fusionconceptai:v4:g2:spatial_support_ref:v1"

function _g2sc_bound(lower, upper)
    QuantityIntervalV1(ExactFiniteIntervalV1(lower, upper, false), G2SC_U)
end

function _g2sc_root(site, position, input_type, output_type)
    SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site), position, input_type, output_type)
end

function _g2sc_chart(name, frame, axes, coordinate_root, metric_root;
                     bounds=nothing, lower=-1 // 1, upper=1 // 1)
    bounds === nothing && (bounds = (_g2sc_bound(lower, upper), _g2sc_bound(lower, upper), _g2sc_bound(lower, upper)))
    CoordinateChartGeneV1(ChartRefV1(name), CoordinateFrameRefV1(frame), bounds,
        axes, coordinate_root, metric_root)
end

function _g2sc_support()
    chart_type = chart_coordinate_type_v1()
    ambient_type = normalized_ambient_coordinate_type_v1()
    metric_type = normalized_covariant_metric_type_v1()
    frame_a = "frame\0α"
    frame_b = "frame-β"
    chart_a_name = "chart\"\\\0Ω"
    chart_b_name = "chart-z"
    axis_x = PeriodicAxisV1(1, NonnegativeQuantityV1(5 // 2, G2SC_U))
    axis_z = PeriodicAxisV1(3, NonnegativeQuantityV1(7 // 3, G2SC_U))
    chart_a = _g2sc_chart(chart_a_name, frame_a, (),
        _g2sc_root("coord\0α", 11, chart_type, ambient_type),
        _g2sc_root("metric\"", 12, chart_type, metric_type))
    chart_b = _g2sc_chart(chart_b_name, frame_b, (axis_z, axis_x),
        _g2sc_root("coord\\β", 21, chart_type, ambient_type),
        _g2sc_root("metricΩ", 22, chart_type, metric_type),
        bounds=(_g2sc_bound(0, 5 // 2), _g2sc_bound(-1, 1), _g2sc_bound(0, 7 // 3)))
    transition_forward = ChartTransitionMapGeneV1(ChartRefV1(chart_a_name), ChartRefV1(chart_b_name),
        _g2sc_root("transition-forward", 31, chart_type, chart_type))
    transition_reverse = ChartTransitionMapGeneV1(ChartRefV1(chart_b_name), ChartRefV1(chart_a_name),
        _g2sc_root("transition-reverse", 32, chart_type, chart_type))
    SpatialSupportGeneV1(SpatialSupportRefV1("support\0空间🚀"), 3,
        (CoordinateFrameRefV1(frame_b), CoordinateFrameRefV1(frame_a)),
        (chart_b, chart_a), (transition_reverse, transition_forward), G2SC_SCALE)
end

function _g2sc_values()
    support = _g2sc_support()
    charts = getfield(support, :charts)
    transitions = getfield(support, :chart_transition_maps)
    (FieldOperatorSiteRefV1("site\0场🚀"),
     getfield(getfield(charts, 2), :coordinate_map_root),
     getfield(getfield(charts, 2), :periodic_axes)[1],
     getfield(charts, 1), getfield(transitions, 1), support)
end

function _g2sc_oracle_hash(text::String)
    bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(text))))
end

function _g2sc_private_pair(support)
    json = FusionConceptAI._g25_support_json(support)
    (json, getfield(FusionConceptAI._g25_support_canonical_hash(support), :value))
end

@testset "G2 5.2 spatial-support closed canonical golden" begin
    values = _g2sc_values()
    expected_names = ("field_operator_site_ref", "spatial_program_root", "periodic_axis",
        "coordinate_chart", "transition_map", "spatial_support")
    expected_types = (FieldOperatorSiteRefV1, SpatialProgramRootRefV1, PeriodicAxisV1,
        CoordinateChartGeneV1, ChartTransitionMapGeneV1, SpatialSupportGeneV1)
    expected_domains = ("fusionconceptai:v4:g2:field_operator_site_ref:v1",
        "fusionconceptai:v4:g2:spatial_program_root_ref:v1", "fusionconceptai:v4:g2:periodic_axis:v1",
        "fusionconceptai:v4:g2:coordinate_chart_gene:v1", "fusionconceptai:v4:g2:chart_transition_map_gene:v1",
        "fusionconceptai:v4:g2:spatial_support_gene:v1")
    rows = [JSON3.read(line, Dict{String,Any}) for line in eachline(joinpath(@__DIR__, "fixtures", "g2_spatial_support_closed_baseline_f08f664.jsonl")) if !isempty(strip(line))]
    @test length(values) == 6
    @test length(rows) == 6
    for (index, (value, row)) in enumerate(zip(values, rows))
        text = canonical_json(value)
        @test row["name"] == expected_names[index]
        @test typeof(value) === expected_types[index]
        @test JSON3.read(text).domain == expected_domains[index]
        @test JSON3.read(text) isa JSON3.Object
        @test text == row["json"]
        @test _g2sc_oracle_hash(text) == row["sha256"]
        @test getfield(canonical_hash(value), :value) == row["sha256"]
        @test row["provenance"] == "f08f6641079d2c56e60cfac29927b48d1769dda1"
    end
    support = last(values)
    private_json, private_hash = _g2sc_private_pair(support)
    @test private_json == canonical_json(support)
    @test private_hash == _g2sc_oracle_hash(private_json)
    @test getfield(support, :ambient_dimension) === Int64(3)
    @test length(getfield(support, :coordinate_frame_refs)) == 2
    @test length(getfield(support, :charts)) == 2
    @test length(getfield(support, :chart_transition_maps)) == 2
    @test getfield(getfield(support, :charts), 1).chart_ref.value == "chart\"\\\0Ω"
    @test isempty(getfield(getfield(support, :charts), 1).periodic_axes)
    @test Tuple(a.axis_position for a in getfield(getfield(support, :charts), 2).periodic_axes) == (1, 3)
    @test getfield(support, :resolution_independent_scale).value === (7 // 3)
    @test occursin("\\u0000", canonical_json(support))
    @test occursin("\\\"", canonical_json(support))
    @test occursin("\\\\", canonical_json(support))
end

@testset "G2 5.2 spatial-support identity, ordering and boundaries" begin
    support = _g2sc_support()
    reversed_support = SpatialSupportGeneV1(getfield(support, :support_ref), 3,
        reverse(getfield(support, :coordinate_frame_refs)),
        reverse(getfield(support, :charts)), reverse(getfield(support, :chart_transition_maps)),
        getfield(support, :resolution_independent_scale))
    @test canonical_json(reversed_support) == canonical_json(support)
    @test canonical_hash(reversed_support) == canonical_hash(support)
    changed_scale = SpatialSupportGeneV1(getfield(support, :support_ref), 3,
        getfield(support, :coordinate_frame_refs), getfield(support, :charts),
        getfield(support, :chart_transition_maps), NonnegativeQuantityV1(8 // 3, G2SC_LENGTH))
    @test canonical_hash(changed_scale) != canonical_hash(support)
    changed_ref = SpatialSupportGeneV1(SpatialSupportRefV1("support-other"), 3,
        getfield(support, :coordinate_frame_refs), getfield(support, :charts),
        getfield(support, :chart_transition_maps), getfield(support, :resolution_independent_scale))
    @test canonical_hash(changed_ref) != canonical_hash(support)
    chart = getfield(support, :charts)[1]
    @test chart.periodic_axes isa Tuple
    @test_throws ArgumentError SpatialSupportGeneV1(getfield(support, :support_ref), 2,
        getfield(support, :coordinate_frame_refs), getfield(support, :charts),
        getfield(support, :chart_transition_maps), getfield(support, :resolution_independent_scale))
    @test_throws ArgumentError SpatialSupportGeneV1(getfield(support, :support_ref), 3,
        getfield(support, :coordinate_frame_refs), getfield(support, :charts),
        getfield(support, :chart_transition_maps), NonnegativeQuantityV1(0, G2SC_LENGTH))
    @test_throws ArgumentError PeriodicAxisV1(1, NonnegativeQuantityV1(0, G2SC_U))
    @test_throws ArgumentError PeriodicAxisV1(1.0, NonnegativeQuantityV1(2, G2SC_U))
    @test_throws ArgumentError SpatialSupportGeneV1(getfield(support, :support_ref), 3,
        [getfield(support, :coordinate_frame_refs)...], getfield(support, :charts),
        getfield(support, :chart_transition_maps), getfield(support, :resolution_independent_scale))
    @test_throws ArgumentError FieldOperatorSiteRefV1("")
    @test_throws ArgumentError FieldOperatorSiteRefV1(1)
end

@testset "G2 5.2 support private canonical boundary" begin
    support = _g2sc_support()
    @test JSON3.read(canonical_json(getfield(support, :support_ref))).domain == G2SC_SUPPORT_DOMAIN
    @test JSON3.read(canonical_json(support)).kind == "spatial_support_gene"
    @test semantic_view(support).ambient_dimension == 3
    @test hash(support) == hash(support)
end
