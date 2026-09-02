"""Closed value-level primitives for the G2 field-geometry vocabulary.

The constructors in this file intentionally validate through concrete, sealed
helpers.  In particular, no open generic conversion or user supplied
`semantic_view` participates in admission of a G2 value.
"""

function _g2_ref_text(value::Any, field::Any)
    typeof(value) === String || throw(ArgumentError("$field must be an immutable String"))
    isvalid(value) || throw(ArgumentError("$field must contain valid Unicode scalar values"))
    isempty(value) && throw(ArgumentError("$field cannot be empty"))
    value
end

const _G2_SIGNED_SAFE_INTEGER_TYPES = (Int8, Int16, Int32, Int64, Int128)

function _g2_signed_int64(value::Any, field::Any)
    value_type = typeof(value)
    value_type in _G2_SIGNED_SAFE_INTEGER_TYPES ||
        throw(ArgumentError("$field requires a fixed-width signed integer"))
    typemin(Int64) <= value <= typemax(Int64) ||
        throw(ArgumentError("$field is outside the Int64 range"))
    Int64(value)
end

function _g2_exact_rational(value::Any, field::Any)
    value_type = typeof(value)
    if value_type === Rational{Int64}
        denominator(value) > 0 || throw(ArgumentError("$field denominator must be positive"))
        return value
    end
    value_type in _G2_SIGNED_SAFE_INTEGER_TYPES ||
        throw(ArgumentError("$field requires Rational{Int64} or a fixed-width signed integer"))
    typemin(Int64) <= value <= typemax(Int64) ||
        throw(ArgumentError("$field is outside the Int64 rational range"))
    Rational{Int64}(Int64(value))
end

const _G2_REF_TYPES = (:SpatialSupportRefV1, :ChartRefV1, :CoordinateFrameRefV1,
    :PhaseFieldRefV1, :ImplicitFieldTermRefV1, :PotentialFieldRefV1,
    :SourceFieldRefV1, :InterfaceOperatorRefV1, :GeometryEvolutionRefV1,
    :FieldParameterRefV1, :SourceBudgetRefV1, :TopologyEventRefV1)

for ref_type in _G2_REF_TYPES
    field_name = lowercase(string(ref_type)[1:end-3]) * " reference"
    @eval begin
        struct $ref_type
            value::String
            function $ref_type(value::Any)
                new(invoke(_g2_ref_text, Tuple{Any,Any}, value, $field_name))
            end
        end
        Base.:(==)(a::$ref_type, b::$ref_type) = a.value == b.value
        Base.hash(a::$ref_type, h::UInt) = hash(a.value, h)
        semantic_view(a::$ref_type) = (value=a.value,)
    end
end

struct SpatialMultiIndex3V1
    indices::NTuple{3,Int64}
    function SpatialMultiIndex3V1(values::Any)
        values isa Tuple && !(values isa NamedTuple) && length(values) == 3 ||
            throw(ArgumentError("spatial multi-index must be an immutable 3-tuple"))
        converted = ntuple(i -> invoke(_g2_signed_int64, Tuple{Any,Any}, values[i],
                                       "spatial multi-index component"), 3)
        new(converted)
    end
end
SpatialMultiIndex3V1(x::Any, y::Any, z::Any) =
    SpatialMultiIndex3V1((x, y, z))
Base.getproperty(value::SpatialMultiIndex3V1, name::Symbol) =
    name === :values ? getfield(value, :indices) : getfield(value, name)
Base.:(==)(a::SpatialMultiIndex3V1, b::SpatialMultiIndex3V1) = a.indices == b.indices
Base.hash(a::SpatialMultiIndex3V1, h::UInt) = hash(a.indices, h)
semantic_view(a::SpatialMultiIndex3V1) = (indices=a.indices,)

struct ExactSpatialVector3V1
    components::NTuple{3,Rational{Int64}}
    unit::UnitSignature
    function ExactSpatialVector3V1(values::Any, unit::Any)
        values isa Tuple && !(values isa NamedTuple) && length(values) == 3 ||
            throw(ArgumentError("exact spatial vector must be an immutable 3-tuple"))
        unit isa UnitSignature || throw(ArgumentError("spatial vector unit must be UnitSignature"))
        converted = ntuple(i -> invoke(_g2_exact_rational, Tuple{Any,Any}, values[i],
                                       "spatial vector component"), 3)
        new(converted, unit)
    end
end
ExactSpatialVector3V1(x::Any, y::Any, z::Any, unit::Any) =
    ExactSpatialVector3V1((x, y, z), unit)
Base.getproperty(value::ExactSpatialVector3V1, name::Symbol) =
    name === :values ? getfield(value, :components) : getfield(value, name)
Base.:(==)(a::ExactSpatialVector3V1, b::ExactSpatialVector3V1) =
    a.components == b.components && a.unit == b.unit
