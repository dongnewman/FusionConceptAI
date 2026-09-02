"""Closed spatial-support declarations for the G2 5.2 field-geometry grammar."""

function _g25_ref_text(value::Any, field::Any)
    typeof(value) === String || throw(ArgumentError("$field must be an immutable String"))
    isvalid(value) || throw(ArgumentError("$field must contain valid Unicode scalar values"))
    Core.sizeof(value) == 0 && throw(ArgumentError("$field cannot be empty"))
    value
end

struct FieldOperatorSiteRefV1
    value::String
    function FieldOperatorSiteRefV1(value::Any)
        new(invoke(_g25_ref_text, Tuple{Any,Any}, value, "field operator site reference"))
    end
end
Base.:(==)(a::FieldOperatorSiteRefV1, b::FieldOperatorSiteRefV1) = a.value == b.value
Base.hash(a::FieldOperatorSiteRefV1, h::UInt) = hash(a.value, h)
semantic_view(a::FieldOperatorSiteRefV1) = (value=a.value,)

function _g25_signed_int64(value::Any, field::Any)
    value_type = typeof(value)
    (value_type === Int8 || value_type === Int16 || value_type === Int32 ||
     value_type === Int64 || value_type === Int128) ||
        throw(ArgumentError("$field requires a fixed-width signed integer"))
    typemin(Int64) <= value <= typemax(Int64) ||
        throw(ArgumentError("$field is outside the Int64 range"))
    Int64(value)
end

struct SpatialProgramRootRefV1
    operator_site_ref::FieldOperatorSiteRefV1
    root_position::Int64
    declared_input_type::PhysicalType
    declared_type::PhysicalType
    function SpatialProgramRootRefV1(operator_site_ref::Any, root_position::Any,
                                     declared_input_type::Any, declared_type::Any)
        operator_site_ref isa FieldOperatorSiteRefV1 ||
            throw(ArgumentError("operator_site_ref must be FieldOperatorSiteRefV1"))
        position = invoke(_g25_signed_int64, Tuple{Any,Any}, root_position, "root_position")
        position >= 1 || throw(ArgumentError("root_position must be at least 1"))
        declared_input_type isa PhysicalType ||
            throw(ArgumentError("declared_input_type must be PhysicalType"))
        declared_type isa PhysicalType || throw(ArgumentError("declared_type must be PhysicalType"))
        new(operator_site_ref, position, declared_input_type, declared_type)
    end
end
Base.:(==)(a::SpatialProgramRootRefV1, b::SpatialProgramRootRefV1) =
    a.operator_site_ref == b.operator_site_ref && a.root_position == b.root_position &&
    a.declared_input_type == b.declared_input_type && a.declared_type == b.declared_type
Base.hash(a::SpatialProgramRootRefV1, h::UInt) =
    hash((a.operator_site_ref, a.root_position, a.declared_input_type, a.declared_type), h)
semantic_view(a::SpatialProgramRootRefV1) =
    (operator_site_ref=a.operator_site_ref, root_position=a.root_position,
     declared_input_type=a.declared_input_type, declared_type=a.declared_type)

function _g25_dimensionless(unit::UnitSignature)
    i = 1
    while i <= fieldcount(typeof(unit.exponents))
        exponent = getfield(unit.exponents, i)
        (numerator(exponent) == 0 && denominator(exponent) == 1) || return false
        i += 1
    end
    true
end
function _g25_si_length(unit::UnitSignature)
    first = getfield(unit.exponents, 1)
    second = getfield(unit.exponents, 2)
    (numerator(first) == 0 && denominator(first) == 1 &&
     numerator(second) == 1 && denominator(second) == 1) || return false
    i = 3
    while i <= fieldcount(typeof(unit.exponents))
        exponent = getfield(unit.exponents, i)
        (numerator(exponent) == 0 && denominator(exponent) == 1) || return false
        i += 1
    end
    true
end

