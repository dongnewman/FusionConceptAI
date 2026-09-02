"""Closed canonical bytes and hashes for the G2 5.2 spatial-support grammar."""

function _g25_write_byte(io::Base.GenericIOBuffer, value::UInt8)
    invoke(write, Tuple{Base.GenericIOBuffer,UInt8}, io, value)
    nothing
end

function _g25_write_ascii(io::Base.GenericIOBuffer, value::String)
    count = Core.sizeof(value)
    GC.@preserve value begin
        pointer = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), value)
        index = 0
        while index < count
            byte = invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, pointer, index + 1)
            invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, byte)
            index += 1
        end
    end
    nothing
end

function _g25_hex_digit(value::UInt8)::UInt8
    value < UInt8(10) ? UInt8(0x30) + value : UInt8(0x61) + (value - UInt8(10))
end

function _g25_write_hex2(io::Base.GenericIOBuffer, value::UInt8)
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io,
           invoke(_g25_hex_digit, Tuple{UInt8}, value >>> 4))
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io,
           invoke(_g25_hex_digit, Tuple{UInt8}, value & UInt8(0x0f)))
    nothing
end

function _g25_write_quoted(io::Base.GenericIOBuffer, value::String)
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x22))
    count = Core.sizeof(value)
    GC.@preserve value begin
        pointer = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), value)
        index = 0
        while index < count
            byte = invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, pointer, index + 1)
            if byte == UInt8(0x22)
                invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "\\\"")
            elseif byte == UInt8(0x5c)
                invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "\\\\")
            elseif byte == UInt8(0x08)
                invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "\\b")
            elseif byte == UInt8(0x0c)
                invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "\\f")
            elseif byte == UInt8(0x0a)
                invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "\\n")
            elseif byte == UInt8(0x0d)
                invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "\\r")
            elseif byte == UInt8(0x09)
                invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "\\t")
            elseif byte < UInt8(0x20)
                invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "\\u00")
                invoke(_g25_write_hex2, Tuple{Base.GenericIOBuffer,UInt8}, io, byte)
            else
                invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, byte)
            end
            index += 1
        end
    end
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x22))
    nothing
end

function _g25_write_uint64(io::Base.GenericIOBuffer, value::UInt64)
    divisor = UInt64(1)
    while divisor <= value ÷ UInt64(10)
        divisor *= UInt64(10)
    end
    while true
        digit = value ÷ divisor
        invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io,
               UInt8(0x30) + UInt8(digit))
        value -= digit * divisor
        divisor == UInt64(1) && break
        divisor ÷= UInt64(10)
    end
    nothing
end

function _g25_write_int64(io::Base.GenericIOBuffer, value::Int64)
    if value < 0
        invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2d))
        magnitude = UInt64(-(value + Int64(1))) + UInt64(1)
    else
        magnitude = UInt64(value)
    end
    invoke(_g25_write_uint64, Tuple{Base.GenericIOBuffer,UInt64}, io, magnitude)
    nothing
end

function _g25_finish(io::Base.GenericIOBuffer)::String
    bytes = invoke(take!, Tuple{Base.GenericIOBuffer}, io)
    invoke(String, Tuple{Vector{UInt8}}, bytes)
end

function _g25_quote(value::String)
    io = IOBuffer()
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end

function _g25_write_rational(io::Base.GenericIOBuffer, value::Rational{Int64})
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"denominator\":")
    invoke(_g25_write_int64, Tuple{Base.GenericIOBuffer,Int64}, io, getfield(value, :den))
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"numerator\":")
    invoke(_g25_write_int64, Tuple{Base.GenericIOBuffer,Int64}, io, getfield(value, :num))
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g25_write_unit(io::Base.GenericIOBuffer, value::UnitSignature)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"exponents\":[")
    i = 1
    count = fieldcount(typeof(value.exponents))
    while i <= count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_g25_write_rational, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io,
               getfield(value.exponents, i))
        i += 1
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "]}")
    nothing
end

