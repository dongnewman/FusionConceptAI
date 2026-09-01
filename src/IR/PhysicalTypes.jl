"""Physical type vocabulary for the v4 typed operator IR."""

struct UnitSignature
    exponents::NTuple{7,Rational{Int64}}
    function UnitSignature(exponents::NTuple{7,<:Real})
        vals = ntuple(i -> Rational{Int64}(exponents[i]), 7)
        new(vals)
    end
end
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

@enum ApplicabilityStatus required not_applicable
@enum MatchStatus unique_match no_match ambiguous out_of_domain invalid_signature
@enum ResolutionStatus resolved terminal_deferred
@enum LifecycleStatus proposed compiled proof_pruned dormant materialized low_fidelity_evaluated frontier_admitted high_fidelity_pending integrated_executed terminal_classified
@enum StageOutcome pass physical_fail numerical_fail unknown not_applicable_stage terminal_deferred_stage
@enum TerminalDisposition credible_within_scope terminal_physical_fail terminal_numerical_fail terminal_unknown terminal_unsupported

struct ApplicabilityRecord
    obligation::String
    status::ApplicabilityStatus
    proof_ref::Union{Nothing,String}
    function ApplicabilityRecord(obligation::AbstractString, status::ApplicabilityStatus, proof_ref=nothing)
        status == not_applicable && (proof_ref isa AbstractString && !isempty(proof_ref) || throw(ArgumentError("not_applicable requires proof_ref")))
        new(String(obligation), status, proof_ref === nothing ? nothing : String(proof_ref))
    end
end

struct EvidenceRef
    evidence_id::String
    function EvidenceRef(id::AbstractString)
        isempty(id) && throw(ArgumentError("evidence_id cannot be empty"))
        new(String(id))
    end
end
