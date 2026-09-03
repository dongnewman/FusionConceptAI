"""Closed G3.1 canonical bytes for control-observation requirements."""

const _G31_OBSERVATION_CHANNEL_REF_DOMAIN = "fusionconceptai:v4:g3:observation_channel_ref:v1"
const _G31_OBSERVATION_CHANNEL_REQUIREMENT_DOMAIN = "fusionconceptai:v4:g3:observation_channel_requirement:v1"

# These value writers are deliberately owned by G3.  The requirement wire is
# an independent closed authority: a later or poisoned G2 public helper must
# not be able to change the bytes of a G3 declaration.
function _g31_write_rational(io::Base.GenericIOBuffer, value::Rational{Int64})
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"denominator\":")
    invoke(_ccbw_int64!, Tuple{Base.GenericIOBuffer,Int64}, io, getfield(value, :den))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"numerator\":")
    invoke(_ccbw_int64!, Tuple{Base.GenericIOBuffer,Int64}, io, getfield(value, :num))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g31_write_unit(io::Base.GenericIOBuffer, value::UnitSignature)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"exponents\":[")
    exponents = getfield(value, :exponents)
    i = 1
    count = fieldcount(typeof(exponents))
    while i <= count
        i > 1 && invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x2c))
        invoke(_g31_write_rational, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io,
               getfield(exponents, i))
        i += 1
    end
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "]}")
    nothing
end

function _g31_write_quantity(io::Base.GenericIOBuffer, value::NonnegativeQuantityV1)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"unit\":")
    invoke(_g31_write_unit, Tuple{Base.GenericIOBuffer,UnitSignature}, io, getfield(value, :unit))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"value\":")
    invoke(_g31_write_rational, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io, getfield(value, :value))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g31_write_interval(io::Base.GenericIOBuffer, value::QuantityIntervalV1)
    interval = getfield(value, :interval)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"allow_equal\":")
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io,
           getfield(interval, :allow_equal) ? "true" : "false")
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"lower\":")
    invoke(_g31_write_rational, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io,
           getfield(interval, :lower))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"upper\":")
    invoke(_g31_write_rational, Tuple{Base.GenericIOBuffer,Rational{Int64}}, io,
           getfield(interval, :upper))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"unit\":")
    invoke(_g31_write_unit, Tuple{Base.GenericIOBuffer,UnitSignature}, io, getfield(value, :unit))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g31_write_time_kind(io::Base.GenericIOBuffer, value::TimeKindV1)
    text = value === static_time ? "\"static_time\"" :
           value === algebraic_time ? "\"algebraic_time\"" :
           value === differential_time ? "\"differential_time\"" :
           value === discrete_time ? "\"discrete_time\"" :
           value === event_time ? "\"event_time\"" :
           throw(ArgumentError("unknown temporal kind"))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, text)
    nothing
end

function _g31_write_temporal(io::Base.GenericIOBuffer, value::TemporalTypeV1)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"clock_ref\":")
    clock = getfield(value, :clock_ref)
    if clock === nothing
        invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "null")
    else
        invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"id\":")
        invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, getfield(clock, :id))
        invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"version\":")
        invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, getfield(clock, :version))
        invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    end
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"derivative_order\":")
    invoke(_ccbw_int64!, Tuple{Base.GenericIOBuffer,Int64}, io, Int64(getfield(value, :derivative_order)))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"kind\":")
    invoke(_g31_write_time_kind, Tuple{Base.GenericIOBuffer,TimeKindV1}, io, getfield(value, :kind))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g31_write_physical_type(io::Base.GenericIOBuffer, value::PhysicalType)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"spatial_dimension\":")
    invoke(_ccbw_int64!, Tuple{Base.GenericIOBuffer,Int64}, io, Int64(getfield(value, :spatial_dimension)))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"tensor_rank\":")
    invoke(_ccbw_int64!, Tuple{Base.GenericIOBuffer,Int64}, io, Int64(getfield(value, :tensor_rank)))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"temporal_type\":")
    invoke(_g31_write_temporal, Tuple{Base.GenericIOBuffer,TemporalTypeV1}, io, getfield(value, :temporal_type))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"units\":")
    invoke(_g31_write_unit, Tuple{Base.GenericIOBuffer,UnitSignature}, io, getfield(value, :units))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"value_kind\":")
    invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io,
           invoke(String, Tuple{Symbol}, getfield(value, :value_kind)))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g31_write_ref_payload(io::Base.GenericIOBuffer, value::String)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"value\":")
    invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, value)
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g31_write_digest_payload(io::Base.GenericIOBuffer, value::Digest256)
    invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, getfield(value, :value))
    nothing
end

