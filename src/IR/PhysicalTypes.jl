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

const _P0_SAFE_INTEGER_TYPES = (Int8, Int16, Int32, Int64, Int128, UInt8, UInt16, UInt32, UInt64, UInt128)
const _P0_SAFE_FLOAT_TYPES = (Float16, Float32, Float64)
_p0_safe_rational(x) = x isa Rational && typeof(numerator(x)) in _P0_SAFE_INTEGER_TYPES && typeof(denominator(x)) in _P0_SAFE_INTEGER_TYPES
_p0_safe_number(x) = typeof(x) in _P0_SAFE_INTEGER_TYPES || typeof(x) in _P0_SAFE_FLOAT_TYPES || _p0_safe_rational(x)
UnitSignature(xs::AbstractVector{<:Real}) = UnitSignature(Tuple(xs))
UnitSignature() = UnitSignature(ntuple(_ -> 0, 7))

Base.:(==)(a::UnitSignature, b::UnitSignature) = a.exponents == b.exponents
Base.hash(a::UnitSignature, h::UInt) = hash(a.exponents, h)

struct PhysicalType
    value_kind::Symbol
    tensor_rank::Int
    spatial_dimension::Int
    time_kind::Symbol
    units::UnitSignature
    function PhysicalType(kind::Symbol, rank::Integer, dim::Integer, time::Symbol, units::UnitSignature=UnitSignature())
        rank >= 0 || throw(ArgumentError("tensor_rank must be non-negative"))
        dim in 0:3 || throw(ArgumentError("spatial_dimension must be in 0:3"))
        time in (:static, :algebraic, :differential) || throw(ArgumentError("invalid time_kind"))
        new(kind, Int(rank), Int(dim), time, units)
    end
end

Base.:(==)(a::PhysicalType, b::PhysicalType) = a.value_kind == b.value_kind && a.tensor_rank == b.tensor_rank &&
    a.spatial_dimension == b.spatial_dimension && a.time_kind == b.time_kind && a.units == b.units

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
        new(String(obligation), status, normalized)
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
                                  spatial_dimension=x.spatial_dimension, time_kind=x.time_kind, units=x.units)
semantic_view(x::ApplicabilityRecord) = (obligation=x.obligation, status=x.status, proof_ref=x.proof_ref)
semantic_view(x::EvidenceRef) = (evidence_id=x.evidence_id,)
semantic_view(x::MetricWithUnit) = (name=x.name, value=x.value, unit=x.unit, uncertainty=x.uncertainty)
