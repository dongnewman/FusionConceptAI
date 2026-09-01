"""Physical type vocabulary for the v4 typed operator IR."""

struct UnitSignature
    exponents::NTuple{7,Rational{Int64}}
    function UnitSignature(exponents::NTuple{7,<:Real})
        vals = ntuple(i -> Rational{Int64}(exponents[i]), 7)
        new(vals)
    end
end
struct Digest256
    value::String
    function Digest256(value::AbstractString)
        occursin(r"^[0-9a-f]{64}$", value) || throw(ArgumentError("Digest256 requires exactly 64 lowercase hex characters"))
        new(String(value))
    end
end
Base.:(==)(a::Digest256, b::Digest256) = a.value == b.value
Base.hash(a::Digest256, h::UInt) = hash(a.value, h)
Base.string(a::Digest256) = a.value
Base.show(io::IO, a::Digest256) = print(io, a.value)
digest256_text(s::AbstractString) = Digest256(bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(String(s))))))
function _validated_string(s::AbstractString, field::AbstractString)
    text = String(s)
    isvalid(text) || throw(ArgumentError("$field must be valid UTF-8"))
    text
end

const _P0_SAFE_INTEGER_TYPES = (Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128)
const _P0_SAFE_FLOAT_TYPES = (Float16, Float32, Float64)
_p0_safe_rational(x) = x isa Rational && typeof(numerator(x)) in _P0_SAFE_INTEGER_TYPES && typeof(denominator(x)) in _P0_SAFE_INTEGER_TYPES
_p0_safe_number(x) = typeof(x) in _P0_SAFE_INTEGER_TYPES || typeof(x) in _P0_SAFE_FLOAT_TYPES || _p0_safe_rational(x)

@enum TimeKindV1 static_time algebraic_time differential_time discrete_time event_time

struct QualifiedRefV1
    id::String
    version::String
    function QualifiedRefV1(id::AbstractString, version::AbstractString)
        !isempty(id) && !isempty(version) || throw(ArgumentError("qualified reference id/version cannot be empty"))
        new(_validated_string(id, "qualified reference id"), _validated_string(version, "qualified reference version"))
    end
end

struct TemporalTypeV1
    kind::TimeKindV1
    derivative_order::UInt8
    clock_ref::Union{Nothing,QualifiedRefV1}
    function TemporalTypeV1(kind::TimeKindV1, derivative_order::UInt8=UInt8(0), clock_ref=nothing)
        clock_ref === nothing || clock_ref isa QualifiedRefV1 ||
            throw(ArgumentError("clock_ref must be QualifiedRefV1 or nothing"))
        if kind in (static_time, algebraic_time)
            derivative_order == 0 && clock_ref === nothing ||
                throw(ArgumentError("static/algebraic time requires order 0 and no clock"))
        elseif kind == differential_time
            clock_ref === nothing || throw(ArgumentError("differential time is continuous and has no clock"))
        elseif kind in (discrete_time, event_time)
            derivative_order == 0 && clock_ref !== nothing ||
                throw(ArgumentError("discrete/event time requires order 0 and a clock"))
        else
            throw(ArgumentError("unknown temporal kind"))
        end
        new(kind, derivative_order, clock_ref)
    end
end
function TemporalTypeV1(kind::TimeKindV1, derivative_order::Integer, clock_ref=nothing)
    0 <= derivative_order <= typemax(UInt8) || throw(ArgumentError("derivative order must fit UInt8"))
    clock = clock_ref === nothing ? nothing :
        clock_ref isa QualifiedRefV1 ? clock_ref : throw(ArgumentError("clock_ref must be QualifiedRefV1"))
    TemporalTypeV1(kind, UInt8(derivative_order), clock)
end

_legacy_time_kind(s::Symbol) = s === :static ? static_time : s === :algebraic ? algebraic_time :
                               s === :differential ? differential_time : throw(ArgumentError("unknown legacy time_kind $s"))
