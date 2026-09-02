"""Closed canonical bytes and hashes for G2 field-geometry primitives."""

function _g2_quote(value::String)
    isvalid(value) || throw(ArgumentError("G2 primitive text must be valid UTF-8"))
    io = IOBuffer()
    print(io, '"')
    for character in value
        if character == '"'; print(io, "\\\"")
        elseif character == '\\'; print(io, "\\\\")
        elseif character == '\b'; print(io, "\\b")
        elseif character == '\f'; print(io, "\\f")
        elseif character == '\n'; print(io, "\\n")
        elseif character == '\r'; print(io, "\\r")
        elseif character == '\t'; print(io, "\\t")
        elseif UInt32(character) < 0x20; print(io, "\\u", lpad(string(UInt32(character), base=16), 4, '0'))
        else; print(io, character)
        end
    end
    print(io, '"')
    String(take!(io))
end

_g2_rational(value::Rational{Int64}) =
    "{\"denominator\":" * string(denominator(value)) * ",\"numerator\":" * string(numerator(value)) * "}"

function _g2_unit(value::UnitSignature)
    encoded = String[]
    for exponent in value.exponents
        push!(encoded, invoke(_g2_rational, Tuple{Rational{Int64}}, exponent))
    end
    "{\"exponents\":[" * join(encoded, ",") * "]}"
end

function _g2_wrap(domain::String, kind::String, payload::String)
    "{\"canonicalization_version\":\"1\",\"domain\":" *
        invoke(_g2_quote, Tuple{String}, domain) * ",\"kind\":" *
        invoke(_g2_quote, Tuple{String}, kind) * ",\"payload\":" * payload * "}"
end

function _g2_ref_wire(domain::String, kind::String, value::String)
    payload = "{\"value\":" * invoke(_g2_quote, Tuple{String}, value) * "}"
    invoke(_g2_wrap, Tuple{String,String,String}, domain, kind, payload)
end

function _g2_index_wire(value::SpatialMultiIndex3V1)
    payload = "{\"indices\":[" * join(string.(value.indices), ",") * "]}"
    invoke(_g2_wrap, Tuple{String,String,String}, "fusionconceptai:v4:g2:spatial_multi_index:v1",
           "spatial_multi_index", payload)
end

function _g2_vector_wire(value::ExactSpatialVector3V1)
    payload = "{\"components\":[" * join((invoke(_g2_rational, Tuple{Rational{Int64}}, x)
        for x in value.components), ",") * "],\"unit\":" *
        invoke(_g2_unit, Tuple{UnitSignature}, value.unit) * "}"
    invoke(_g2_wrap, Tuple{String,String,String}, "fusionconceptai:v4:g2:exact_spatial_vector:v1",
           "exact_spatial_vector", payload)
end

function _g2_interval_payload(value::ExactFiniteIntervalV1)
    "{\"allow_equal\":" * (value.allow_equal ? "true" : "false") *
        ",\"lower\":" * invoke(_g2_rational, Tuple{Rational{Int64}}, value.lower) *
        ",\"upper\":" * invoke(_g2_rational, Tuple{Rational{Int64}}, value.upper) * "}"
end
function _g2_quantity_payload(value::QuantityIntervalV1)
    "{\"interval\":" * invoke(_g2_interval_payload, Tuple{ExactFiniteIntervalV1}, value.interval) *
        ",\"unit\":" * invoke(_g2_unit, Tuple{UnitSignature}, value.unit) * "}"
end
function _g2_transform_payload(value::ParameterTransformSpecV1)
    scale = value.scale === nothing ? "null" :
        "{\"unit\":" * invoke(_g2_unit, Tuple{UnitSignature}, value.scale.unit) *
        ",\"value\":" * invoke(_g2_rational, Tuple{Rational{Int64}}, value.scale.value) * "}"
    label = value.kind == transform_linear ? "linear" : value.kind == transform_log ? "log" :
        value.kind == transform_signed_log ? "signed_log" : throw(ArgumentError("invalid parameter transform kind"))
    "{\"kind\":" * invoke(_g2_quote, Tuple{String}, label) * ",\"scale\":" * scale * "}"
