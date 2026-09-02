"""Closed canonical bytes and hashes for G2 field-geometry primitives."""

function _g2_quote(value::String)
    io = _ccbw_new(); _ccbw_quote!(io, value); _ccbw_finish(io)
end

function _g2_rational_to!(io::Base.GenericIOBuffer, value::Rational{Int64})
    _ccbw_ascii!(io, "{\"denominator\":"); _ccbw_int64!(io, getfield(value, :den))
    _ccbw_ascii!(io, ",\"numerator\":"); _ccbw_int64!(io, getfield(value, :num)); _ccbw_byte!(io, UInt8('}')); io
end
function _g2_rational(value::Rational{Int64})
    io = _ccbw_new(); _g2_rational_to!(io, value); _ccbw_finish(io)
end
function _g2_unit_to!(io::Base.GenericIOBuffer, value::UnitSignature)
    _ccbw_ascii!(io, "{\"exponents\":[")
    exponents = getfield(value, :exponents); count = fieldcount(typeof(exponents)); index = 1
    while index <= count
        index > 1 && _ccbw_byte!(io, UInt8(',')); _g2_rational_to!(io, getfield(exponents, index)); index += 1
    end
    _ccbw_ascii!(io, "]}"); io
end
function _g2_unit(value::UnitSignature)
    io = _ccbw_new(); _g2_unit_to!(io, value); _ccbw_finish(io)
end

function _g2_wrap(io::Base.GenericIOBuffer, domain::String, kind::String)
    _ccbw_ascii!(io, "{\"canonicalization_version\":\"1\",\"domain\":"); _ccbw_quote!(io, domain)
    _ccbw_ascii!(io, ",\"kind\":"); _ccbw_quote!(io, kind); _ccbw_ascii!(io, ",\"payload\":"); io
end
function _g2_wrap_end!(io::Base.GenericIOBuffer); _ccbw_byte!(io, UInt8('}')); io; end
function _g2_ref_wire(io::Base.GenericIOBuffer, domain::String, kind::String, value::String)
    _g2_wrap(io, domain, kind); _ccbw_ascii!(io, "{\"value\":"); _ccbw_quote!(io, value); _ccbw_ascii!(io, "}}"); io
end

function _g2_index_wire(io::Base.GenericIOBuffer, value::SpatialMultiIndex3V1)
    _g2_wrap(io, "fusionconceptai:v4:g2:spatial_multi_index:v1", "spatial_multi_index")
    indices = getfield(value, :indices); _ccbw_ascii!(io, "{\"indices\":[")
    _ccbw_int64!(io, getfield(indices, 1)); _ccbw_byte!(io, UInt8(',')); _ccbw_int64!(io, getfield(indices, 2)); _ccbw_byte!(io, UInt8(',')); _ccbw_int64!(io, getfield(indices, 3))
    _ccbw_ascii!(io, "]}"); _g2_wrap_end!(io); io
end
function _g2_vector_wire(io::Base.GenericIOBuffer, value::ExactSpatialVector3V1)
    _g2_wrap(io, "fusionconceptai:v4:g2:exact_spatial_vector:v1", "exact_spatial_vector")
    components = getfield(value, :components); _ccbw_ascii!(io, "{\"components\":[")
    _g2_rational_to!(io, getfield(components, 1)); _ccbw_byte!(io, UInt8(',')); _g2_rational_to!(io, getfield(components, 2)); _ccbw_byte!(io, UInt8(',')); _g2_rational_to!(io, getfield(components, 3))
    _ccbw_ascii!(io, "],\"unit\":"); _g2_unit_to!(io, getfield(value, :unit)); _ccbw_ascii!(io, "}"); _g2_wrap_end!(io); io
end
function _g2_interval_to!(io::Base.GenericIOBuffer, value::ExactFiniteIntervalV1)
    _ccbw_ascii!(io, "{\"allow_equal\":"); _ccbw_ascii!(io, getfield(value, :allow_equal) ? "true" : "false")
    _ccbw_ascii!(io, ",\"lower\":"); _g2_rational_to!(io, getfield(value, :lower)); _ccbw_ascii!(io, ",\"upper\":"); _g2_rational_to!(io, getfield(value, :upper)); _ccbw_byte!(io, UInt8('}')); io
end
function _g2_quantity_to!(io::Base.GenericIOBuffer, value::QuantityIntervalV1)
    _ccbw_ascii!(io, "{\"interval\":"); _g2_interval_to!(io, getfield(value, :interval)); _ccbw_ascii!(io, ",\"unit\":"); _g2_unit_to!(io, getfield(value, :unit)); _ccbw_byte!(io, UInt8('}')); io