function _g25_unit(value::UnitSignature)
    io = IOBuffer()
    invoke(_g25_write_unit, Tuple{Base.GenericIOBuffer,UnitSignature}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end

function _g25_write_quantity(io::Base.GenericIOBuffer, value::NonnegativeQuantityV1)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"unit\":")
    invoke(_g25_write_unit, Tuple{Base.GenericIOBuffer,UnitSignature}, io, value.unit)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"value\":")
    invoke(_g25_write_rational, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io, value.value)
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g25_write_interval(io::Base.GenericIOBuffer, value::QuantityIntervalV1)
    interval = value.interval
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"allow_equal\":")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io,
           interval.allow_equal ? "true" : "false")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"lower\":")
    invoke(_g25_write_rational, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io, interval.lower)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"upper\":")
    invoke(_g25_write_rational, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io, interval.upper)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"unit\":")
    invoke(_g25_write_unit, Tuple{Base.GenericIOBuffer,UnitSignature}, io, value.unit)
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g25_write_time_kind(io::Base.GenericIOBuffer, value::TimeKindV1)
    if value === static_time
        text = "\"static_time\""
    elseif value === algebraic_time
        text = "\"algebraic_time\""
    elseif value === differential_time
        text = "\"differential_time\""
    elseif value === discrete_time
        text = "\"discrete_time\""
    elseif value === event_time
        text = "\"event_time\""
    else
        throw(ArgumentError("unknown temporal kind"))
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, text)
    nothing
end

function _g25_write_temporal(io::Base.GenericIOBuffer, value::TemporalTypeV1)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"clock_ref\":")
    if value.clock_ref === nothing
        invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "null")
    else
        invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"id\":")
        invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value.clock_ref.id)
        invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"version\":")
        invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value.clock_ref.version)
        invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"derivative_order\":")
    invoke(_g25_write_int64, Tuple{Base.GenericIOBuffer,Int64}, io, Int64(value.derivative_order))
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"kind\":")
    invoke(_g25_write_time_kind, Tuple{Base.GenericIOBuffer,TimeKindV1}, io, value.kind)
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g25_write_symbol(io::Base.GenericIOBuffer, value::Symbol)
    text = invoke(String, Tuple{Symbol}, value)
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, text)
    nothing
end

function _g25_write_physical_type(io::Base.GenericIOBuffer, value::PhysicalType)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"spatial_dimension\":")
    invoke(_g25_write_int64, Tuple{Base.GenericIOBuffer,Int64}, io, Int64(value.spatial_dimension))
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"tensor_rank\":")
    invoke(_g25_write_int64, Tuple{Base.GenericIOBuffer,Int64}, io, Int64(value.tensor_rank))
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"temporal_type\":")
    invoke(_g25_write_temporal, Tuple{Base.GenericIOBuffer,TemporalTypeV1}, io, value.temporal_type)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"units\":")
    invoke(_g25_write_unit, Tuple{Base.GenericIOBuffer,UnitSignature}, io, value.units)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"value_kind\":")
    invoke(_g25_write_symbol, Tuple{Base.GenericIOBuffer,Symbol}, io, value.value_kind)
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g25_write_wrap_start(io::Base.GenericIOBuffer, domain::String, kind::String)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io,
           "{\"canonicalization_version\":\"1\",\"domain\":")
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, domain)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"kind\":")
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, kind)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"payload\":")
    nothing