end
function _g2_field_parameter_wire(value::FieldParameterGeneV1)
    payload = "{\"bounds\":" * invoke(_g2_quantity_payload, Tuple{QuantityIntervalV1}, value.bounds) *
        ",\"normalized_gene\":" * repr(value.normalized_gene) * ",\"ref\":{\"value\":" *
        invoke(_g2_quote, Tuple{String}, value.ref.value) * "},\"transform\":" *
        invoke(_g2_transform_payload, Tuple{ParameterTransformSpecV1}, value.transform) *
        ",\"unit\":" * invoke(_g2_unit, Tuple{UnitSignature}, value.unit) * "}"
    invoke(_g2_wrap, Tuple{String,String,String}, "fusionconceptai:v4:g2:field_parameter_gene:v1",
           "field_parameter_gene", payload)
end

const _G2_REF_WIRE_SPECS = ((SpatialSupportRefV1, "fusionconceptai:v4:g2:spatial_support_ref:v1", "spatial_support_ref"),
    (ChartRefV1, "fusionconceptai:v4:g2:chart_ref:v1", "chart_ref"),
    (CoordinateFrameRefV1, "fusionconceptai:v4:g2:coordinate_frame_ref:v1", "coordinate_frame_ref"),
    (PhaseFieldRefV1, "fusionconceptai:v4:g2:phase_field_ref:v1", "phase_field_ref"),
    (ImplicitFieldTermRefV1, "fusionconceptai:v4:g2:implicit_field_term_ref:v1", "implicit_field_term_ref"),
    (PotentialFieldRefV1, "fusionconceptai:v4:g2:potential_field_ref:v1", "potential_field_ref"),
    (SourceFieldRefV1, "fusionconceptai:v4:g2:source_field_ref:v1", "source_field_ref"),
    (InterfaceOperatorRefV1, "fusionconceptai:v4:g2:interface_operator_ref:v1", "interface_operator_ref"),
    (GeometryEvolutionRefV1, "fusionconceptai:v4:g2:geometry_evolution_ref:v1", "geometry_evolution_ref"),
    (FieldParameterRefV1, "fusionconceptai:v4:g2:field_parameter_ref:v1", "field_parameter_ref"),
    (SourceBudgetRefV1, "fusionconceptai:v4:g2:source_budget_ref:v1", "source_budget_ref"),
    (TopologyEventRefV1, "fusionconceptai:v4:g2:topology_event_ref:v1", "topology_event_ref"))

for (ref_type, domain, kind) in _G2_REF_WIRE_SPECS
    @eval begin
        canonical_json(value::$ref_type) =
            invoke(_g2_ref_wire, Tuple{String,String,String}, $domain, $kind, value.value)
        canonical_hash(value::$ref_type) =
            invoke(_g2_hash_bytes, Tuple{String}, invoke(_g2_ref_wire, Tuple{String,String,String},
                $domain, $kind, value.value))
    end
end

canonical_json(value::SpatialMultiIndex3V1) = _g2_index_wire(value)
canonical_hash(value::SpatialMultiIndex3V1) =
    invoke(_g2_hash_bytes, Tuple{String}, _g2_index_wire(value))
canonical_json(value::ExactSpatialVector3V1) = _g2_vector_wire(value)
canonical_hash(value::ExactSpatialVector3V1) =
    invoke(_g2_hash_bytes, Tuple{String}, _g2_vector_wire(value))
canonical_json(value::FieldParameterGeneV1) = _g2_field_parameter_wire(value)
canonical_hash(value::FieldParameterGeneV1) =
    invoke(_g2_hash_bytes, Tuple{String}, _g2_field_parameter_wire(value))

function _g2_hash_bytes(value::String)::Digest256
    hex = bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(value))))
    invoke(Digest256, Tuple{AbstractString}, hex)
end
