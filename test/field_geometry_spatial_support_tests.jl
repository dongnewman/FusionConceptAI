using Test
using SHA
using FusionConceptAI

const G2S_U0 = UnitSignature()
const G2S_LEN = UnitSignature((0, 1, 0, 0, 0, 0, 0))
const G2S_HALF_LEN = UnitSignature((0 // 1, 1 // 2, 0 // 1, 0 // 1, 0 // 1, 0 // 1, 0 // 1))
const G2S_SITE_DOMAIN = "fusionconceptai:v4:g2:field_operator_site_ref:v1"
const G2S_ROOT_DOMAIN = "fusionconceptai:v4:g2:spatial_program_root_ref:v1"
const G2S_AXIS_DOMAIN = "fusionconceptai:v4:g2:periodic_axis:v1"
const G2S_CHART_DOMAIN = "fusionconceptai:v4:g2:coordinate_chart_gene:v1"
const G2S_TRANSITION_DOMAIN = "fusionconceptai:v4:g2:chart_transition_map_gene:v1"
const G2S_SUPPORT_DOMAIN = "fusionconceptai:v4:g2:spatial_support_gene:v1"

_g2s_bytes(x) = Vector{UInt8}(codeunits(canonical_json(x)))
_g2s_hash(x) = Digest256(bytes2hex(SHA.sha256(_g2s_bytes(x))))
_g2s_domain(x) = match(r"\"domain\":\"([^\"]+)\"", canonical_json(x)).captures[1]

function _g2s_bounds(lo=-1 // 1, hi=1 // 1; unit=G2S_U0, allow_equal=false)
    interval = ExactFiniteIntervalV1(lo, hi, allow_equal)
    QuantityIntervalV1(interval, unit)
end

function _g2s_root(site, pos, input, output)
    SpatialProgramRootRefV1(FieldOperatorSiteRefV1(site), pos, input, output)
end

function _g2s_chart(name, frame; axes=(), coord_site="coord", metric_site="metric",
                    coord_pos=1, metric_pos=1, lo=-1 // 1, hi=1 // 1)
    cc = chart_coordinate_type_v1()
    ambient = normalized_ambient_coordinate_type_v1()
    metric = normalized_covariant_metric_type_v1()
    coord_root = _g2s_root(coord_site, coord_pos, cc, ambient)
    metric_root = _g2s_root(metric_site, metric_pos, cc, metric)
    bounds = (_g2s_bounds(lo, hi), _g2s_bounds(lo, hi), _g2s_bounds(lo, hi))
    CoordinateChartGeneV1(ChartRefV1(name), CoordinateFrameRefV1(frame), bounds,
        axes, coord_root, metric_root)
end

function _g2s_axis(position, width=2 // 1; unit=G2S_U0)
    PeriodicAxisV1(position, NonnegativeQuantityV1(width, unit))
end

function _g2s_support(; ncharts=1, nframes=1, axes=(), transitions=(), scale=1 // 1,
                       frame_names=nothing, chart_names=nothing)
    frames = frame_names === nothing ? ntuple(i -> CoordinateFrameRefV1("frame-$i"), nframes) : frame_names
    charts = chart_names === nothing ? ntuple(i -> _g2s_chart("chart-$i", "frame-$(1 + mod(i - 1, nframes))"; axes=axes), ncharts) : chart_names
    SpatialSupportGeneV1(SpatialSupportRefV1("support"), 3, frames, charts,
        transitions, NonnegativeQuantityV1(scale, G2S_LEN))
end

@testset "G2 5.2 spatial support contracts" begin
    @testset "factory signatures and six canonical domains" begin
        cc = chart_coordinate_type_v1()
        ambient = normalized_ambient_coordinate_type_v1()
        metric = normalized_covariant_metric_type_v1()
        @test cc.value_kind == :chart_coordinate && cc.tensor_rank == 1 && cc.spatial_dimension == 3
        @test cc.temporal_type.kind == static_time && cc.temporal_type.derivative_order == 0 && cc.temporal_type.clock_ref === nothing
        @test cc.units == G2S_U0
        @test ambient.value_kind == :normalized_ambient_coordinate && ambient.tensor_rank == 1 && ambient.spatial_dimension == 3
        @test ambient.units == G2S_U0
        @test metric.value_kind == :normalized_covariant_metric && metric.tensor_rank == 2 && metric.spatial_dimension == 3
        @test metric.units == G2S_U0
        site = FieldOperatorSiteRefV1("site")
        root = SpatialProgramRootRefV1(site, 1, cc, ambient)
        axis = _g2s_axis(1)
        chart = _g2s_chart("chart", "frame"; axes=(axis,))
        transition_root = _g2s_root("transition", 1, cc, cc)
        transition = ChartTransitionMapGeneV1(chart.chart_ref, ChartRefV1("other"), transition_root)
        support = SpatialSupportGeneV1(SpatialSupportRefV1("support"), 3,
            (CoordinateFrameRefV1("frame"),), (chart,), (), NonnegativeQuantityV1(1, G2S_LEN))
        values = Any[site, root, axis, chart, transition, support]
        expected = (G2S_SITE_DOMAIN, G2S_ROOT_DOMAIN, G2S_AXIS_DOMAIN, G2S_CHART_DOMAIN,
            G2S_TRANSITION_DOMAIN, G2S_SUPPORT_DOMAIN)
        @test [_g2s_domain(x) for x in values] == collect(expected)
        @test all(canonical_hash(x) == _g2s_hash(x) for x in values)
        forbidden_fields = (:graph, :bindings, :binding, :trusted, :evidence, :status, :pass, :phenotype)
        @test all(isempty(intersect(Set(fieldnames(typeof(x))), Set(forbidden_fields))) for x in values)
        @test all(!occursin(word, canonical_json(x)) for x in values for word in
            ("metadata", "family", "seed", "solver", "evidence", "status", "pass", "phenotype"))
    end

    @testset "chart counts, axes, frames, and set semantics" begin
        @test chart_count(_g2s_support(ncharts=1)) == 1
        @test chart_count(_g2s_support(ncharts=2)) == 2
        @test chart_count(_g2s_support(ncharts=4, nframes=2)) == 4
        shared_roots = _g2s_support(ncharts=2)
        @test shared_roots.charts[1].coordinate_map_root === shared_roots.charts[2].coordinate_map_root
        @test shared_roots.charts[1].metric_program_root === shared_roots.charts[2].metric_program_root
        for n in 0:3
            support = _g2s_support(ncharts=1, axes=ntuple(i -> _g2s_axis(i), n))
            @test length(support.charts[1].periodic_axes) == n
        end
        sorted_axes = _g2s_chart("sorted-axes", "frame";
            axes=(_g2s_axis(3), _g2s_axis(1)))
        @test Tuple(axis.axis_position for axis in sorted_axes.periodic_axes) == (1, 3)
        @test_throws ArgumentError _g2s_chart("duplicate-axes", "frame";
            axes=(_g2s_axis(1), _g2s_axis(1)))
        negative = _g2s_chart("negative", "frame"; lo=-7 // 3, hi=-2 // 5)
        @test negative.chart_bounds[1].interval.lower === (-7 // 3)
        @test negative.chart_bounds[1].interval.upper === (-2 // 5)
        fractional = _g2s_chart("fractional", "frame"; lo=1 // 3, hi=7 // 6,
            axes=(_g2s_axis(1, 5 // 6),))
        @test fractional.periodic_axes[1].period.value === (5 // 6)
        edge_hi = _g2s_chart("edge-hi", "frame"; lo=typemax(Int64) - 3,
            hi=typemax(Int64) - 1, axes=(_g2s_axis(1, 2),))
        edge_lo = _g2s_chart("edge-lo", "frame"; lo=typemin(Int64) + 1,
            hi=typemin(Int64) + 3, axes=(_g2s_axis(1, 2),))
        @test edge_hi.periodic_axes[1].period.value === (2 // 1)
        @test edge_lo.periodic_axes[1].period.value === (2 // 1)
        shared = _g2s_support(ncharts=4, nframes=1)
        @test length(shared.coordinate_frame_refs) == 1 && all(c.frame_ref.value == "frame-1" for c in shared.charts)
        @test !hasproperty(shared, :frames)
        @test canonical_hash(_g2s_support(ncharts=2, nframes=2,
            frame_names=(CoordinateFrameRefV1("a"), CoordinateFrameRefV1("b")),
            chart_names=(_g2s_chart("a", "a"), _g2s_chart("b", "b")))) ==
            canonical_hash(_g2s_support(ncharts=2, nframes=2,
                frame_names=(CoordinateFrameRefV1("b"), CoordinateFrameRefV1("a")),
                chart_names=(_g2s_chart("b", "b"), _g2s_chart("a", "a"))))
    end

    @testset "root signatures and directed transitions" begin
        cc, ambient, metric = chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1(), normalized_covariant_metric_type_v1()
        coord = _g2s_root("same-site", 1, cc, ambient)
        metric_root = _g2s_root("same-site", 2, cc, metric)
        @test coord.operator_site_ref.value == metric_root.operator_site_ref.value && coord.root_position != metric_root.root_position
        @test coord.declared_input_type == cc && coord.declared_type == ambient
        reused = _g2s_chart("reused", "frame"; coord_site="same", metric_site="other")
        reused2 = _g2s_chart("reused-2", "frame"; coord_site="same", metric_site="other")
        @test reused.coordinate_map_root.operator_site_ref.value == reused2.coordinate_map_root.operator_site_ref.value
        transition_root = _g2s_root("transition", 1, cc, cc)
        forward = ChartTransitionMapGeneV1(ChartRefV1("a"), ChartRefV1("b"), transition_root)
        reverse = ChartTransitionMapGeneV1(ChartRefV1("b"), ChartRefV1("a"), transition_root)
        @test canonical_hash(forward) != canonical_hash(reverse)
        support = _g2s_support(ncharts=2, nframes=1, frame_names=(CoordinateFrameRefV1("frame"),),
            chart_names=(_g2s_chart("a", "frame"), _g2s_chart("b", "frame")),
            transitions=(forward, reverse))
        @test length(support.chart_transition_maps) == 2
        @test canonical_hash(support) == canonical_hash(_g2s_support(ncharts=2, nframes=1,
            frame_names=(CoordinateFrameRefV1("frame"),),
            chart_names=(_g2s_chart("b", "frame"), _g2s_chart("a", "frame")),
            transitions=(reverse, forward)))
    end

    @testset "opaque Unicode/NUL references and constructor rejection" begin
        labels = ("é", "é", "状态\0🚀")
        @test length(unique(canonical_hash(FieldOperatorSiteRefV1(x)) for x in labels)) == 3
        @test length(unique(canonical_hash(CoordinateFrameRefV1(x)) for x in labels)) == 3
        cc = chart_coordinate_type_v1()
        nul_root_a = _g2s_root("a\0b", 1, cc, cc)
        nul_root_b = _g2s_root("a", 1, cc, cc)
        @test canonical_hash(nul_root_a) != canonical_hash(nul_root_b)
        nul_transition_a = ChartTransitionMapGeneV1(ChartRefV1("a\0b"), ChartRefV1("c"), nul_root_a)
        nul_transition_b = ChartTransitionMapGeneV1(ChartRefV1("a"), ChartRefV1("b\0c"), nul_root_a)
        @test canonical_hash(nul_transition_a) != canonical_hash(nul_transition_b)
        @test_throws ArgumentError FieldOperatorSiteRefV1("")
        @test_throws ArgumentError FieldOperatorSiteRefV1(1)
        @test_throws ArgumentError FieldOperatorSiteRefV1(CoordinateFrameRefV1("wrong"))
        @test_throws ArgumentError SpatialProgramRootRefV1(FieldOperatorSiteRefV1("s"), true,
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1())
        @test_throws ArgumentError SpatialProgramRootRefV1(FieldOperatorSiteRefV1("s"), 0,
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1())
        @test_throws ArgumentError SpatialProgramRootRefV1(FieldOperatorSiteRefV1("s"), UInt8(1),
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1())
        @test_throws ArgumentError SpatialProgramRootRefV1(FieldOperatorSiteRefV1("s"), big(1),
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1())
        @test_throws ArgumentError SpatialProgramRootRefV1(FieldOperatorSiteRefV1("s"), 1.0,
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1())
        @test SpatialProgramRootRefV1(FieldOperatorSiteRefV1("s"), typemax(Int64),
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1()).root_position === typemax(Int64)
        @test_throws ArgumentError SpatialProgramRootRefV1(FieldOperatorSiteRefV1("s"), Int128(typemax(Int64)) + 1,
            chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1())
        @test_throws ArgumentError PeriodicAxisV1(UInt8(1), NonnegativeQuantityV1(2, G2S_U0))
        @test_throws ArgumentError PeriodicAxisV1(big(1), NonnegativeQuantityV1(2, G2S_U0))
        @test_throws ArgumentError PeriodicAxisV1(1.0, NonnegativeQuantityV1(2, G2S_U0))
        @test_throws ArgumentError PeriodicAxisV1(0, NonnegativeQuantityV1(2, G2S_U0))
        @test_throws ArgumentError PeriodicAxisV1(4, NonnegativeQuantityV1(2, G2S_U0))
        @test PeriodicAxisV1(Int64(1), NonnegativeQuantityV1(2, G2S_U0)).axis_position === Int64(1)
        @test PeriodicAxisV1(Int64(3), NonnegativeQuantityV1(2, G2S_U0)).axis_position === Int64(3)
        @test_throws ArgumentError PeriodicAxisV1(Int128(typemax(Int64)) + 1, NonnegativeQuantityV1(2, G2S_U0))
    end

    @testset "negative structural, bounds, axis, scale, and PhysicalType controls" begin
        valid = _g2s_support()
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 2, valid.coordinate_frame_refs, valid.charts, valid.chart_transition_maps, valid.resolution_independent_scale)
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, (), valid.charts, valid.chart_transition_maps, valid.resolution_independent_scale)
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, ntuple(i -> CoordinateFrameRefV1("f-$i"), 5), valid.charts, valid.chart_transition_maps, valid.resolution_independent_scale)
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, valid.coordinate_frame_refs, (), valid.chart_transition_maps, valid.resolution_independent_scale)
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, valid.coordinate_frame_refs, ntuple(i -> _g2s_chart("c-$i", "frame-1"), 5), valid.chart_transition_maps, valid.resolution_independent_scale)
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, (valid.coordinate_frame_refs[1], valid.coordinate_frame_refs[1]), valid.charts, valid.chart_transition_maps, valid.resolution_independent_scale)
        @test_throws ArgumentError CoordinateChartGeneV1(valid.charts[1].chart_ref, valid.charts[1].frame_ref,
            [valid.charts[1].chart_bounds...], valid.charts[1].periodic_axes,
            valid.charts[1].coordinate_map_root, valid.charts[1].metric_program_root)
        bad_bounds = (_g2s_bounds(-1, 1; unit=G2S_LEN), _g2s_bounds(), _g2s_bounds())
        @test_throws ArgumentError CoordinateChartGeneV1(ChartRefV1("bad"), CoordinateFrameRefV1("frame"), bad_bounds, (),
            valid.charts[1].coordinate_map_root, valid.charts[1].metric_program_root)
        @test_throws ArgumentError CoordinateChartGeneV1(ChartRefV1("bad"), CoordinateFrameRefV1("frame"),
            (_g2s_bounds(1, 1), _g2s_bounds(), _g2s_bounds()), (), valid.charts[1].coordinate_map_root, valid.charts[1].metric_program_root)
        @test_throws ArgumentError CoordinateChartGeneV1(ChartRefV1("bad"), CoordinateFrameRefV1("frame"),
            (_g2s_bounds(-1, 1; allow_equal=true), _g2s_bounds(), _g2s_bounds()), (), valid.charts[1].coordinate_map_root, valid.charts[1].metric_program_root)
        @test_throws ArgumentError CoordinateChartGeneV1(ChartRefV1("bad"), CoordinateFrameRefV1("frame"),
            ((_g2s_bounds().interval,), _g2s_bounds(), _g2s_bounds()), (), valid.charts[1].coordinate_map_root, valid.charts[1].metric_program_root)
        @test_throws ArgumentError PeriodicAxisV1(1, NonnegativeQuantityV1(0, G2S_U0))
        @test_throws ArgumentError PeriodicAxisV1(1, NonnegativeQuantityV1(2.0, G2S_U0))
        @test_throws ArgumentError PeriodicAxisV1(1, NonnegativeQuantityV1(2, G2S_LEN))
        @test_throws ArgumentError PeriodicAxisV1(1, NonnegativeQuantityV1(big(2), G2S_U0))
        @test_throws ArgumentError _g2s_chart("bad-period", "frame"; axes=(_g2s_axis(1, 3 // 1),))
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, valid.coordinate_frame_refs, valid.charts, valid.chart_transition_maps, NonnegativeQuantityV1(0, G2S_LEN))
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, valid.coordinate_frame_refs, valid.charts, valid.chart_transition_maps, NonnegativeQuantityV1(1, G2S_U0))
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, valid.coordinate_frame_refs, valid.charts, valid.chart_transition_maps, NonnegativeQuantityV1(1, G2S_HALF_LEN))
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, valid.coordinate_frame_refs, valid.charts, valid.chart_transition_maps, NonnegativeQuantityV1(1.0, G2S_LEN))
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, valid.coordinate_frame_refs, valid.charts, valid.chart_transition_maps, [valid.resolution_independent_scale])
        @test_throws ArgumentError invoke(SpatialSupportGeneV1, Tuple{Any,Any,Any,Any,Any,Any},
            valid.support_ref, 3, valid.coordinate_frame_refs, valid.charts,
            valid.chart_transition_maps, [valid.resolution_independent_scale])

        base_chart = valid.charts[1]
        expected_chart = chart_coordinate_type_v1()
        expected_ambient = normalized_ambient_coordinate_type_v1()
        bad_chart(input, output=expected_ambient) = CoordinateChartGeneV1(
            ChartRefV1("bad-type"), CoordinateFrameRefV1("frame-1"), base_chart.chart_bounds,
            (), SpatialProgramRootRefV1(FieldOperatorSiteRefV1("bad"), 1, input, output),
            base_chart.metric_program_root)
        @test_throws ArgumentError bad_chart(PhysicalType(:wrong, expected_chart.tensor_rank, expected_chart.spatial_dimension, expected_chart.temporal_type, expected_chart.units))
        @test_throws ArgumentError bad_chart(PhysicalType(expected_chart.value_kind, expected_chart.tensor_rank + 1, expected_chart.spatial_dimension, expected_chart.temporal_type, expected_chart.units))
        @test_throws ArgumentError bad_chart(PhysicalType(expected_chart.value_kind, expected_chart.tensor_rank, 2, expected_chart.temporal_type, expected_chart.units))
        @test_throws ArgumentError bad_chart(PhysicalType(expected_chart.value_kind, expected_chart.tensor_rank, expected_chart.spatial_dimension, TemporalTypeV1(algebraic_time), expected_chart.units))
        @test_throws ArgumentError bad_chart(PhysicalType(expected_chart.value_kind, expected_chart.tensor_rank, expected_chart.spatial_dimension, TemporalTypeV1(discrete_time, 0, QualifiedRefV1("clock", "v1")), expected_chart.units))
        @test_throws ArgumentError bad_chart(PhysicalType(expected_chart.value_kind, expected_chart.tensor_rank, expected_chart.spatial_dimension, expected_chart.temporal_type, G2S_LEN))
        @test_throws ArgumentError bad_chart(expected_chart, PhysicalType(:wrong, expected_ambient.tensor_rank, expected_ambient.spatial_dimension, expected_ambient.temporal_type, expected_ambient.units))
        @test_throws ArgumentError bad_chart(expected_chart, PhysicalType(expected_ambient.value_kind, expected_ambient.tensor_rank + 1, expected_ambient.spatial_dimension, expected_ambient.temporal_type, expected_ambient.units))
        @test_throws ArgumentError bad_chart(expected_chart, PhysicalType(expected_ambient.value_kind, expected_ambient.tensor_rank, 2, expected_ambient.temporal_type, expected_ambient.units))
        @test_throws ArgumentError bad_chart(expected_chart, PhysicalType(expected_ambient.value_kind, expected_ambient.tensor_rank, expected_ambient.spatial_dimension, TemporalTypeV1(algebraic_time), expected_ambient.units))
        @test_throws ArgumentError bad_chart(expected_chart, PhysicalType(expected_ambient.value_kind, expected_ambient.tensor_rank, expected_ambient.spatial_dimension, TemporalTypeV1(discrete_time, 0, QualifiedRefV1("clock", "v1")), expected_ambient.units))
        @test_throws ArgumentError bad_chart(expected_chart, PhysicalType(expected_ambient.value_kind, expected_ambient.tensor_rank, expected_ambient.spatial_dimension, expected_ambient.temporal_type, G2S_LEN))

        expected_metric = normalized_covariant_metric_type_v1()
        bad_metric(input=expected_chart, output=expected_metric) = CoordinateChartGeneV1(
            ChartRefV1("bad-metric"), CoordinateFrameRefV1("frame-1"), base_chart.chart_bounds, (),
            base_chart.coordinate_map_root,
            SpatialProgramRootRefV1(FieldOperatorSiteRefV1("bad-metric"), 1, input, output))
        metric_bad_inputs = (
            PhysicalType(:wrong, expected_chart.tensor_rank, expected_chart.spatial_dimension, expected_chart.temporal_type, expected_chart.units),
            PhysicalType(expected_chart.value_kind, expected_chart.tensor_rank + 1, expected_chart.spatial_dimension, expected_chart.temporal_type, expected_chart.units),
            PhysicalType(expected_chart.value_kind, expected_chart.tensor_rank, 2, expected_chart.temporal_type, expected_chart.units),
            PhysicalType(expected_chart.value_kind, expected_chart.tensor_rank, expected_chart.spatial_dimension, TemporalTypeV1(algebraic_time), expected_chart.units),
            PhysicalType(expected_chart.value_kind, expected_chart.tensor_rank, expected_chart.spatial_dimension, TemporalTypeV1(discrete_time, 0, QualifiedRefV1("clock", "v1")), expected_chart.units),
            PhysicalType(expected_chart.value_kind, expected_chart.tensor_rank, expected_chart.spatial_dimension, expected_chart.temporal_type, G2S_LEN))
        for bad in metric_bad_inputs
            @test_throws ArgumentError bad_metric(bad)
        end
        metric_bad_outputs = (
            PhysicalType(:wrong, expected_metric.tensor_rank, expected_metric.spatial_dimension, expected_metric.temporal_type, expected_metric.units),
            PhysicalType(expected_metric.value_kind, expected_metric.tensor_rank + 1, expected_metric.spatial_dimension, expected_metric.temporal_type, expected_metric.units),
            PhysicalType(expected_metric.value_kind, expected_metric.tensor_rank, 2, expected_metric.temporal_type, expected_metric.units),
            PhysicalType(expected_metric.value_kind, expected_metric.tensor_rank, expected_metric.spatial_dimension, TemporalTypeV1(algebraic_time), expected_metric.units),
            PhysicalType(expected_metric.value_kind, expected_metric.tensor_rank, expected_metric.spatial_dimension, TemporalTypeV1(discrete_time, 0, QualifiedRefV1("clock", "v1")), expected_metric.units),
            PhysicalType(expected_metric.value_kind, expected_metric.tensor_rank, expected_metric.spatial_dimension, expected_metric.temporal_type, G2S_LEN))
        for bad in metric_bad_outputs
            @test_throws ArgumentError bad_metric(expected_chart, bad)
        end

        dangling = ChartTransitionMapGeneV1(ChartRefV1("missing"), ChartRefV1("also-missing"),
            _g2s_root("transition", 1, chart_coordinate_type_v1(), chart_coordinate_type_v1()))
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, valid.coordinate_frame_refs, valid.charts, (dangling,), valid.resolution_independent_scale)
        @test_throws ArgumentError ChartTransitionMapGeneV1(ChartRefV1("a"), ChartRefV1("b"),
            _g2s_root("transition", 1, chart_coordinate_type_v1(), normalized_ambient_coordinate_type_v1()))
        @test_throws ArgumentError ChartTransitionMapGeneV1(ChartRefV1("chart-1"), ChartRefV1("chart-1"),
            _g2s_root("transition", 1, chart_coordinate_type_v1(), chart_coordinate_type_v1()))
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3, valid.coordinate_frame_refs, valid.charts,
            (ChartTransitionMapGeneV1(ChartRefV1("chart-1"), ChartRefV1("chart-2"), _g2s_root("transition", 1, chart_coordinate_type_v1(), chart_coordinate_type_v1())),
             ChartTransitionMapGeneV1(ChartRefV1("chart-1"), ChartRefV1("chart-2"), _g2s_root("transition", 2, chart_coordinate_type_v1(), chart_coordinate_type_v1()))), valid.resolution_independent_scale)
        bad_transition(input) = ChartTransitionMapGeneV1(ChartRefV1("a"), ChartRefV1("b"),
            _g2s_root("transition", 1, input, chart_coordinate_type_v1()))
        for bad in metric_bad_inputs
            @test_throws ArgumentError bad_transition(bad)
        end
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3,
            (CoordinateFrameRefV1("frame-1"), CoordinateFrameRefV1("unused")), valid.charts,
            valid.chart_transition_maps, valid.resolution_independent_scale)
        conflicting = _g2s_chart("conflicting", "frame-1"; coord_site="same", metric_site="same",
            coord_pos=1, metric_pos=1)
        @test_throws ArgumentError SpatialSupportGeneV1(valid.support_ref, 3,
            valid.coordinate_frame_refs, (conflicting,), (), valid.resolution_independent_scale)
        @test canonical_hash(valid) != canonical_hash(SpatialSupportGeneV1(
            SpatialSupportRefV1("renamed"), valid.ambient_dimension, valid.coordinate_frame_refs,
            valid.charts, valid.chart_transition_maps, valid.resolution_independent_scale))
        @test FieldOperatorSiteRefV1("family/device") isa FieldOperatorSiteRefV1
        @test FieldOperatorSiteRefV1("family/device").value == "family/device"
    end
end