struct PeriodicAxisV1
    axis_position::Int64
    period::NonnegativeQuantityV1
    function PeriodicAxisV1(axis_position::Any, period::Any)
        position = invoke(_g25_signed_int64, Tuple{Any,Any}, axis_position, "axis_position")
        1 <= position <= 3 || throw(ArgumentError("axis_position must be in 1:3"))
        period isa NonnegativeQuantityV1 || throw(ArgumentError("period must be NonnegativeQuantityV1"))
        period.value > 0 || throw(ArgumentError("period must be strictly positive"))
        invoke(_g25_dimensionless, Tuple{UnitSignature}, period.unit) ||
            throw(ArgumentError("period must be dimensionless"))
        new(position, period)
    end
end
Base.:(==)(a::PeriodicAxisV1, b::PeriodicAxisV1) =
    a.axis_position == b.axis_position && a.period == b.period
Base.hash(a::PeriodicAxisV1, h::UInt) = hash((a.axis_position, a.period), h)
semantic_view(a::PeriodicAxisV1) = (axis_position=a.axis_position, period=a.period)

function _g25_rational_equal_big(value::Rational{Int64}, numerator_big::BigInt,
                                  denominator_big::BigInt)
    BigInt(numerator(value)) * denominator_big == numerator_big * BigInt(denominator(value))
end

function _g25_quantity_interval_equal_period(bound::QuantityIntervalV1,
                                              period::NonnegativeQuantityV1)
    lower = bound.interval.lower
    upper = bound.interval.upper
    difference_numerator = BigInt(numerator(upper)) * BigInt(denominator(lower)) -
        BigInt(numerator(lower)) * BigInt(denominator(upper))
    difference_denominator = BigInt(denominator(upper)) * BigInt(denominator(lower))
    invoke(_g25_rational_equal_big, Tuple{Rational{Int64},BigInt,BigInt},
           period.value, difference_numerator, difference_denominator)
end

function _g25_periodic_axes_sorted(values::Any)
    values isa Tuple && !(values isa NamedTuple) ||
        throw(ArgumentError("periodic_axes must be an immutable tuple"))
    value_count = fieldcount(typeof(values))
    value_count <= 3 || throw(ArgumentError("periodic_axes cannot contain more than three axes"))
    i = 1
    while i <= value_count
        typeof(getfield(values, i)) === PeriodicAxisV1 ||
            throw(ArgumentError("periodic_axes must contain PeriodicAxisV1 values"))
        i += 1
    end
    positions = Vector{Int64}(undef, value_count)
    position_count = 0
    i = 1
    while i <= value_count
        value = getfield(values, i)
        j = 1
        while j <= position_count
            Core.arrayref(true, positions, j) === value.axis_position &&
                throw(ArgumentError("periodic axis positions must be unique"))
            j += 1
        end
        position_count += 1
        Core.arrayset(true, positions, value.axis_position, position_count)
        i += 1
    end
    sorted = Vector{PeriodicAxisV1}(undef, value_count)
    i = 1
    while i <= value_count
        Core.arrayset(true, sorted, getfield(values, i), i)
        i += 1
    end
    i = 2
    while i <= value_count
        current = Core.arrayref(true, sorted, i)
        j = i - 1
        while j >= 1 && current.axis_position < Core.arrayref(true, sorted, j).axis_position
            Core.arrayset(true, sorted, Core.arrayref(true, sorted, j), j + 1)
            j -= 1
        end
        Core.arrayset(true, sorted, current, j + 1)
        i += 1
    end
    ntuple(i -> Core.arrayref(true, sorted, i), value_count)
end

function _g25_expected_chart_coordinate_type()
    PhysicalType(:chart_coordinate, 1, 3, TemporalTypeV1(static_time), UnitSignature())
end
function _g25_expected_normalized_ambient_type()
    PhysicalType(:normalized_ambient_coordinate, 1, 3, TemporalTypeV1(static_time), UnitSignature())
end
function _g25_expected_normalized_metric_type()
    PhysicalType(:normalized_covariant_metric, 2, 3, TemporalTypeV1(static_time), UnitSignature())
end

