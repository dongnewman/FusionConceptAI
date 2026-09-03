"""G3.1 observation-channel requirement record and closed validation."""

function _g31_exact(value::Any, expected::Type, field::String)
    typeof(value) === expected || throw(ArgumentError("$field must be $(expected)"))
    value
end

function _g31_rational_le(a::Rational{Int64}, b::Rational{Int64})
    BigInt(getfield(a, :num)) * BigInt(getfield(b, :den)) <=
        BigInt(getfield(b, :num)) * BigInt(getfield(a, :den))
end

function _g31_rational_ge(a::Rational{Int64}, b::Rational{Int64})
    BigInt(getfield(a, :num)) * BigInt(getfield(b, :den)) >=
        BigInt(getfield(b, :num)) * BigInt(getfield(a, :den))
end

function _g31_rational_positive(value::Rational{Int64})
    BigInt(getfield(value, :num)) > BigInt(0)
end

function _g31_rational_gt_sum(a::Rational{Int64}, b::Rational{Int64},
                              c::Rational{Int64}, d::Rational{Int64})
    an, ad = BigInt(getfield(a, :num)), BigInt(getfield(a, :den))
    bn, bd = BigInt(getfield(b, :num)), BigInt(getfield(b, :den))
    cn, cd = BigInt(getfield(c, :num)), BigInt(getfield(c, :den))
    dn, dd = BigInt(getfield(d, :num)), BigInt(getfield(d, :den))
    an * bd * cd * dd > bn * ad * cd * dd + cn * ad * bd * dd + dn * ad * bd * cd
end

function _g31_unit_matches(a::UnitSignature, b::UnitSignature)
    ae = getfield(a, :exponents)
    be = getfield(b, :exponents)
    i = 1
    while i <= 7
        av = getfield(ae, i)
        bv = getfield(be, i)
        BigInt(getfield(av, :num)) * BigInt(getfield(bv, :den)) ==
            BigInt(getfield(bv, :num)) * BigInt(getfield(av, :den)) || return false
        i += 1
    end
    true
end

function _g31_unit_exponents(value::UnitSignature, expected::NTuple{7,Int64})
    exponents = getfield(value, :exponents)
    i = 1
    while i <= 7
        actual = getfield(exponents, i)
        expected_value = getfield(expected, i)
        getfield(actual, :num) == expected_value && getfield(actual, :den) == Int64(1) || return false
        i += 1
    end
    true
end

const _G31_TIME_UNITS = (Int64(0), Int64(0), Int64(1), Int64(0), Int64(0), Int64(0), Int64(0))
const _G31_INV_TIME_UNITS = (Int64(0), Int64(0), Int64(-1), Int64(0), Int64(0), Int64(0), Int64(0))

function _g31_sampling_output_type(observable::ObservableGeneV1)
    program = getfield(observable, :sampling_program)
    roots = getfield(program, :roots)
    fieldcount(typeof(roots)) == 1 || throw(ArgumentError("observable sampling program must have one root"))
    root_position = getfield(roots, 1)
    nodes = getfield(program, :nodes)
    root = getfield(nodes, root_position)
    root_type = typeof(root)
    (root_type === ASTInputV1 || root_type === ASTParameterV1 ||
     root_type === ASTConstantV1 || root_type === ASTApplyV1) ||
        throw(ArgumentError("observable sampling program contains an unsealed root node kind"))
    output_type = getfield(root, :output_type)
    typeof(output_type) === PhysicalType ||
        throw(ArgumentError("observable sampling root output type is not a sealed PhysicalType"))
    output_type
end

function _g31_observable_hash(observable::ObservableGeneV1)
    invoke(_g1_observable_canonical_hash, Tuple{ObservableGeneV1}, observable)
end

function _g31_support_hash(support::SpatialSupportGeneV1)
    invoke(_g25_support_canonical_hash, Tuple{SpatialSupportGeneV1}, support)
end