Base.hash(a::ExactSpatialVector3V1, h::UInt) = hash((a.components, a.unit), h)
semantic_view(a::ExactSpatialVector3V1) = (components=a.components, unit=a.unit)

function _g2_finite_float(value::Any, field::Any)
    value_type = typeof(value)
    value_type in (Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32,
                   UInt64, UInt128, Float16, Float32, Float64, Rational{Int64}) ||
        throw(ArgumentError("$field requires a fixed-width finite numeric value"))
    converted = try Float64(value) catch
        throw(ArgumentError("$field cannot be converted to Float64"))
    end
    isfinite(converted) || throw(ArgumentError("$field must be finite after Float64 conversion"))
    converted == 0.0 ? 0.0 : converted
end

struct FieldParameterGeneV1
    ref::FieldParameterRefV1
    unit::UnitSignature
    transform::ParameterTransformSpecV1
    bounds::QuantityIntervalV1
    normalized_gene::Float64
    function FieldParameterGeneV1(ref::Any, unit::Any, transform::Any, bounds::Any,
                                  normalized_gene::Any)
        ref isa FieldParameterRefV1 || throw(ArgumentError("ref must be FieldParameterRefV1"))
        unit isa UnitSignature || throw(ArgumentError("unit must be UnitSignature"))
        transform isa ParameterTransformSpecV1 ||
            throw(ArgumentError("transform must be ParameterTransformSpecV1"))
        bounds isa QuantityIntervalV1 || throw(ArgumentError("bounds must be QuantityIntervalV1"))
        bounds.unit == unit || throw(ArgumentError("parameter bounds unit must match parameter unit"))
        bounds.interval.lower < bounds.interval.upper ||
            throw(ArgumentError("parameter bounds must be strictly ordered"))
        transform.kind == transform_log && bounds.interval.lower > 0 ||
            transform.kind != transform_log || throw(ArgumentError("log parameter bounds must be positive"))
        transform.kind == transform_signed_log && transform.scale.unit == unit ||
            transform.kind != transform_signed_log ||
            throw(ArgumentError("signed_log scale unit must match parameter unit"))
        normalized = invoke(_g2_finite_float, Tuple{Any,Any}, normalized_gene, "normalized_gene")
        -1.0 <= normalized <= 1.0 || throw(ArgumentError("normalized_gene must lie in [-1,1]"))
        new(ref, unit, transform, bounds, normalized)
    end
end

function _g2_derive_field_parameter_value_sealed(gene::FieldParameterGeneV1,
                                                  normalized_gene::Any)
    z = invoke(_g2_finite_float, Tuple{Any,Any}, normalized_gene, "normalized_gene")
    -1.0 <= z <= 1.0 || throw(ArgumentError("normalized_gene must lie in [-1,1]"))
    lower_exact = gene.bounds.interval.lower
    upper_exact = gene.bounds.interval.upper
    z == -1.0 && return lower_exact
    z == 1.0 && return upper_exact
    lower = Float64(lower_exact)
    upper = Float64(upper_exact)
    t = (z + 1.0) / 2.0
    gene.transform.kind == transform_linear && return lower + t * (upper - lower)
    gene.transform.kind == transform_log &&
        return exp(log(lower) + t * (log(upper) - log(lower)))
    gene.transform.kind == transform_signed_log || throw(ArgumentError("unknown parameter transform kind"))
    scale = Float64(gene.transform.scale.value)
    forward(x) = sign(x) * log1p(abs(x) / scale)
    inverse(x) = sign(x) * scale * expm1(abs(x))
    inverse(forward(lower) + t * (forward(upper) - forward(lower)))
end

derive_field_parameter_value(gene::FieldParameterGeneV1) =
    invoke(_g2_derive_field_parameter_value_sealed, Tuple{FieldParameterGeneV1,Any},
           gene, gene.normalized_gene)
derive_field_parameter_value(gene::FieldParameterGeneV1, normalized_gene::Float64) =
    invoke(_g2_derive_field_parameter_value_sealed, Tuple{FieldParameterGeneV1,Any},
           gene, normalized_gene)
derive_field_parameter_value(::FieldParameterGeneV1, ::Any) =
    throw(ArgumentError("normalized_gene must be Float64"))
field_parameter_value(gene::FieldParameterGeneV1) =
    invoke(_g2_derive_field_parameter_value_sealed, Tuple{FieldParameterGeneV1,Any},
           gene, gene.normalized_gene)
field_parameter_value(gene::FieldParameterGeneV1, normalized_gene::Float64) =
    invoke(_g2_derive_field_parameter_value_sealed, Tuple{FieldParameterGeneV1,Any},
           gene, normalized_gene)
field_parameter_value(::FieldParameterGeneV1, ::Any) =
    throw(ArgumentError("normalized_gene must be Float64"))

semantic_view(a::FieldParameterGeneV1) =
    (ref=a.ref, unit=a.unit, transform=a.transform, bounds=a.bounds,
     normalized_gene=a.normalized_gene)