_legacy_time_symbol(k::TimeKindV1) = k == static_time ? :static : k == algebraic_time ? :algebraic :
                                      k == differential_time ? :differential : Symbol(k)

"""Recursive admission trait for values that can be represented canonically."""
function is_canonical_value(x)
    x === nothing && return true
    if Base.ismutabletype(typeof(x))
        (typeof(x) === String || x isa Symbol) && return true
        return false
    end
    x isa AbstractString && return typeof(x) === String && isvalid(x)
    x isa Bool && return true
    x isa Symbol && return true
    x isa Number && return _p0_safe_number(x)
    x isa Enum && return true
    (x isa AbstractArray || x isa AbstractDict || x isa AbstractSet) && return false
    x isa NamedTuple && return all(is_canonical_value, values(x))
    x isa Tuple && return all(is_canonical_value, x)
    isstructtype(typeof(x)) || return false
    hasmethod(semantic_view, Tuple{typeof(x)}) || return false
    projected = try
        semantic_view(x)
    catch
        return false
    end
    projected === x && return false
    is_canonical_value(projected)
end
UnitSignature(xs::AbstractVector{<:Real}) = UnitSignature(Tuple(xs))
UnitSignature() = UnitSignature(ntuple(_ -> 0, 7))

Base.:(==)(a::UnitSignature, b::UnitSignature) = a.exponents == b.exponents
Base.hash(a::UnitSignature, h::UInt) = hash(a.exponents, h)

struct PhysicalType
    value_kind::Symbol
    tensor_rank::Int
    spatial_dimension::Int
    temporal_type::TemporalTypeV1
    units::UnitSignature
    function PhysicalType(kind::Symbol, rank::Integer, dim::Integer, temporal::TemporalTypeV1, units::UnitSignature=UnitSignature())
        rank isa Bool && throw(ArgumentError("tensor_rank must be an integer"))
        dim isa Bool && throw(ArgumentError("spatial_dimension must be an integer"))
        typemin(Int) <= rank <= typemax(Int) || throw(ArgumentError("tensor_rank is out of range"))
        typemin(Int) <= dim <= typemax(Int) || throw(ArgumentError("spatial_dimension is out of range"))
        Int(rank) >= 0 || throw(ArgumentError("tensor_rank must be non-negative"))
        Int(dim) in 0:3 || throw(ArgumentError("spatial_dimension must be in 0:3"))
        new(kind, Int(rank), Int(dim), temporal, units)
    end
end
PhysicalType(kind::Symbol, rank::Integer, dim::Integer, time::Symbol, units::UnitSignature=UnitSignature()) =
    PhysicalType(kind, rank, dim, TemporalTypeV1(_legacy_time_kind(time)), units)
function Base.getproperty(x::PhysicalType, name::Symbol)
    name === :time_kind && return _legacy_time_symbol(getfield(x, :temporal_type).kind)
    getfield(x, name)
end
Base.propertynames(::PhysicalType, private::Bool=false) =
    (:value_kind, :tensor_rank, :spatial_dimension, :temporal_type, :time_kind, :units)

Base.:(==)(a::PhysicalType, b::PhysicalType) = a.value_kind == b.value_kind && a.tensor_rank == b.tensor_rank &&
    a.spatial_dimension == b.spatial_dimension && a.temporal_type == b.temporal_type && a.units == b.units
Base.:(==)(a::TemporalTypeV1, b::TemporalTypeV1) = a.kind == b.kind && a.derivative_order == b.derivative_order && a.clock_ref == b.clock_ref
Base.:(==)(a::QualifiedRefV1, b::QualifiedRefV1) = a.id == b.id && a.version == b.version