struct ObservationChannelRequirementV1
    channel_ref::ObservationChannelRefV1
    observable_ref::ObservableRefV1
    observable_content_hash::Digest256
    spatial_support_ref::SpatialSupportRefV1
    spatial_support_content_hash::Digest256
    measurement_type::PhysicalType
    maximum_sampling_period::NonnegativeQuantityV1
    maximum_latency::NonnegativeQuantityV1
    minimum_bandwidth::NonnegativeQuantityV1
    required_measurement_range::QuantityIntervalV1
    maximum_resolution::NonnegativeQuantityV1
    function ObservationChannelRequirementV1(channel_ref::Any, observable::Any, spatial_support::Any,
                                             maximum_sampling_period::Any, maximum_latency::Any,
                                             minimum_bandwidth::Any, required_measurement_range::Any,
                                             maximum_resolution::Any)
        channel = invoke(_g31_exact, Tuple{Any,Type,String}, channel_ref, ObservationChannelRefV1, "channel_ref")
        observable_value = invoke(_g31_exact, Tuple{Any,Type,String}, observable, ObservableGeneV1, "observable")
        support_value = invoke(_g31_exact, Tuple{Any,Type,String}, spatial_support, SpatialSupportGeneV1, "spatial_support")
        sampling = invoke(_g31_exact, Tuple{Any,Type,String}, maximum_sampling_period, NonnegativeQuantityV1, "maximum_sampling_period")
        latency = invoke(_g31_exact, Tuple{Any,Type,String}, maximum_latency, NonnegativeQuantityV1, "maximum_latency")
        bandwidth = invoke(_g31_exact, Tuple{Any,Type,String}, minimum_bandwidth, NonnegativeQuantityV1, "minimum_bandwidth")
        required_range = invoke(_g31_exact, Tuple{Any,Type,String}, required_measurement_range, QuantityIntervalV1, "required_measurement_range")
        resolution = invoke(_g31_exact, Tuple{Any,Type,String}, maximum_resolution, NonnegativeQuantityV1, "maximum_resolution")
        measurement_type = invoke(_g31_sampling_output_type, Tuple{ObservableGeneV1}, observable_value)

        invoke(_g31_unit_exponents, Tuple{UnitSignature,NTuple{7,Int64}}, getfield(sampling, :unit), _G31_TIME_UNITS) ||
            throw(ArgumentError("maximum_sampling_period must use time units"))
        invoke(_g31_unit_exponents, Tuple{UnitSignature,NTuple{7,Int64}}, getfield(latency, :unit), _G31_TIME_UNITS) ||
            throw(ArgumentError("maximum_latency must use time units"))
        invoke(_g31_unit_exponents, Tuple{UnitSignature,NTuple{7,Int64}}, getfield(bandwidth, :unit), _G31_INV_TIME_UNITS) ||
            throw(ArgumentError("minimum_bandwidth must use inverse-time units"))
        invoke(_g31_unit_matches, Tuple{UnitSignature,UnitSignature}, getfield(required_range, :unit), getfield(measurement_type, :units)) ||
            throw(ArgumentError("required_measurement_range units must match measurement_type"))
        invoke(_g31_unit_matches, Tuple{UnitSignature,UnitSignature}, getfield(resolution, :unit), getfield(measurement_type, :units)) ||
            throw(ArgumentError("maximum_resolution units must match measurement_type"))
        invoke(_g31_rational_positive, Tuple{Rational{Int64}}, getfield(sampling, :value)) ||
            throw(ArgumentError("maximum_sampling_period must be strictly positive"))
        invoke(_g31_rational_le, Tuple{Rational{Int64},Rational{Int64}},
               getfield(getfield(required_range, :interval), :lower),
               getfield(getfield(getfield(observable_value, :expected_effect_interval), :interval), :lower)) ||
            throw(ArgumentError("required_measurement_range lower bound is too high"))
        invoke(_g31_rational_ge, Tuple{Rational{Int64},Rational{Int64}},
               getfield(getfield(required_range, :interval), :upper),
               getfield(getfield(getfield(observable_value, :expected_effect_interval), :interval), :upper)) ||
            throw(ArgumentError("required_measurement_range upper bound is too low"))
        invoke(_g31_rational_gt_sum, Tuple{Rational{Int64},Rational{Int64},Rational{Int64},Rational{Int64}},
               getfield(getfield(observable_value, :minimum_effect_size), :value),
               getfield(getfield(observable_value, :noise_floor), :value),
               getfield(getfield(observable_value, :numerical_floor), :value),
               getfield(resolution, :value)) ||
            throw(ArgumentError("minimum effect must exceed noise, numerical, and resolution floors"))

        new(channel, getfield(observable_value, :observable_ref), invoke(_g31_observable_hash, Tuple{ObservableGeneV1}, observable_value),
            getfield(support_value, :support_ref), invoke(_g31_support_hash, Tuple{SpatialSupportGeneV1}, support_value), measurement_type,
            sampling, latency, bandwidth, required_range, resolution)
    end
end

Base.:(==)(a::ObservationChannelRequirementV1, b::ObservationChannelRequirementV1) =
    invoke(_g31_text_equal, Tuple{String,String},
           getfield(getfield(a, :channel_ref), :value), getfield(getfield(b, :channel_ref), :value)) &&
    getfield(a, :observable_ref) == getfield(b, :observable_ref) &&
    getfield(a, :observable_content_hash) == getfield(b, :observable_content_hash) &&
    getfield(a, :spatial_support_ref) == getfield(b, :spatial_support_ref) &&
    getfield(a, :spatial_support_content_hash) == getfield(b, :spatial_support_content_hash) &&
    getfield(a, :measurement_type) == getfield(b, :measurement_type) &&
    getfield(a, :maximum_sampling_period) == getfield(b, :maximum_sampling_period) &&
    getfield(a, :maximum_latency) == getfield(b, :maximum_latency) &&
    getfield(a, :minimum_bandwidth) == getfield(b, :minimum_bandwidth) &&
    getfield(a, :required_measurement_range) == getfield(b, :required_measurement_range) &&
    getfield(a, :maximum_resolution) == getfield(b, :maximum_resolution)
Base.hash(a::ObservationChannelRequirementV1, h::UInt) = hash(semantic_view(a), h)
semantic_view(a::ObservationChannelRequirementV1) =
    (channel_ref=getfield(a, :channel_ref), observable_ref=getfield(a, :observable_ref),
     observable_content_hash=getfield(a, :observable_content_hash),
     spatial_support_ref=getfield(a, :spatial_support_ref),
     spatial_support_content_hash=getfield(a, :spatial_support_content_hash),
     measurement_type=getfield(a, :measurement_type),
     maximum_sampling_period=getfield(a, :maximum_sampling_period),
     maximum_latency=getfield(a, :maximum_latency), minimum_bandwidth=getfield(a, :minimum_bandwidth),
     required_measurement_range=getfield(a, :required_measurement_range),
     maximum_resolution=getfield(a, :maximum_resolution))