chart_coordinate_type_v1() = invoke(_g25_expected_chart_coordinate_type, Tuple{})
normalized_ambient_coordinate_type_v1() = invoke(_g25_expected_normalized_ambient_type, Tuple{})
normalized_covariant_metric_type_v1() = invoke(_g25_expected_normalized_metric_type, Tuple{})

function _g25_type_matches(value::Any, expected::Any)
    typeof(value) === PhysicalType && typeof(expected) === PhysicalType || return false
    value.value_kind === expected.value_kind && value.tensor_rank === expected.tensor_rank &&
        value.spatial_dimension === expected.spatial_dimension &&
        value.temporal_type.kind === expected.temporal_type.kind &&
        value.temporal_type.derivative_order === expected.temporal_type.derivative_order &&
        value.temporal_type.clock_ref === expected.temporal_type.clock_ref &&
        invoke(_g25_unit_matches, Tuple{UnitSignature,UnitSignature}, value.units, expected.units)
end
function _g25_unit_matches(a::UnitSignature, b::UnitSignature)
    i = 1
    while i <= fieldcount(typeof(a.exponents))
        left = getfield(a.exponents, i)
        right = getfield(b.exponents, i)
        (numerator(left) == numerator(right) && denominator(left) == denominator(right)) || return false
        i += 1
    end
    true
end

struct CoordinateChartGeneV1
    chart_ref::ChartRefV1
    frame_ref::CoordinateFrameRefV1
    chart_bounds::NTuple{3,QuantityIntervalV1}
    periodic_axes::Tuple{Vararg{PeriodicAxisV1}}
    coordinate_map_root::SpatialProgramRootRefV1
    metric_program_root::SpatialProgramRootRefV1
    function CoordinateChartGeneV1(chart_ref::Any, frame_ref::Any, chart_bounds::Any,
                                   periodic_axes::Any, coordinate_map_root::Any,
                                   metric_program_root::Any)
        chart_ref isa ChartRefV1 || throw(ArgumentError("chart_ref must be ChartRefV1"))
        frame_ref isa CoordinateFrameRefV1 ||
            throw(ArgumentError("frame_ref must be CoordinateFrameRefV1"))
        chart_bounds isa Tuple && !(chart_bounds isa NamedTuple) &&
            fieldcount(typeof(chart_bounds)) == 3 ||
            throw(ArgumentError("chart_bounds must be an immutable 3-tuple"))
        i = 1
        while i <= fieldcount(typeof(chart_bounds))
            typeof(getfield(chart_bounds, i)) === QuantityIntervalV1 ||
                throw(ArgumentError("chart_bounds must contain QuantityIntervalV1 values"))
            bound = getfield(chart_bounds, i)
            invoke(_g25_dimensionless, Tuple{UnitSignature}, bound.unit) ||
                throw(ArgumentError("chart bounds must be dimensionless"))
            bound.interval.lower < bound.interval.upper ||
                throw(ArgumentError("chart bounds must be strictly ordered"))
            bound.interval.allow_equal == false ||
                throw(ArgumentError("chart bounds must disallow equal endpoints"))
            i += 1
        end
        axes = invoke(_g25_periodic_axes_sorted, Tuple{Any}, periodic_axes)
        i = 1
        while i <= fieldcount(typeof(axes))
            axis = getfield(axes, i)
            bound = getfield(chart_bounds, axis.axis_position)
            invoke(_g25_quantity_interval_equal_period, Tuple{QuantityIntervalV1,NonnegativeQuantityV1},
                   bound, axis.period) ||
                throw(ArgumentError("period must equal the corresponding chart bound span"))
            i += 1
        end
        coordinate_map_root isa SpatialProgramRootRefV1 ||
            throw(ArgumentError("coordinate_map_root must be SpatialProgramRootRefV1"))
        metric_program_root isa SpatialProgramRootRefV1 ||
            throw(ArgumentError("metric_program_root must be SpatialProgramRootRefV1"))
        expected_chart = invoke(_g25_expected_chart_coordinate_type, Tuple{})
        expected_ambient = invoke(_g25_expected_normalized_ambient_type, Tuple{})
        expected_metric = invoke(_g25_expected_normalized_metric_type, Tuple{})
        invoke(_g25_type_matches, Tuple{Any,Any}, coordinate_map_root.declared_input_type, expected_chart) ||
            throw(ArgumentError("coordinate map root input type must be chart_coordinate"))
        invoke(_g25_type_matches, Tuple{Any,Any}, coordinate_map_root.declared_type, expected_ambient) ||
            throw(ArgumentError("coordinate map root output type must be normalized_ambient_coordinate"))
        invoke(_g25_type_matches, Tuple{Any,Any}, metric_program_root.declared_input_type, expected_chart) ||
            throw(ArgumentError("metric program root input type must be chart_coordinate"))
        invoke(_g25_type_matches, Tuple{Any,Any}, metric_program_root.declared_type, expected_metric) ||
            throw(ArgumentError("metric program root output type must be normalized_covariant_metric"))
        new(chart_ref, frame_ref,
            (getfield(chart_bounds, 1), getfield(chart_bounds, 2), getfield(chart_bounds, 3)), axes,
            coordinate_map_root, metric_program_root)
    end