@enum ApplicabilityStatus required not_applicable
@enum MatchStatus unique_match no_match ambiguous out_of_domain invalid_signature
@enum ResolutionStatus resolved terminal_deferred
@enum LifecycleStatus proposed compiled proof_pruned dormant materialized low_fidelity_evaluated frontier_admitted high_fidelity_pending integrated_executed terminal_classified
@enum StageOutcome pass physical_fail numerical_fail unknown not_applicable_stage terminal_deferred_stage
@enum TerminalDisposition credible_within_scope terminal_physical_fail terminal_numerical_fail terminal_unknown terminal_unsupported
@enum ClaimCeiling none screen_only candidate_bound integrated whole_device_vvuq validation_vvuq

struct ApplicabilityRecord
    obligation::String
    status::ApplicabilityStatus
    proof_ref::Union{Nothing,Digest256}
    function ApplicabilityRecord(obligation::AbstractString, status::ApplicabilityStatus, proof_ref=nothing)
        !isempty(obligation) || throw(ArgumentError("applicability obligation cannot be empty"))
        status == not_applicable && proof_ref === nothing && throw(ArgumentError("not_applicable requires proof_ref"))
        normalized = proof_ref === nothing ? nothing : proof_ref isa Digest256 ? proof_ref :
                     proof_ref isa AbstractString ? Digest256(proof_ref) : throw(ArgumentError("proof_ref must be Digest256"))
        new(_validated_string(obligation, "applicability obligation"), status, normalized)
    end
end

struct EvidenceRef
    evidence_id::Digest256
    function EvidenceRef(id::AbstractString)
        new(Digest256(id))
    end
end
EvidenceRef(id::Digest256) = EvidenceRef(id.value)

struct MetricWithUnit
    name::Symbol
    value::Float64
    unit::UnitSignature
    uncertainty::Union{Nothing,Float64}
    function MetricWithUnit(name::Symbol, value::Real, unit::UnitSignature=UnitSignature(); uncertainty=nothing)
        value64 = Float64(value)
        isfinite(value64) || throw(ArgumentError("metric value must be finite after Float64 conversion"))
        uncertainty64 = uncertainty === nothing ? nothing : Float64(uncertainty)
        uncertainty64 === nothing || (isfinite(uncertainty64) && uncertainty64 >= 0) || throw(ArgumentError("invalid metric uncertainty"))
        new(name, value64, unit, uncertainty64)
    end
end

"""Reject mutable containers recursively; all P0 payloads are value objects."""
function deep_immutable(x)
    x === nothing && return true
    # String and Symbol are the only mutable-reported atomic values admitted;
    # every other mutable value is rejected before any whitelist is consulted.
    if Base.ismutabletype(typeof(x))
        typeof(x) === String && return true
        x isa Symbol && return true
        return false
    end
    x isa AbstractString && return false
    (x isa Bool || x isa Symbol) && return true
    x isa Number && return _p0_safe_number(x)
    x isa Enum && return true
    (x isa AbstractArray || x isa AbstractDict || x isa AbstractSet) && return false
    x isa NamedTuple && return all(deep_immutable, values(x))
    x isa Tuple && return all(deep_immutable, x)
    isstructtype(typeof(x)) && return all(deep_immutable, (getfield(x, f) for f in fieldnames(typeof(x))))
    false
end

"""Every canonicalizable strong type provides its own semantic projection."""
semantic_view(x::UnitSignature) = (exponents=x.exponents,)
semantic_view(x::Digest256) = (value=x.value,)
semantic_view(x::PhysicalType) = (value_kind=x.value_kind, tensor_rank=x.tensor_rank,
                                  spatial_dimension=x.spatial_dimension, temporal_type=x.temporal_type, units=x.units)
semantic_view(x::QualifiedRefV1) = (id=x.id, version=x.version)
semantic_view(x::TemporalTypeV1) = (kind=x.kind, derivative_order=x.derivative_order, clock_ref=x.clock_ref)
semantic_view(x::ApplicabilityRecord) = (obligation=x.obligation, status=x.status, proof_ref=x.proof_ref)
semantic_view(x::EvidenceRef) = (evidence_id=x.evidence_id,)
semantic_view(x::MetricWithUnit) = (name=x.name, value=x.value, unit=x.unit, uncertainty=x.uncertainty)