end
function _g25_write_wrap_end(io::Base.GenericIOBuffer)
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g25_write_ref_wire(io::Base.GenericIOBuffer, domain::String, kind::String, value::String)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io, domain, kind)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"value\":")
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value)
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g25_write_root_wire(io::Base.GenericIOBuffer, value::SpatialProgramRootRefV1)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           "fusionconceptai:v4:g2:spatial_program_root_ref:v1", "spatial_program_root_ref")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"declared_input_type\":")
    invoke(_g25_write_physical_type, Tuple{Base.GenericIOBuffer,PhysicalType}, io, value.declared_input_type)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"declared_type\":")
    invoke(_g25_write_physical_type, Tuple{Base.GenericIOBuffer,PhysicalType}, io, value.declared_type)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"operator_site_ref\":{\"value\":")
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value.operator_site_ref.value)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "},\"root_position\":")
    invoke(_g25_write_int64, Tuple{Base.GenericIOBuffer,Int64}, io, value.root_position)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "}")
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g25_write_axis_wire(io::Base.GenericIOBuffer, value::PeriodicAxisV1)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           "fusionconceptai:v4:g2:periodic_axis:v1", "periodic_axis")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"axis_position\":")
    invoke(_g25_write_int64, Tuple{Base.GenericIOBuffer,Int64}, io, value.axis_position)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"period\":")
    invoke(_g25_write_quantity, Tuple{Base.GenericIOBuffer,NonnegativeQuantityV1}, io, value.period)
    invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g25_write_chart_wire(io::Base.GenericIOBuffer, value::CoordinateChartGeneV1)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           "fusionconceptai:v4:g2:coordinate_chart_gene:v1", "coordinate_chart_gene")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"chart_bounds\":[")
    i = 1
    bound_count = fieldcount(typeof(value.chart_bounds))
    while i <= bound_count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_g25_write_interval, Tuple{Base.GenericIOBuffer,QuantityIntervalV1}, io,
               getfield(value.chart_bounds, i))
        i += 1
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "],\"chart_ref\":{\"value\":")
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value.chart_ref.value)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "},\"coordinate_map_root\":")
    invoke(_g25_write_root_wire, Tuple{Base.GenericIOBuffer,SpatialProgramRootRefV1}, io, value.coordinate_map_root)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"frame_ref\":{\"value\":")
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value.frame_ref.value)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "},\"metric_program_root\":")
    invoke(_g25_write_root_wire, Tuple{Base.GenericIOBuffer,SpatialProgramRootRefV1}, io, value.metric_program_root)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"periodic_axes\":[")
    i = 1
    axis_count = fieldcount(typeof(value.periodic_axes))
    while i <= axis_count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_g25_write_axis_wire, Tuple{Base.GenericIOBuffer,PeriodicAxisV1}, io,
               getfield(value.periodic_axes, i))
        i += 1
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "]}")
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g25_write_transition_wire(io::Base.GenericIOBuffer, value::ChartTransitionMapGeneV1)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           "fusionconceptai:v4:g2:chart_transition_map_gene:v1", "chart_transition_map_gene")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"source_chart_ref\":{\"value\":")
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value.source_chart_ref.value)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "},\"target_chart_ref\":{\"value\":")
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value.target_chart_ref.value)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "},\"transition_map_root\":")
    invoke(_g25_write_root_wire, Tuple{Base.GenericIOBuffer,SpatialProgramRootRefV1}, io, value.transition_map_root)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "}")
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g25_write_support_wire(io::Base.GenericIOBuffer, value::SpatialSupportGeneV1)
    invoke(_g25_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           "fusionconceptai:v4:g2:spatial_support_gene:v1", "spatial_support_gene")
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"ambient_dimension\":")
    invoke(_g25_write_int64, Tuple{Base.GenericIOBuffer,Int64}, io, value.ambient_dimension)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"chart_transition_maps\":[")
    i = 1
    transition_count = fieldcount(typeof(value.chart_transition_maps))
    while i <= transition_count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_g25_write_transition_wire, Tuple{Base.GenericIOBuffer,ChartTransitionMapGeneV1}, io,
               getfield(value.chart_transition_maps, i))
        i += 1
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "],\"charts\":[")
    i = 1
    chart_count = fieldcount(typeof(value.charts))
    while i <= chart_count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_g25_write_chart_wire, Tuple{Base.GenericIOBuffer,CoordinateChartGeneV1}, io,
               getfield(value.charts, i))
        i += 1
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "],\"coordinate_frame_refs\":[")
    i = 1
    frame_count = fieldcount(typeof(value.coordinate_frame_refs))
    while i <= frame_count
        i > 1 && invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "{\"value\":")
        frame = getfield(value.coordinate_frame_refs, i)
        invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, frame.value)
        invoke(_g25_write_byte, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
        i += 1
    end
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "],\"resolution_independent_scale\":")
    invoke(_g25_write_quantity, Tuple{Base.GenericIOBuffer,NonnegativeQuantityV1}, io,
           value.resolution_independent_scale)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, ",\"support_ref\":{\"value\":")
    invoke(_g25_write_quoted, Tuple{Base.GenericIOBuffer,String}, io, value.support_ref.value)
    invoke(_g25_write_ascii, Tuple{Base.GenericIOBuffer,String}, io, "}}")
    invoke(_g25_write_wrap_end, Tuple{Base.GenericIOBuffer}, io)
    nothing
end