end
Base.:(==)(a::CoordinateChartGeneV1, b::CoordinateChartGeneV1) =
    a.chart_ref == b.chart_ref && a.frame_ref == b.frame_ref && a.chart_bounds == b.chart_bounds &&
    a.periodic_axes == b.periodic_axes && a.coordinate_map_root == b.coordinate_map_root &&
    a.metric_program_root == b.metric_program_root
Base.hash(a::CoordinateChartGeneV1, h::UInt) =
    hash((a.chart_ref, a.frame_ref, a.chart_bounds, a.periodic_axes,
          a.coordinate_map_root, a.metric_program_root), h)
semantic_view(a::CoordinateChartGeneV1) =
    (chart_ref=a.chart_ref, frame_ref=a.frame_ref, chart_bounds=a.chart_bounds,
     periodic_axes=a.periodic_axes, coordinate_map_root=a.coordinate_map_root,
     metric_program_root=a.metric_program_root)

struct ChartTransitionMapGeneV1
    source_chart_ref::ChartRefV1
    target_chart_ref::ChartRefV1
    transition_map_root::SpatialProgramRootRefV1
    function ChartTransitionMapGeneV1(source_chart_ref::Any, target_chart_ref::Any,
                                      transition_map_root::Any)
        source_chart_ref isa ChartRefV1 || throw(ArgumentError("source_chart_ref must be ChartRefV1"))
        target_chart_ref isa ChartRefV1 || throw(ArgumentError("target_chart_ref must be ChartRefV1"))
        invoke(_g25_text_equal, Tuple{String,String}, source_chart_ref.value, target_chart_ref.value) &&
            throw(ArgumentError("source and target chart references must differ"))
        transition_map_root isa SpatialProgramRootRefV1 ||
            throw(ArgumentError("transition_map_root must be SpatialProgramRootRefV1"))
        expected_chart = invoke(_g25_expected_chart_coordinate_type, Tuple{})
        invoke(_g25_type_matches, Tuple{Any,Any}, transition_map_root.declared_input_type, expected_chart) ||
            throw(ArgumentError("transition map root input type must be chart_coordinate"))
        invoke(_g25_type_matches, Tuple{Any,Any}, transition_map_root.declared_type, expected_chart) ||
            throw(ArgumentError("transition map root output type must be chart_coordinate"))
        new(source_chart_ref, target_chart_ref, transition_map_root)
    end
end
Base.:(==)(a::ChartTransitionMapGeneV1, b::ChartTransitionMapGeneV1) =
    a.source_chart_ref == b.source_chart_ref && a.target_chart_ref == b.target_chart_ref &&
    a.transition_map_root == b.transition_map_root
Base.hash(a::ChartTransitionMapGeneV1, h::UInt) =
    hash((a.source_chart_ref, a.target_chart_ref, a.transition_map_root), h)