function _g31_write_wrap_start(io::Base.GenericIOBuffer, domain::String, kind::String)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io,
           "{\"canonicalization_version\":\"1\",\"domain\":")
    invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, domain)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"kind\":")
    invoke(_ccbw_quote!, Tuple{Base.GenericIOBuffer,AbstractString}, io, kind)
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"payload\":")
    nothing
end

function _g31_write_ref_wire(io::Base.GenericIOBuffer, value::ObservationChannelRefV1)
    invoke(_g31_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           _G31_OBSERVATION_CHANNEL_REF_DOMAIN, "observation_channel_ref")
    invoke(_g31_write_ref_payload, Tuple{Base.GenericIOBuffer,String}, io, getfield(value, :value))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g31_write_requirement_wire(io::Base.GenericIOBuffer, value::ObservationChannelRequirementV1)
    invoke(_g31_write_wrap_start, Tuple{Base.GenericIOBuffer,String,String}, io,
           _G31_OBSERVATION_CHANNEL_REQUIREMENT_DOMAIN, "observation_channel_requirement")
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, "{\"channel_ref\":")
    invoke(_g31_write_ref_payload, Tuple{Base.GenericIOBuffer,String}, io, getfield(getfield(value, :channel_ref), :value))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"maximum_latency\":")
    invoke(_g31_write_quantity, Tuple{Base.GenericIOBuffer,NonnegativeQuantityV1}, io, getfield(value, :maximum_latency))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"maximum_resolution\":")
    invoke(_g31_write_quantity, Tuple{Base.GenericIOBuffer,NonnegativeQuantityV1}, io, getfield(value, :maximum_resolution))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"maximum_sampling_period\":")
    invoke(_g31_write_quantity, Tuple{Base.GenericIOBuffer,NonnegativeQuantityV1}, io, getfield(value, :maximum_sampling_period))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"measurement_type\":")
    invoke(_g31_write_physical_type, Tuple{Base.GenericIOBuffer,PhysicalType}, io, getfield(value, :measurement_type))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"minimum_bandwidth\":")
    invoke(_g31_write_quantity, Tuple{Base.GenericIOBuffer,NonnegativeQuantityV1}, io, getfield(value, :minimum_bandwidth))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"observable_content_hash\":")
    invoke(_g31_write_digest_payload, Tuple{Base.GenericIOBuffer,Digest256}, io, getfield(value, :observable_content_hash))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"observable_ref\":")
    invoke(_g31_write_ref_payload, Tuple{Base.GenericIOBuffer,String}, io, getfield(getfield(value, :observable_ref), :value))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"required_measurement_range\":")
    invoke(_g31_write_interval, Tuple{Base.GenericIOBuffer,QuantityIntervalV1}, io, getfield(value, :required_measurement_range))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"spatial_support_content_hash\":")
    invoke(_g31_write_digest_payload, Tuple{Base.GenericIOBuffer,Digest256}, io, getfield(value, :spatial_support_content_hash))
    invoke(_ccbw_ascii!, Tuple{Base.GenericIOBuffer,String}, io, ",\"spatial_support_ref\":")
    invoke(_g31_write_ref_payload, Tuple{Base.GenericIOBuffer,String}, io, getfield(getfield(value, :spatial_support_ref), :value))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    invoke(_ccbw_byte!, Tuple{Base.GenericIOBuffer,UInt8}, io, UInt8(0x7d))
    nothing
end

function _g31_channel_ref_json(value::ObservationChannelRefV1)
    io = invoke(_ccbw_new, Tuple{})
    invoke(_g31_write_ref_wire, Tuple{Base.GenericIOBuffer,ObservationChannelRefV1}, io, value)
    invoke(_ccbw_finish, Tuple{Base.GenericIOBuffer}, io)
end

function _g31_requirement_json(value::ObservationChannelRequirementV1)
    io = invoke(_ccbw_new, Tuple{})
    invoke(_g31_write_requirement_wire, Tuple{Base.GenericIOBuffer,ObservationChannelRequirementV1}, io, value)
    invoke(_ccbw_finish, Tuple{Base.GenericIOBuffer}, io)
end

canonical_json(value::ObservationChannelRefV1) =
    invoke(_g31_channel_ref_json, Tuple{ObservationChannelRefV1}, value)
canonical_json(value::ObservationChannelRequirementV1) =
    invoke(_g31_requirement_json, Tuple{ObservationChannelRequirementV1}, value)

canonical_hash(value::ObservationChannelRefV1) =
    invoke(_ccbw_hash_bytes, Tuple{String}, invoke(_g31_channel_ref_json, Tuple{ObservationChannelRefV1}, value))
canonical_hash(value::ObservationChannelRequirementV1) =
    invoke(_ccbw_hash_bytes, Tuple{String}, invoke(_g31_requirement_json, Tuple{ObservationChannelRequirementV1}, value))