end
function _g2_transform_to!(io::Base.GenericIOBuffer, value::ParameterTransformSpecV1)
    kind = getfield(value, :kind); scale = getfield(value, :scale); _ccbw_ascii!(io, "{\"kind\":")
    if kind === transform_linear; _ccbw_quote!(io, "linear")
    elseif kind === transform_log; _ccbw_quote!(io, "log")
    elseif kind === transform_signed_log; _ccbw_quote!(io, "signed_log")
    else; throw(ArgumentError("invalid parameter transform kind")); end
    _ccbw_ascii!(io, ",\"scale\":")
    if scale === nothing; _ccbw_ascii!(io, "null")
    else
        _ccbw_ascii!(io, "{\"unit\":"); _g2_unit_to!(io, getfield(scale, :unit)); _ccbw_ascii!(io, ",\"value\":"); _g2_rational_to!(io, getfield(scale, :value)); _ccbw_byte!(io, UInt8('}'))
    end
    _ccbw_byte!(io, UInt8('}')); io
end
function _g2_field_parameter_wire(io::Base.GenericIOBuffer, value::FieldParameterGeneV1)
    _ccbw_ascii!(io, "{\"bounds\":"); _g2_quantity_to!(io, getfield(value, :bounds)); _ccbw_ascii!(io, ",\"normalized_gene\":"); _ccbw_float!(io, getfield(value, :normalized_gene))
    _ccbw_ascii!(io, ",\"ref\":{\"value\":"); _ccbw_quote!(io, getfield(getfield(value, :ref), :value)); _ccbw_ascii!(io, "},\"transform\":"); _g2_transform_to!(io, getfield(value, :transform)); _ccbw_ascii!(io, ",\"unit\":"); _g2_unit_to!(io, getfield(value, :unit)); _ccbw_byte!(io, UInt8('}')); io
end

const _G2_REF_WIRE_SPECS = ((SpatialSupportRefV1, "fusionconceptai:v4:g2:spatial_support_ref:v1", "spatial_support_ref"),
    (ChartRefV1, "fusionconceptai:v4:g2:chart_ref:v1", "chart_ref"), (CoordinateFrameRefV1, "fusionconceptai:v4:g2:coordinate_frame_ref:v1", "coordinate_frame_ref"),
    (PhaseFieldRefV1, "fusionconceptai:v4:g2:phase_field_ref:v1", "phase_field_ref"), (ImplicitFieldTermRefV1, "fusionconceptai:v4:g2:implicit_field_term_ref:v1", "implicit_field_term_ref"),
    (PotentialFieldRefV1, "fusionconceptai:v4:g2:potential_field_ref:v1", "potential_field_ref"), (SourceFieldRefV1, "fusionconceptai:v4:g2:source_field_ref:v1", "source_field_ref"),
    (InterfaceOperatorRefV1, "fusionconceptai:v4:g2:interface_operator_ref:v1", "interface_operator_ref"), (GeometryEvolutionRefV1, "fusionconceptai:v4:g2:geometry_evolution_ref:v1", "geometry_evolution_ref"),
    (FieldParameterRefV1, "fusionconceptai:v4:g2:field_parameter_ref:v1", "field_parameter_ref"), (SourceBudgetRefV1, "fusionconceptai:v4:g2:source_budget_ref:v1", "source_budget_ref"),
    (TopologyEventRefV1, "fusionconceptai:v4:g2:topology_event_ref:v1", "topology_event_ref"))
for (ref_type, domain, kind) in _G2_REF_WIRE_SPECS
    @eval begin
        function canonical_json(value::$ref_type)
            io = _ccbw_new(); _g2_ref_wire(io, $domain, $kind, getfield(value, :value)); _ccbw_finish(io)
        end
        function canonical_hash(value::$ref_type)
            io = _ccbw_new(); _g2_ref_wire(io, $domain, $kind, getfield(value, :value)); _ccbw_hash_bytes(_ccbw_finish(io))
        end
    end
end

function _g2_index_json(value::SpatialMultiIndex3V1); io = _ccbw_new(); _g2_index_wire(io, value); _ccbw_finish(io); end
function _g2_vector_json(value::ExactSpatialVector3V1); io = _ccbw_new(); _g2_vector_wire(io, value); _ccbw_finish(io); end
function _g2_field_parameter_json(value::FieldParameterGeneV1)
    io = _ccbw_new(); _g2_wrap(io, "fusionconceptai:v4:g2:field_parameter_gene:v1", "field_parameter_gene"); _g2_field_parameter_wire(io, value); _g2_wrap_end!(io); _ccbw_finish(io)
end
canonical_json(value::SpatialMultiIndex3V1) = invoke(_g2_index_json, Tuple{SpatialMultiIndex3V1}, value)
canonical_hash(value::SpatialMultiIndex3V1) = _ccbw_hash_bytes(invoke(_g2_index_json, Tuple{SpatialMultiIndex3V1}, value))
canonical_json(value::ExactSpatialVector3V1) = invoke(_g2_vector_json, Tuple{ExactSpatialVector3V1}, value)
canonical_hash(value::ExactSpatialVector3V1) = _ccbw_hash_bytes(invoke(_g2_vector_json, Tuple{ExactSpatialVector3V1}, value))
canonical_json(value::FieldParameterGeneV1) = invoke(_g2_field_parameter_json, Tuple{FieldParameterGeneV1}, value)
canonical_hash(value::FieldParameterGeneV1) = _ccbw_hash_bytes(invoke(_g2_field_parameter_json, Tuple{FieldParameterGeneV1}, value))