semantic_view(a::ChartTransitionMapGeneV1) =
    (source_chart_ref=a.source_chart_ref, target_chart_ref=a.target_chart_ref,
     transition_map_root=a.transition_map_root)

function _g25_tuple_unique(values::Tuple, key::Function, field::String)
    value_count = fieldcount(typeof(values))
    keys = Vector{Any}(undef, value_count)
    count = 0
    i = 1
    while i <= value_count
        current = key(getfield(values, i))
        j = 1
        while j <= count
            invoke(_g25_key_equal, Tuple{Any,Any}, Core.arrayref(true, keys, j), current) &&
                throw(ArgumentError("$field must be unique"))
            j += 1
        end
        count += 1
        Core.arrayset(true, keys, current, count)
        i += 1
    end
    nothing
end
function _g25_key_equal(a::Any, b::Any)
    a isa Tuple && b isa Tuple && fieldcount(typeof(a)) == fieldcount(typeof(b)) || return false
    i = 1
    while i <= fieldcount(typeof(a))
        invoke(_g25_atom_equal, Tuple{Any,Any}, getfield(a, i), getfield(b, i)) || return false
        i += 1
    end
    true
end
_g25_text_equal(a::String, b::String) = invoke(==, Tuple{String,String}, a, b)
function _g25_atom_equal(a::Any, b::Any)
    typeof(a) === typeof(b) || return false
    if a isa Tuple
        return invoke(_g25_key_equal, Tuple{Any,Any}, a, b)
    elseif a isa String
        return invoke(==, Tuple{String,String}, a, b)
    else
        return a === b || invoke(==, Tuple{typeof(a),typeof(b)}, a, b)
    end
end
function _g25_atom_less(a::Any, b::Any)
    typeof(a) === typeof(b) ||
        return invoke(isless, Tuple{String,String}, string(typeof(a)), string(typeof(b)))
    typeof(a) === Nothing && return false
    invoke(isless, Tuple{typeof(a),typeof(b)}, a, b)
end
function _g25_key_less(a::Any, b::Any)
    a isa Tuple && b isa Tuple || return invoke(_g25_atom_less, Tuple{Any,Any}, a, b)
    a_count = fieldcount(typeof(a))
    b_count = fieldcount(typeof(b))
    common_count = min(a_count, b_count)
    i = 1
    while i <= common_count
        left = getfield(a, i)
        right = getfield(b, i)
        invoke(_g25_atom_equal, Tuple{Any,Any}, left, right) ||
            return invoke(_g25_key_less, Tuple{Any,Any}, left, right)
        i += 1
    end
    a_count < b_count
end
_g25_frame_key(value::CoordinateFrameRefV1) = (value.value,)
_g25_chart_key(value::CoordinateChartGeneV1) =
    (value.chart_ref.value, value.frame_ref.value, value.chart_bounds,
     value.periodic_axes, value.coordinate_map_root, value.metric_program_root)
_g25_transition_key(value::ChartTransitionMapGeneV1) =
    (value.source_chart_ref.value, value.target_chart_ref.value, value.transition_map_root)

function _g25_sorted(values::Tuple, key::Function)
    value_count = fieldcount(typeof(values))
    items = Vector{Any}(undef, value_count)
    i = 1
    while i <= value_count
        Core.arrayset(true, items, getfield(values, i), i)
        i += 1
    end
    i = 2
    while i <= value_count
        current = Core.arrayref(true, items, i)
        current_key = key(current)
        j = i - 1
        prior_key = j >= 1 ? key(Core.arrayref(true, items, j)) : nothing
        while j >= 1 && invoke(_g25_key_less, Tuple{Any,Any}, current_key, prior_key)
            Core.arrayset(true, items, Core.arrayref(true, items, j), j + 1)
            j -= 1
            j >= 1 && (prior_key = key(Core.arrayref(true, items, j)))
        end
        Core.arrayset(true, items, current, j + 1)
        i += 1
    end
    ntuple(i -> Core.arrayref(true, items, i), value_count)