function _g25_ref_json(value::FieldOperatorSiteRefV1)
    io = IOBuffer()
    invoke(_g25_write_ref_wire, Tuple{Base.GenericIOBuffer,String,String,String}, io,
           "fusionconceptai:v4:g2:field_operator_site_ref:v1", "field_operator_site_ref", value.value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end
function _g25_root_json(value::SpatialProgramRootRefV1)
    io = IOBuffer()
    invoke(_g25_write_root_wire, Tuple{Base.GenericIOBuffer,SpatialProgramRootRefV1}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end
function _g25_axis_json(value::PeriodicAxisV1)
    io = IOBuffer()
    invoke(_g25_write_axis_wire, Tuple{Base.GenericIOBuffer,PeriodicAxisV1}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end
function _g25_chart_json(value::CoordinateChartGeneV1)
    io = IOBuffer()
    invoke(_g25_write_chart_wire, Tuple{Base.GenericIOBuffer,CoordinateChartGeneV1}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end
function _g25_transition_json(value::ChartTransitionMapGeneV1)
    io = IOBuffer()
    invoke(_g25_write_transition_wire, Tuple{Base.GenericIOBuffer,ChartTransitionMapGeneV1}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end
function _g25_support_json(value::SpatialSupportGeneV1)
    io = IOBuffer()
    invoke(_g25_write_support_wire, Tuple{Base.GenericIOBuffer,SpatialSupportGeneV1}, io, value)
    invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
end

canonical_json(value::FieldOperatorSiteRefV1) = invoke(_g25_ref_json, Tuple{FieldOperatorSiteRefV1}, value)
canonical_json(value::SpatialProgramRootRefV1) = invoke(_g25_root_json, Tuple{SpatialProgramRootRefV1}, value)
canonical_json(value::PeriodicAxisV1) = invoke(_g25_axis_json, Tuple{PeriodicAxisV1}, value)
canonical_json(value::CoordinateChartGeneV1) = invoke(_g25_chart_json, Tuple{CoordinateChartGeneV1}, value)
canonical_json(value::ChartTransitionMapGeneV1) = invoke(_g25_transition_json, Tuple{ChartTransitionMapGeneV1}, value)
canonical_json(value::SpatialSupportGeneV1) = invoke(_g25_support_json, Tuple{SpatialSupportGeneV1}, value)

function _g25_hash_bytes(value::String)::Digest256
    count = Core.sizeof(value)
    bytes = Vector{UInt8}(undef, count)
    GC.@preserve value begin
        pointer = ccall(:jl_string_ptr, Ptr{UInt8}, (Any,), value)
        i = 1
        while i <= count
            byte = invoke(unsafe_load, Tuple{Ptr{UInt8},Integer}, pointer, i)
            Core.arrayset(true, bytes, byte, i)
            i += 1
        end
    end
    digest = invoke(SHA.sha256, Tuple{SHA.AbstractBytes}, bytes)
    io = IOBuffer()
    i = 1
    while i <= 32
        byte = Core.arrayref(true, digest, i)
        invoke(_g25_write_hex2, Tuple{Base.GenericIOBuffer,UInt8}, io, byte)
        i += 1
    end
    hex = invoke(_g25_finish, Tuple{Base.GenericIOBuffer}, io)
    invoke(Digest256, Tuple{AbstractString}, hex)
end

canonical_hash(value::FieldOperatorSiteRefV1) = invoke(_g25_hash_bytes, Tuple{String}, invoke(_g25_ref_json, Tuple{FieldOperatorSiteRefV1}, value))
canonical_hash(value::SpatialProgramRootRefV1) = invoke(_g25_hash_bytes, Tuple{String}, invoke(_g25_root_json, Tuple{SpatialProgramRootRefV1}, value))
canonical_hash(value::PeriodicAxisV1) = invoke(_g25_hash_bytes, Tuple{String}, invoke(_g25_axis_json, Tuple{PeriodicAxisV1}, value))
canonical_hash(value::CoordinateChartGeneV1) = invoke(_g25_hash_bytes, Tuple{String}, invoke(_g25_chart_json, Tuple{CoordinateChartGeneV1}, value))
canonical_hash(value::ChartTransitionMapGeneV1) = invoke(_g25_hash_bytes, Tuple{String}, invoke(_g25_transition_json, Tuple{ChartTransitionMapGeneV1}, value))
canonical_hash(value::SpatialSupportGeneV1) = invoke(_g25_hash_bytes, Tuple{String}, invoke(_g25_support_json, Tuple{SpatialSupportGeneV1}, value))