end

function _g25_root_signature(root::SpatialProgramRootRefV1)
    (invoke(_g25_type_key, Tuple{PhysicalType}, root.declared_input_type),
     invoke(_g25_type_key, Tuple{PhysicalType}, root.declared_type))
end
function _g25_type_key(value::PhysicalType)
    temporal = value.temporal_type
    clock = temporal.clock_ref === nothing ? nothing :
        (temporal.clock_ref.id, temporal.clock_ref.version)
    (value.value_kind, value.tensor_rank, value.spatial_dimension, temporal.kind,
     temporal.derivative_order, clock, invoke(_g25_unit_key, Tuple{UnitSignature}, value.units))
end
function _g25_unit_key(value::UnitSignature)
    ntuple(i -> begin
        exponent = getfield(value.exponents, i)
        (numerator(exponent), denominator(exponent))
    end, fieldcount(typeof(value.exponents)))
end
function _g25_quantity_key(value::NonnegativeQuantityV1)
    (invoke(_g25_unit_key, Tuple{UnitSignature}, value.unit), numerator(value.value), denominator(value.value))
end
function _g25_interval_key(value::QuantityIntervalV1)
    interval = value.interval
    (invoke(_g25_unit_key, Tuple{UnitSignature}, value.unit), interval.allow_equal, numerator(interval.lower),
     denominator(interval.lower), numerator(interval.upper), denominator(interval.upper))
end
function _g25_root_key(value::SpatialProgramRootRefV1)
    (value.operator_site_ref.value, value.root_position,
     invoke(_g25_root_signature, Tuple{SpatialProgramRootRefV1}, value))
end
function _g25_chart_structural_key(value::CoordinateChartGeneV1)
    bounds = ntuple(i -> invoke(_g25_interval_key, Tuple{QuantityIntervalV1}, getfield(value.chart_bounds, i)),
                    fieldcount(typeof(value.chart_bounds)))
    axes = ntuple(i -> invoke(_g25_axis_key, Tuple{PeriodicAxisV1}, getfield(value.periodic_axes, i)),
                  fieldcount(typeof(value.periodic_axes)))
    (value.chart_ref.value, value.frame_ref.value, bounds, axes,
     invoke(_g25_root_key, Tuple{SpatialProgramRootRefV1}, value.coordinate_map_root),
     invoke(_g25_root_key, Tuple{SpatialProgramRootRefV1}, value.metric_program_root))
end
function _g25_axis_key(value::PeriodicAxisV1)
    (value.axis_position, invoke(_g25_quantity_key, Tuple{NonnegativeQuantityV1}, value.period))
end
function _g25_transition_structural_key(value::ChartTransitionMapGeneV1)
    (value.source_chart_ref.value, value.target_chart_ref.value,
     invoke(_g25_root_key, Tuple{SpatialProgramRootRefV1}, value.transition_map_root))
end
function _g25_root_at(charts::Tuple, transitions::Tuple, position::Int)
    chart_count = fieldcount(typeof(charts))
    position >= 1 && position <= 2 * chart_count + fieldcount(typeof(transitions)) ||
        throw(ArgumentError("root position is outside the spatial support declaration"))
    if position <= 2 * chart_count
        chart = getfield(charts, (position + 1) ÷ 2)
        return iseven(position) ? chart.metric_program_root : chart.coordinate_map_root
    end
    getfield(getfield(transitions, position - 2 * chart_count), :transition_map_root)
end

struct SpatialSupportGeneV1
    support_ref::SpatialSupportRefV1
    ambient_dimension::Int64
    coordinate_frame_refs::Tuple{Vararg{CoordinateFrameRefV1}}
    charts::Tuple{Vararg{CoordinateChartGeneV1}}
    chart_transition_maps::Tuple{Vararg{ChartTransitionMapGeneV1}}
    resolution_independent_scale::NonnegativeQuantityV1
    function SpatialSupportGeneV1(support_ref::Any, ambient_dimension::Any,
                                  coordinate_frame_refs::Any, charts::Any,
                                  chart_transition_maps::Any,
                                  resolution_independent_scale::Any)
        support_ref isa SpatialSupportRefV1 || throw(ArgumentError("support_ref must be SpatialSupportRefV1"))
        dimension = invoke(_g25_signed_int64, Tuple{Any,Any}, ambient_dimension, "ambient_dimension")
        dimension == 3 || throw(ArgumentError("ambient_dimension must be exactly 3"))
        coordinate_frame_refs isa Tuple && !(coordinate_frame_refs isa NamedTuple) ||
            throw(ArgumentError("coordinate_frame_refs must be an immutable tuple"))
        charts isa Tuple && !(charts isa NamedTuple) ||
            throw(ArgumentError("charts must be an immutable tuple"))
        chart_transition_maps isa Tuple && !(chart_transition_maps isa NamedTuple) ||
            throw(ArgumentError("chart_transition_maps must be an immutable tuple"))
        i = 1
        while i <= fieldcount(typeof(coordinate_frame_refs))
            typeof(getfield(coordinate_frame_refs, i)) === CoordinateFrameRefV1 ||
                throw(ArgumentError("coordinate_frame_refs must contain CoordinateFrameRefV1 values"))
            i += 1
        end
        i = 1
        while i <= fieldcount(typeof(charts))
            typeof(getfield(charts, i)) === CoordinateChartGeneV1 ||
                throw(ArgumentError("charts must contain CoordinateChartGeneV1 values"))
            i += 1
        end
        i = 1
        while i <= fieldcount(typeof(chart_transition_maps))
            typeof(getfield(chart_transition_maps, i)) === ChartTransitionMapGeneV1 ||
                throw(ArgumentError("chart_transition_maps must contain ChartTransitionMapGeneV1 values"))
            i += 1
        end
        frame_count = fieldcount(typeof(coordinate_frame_refs))
        chart_count = fieldcount(typeof(charts))
        transition_count = fieldcount(typeof(chart_transition_maps))
        1 <= frame_count <= 4 ||
            throw(ArgumentError("coordinate_frame_refs count must be in 1:4"))
        1 <= chart_count <= 4 || throw(ArgumentError("charts count must be in 1:4"))
        transition_count <= 12 ||
            throw(ArgumentError("chart_transition_maps count must be in 0:12"))
        invoke(_g25_tuple_unique, Tuple{Tuple,Function,String}, coordinate_frame_refs,
               _g25_frame_key, "coordinate_frame_refs")
        invoke(_g25_tuple_unique, Tuple{Tuple,Function,String}, charts,
            chart -> (chart.chart_ref.value,), "chart references")
        invoke(_g25_tuple_unique, Tuple{Tuple,Function,String}, chart_transition_maps,
            transition -> (transition.source_chart_ref.value, transition.target_chart_ref.value),
            "chart transition directed pairs")
        i = 1
        while i <= fieldcount(typeof(charts))
            chart = getfield(charts, i)
            j = 1
            found = false
            while j <= fieldcount(typeof(coordinate_frame_refs))
                frame = getfield(coordinate_frame_refs, j)
                found = invoke(_g25_text_equal, Tuple{String,String}, frame.value, chart.frame_ref.value)
                found && break
                j += 1
            end
            found ||
                throw(ArgumentError("chart frame reference must resolve in coordinate_frame_refs"))
            i += 1
        end
        i = 1
        while i <= fieldcount(typeof(coordinate_frame_refs))
            frame = getfield(coordinate_frame_refs, i)
            j = 1
            found = false
            while j <= fieldcount(typeof(charts))
                chart = getfield(charts, j)
                found = invoke(_g25_text_equal, Tuple{String,String}, chart.frame_ref.value, frame.value)
                found && break
                j += 1
            end
            found ||
                throw(ArgumentError("every coordinate frame must be used by a chart"))
            i += 1
        end
        i = 1
        while i <= fieldcount(typeof(chart_transition_maps))
            transition = getfield(chart_transition_maps, i)
            j = 1
            found = false
            while j <= fieldcount(typeof(charts))
                chart = getfield(charts, j)
                found = invoke(_g25_text_equal, Tuple{String,String}, chart.chart_ref.value, transition.source_chart_ref.value)
                found && break
                j += 1
            end
            found ||
                throw(ArgumentError("transition source chart reference must resolve"))
            j = 1
            found = false
            while j <= fieldcount(typeof(charts))
                chart = getfield(charts, j)
                found = invoke(_g25_text_equal, Tuple{String,String}, chart.chart_ref.value, transition.target_chart_ref.value)
                found && break
                j += 1
            end
            found ||
                throw(ArgumentError("transition target chart reference must resolve"))
            i += 1
        end
        root_count = 2 * fieldcount(typeof(charts)) + fieldcount(typeof(chart_transition_maps))
        signatures = Vector{Tuple{String,Int64,Any}}(undef, root_count)
        signature_count = 0
        i = 1
        while i <= root_count
            root = invoke(_g25_root_at, Tuple{Tuple,Tuple,Int}, charts, chart_transition_maps, i)
            key = (root.operator_site_ref.value, root.root_position)
            signature = invoke(_g25_root_signature, Tuple{SpatialProgramRootRefV1}, root)
            j = 1
            while j <= signature_count
                prior = Core.arrayref(true, signatures, j)
                same_identity = invoke(_g25_text_equal, Tuple{String,String},
                                       getfield(prior, 1), getfield(key, 1)) &&
                    getfield(prior, 2) === getfield(key, 2)
                if same_identity
                    invoke(_g25_key_equal, Tuple{Any,Any}, getfield(prior, 3), signature) ||
                        throw(ArgumentError("program root position is reused with a conflicting signature"))
                end
                j += 1
            end
            signature_count += 1
            Core.arrayset(true, signatures,
                          (getfield(key, 1), getfield(key, 2), signature), signature_count)
            i += 1
        end
        resolution_independent_scale isa NonnegativeQuantityV1 ||
            throw(ArgumentError("resolution_independent_scale must be NonnegativeQuantityV1"))
        resolution_independent_scale.value > 0 ||
            throw(ArgumentError("resolution_independent_scale must be strictly positive"))
        invoke(_g25_si_length, Tuple{UnitSignature}, resolution_independent_scale.unit) ||
            throw(ArgumentError("resolution_independent_scale must use SI length units"))
        sorted_frames = invoke(_g25_sorted, Tuple{Tuple,Function}, coordinate_frame_refs, _g25_frame_key)
        sorted_charts = invoke(_g25_sorted, Tuple{Tuple,Function}, charts, _g25_chart_structural_key)
        sorted_transitions = invoke(_g25_sorted, Tuple{Tuple,Function}, chart_transition_maps, _g25_transition_structural_key)
        new(support_ref, dimension, sorted_frames, sorted_charts, sorted_transitions,
            resolution_independent_scale)
    end
end
Base.:(==)(a::SpatialSupportGeneV1, b::SpatialSupportGeneV1) =
    a.support_ref == b.support_ref && a.ambient_dimension == b.ambient_dimension &&
    a.coordinate_frame_refs == b.coordinate_frame_refs && a.charts == b.charts &&
    a.chart_transition_maps == b.chart_transition_maps &&
    a.resolution_independent_scale == b.resolution_independent_scale
Base.hash(a::SpatialSupportGeneV1, h::UInt) = hash((a.support_ref, a.ambient_dimension,
    a.coordinate_frame_refs, a.charts, a.chart_transition_maps,
    a.resolution_independent_scale), h)
semantic_view(a::SpatialSupportGeneV1) =
    (support_ref=a.support_ref, ambient_dimension=a.ambient_dimension,
     coordinate_frame_refs=a.coordinate_frame_refs, charts=a.charts,
     chart_transition_maps=a.chart_transition_maps,
     resolution_independent_scale=a.resolution_independent_scale)

chart_count(value::SpatialSupportGeneV1)::Int = fieldcount(typeof(value.charts))
